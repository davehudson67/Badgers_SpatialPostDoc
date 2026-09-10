# =============================================================================
# WOODCHESTER V7b-M ROBUSTNESS PATCH
# Refit only poorly represented conditional posteriors (IS_ESS < 500)
# using 50,000 defensive-mixture importance proposals, then replace their
# equal-weight posterior draws in the pooled modular mixture.
#
# This does NOT change the model. It only improves numerical representation of
# the small number of paired latent histories with weak importance-sampling ESS.
# =============================================================================

library(tidyverse)

IN_FILE <- "results/V7bM_movement_to_infection_FULL_1500.rds"
OUT_FILE <- "results/V7bM_movement_to_infection_FULL_1500_ROBUST.rds"
OUT_CSV <- "results/V7bM_movement_to_infection_FULL_1500_ROBUST_summary.csv"

ESS_THRESHOLD <- 500
N_PROP_RETRY <- 50000L
N_KEEP <- 100L
SEED <- 7092030L

if(!file.exists(IN_FILE)) stop("Missing full V7b-M result: ",IN_FILE)
obj <- readRDS(IN_FILE)
set.seed(SEED)

P <- ncol(obj$design)
X <- obj$design
PRIOR_MEAN <- obj$priors$mean
PRIOR_SD <- obj$priors$sd
par_names <- colnames(X)

if(is.null(par_names)) par_names <- names(PRIOR_MEAN)
if(length(par_names)!=P) stop("Could not recover parameter names.")

n_mat <- obj$pair_counts$n
y_mat <- obj$pair_counts$y
cells <- obj$pair_counts$cells
pair_diag <- obj$pair_diagnostics
pooled_original <- obj$coefficient_draws

bad <- pair_diag %>%
  filter(IS_ESS < ESS_THRESHOLD) %>%
  arrange(IS_ESS)

cat("\n============================================================\n")
cat("V7b-M IMPORTANCE-SAMPLING ROBUSTNESS PATCH\n")
cat("============================================================\n")
cat("Pairs below ESS threshold:",nrow(bad),"/",nrow(pair_diag),"\n")
cat("Threshold:",ESS_THRESHOLD,"\n")
cat("Retry proposals per poor pair:",N_PROP_RETRY,"\n\n")

if(nrow(bad)==0L){
  cat("No poor pairs found. Nothing to patch.\n")
  quit(save="no")
}

print(
  bad %>%
    select(pair_draw,n_risk,n_events,mode_beta_move,IS_ESS,max_importance_weight),
  n=Inf,width=Inf
)

# Utilities --------------------------------------------------------------------
log1pexp <- function(x)
  ifelse(x>0,x+log1p(exp(-x)),log1p(exp(x)))

logpost_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  ll <- sum(y*eta-n*log1pexp(eta))
  lp <- -0.5*sum(((theta-PRIOR_MEAN)/PRIOR_SD)^2)
  ll+lp
}

nlp_one <- function(theta,n,y) -logpost_one(theta,n,y)

grad_nlp_one <- function(theta,n,y){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  g <- as.vector(crossprod(X,y-n*p))-(theta-PRIOR_MEAN)/(PRIOR_SD^2)
  -g
}

hessian_one <- function(theta,n){
  eta <- as.vector(X%*%theta)
  p <- plogis(eta)
  w <- n*p*(1-p)
  crossprod(X,X*w)+diag(1/(PRIOR_SD^2),length(theta))
}

logpost_many <- function(theta_mat,n,y){
  eta <- theta_mat%*%t(X)
  ll <- rowSums(
    sweep(eta,2,y,"*") -
    sweep(log1pexp(eta),2,n,"*")
  )
  z <- sweep(theta_mat,2,PRIOR_MEAN,"-")
  lp <- -0.5*rowSums(sweep(z^2,2,PRIOR_SD^2,"/"))
  ll+lp
}

draw_mvn <- function(n,mu,Sigma){
  R <- chol(Sigma)
  sweep(matrix(rnorm(n*length(mu)),n,length(mu))%*%R,2,mu,"+")
}

logdmvn_many <- function(x,mu,Sigma){
  d <- length(mu)
  md <- mahalanobis(x,center=mu,cov=Sigma)
  logdet <- as.numeric(determinant(Sigma,logarithm=TRUE)$modulus)
  -0.5*(d*log(2*pi)+logdet+md)
}

logsumexp_rows <- function(M){
  m <- apply(M,1,max)
  m + log(rowSums(exp(M-m)))
}

# Patch only poor pairs ---------------------------------------------------------
replacement <- vector("list",nrow(bad))
retry_diag <- vector("list",nrow(bad))

for(bb in seq_len(nrow(bad))){
  pd <- bad$pair_draw[bb]

  # pair_draw is 1:1500 in the full run; locate row defensively.
  rr <- match(pd,pair_diag$pair_draw)
  if(is.na(rr)) stop("Could not locate pair_draw ",pd)

  n <- as.numeric(n_mat[rr,])
  y <- as.numeric(y_mat[rr,])

  opt <- optim(
    par=PRIOR_MEAN,
    fn=nlp_one,
    gr=grad_nlp_one,
    n=n,y=y,
    method="BFGS",
    control=list(maxit=1500,reltol=1e-11)
  )
  if(opt$convergence!=0L)
    warning("optim convergence code ",opt$convergence," for pair_draw ",pd)

  H <- hessian_one(opt$par,n)
  eg <- eigen(H,symmetric=TRUE)
  eg$values[eg$values<1e-8] <- 1e-8
  V <- eg$vectors%*%diag(1/eg$values,P)%*%t(eg$vectors)

  # More defensive than the production proposal:
  # 80% local, 15% broad, 5% very broad.
  V1 <- V*(1.25^2)
  V2 <- V*(2.75^2)
  V3 <- V*(5.0^2)

  comp <- sample.int(
    3,N_PROP_RETRY,replace=TRUE,
    prob=c(.80,.15,.05)
  )

  prop <- matrix(NA_real_,N_PROP_RETRY,P)
  if(any(comp==1L)) prop[comp==1L,] <- draw_mvn(sum(comp==1L),opt$par,V1)
  if(any(comp==2L)) prop[comp==2L,] <- draw_mvn(sum(comp==2L),opt$par,V2)
  if(any(comp==3L)) prop[comp==3L,] <- draw_mvn(sum(comp==3L),opt$par,V3)

  LQ <- cbind(
    log(.80)+logdmvn_many(prop,opt$par,V1),
    log(.15)+logdmvn_many(prop,opt$par,V2),
    log(.05)+logdmvn_many(prop,opt$par,V3)
  )
  logq <- logsumexp_rows(LQ)

  logw <- logpost_many(prop,n,y)-logq
  logw <- logw-max(logw)
  w <- exp(logw)
  w <- w/sum(w)

  is_ess <- 1/sum(w^2)
  max_w <- max(w)

  keep <- sample.int(N_PROP_RETRY,N_KEEP,replace=TRUE,prob=w)
  repl <- as_tibble(prop[keep,,drop=FALSE])
  names(repl) <- par_names
  repl <- repl %>% mutate(pair_draw=pd,.before=1)
  replacement[[bb]] <- repl

  retry_diag[[bb]] <- tibble(
    pair_draw=pd,
    old_IS_ESS=bad$IS_ESS[bb],
    old_max_weight=bad$max_importance_weight[bb],
    retry_IS_ESS=is_ess,
    retry_max_weight=max_w,
    mode_beta_move=opt$par[match("beta_move",par_names)],
    optim_code=opt$convergence
  )

  cat(
    "pair",pd,
    ": ESS",round(bad$IS_ESS[bb],1),"->",round(is_ess,1),
    "; max w",signif(bad$max_importance_weight[bb],3),"->",signif(max_w,3),"\n"
  )
}

replacement <- bind_rows(replacement)
retry_diag <- bind_rows(retry_diag)

# Replace exactly N_KEEP draws for each poor pair, preserving equal pair weight.
pooled_patched <- pooled_original %>%
  filter(!pair_draw%in%bad$pair_draw) %>%
  bind_rows(replacement) %>%
  arrange(pair_draw)

expected_n <- nrow(pair_diag)*N_KEEP
if(nrow(pooled_patched)!=expected_n)
  stop("Patched pooled posterior has ",nrow(pooled_patched),
       " rows; expected ",expected_n)

# Summaries --------------------------------------------------------------------
summ <- function(x){
  tibble(
    mean=mean(x),
    sd=sd(x),
    median=median(x),
    q025=unname(quantile(x,.025)),
    q975=unname(quantile(x,.975)),
    P_gt_0=mean(x>0)
  )
}

main_summary <- bind_rows(
  lapply(c("alpha","beta_move","beta_sex"),function(nm)
    summ(pooled_patched[[nm]]) %>%
      mutate(parameter=nm,.before=1))
)

effects <- pooled_patched %>%
  transmute(
    pair_draw,
    beta_move,beta_sex,
    OR_high_mobility=exp(beta_move),
    OR_male=exp(beta_sex)
  )

derived_summary <- tibble(
  quantity=c("OR_high_mobility","OR_male"),
  median=c(median(effects$OR_high_mobility),median(effects$OR_male)),
  q025=c(quantile(effects$OR_high_mobility,.025),quantile(effects$OR_male,.025)),
  q975=c(quantile(effects$OR_high_mobility,.975),quantile(effects$OR_male,.975))
)

orig_beta <- pooled_original$beta_move
new_beta <- pooled_patched$beta_move

comparison <- tibble(
  version=c("original","robust_patched"),
  beta_move_median=c(median(orig_beta),median(new_beta)),
  beta_move_q025=c(quantile(orig_beta,.025),quantile(new_beta,.025)),
  beta_move_q975=c(quantile(orig_beta,.975),quantile(new_beta,.975)),
  P_beta_move_gt_0=c(mean(orig_beta>0),mean(new_beta>0)),
  OR_median=c(median(exp(orig_beta)),median(exp(new_beta))),
  OR_q025=c(quantile(exp(orig_beta),.025),quantile(exp(new_beta),.025)),
  OR_q975=c(quantile(exp(orig_beta),.975),quantile(exp(new_beta),.975))
)

cat("\n============================================================\n")
cat("ORIGINAL VS ROBUST-PATCHED V7b-M\n")
cat("============================================================\n")
print(comparison,width=Inf)

cat("\nRetry diagnostics:\n")
print(retry_diag,n=Inf,width=Inf)

cat("\nPatched posterior:\n")
print(main_summary,n=Inf,width=Inf)
print(derived_summary,n=Inf,width=Inf)

# Save -------------------------------------------------------------------------
obj$coefficient_draws_original <- obj$coefficient_draws
obj$coefficient_draws <- pooled_patched
obj$effect_draws <- effects
obj$main_summary <- main_summary
obj$derived_summary <- derived_summary
obj$robustness_patch <- list(
  ESS_threshold=ESS_THRESHOLD,
  n_prop_retry=N_PROP_RETRY,
  n_keep=N_KEEP,
  seed=SEED,
  poor_pairs=bad$pair_draw,
  retry_diagnostics=retry_diag,
  comparison=comparison
)

saveRDS(obj,OUT_FILE)

bind_rows(
  main_summary %>%
    transmute(
      type="coefficient",name=parameter,
      median,q025,q975,
      probability_positive=P_gt_0
    ),
  derived_summary %>%
    transmute(
      type="derived",name=quantity,
      median,q025,q975,
      probability_positive=NA_real_
    )
) %>%
  write_csv(OUT_CSV)

cat("\nSaved:",OUT_FILE,"\n")
cat("Saved:",OUT_CSV,"\n")
