# =============================================================================
# WOODCHESTER V7b-M SAME-SOCIAL-GROUP INFECTION-PRESSURE SENSITIVITY
#
# Mechanistic follow-up to the frozen primary V7b-M total-effect analysis.
#
# Models fitted on the SAME pressure-supported risk rows:
#   M0_CC        movement + sex + quarter + 5-year period
#   M1_RAW       M0_CC + raw same-group infection prevalence
#   M1_SMOOTH    M0_CC + smoothed same-group infection prevalence
#   M2_INTERACT  M1_RAW + movement x pressure
#
# Pressure is evaluated at Q4 of movement-ending year t.
# Outcome is infection acquisition in Q1-Q4 of t+1.
#
# M0_CC is essential: it distinguishes sample-restriction effects from actual
# pressure adjustment.
#
# Same-group pressure may lie on the movement -> infection pathway, so M1/M2
# are mechanistic/direct-effect sensitivities, NOT replacements for primary V7b.
#
# Within each paired latent history:
#   glm discrete-time hazard -> badger-cluster-robust covariance -> MVN draws.
# Equal numbers of draws are pooled over paired histories.
# =============================================================================

library(tidyverse)

MOVE_FILE  <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
PAIR_FILE  <- "data/badger_phase2_paired_latent_inputs.rds"
INF_FILE   <- "data/badger_infection_trajectories_all_tests_inferred.rds"
PRESS_FILE <- "data/badger_V7b_spatial_infection_pressure_500draws.rds"

for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,PRESS_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
paired <- readRDS(PAIR_FILE)
inf <- readRDS(INF_FILE)
press <- readRDS(PRESS_FILE)

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","1500"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","100"))
MIN_GROUP_N <- as.integer(Sys.getenv("MIN_GROUP_N","1"))
SEED <- as.integer(Sys.getenv("SEED","7092042"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","FULL_1500")

set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)
INF_IDS <- trimws(as.character(inf$tattoo))

pidx <- as_tibble(press$interval_index) %>%
  mutate(
    pressure_row=row_number(),
    tattoo=trimws(as.character(tattoo)),
    model_i=as.integer(model_i),
    interval_col=as.integer(interval_col),
    pressure_year=as.integer(pressure_year),
    focal_inf_row=as.integer(focal_inf_row)
  )

P_RAW <- press$matrices$samegroup_prev
P_SMOOTH <- press$matrices$samegroup_prev_smooth
GROUP_N <- as.integer(press$support_vectors$samegroup_n)

if(!all(dim(P_RAW)==c(nrow(pidx),ncol(inf$infection_time))))
  stop("Pressure matrix dimension mismatch.")

last_live <- setNames(
  as.integer(paired$live_bounds$last_live_time),
  trimws(as.character(paired$live_bounds$tattoo))
)

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))

if(MAX_PAIRS < nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS)
    pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS,replace=FALSE))
  pair_index <- pair_index[pick,,drop=FALSE]
}

rmvn_psd <- function(n,mu,Sigma){
  Sigma <- (Sigma+t(Sigma))/2
  ee <- eigen(Sigma,symmetric=TRUE)
  ee$values[ee$values<1e-10] <- 1e-10
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  Z <- matrix(rnorm(n*length(mu)),nrow=n)
  sweep(Z %*% t(A),2,mu,"+")
}

cluster_vcov_glm <- function(fit,cluster){
  X <- model.matrix(fit)
  cf <- coef(fit)
  active <- which(is.finite(cf))
  if(!length(active)) stop("No estimable coefficients.")

  X <- X[,active,drop=FALSE]
  cf <- cf[active]

  mu <- fitted(fit)
  y <- model.response(model.frame(fit))
  w <- mu*(1-mu)

  XtWX <- crossprod(X,X*w)
  bread <- tryCatch(
    solve(XtWX),
    error=function(e) qr.solve(XtWX,diag(ncol(XtWX)))
  )

  score_rows <- X * as.numeric(y-mu)
  U <- rowsum(score_rows,group=cluster,reorder=FALSE)
  meat <- crossprod(U)

  G <- nrow(U)
  N <- nrow(X)
  K <- ncol(X)
  correction <- if(G>1L && N>K)
    (G/(G-1))*((N-1)/(N-K)) else 1

  V <- bread %*% (correction*meat) %*% bread
  V <- (V+t(V))/2
  rownames(V) <- colnames(V) <- names(cf)

  list(beta=cf,V=V,G=G)
}

fit_one <- function(formula,d,nkeep){
  warns <- character(0)

  fit <- tryCatch(
    withCallingHandlers(
      glm(
        formula,
        family=binomial(link="logit"),
        data=d,
        control=glm.control(maxit=100,epsilon=1e-8)
      ),
      warning=function(w){
        warns <<- c(warns,conditionMessage(w))
        invokeRestart("muffleWarning")
      }
    ),
    error=function(e)e
  )

  if(inherits(fit,"error"))
    return(list(ok=FALSE,draws=NULL,converged=FALSE,
                warning=paste(unique(warns),collapse=" | "),
                message=conditionMessage(fit)))

  if(!isTRUE(fit$converged))
    return(list(ok=FALSE,draws=NULL,converged=FALSE,
                warning=paste(unique(warns),collapse=" | "),
                message="glm did not converge"))

  rob <- tryCatch(cluster_vcov_glm(fit,d$tattoo),error=function(e)e)

  if(inherits(rob,"error"))
    return(list(ok=FALSE,draws=NULL,converged=TRUE,
                warning=paste(unique(warns),collapse=" | "),
                message=paste("cluster covariance failed:",conditionMessage(rob))))

  if(any(!is.finite(rob$V)))
    return(list(ok=FALSE,draws=NULL,converged=TRUE,
                warning=paste(unique(warns),collapse=" | "),
                message="non-finite cluster covariance"))

  dr <- rmvn_psd(nkeep,rob$beta,rob$V)
  colnames(dr) <- names(rob$beta)

  list(ok=TRUE,draws=as_tibble(dr),converged=TRUE,
       warning=paste(unique(warns),collapse=" | "),message="")
}

make_risk_data <- function(move_draw,inf_col){
  st <- as.integer(mov$state_draws[move_draw,pidx$interval_col])
  it_focal <- as.integer(inf$infection_time[pidx$focal_inf_row,inf_col])

  pressure <- as.numeric(P_RAW[,inf_col])
  pressure_smooth <- as.numeric(P_SMOOTH[,inf_col])

  q4_t <- 4L*(pidx$pressure_year-START_YEAR)+4L
  susceptible <- it_focal==0L | it_focal>q4_t

  start_q <- 4L*((pidx$pressure_year+1L)-START_YEAR)+1L
  end_q <- start_q+3L
  llt <- as.integer(last_live[pidx$tattoo])

  support <- !is.na(GROUP_N) &
    GROUP_N>=MIN_GROUP_N &
    is.finite(pressure) &
    is.finite(pressure_smooth)

  keep_interval <- susceptible & start_q<=llt & support
  rr <- which(keep_interval)

  out <- vector("list",length(rr)*2L)
  oo <- 0L

  for(j in rr){
    last_q <- min(end_q[j],llt[j])

    for(qtime in start_q[j]:last_q){
      if(it_focal[j]>0L && it_focal[j]<qtime) break

      q <- ((qtime-1L)%%4L)+1L
      yr <- START_YEAR + ((qtime-1L)%/%4L)
      ev <- as.integer(it_focal[j]>0L && it_focal[j]==qtime)

      oo <- oo+1L
      out[[oo]] <- tibble(
        tattoo=pidx$tattoo[j],
        sex=as.integer(mov$sex[pidx$model_i[j]]),
        movement_state=st[j],
        pressure=pressure[j],
        pressure_smooth=pressure_smooth[j],
        pressure10=10*pressure[j],
        pressure_smooth10=10*pressure_smooth[j],
        group_n=GROUP_N[j],
        outcome_quarter=q,
        outcome_year=yr,
        period_start=5L*(yr%/%5L),
        infection_event=ev
      )

      if(ev==1L) break
    }
  }

  if(!oo) return(tibble())

  bind_rows(out[seq_len(oo)]) %>%
    mutate(
      tattoo=factor(tattoo),
      quarter=factor(outcome_quarter),
      period=factor(period_start)
    )
}

F_M0 <- infection_event ~ movement_state + sex + quarter + period
F_M1 <- infection_event ~ movement_state + pressure10 + sex + quarter + period
F_M1S <- infection_event ~ movement_state + pressure_smooth10 + sex + quarter + period
F_M2 <- infection_event ~ movement_state*pressure10 + sex + quarter + period

cat("\n============================================================\n")
cat("V7b-M SAME-GROUP PRESSURE SENSITIVITY\n")
cat("============================================================\n")
cat("Paired histories:",nrow(pair_index),"\n")
cat("Minimum other badgers in group:",MIN_GROUP_N,"\n")
cat("Draws/history/model:",N_KEEP,"\n")
cat("Covariance: badger-cluster robust\n")
cat("Pressure coefficient scale: +10 percentage points\n\n")

draw_list <- list()
diag_list <- list()
nd <- 0L
ng <- 0L

for(pp in seq_len(nrow(pair_index))){
  move_draw <- pair_index$movement_draw[pp]
  inf_col <- pair_index$infection_col[pp]
  d <- make_risk_data(move_draw,inf_col)

  if(!nrow(d)) stop("Empty risk data at pair ",pair_index$pair_draw[pp])

  if(pp==1L){
    cat("FIRST-PAIR AUDIT\n")
    cat("Risk quarters:",nrow(d),"\n")
    cat("Events:",sum(d$infection_event),"\n")
    cat("Badgers:",n_distinct(d$tattoo),"\n")
    cat("High-mobility risk quarters:",sum(d$movement_state==1L),"\n")
    cat("Median group support:",median(d$group_n),"\n")
    cat("Raw pressure summary:\n")
    print(summary(d$pressure))
    cat("\n")
  }

  fits <- list(
    M0_CC=fit_one(F_M0,d,N_KEEP),
    M1_RAW=fit_one(F_M1,d,N_KEEP),
    M1_SMOOTH=fit_one(F_M1S,d,N_KEEP),
    M2_INTERACTION=fit_one(F_M2,d,N_KEEP)
  )

  for(nm in names(fits)){
    z <- fits[[nm]]
    ng <- ng+1L
    diag_list[[ng]] <- tibble(
      pair_draw=pair_index$pair_draw[pp],
      movement_draw=move_draw,
      infection_col=inf_col,
      model=nm,
      n_rows=nrow(d),
      n_events=sum(d$infection_event),
      n_badgers=n_distinct(d$tattoo),
      n_high_rows=sum(d$movement_state==1L),
      fit_ok=z$ok,
      converged=z$converged,
      warnings=z$warning,
      message=z$message
    )

    if(z$ok){
      dr <- z$draws
      dr$pair_draw <- pair_index$pair_draw[pp]
      dr$model <- nm
      nd <- nd+1L
      draw_list[[nd]] <- dr
    }
  }

  if(pp%%100L==0L)
    cat("Processed pair",pp,"/",nrow(pair_index),"\n")
}

draws <- bind_rows(draw_list)
diag <- bind_rows(diag_list)

cat("\n============================================================\n")
cat("FIT AUDIT\n")
cat("============================================================\n")

fit_audit <- diag %>%
  group_by(model) %>%
  summarise(
    pairs=n(),
    fitted=sum(fit_ok),
    failed=sum(!fit_ok),
    pairs_with_warnings=sum(nchar(warnings)>0),
    median_rows=median(n_rows),
    median_events=median(n_events),
    median_badgers=median(n_badgers),
    median_high_rows=median(n_high_rows),
    .groups="drop"
  )

print(fit_audit,n=Inf,width=Inf)

if(any(!diag$fit_ok)){
  cat("\nFailures:\n")
  print(diag %>% filter(!fit_ok) %>% count(model,message,sort=TRUE),
        n=50,width=Inf)
}

if(any(nchar(diag$warnings)>0)){
  cat("\nWarnings:\n")
  print(diag %>% filter(nchar(warnings)>0) %>% count(model,warnings,sort=TRUE),
        n=50,width=Inf)
}

summarise_parameter <- function(df,param,label){
  x <- df[[param]]
  tibble(
    model=unique(df$model),
    parameter=label,
    mean=mean(x),
    sd=sd(x),
    median=median(x),
    q025=unname(quantile(x,.025)),
    q975=unname(quantile(x,.975)),
    P_gt_0=mean(x>0),
    OR_median=median(exp(x)),
    OR_q025=unname(quantile(exp(x),.025)),
    OR_q975=unname(quantile(exp(x),.975))
  )
}

summary_rows <- list()
ns <- 0L

for(nm in unique(draws$model)){
  z <- draws %>% filter(model==nm)

  if("movement_state"%in%names(z)){
    ns <- ns+1L
    summary_rows[[ns]] <- summarise_parameter(z,"movement_state","beta_move")
  }
  if("pressure10"%in%names(z)){
    ns <- ns+1L
    summary_rows[[ns]] <- summarise_parameter(
      z,"pressure10","beta_pressure_per_10pp"
    )
  }
  if("pressure_smooth10"%in%names(z)){
    ns <- ns+1L
    summary_rows[[ns]] <- summarise_parameter(
      z,"pressure_smooth10","beta_smoothed_pressure_per_10pp"
    )
  }

  int_name <- grep(
    "movement_state:pressure10|pressure10:movement_state",
    names(z),value=TRUE
  )
  if(length(int_name)){
    ns <- ns+1L
    summary_rows[[ns]] <- summarise_parameter(
      z,int_name[1],"beta_move_x_pressure_per_10pp"
    )
  }

  if("sex"%in%names(z)){
    ns <- ns+1L
    summary_rows[[ns]] <- summarise_parameter(z,"sex","beta_sex")
  }
}

param_summary <- bind_rows(summary_rows)

cat("\n============================================================\n")
cat("POOLED COEFFICIENT SUMMARY\n")
cat("============================================================\n")
print(param_summary,n=Inf,width=Inf)

interaction_derived <- tibble()

if("M2_INTERACTION"%in%draws$model){
  z <- draws %>% filter(model=="M2_INTERACTION")
  int_name <- grep(
    "movement_state:pressure10|pressure10:movement_state",
    names(z),value=TRUE
  )

  if(length(int_name)){
    bM <- z$movement_state
    bI <- z[[int_name[1]]]

    interaction_derived <- bind_rows(
      lapply(c(0,.10,.25,.50),function(p){
        lp <- bM+bI*(10*p)
        tibble(
          pressure_prevalence=p,
          OR_move_median=median(exp(lp)),
          OR_move_q025=unname(quantile(exp(lp),.025)),
          OR_move_q975=unname(quantile(exp(lp),.975)),
          P_move_positive=mean(lp>0)
        )
      })
    )

    cat("\n============================================================\n")
    cat("INTERACTION: MOVEMENT OR AT SELECTED SAME-GROUP PRESSURES\n")
    cat("============================================================\n")
    print(interaction_derived,n=Inf,width=Inf)
  }
}

movement_compare <- param_summary %>%
  filter(parameter=="beta_move") %>%
  select(model,median,q025,q975,P_gt_0,OR_median,OR_q025,OR_q975)

cat("\n============================================================\n")
cat("MOVEMENT EFFECT COMPARISON ON SAME PRESSURE-SUPPORTED SAMPLE\n")
cat("============================================================\n")
print(movement_compare,n=Inf,width=Inf)

cat("\nINTERPRETATION GUIDE\n")
cat("- Compare frozen primary V7b-M with M0_CC to diagnose subset selection.\n")
cat("- Compare M0_CC with M1_RAW to diagnose pressure adjustment.\n")
cat("- beta_pressure is per +10 percentage-points same-group prevalence at Q4(t).\n")
cat("- M2 interaction is exploratory and may be imprecise.\n")
cat("- M1/M2 are mechanistic/direct-effect sensitivities, not total-effect replacements.\n")

dir.create("results",showWarnings=FALSE,recursive=TRUE)

out_rds <- paste0(
  "results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,".rds"
)
out_summary <- paste0(
  "results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,"_summary.csv"
)
out_fit <- paste0(
  "results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,"_fit_audit.csv"
)

saveRDS(
  list(
    model="V7b-M same-social-group pressure mechanistic sensitivity",
    coefficient_draws=draws,
    parameter_summary=param_summary,
    movement_comparison=movement_compare,
    interaction_derived=interaction_derived,
    fit_audit=fit_audit,
    fit_diagnostics=diag,
    settings=list(
      min_group_n=MIN_GROUP_N,
      paired_histories=nrow(pair_index),
      draws_per_history=N_KEEP,
      pressure_time="Q4(t)",
      outcome_time="Q1-Q4(t+1)",
      pressure_scale="10 percentage points",
      covariance="badger-cluster robust",
      complete_case_benchmark=TRUE
    )
  ),
  out_rds
)

write_csv(param_summary,out_summary)
write_csv(fit_audit,out_fit)

cat("\nSaved:",out_rds,"\n")
cat("Saved:",out_summary,"\n")
cat("Saved:",out_fit,"\n")
