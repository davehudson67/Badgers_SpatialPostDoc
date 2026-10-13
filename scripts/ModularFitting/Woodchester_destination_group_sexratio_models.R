# =============================================================================
# WOODCHESTER DESTINATION SOCIAL-GROUP SEX-RATIO MODELS
#
# Lightweight development analysis following the destination sex-ratio audit.
# Two pre-specified questions:
#   1) FOLLOW-UP: after an observed group switch, is the mover observed with a
#      social group at t+1, and does that depend on mover sex / destination sex ratio?
#   2) SETTLEMENT: conditional on observed t+1 social-group follow-up, does the
#      mover remain in the destination group, and does that depend on mover sex /
#      destination sex ratio?
#
# Both models require >=3 OTHER sex-known badgers in the destination group-year.
# Destination female proportion excludes the focal mover.
# Female proportion is centred at 50% and scaled per +10 percentage points.
# Destination group size is centred at the analysis-sample median and scaled per
# +5 other sex-known badgers. A 5-year calendar-period factor adjusts for broad
# temporal changes in observation/trapping conditions.
# Repeated switch events from the same badger use badger-cluster robust covariance.
# This is a lightweight development analysis, not a latent movement model.
# =============================================================================

library(tidyverse)

ENTRY_FILE <- "results/destination_group_sexratio_entry_events.csv"
if(!file.exists(ENTRY_FILE)) stop("Missing required file: ",ENTRY_FILE,". Run Woodchester_destination_group_sexratio_audit.R first.")

set.seed(7092064)
N_DRAW <- as.integer(Sys.getenv("N_DRAW","10000"))

x <- read_csv(ENTRY_FILE,show_col_types=FALSE) %>%
  mutate(tattoo=trimws(as.character(tattoo)),sex=trimws(as.character(sex)),
         male=as.integer(sex=="Male"),entry_year=as.integer(entry_year),
         dest_n_other=as.numeric(dest_n_other),dest_prop_female_other=as.numeric(dest_prop_female_other),
         has_tplus1=as.logical(has_tplus1),stay_next_year=as.integer(stay_next_year)) %>%
  filter(sex %in% c("Female","Male"),dest_n_other>=3,is.finite(dest_prop_female_other),
         dest_prop_female_other>=0,dest_prop_female_other<=1,!is.na(entry_year))

if(!nrow(x)) stop("No eligible entry events after >=3-other destination filter.")
SIZE_CENTER <- median(x$dest_n_other)
x <- x %>%
  mutate(female10=(dest_prop_female_other-.50)/.10,
         dest_size5=(dest_n_other-SIZE_CENTER)/5,
         period5=factor(5L*(entry_year%/%5L)))

inv_psd <- function(M){
  M <- (M+t(M))/2
  ee <- eigen(M,symmetric=TRUE)
  tol <- max(1e-12,max(abs(ee$values))*1e-10)
  keep <- ee$values>tol
  if(!any(keep)) stop("Information matrix has no positive eigenvalues.")
  V <- ee$vectors[,keep,drop=FALSE]
  V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)
}

rmvn_psd <- function(n,mu,Sigma){
  mu <- as.numeric(mu); Sigma <- as.matrix(Sigma); Sigma <- (Sigma+t(Sigma))/2
  ee <- eigen(Sigma,symmetric=TRUE); ee$values[ee$values<1e-12] <- 1e-12
  A <- ee$vectors %*% diag(sqrt(ee$values),nrow=length(ee$values))
  Z <- matrix(rnorm(n*length(mu)),nrow=n)
  out <- sweep(Z %*% t(A),2,mu,"+")
  colnames(out) <- names(mu)
  out
}

fit_cluster_logit <- function(d,outcome_name){
  d <- d %>% mutate(outcome=as.integer(.data[[outcome_name]]))
  if(!all(d$outcome %in% c(0L,1L))) stop("Invalid binary outcome in ",outcome_name)
  form <- outcome ~ male*female10 + dest_size5 + period5
  fit <- glm(form,data=d,family=binomial())
  if(!isTRUE(fit$converged)) stop("GLM failed to converge for ",outcome_name)
  X <- model.matrix(fit); y <- model.response(model.frame(fit)); mu <- fitted(fit)
  cf_all <- coef(fit); active <- which(is.finite(cf_all)); X <- X[,active,drop=FALSE]; cf <- cf_all[active]
  names(cf) <- colnames(X)
  w <- pmax(mu*(1-mu),1e-12)
  bread <- inv_psd(crossprod(X,X*w))
  score_rows <- X*as.numeric(y-mu)
  U <- rowsum(score_rows,group=d$tattoo,reorder=FALSE)
  meat <- crossprod(U)
  G <- nrow(U); N <- nrow(X); K <- ncol(X)
  correction <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1
  V <- bread %*% (correction*meat) %*% bread; V <- (V+t(V))/2
  rownames(V) <- colnames(V) <- names(cf)
  dr <- rmvn_psd(N_DRAW,cf,V); colnames(dr) <- names(cf)
  list(data=d,fit=fit,beta=cf,V=V,draws=dr,n=nrow(d),events=sum(y),badgers=n_distinct(d$tattoo),clusters=G)
}

summarise_coef <- function(obj,model_label){
  dr <- obj$draws
  wanted <- c("male"="male","female10"="female_prop_per_10pp","male:female10"="male_x_female_prop_per_10pp","dest_size5"="destination_size_per_5")
  bind_rows(lapply(names(wanted),function(nm){
    if(!nm %in% colnames(dr)) return(NULL)
    z <- dr[,nm]
    tibble(model=model_label,parameter=unname(wanted[nm]),n_draws=length(z),mean=mean(z),sd=sd(z),median=median(z),
           q025=unname(quantile(z,.025)),q975=unname(quantile(z,.975)),P_gt_0=mean(z>0),
           OR_median=median(exp(z)),OR_q025=unname(quantile(exp(z),.025)),OR_q975=unname(quantile(exp(z),.975)))
  }))
}

# Marginal-standardized predicted probabilities: set sex and destination female
# proportion for every observed row while retaining each row's observed group size
# and period, then average predictions. This avoids choosing an arbitrary period.
marginal_predictions <- function(obj,model_label){
  d0 <- obj$data; beta_draws <- obj$draws
  bind_rows(lapply(c("Female","Male"),function(sx){
    bind_rows(lapply(c(.30,.50,.70),function(pf){
      nd <- d0 %>% mutate(male=as.integer(sx=="Male"),female10=(pf-.50)/.10)
      Xn <- model.matrix(delete.response(terms(obj$fit)),data=nd)
      Xn <- Xn[,colnames(beta_draws),drop=FALSE]
      # Average predicted probability for each robust coefficient draw.
      # 10k draws x ~500 rows is small enough for this development analysis.
      eta <- beta_draws %*% t(Xn)
      pp <- rowMeans(plogis(eta))
      tibble(model=model_label,sex=sx,dest_prop_female=pf,n_draws=length(pp),
             prob_median=median(pp),prob_q025=unname(quantile(pp,.025)),prob_q975=unname(quantile(pp,.975)))
    }))
  }))
}

cat("\n============================================================\n")
cat("DESTINATION SEX-RATIO FOLLOW-UP + SETTLEMENT MODELS\n")
cat("============================================================\n")
cat("Eligible group-switch events (>=3 destination others):",nrow(x),"\n")
cat("Distinct movers:",n_distinct(x$tattoo),"\n")
cat("Destination group-size centring value:",SIZE_CENTER,"other sex-known badgers\n")
cat("Observed social-group follow-up at t+1:",sum(x$has_tplus1),"/",nrow(x),sprintf("(%.1f%%)",100*mean(x$has_tplus1)),"\n")
cat("Movers with >1 eligible switch event:",sum(table(x$tattoo)>1L),"\n")

follow <- fit_cluster_logit(x %>% mutate(followup_tplus1=as.integer(has_tplus1)),"followup_tplus1")
settle_dat <- x %>% filter(has_tplus1,!is.na(stay_next_year))
settle <- fit_cluster_logit(settle_dat,"stay_next_year")

model_audit <- tibble(
  model=c("FOLLOWUP","SETTLEMENT"),
  n_rows=c(follow$n,settle$n),
  n_events=c(follow$events,settle$events),
  event_rate=c(follow$events/follow$n,settle$events/settle$n),
  n_badgers=c(follow$badgers,settle$badgers),
  n_clusters=c(follow$clusters,settle$clusters)
)
coef_summary <- bind_rows(summarise_coef(follow,"FOLLOWUP"),summarise_coef(settle,"SETTLEMENT"))
predictions <- bind_rows(marginal_predictions(follow,"FOLLOWUP"),marginal_predictions(settle,"SETTLEMENT"))

cat("\nMODEL AUDIT\n"); print(model_audit,width=Inf)
cat("\nCORE COEFFICIENTS\n"); print(coef_summary,n=Inf,width=Inf)
cat("\nMARGINAL-STANDARDIZED PREDICTED PROBABILITIES\n"); print(predictions,n=Inf,width=Inf)
cat("\nInterpretation:\n")
cat("  FOLLOWUP outcome = observed with any social group at t+1.\n")
cat("  SETTLEMENT outcome = same destination group at t+1, conditional on observed t+1.\n")
cat("  female_prop coefficient = effect of +10 percentage points female among OTHER destination-group badgers.\n")
cat("  male:female_prop interaction = whether that female-proportion slope differs for male movers.\n")
cat("  male main effect is male vs female at a 50:50 destination, adjusted for size and period.\n")

prefix <- "results/destination_group_sexratio_models"
saveRDS(list(settings=list(min_dest_other=3,female_reference=.50,female_scale=.10,size_center=SIZE_CENTER,size_scale=5,n_draw=N_DRAW,
                           period_adjustment="5-year factor",covariance="badger-cluster robust"),
             model_audit=model_audit,coefficient_summary=coef_summary,predictions=predictions,
             followup=list(coefficients=follow$beta,covariance=follow$V),
             settlement=list(coefficients=settle$beta,covariance=settle$V)),paste0(prefix,".rds"))
write_csv(model_audit,paste0(prefix,"_audit.csv"))
write_csv(coef_summary,paste0(prefix,"_summary.csv"))
write_csv(predictions,paste0(prefix,"_predictions.csv"))
cat("\nSaved:\n",prefix,".rds\n",prefix,"_audit.csv\n",prefix,"_summary.csv\n",prefix,"_predictions.csv\n",sep="")
