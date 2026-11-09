#!/usr/bin/env Rscript
# Woodchester V12I v0: entry, temporary absence, survival, observation.
# SYNTHETIC DATA ONLY. No Supabase access and no changes to V11.
# This is an identifiability/implementation test, NOT an empirical immigration estimate.
set.seed(20261109)
out <- "outputs/v12_immigration_prototype"
dir.create(out, showWarnings = FALSE, recursive = TRUE)

# States: N=not yet entered, I=alive/inside, O=alive/outside,
# D=dead. 'Outside' is temporary availability, NOT proved emigration.
states <- c("N", "I", "O", "D")
N <- 400L; T <- 16L
truth <- c(psi = .12, gamma = .15, phi = .87, exit = .14, return = .40)
# Known observation parameters in this first experiment; later estimate/calibrate.
obs <- c(p_inside_core = .40, p_inside_edge = .12,
         p_outside_core = .002, p_outside_edge = .018, recovery = .18)
# y: 0=no record, 1=core capture, 2=edge capture, 3=dead recovery.
# Source labels below are latent truth for simulation, not observed data.
origin <- rep(NA_character_, N)
state <- matrix(1L, N, T, dimnames = list(NULL, NULL)) # 1=N,2=I,3=O,4=D
y <- matrix(0L, N, T)

transition <- function(par) {
  with(as.list(par), {
    A <- matrix(0, 4, 4)
    A[1, ] <- c(1 - gamma, gamma, 0, 0)
    A[2, ] <- c(0, phi * (1-exit), phi * exit, 1-phi)
    A[3, ] <- c(0, phi * return, phi * (1-return), 1-phi)
    A[4, 4] <- 1
    A
  })
}
A <- transition(truth)
state[,1] <- sample.int(2, N, replace = TRUE, prob = c(1-truth["psi"], truth["psi"]))
origin[state[,1] == 2] <- sample(c("immigrant","locally_recruited"),
                                 sum(state[,1] == 2), TRUE, prob=c(.6,.4))

draw_observation <- function(previous, current) {
  if (current == 4L && previous %in% 2:3 &&
      runif(1) < obs["recovery"]) return(3L)
  if (current == 2L)
    return(sample(0:2, 1, prob=c(1-obs["p_inside_core"]-obs["p_inside_edge"],
                                  obs["p_inside_core"],obs["p_inside_edge"])))
  if (current == 3L)
    return(sample(0:2, 1, prob=c(1-obs["p_outside_core"]-obs["p_outside_edge"],
                                  obs["p_outside_core"],obs["p_outside_edge"])))
  0L
}
for (i in seq_len(N)) y[i,1] <- draw_observation(1L, state[i,1])
for (tt in 2:T) {
  for (i in seq_len(N)) {
    prev <- state[i,tt-1]
    state[i,tt] <- sample.int(4L, 1L, prob=A[prev,])
    if (prev == 1L && state[i,tt] == 2L)
      origin[i] <- sample(c("immigrant","locally_recruited"),1L,prob=c(.6,.4))
    y[i,tt] <- draw_observation(prev, state[i,tt])
  }
}
# Transition-dependent emission matrices B[[code+1]][previous, current]
# Capture probability depends on latent availability and recovery happens
# only at the transition into death; an old dead animal cannot be recovered again.
emissions <- function(obs, include_recovery = TRUE) {
  B <- lapply(seq_len(4), function(k) matrix(0,4,4))
  for (a in 1:4) for (b in 1:4) {
    if (b == 1L) B[[1]][a,b] <- 1
    if (b == 2L) {
      B[[2]][a,b] <- obs["p_inside_core"]
      B[[3]][a,b] <- obs["p_inside_edge"]
      B[[1]][a,b] <- 1 - B[[2]][a,b] - B[[3]][a,b]
    }
    if (b == 3L) {
      B[[2]][a,b] <- obs["p_outside_core"]
      B[[3]][a,b] <- obs["p_outside_edge"]
      B[[1]][a,b] <- 1 - B[[2]][a,b] - B[[3]][a,b]
    }
    if (b == 4L) {
      q <- if (include_recovery && a %in% 2:3) obs["recovery"] else 0
      B[[4]][a,b] <- q
      B[[1]][a,b] <- 1-q
    }
  }
  B
}
# Forward algorithm integrates over all unobserved state paths.
# This experimental likelihood assumes the number of candidates N and the
# initial-entry probability psi are KNOWN. That is not true for the real data.
loglik <- function(par, dat, obs, psi, include_recovery = TRUE) {
  A <- transition(par)
  B <- emissions(obs, include_recovery)
  initial <- c(1-psi, psi, 0, 0)
  # y at first occasion has no previous-state transition.
  alpha <- matrix(rep(initial, each=nrow(dat)), nrow(dat), 4)
  for (code in 0:3) {
    sel <- which(dat[,1] == code)
    if (length(sel)) alpha[sel,] <- sweep(alpha[sel,,drop=FALSE], 2,
                                           B[[code+1]][1,], "*")
  }
  scale <- rowSums(alpha)
  if (any(scale <= 0)) return(-Inf)
  total <- sum(log(scale))
  alpha <- alpha / scale
  for (tt in 2:ncol(dat)) {
    next_alpha <- matrix(0, nrow(dat), 4)
    for (code in 0:3) {
      sel <- which(dat[,tt] == code)
      if (length(sel)) next_alpha[sel,] <-
        alpha[sel,,drop=FALSE] %*% (A * B[[code+1]])
    }
    scale <- rowSums(next_alpha)
    if (any(scale <= 0)) return(-Inf)
    total <- total + sum(log(scale))
    alpha <- next_alpha / scale
  }
  total
}
# fit entry, survival, exit and return; hold observation probabilities fixed
fit <- function(dat, use_recoveries) {
  if (!use_recoveries) dat[dat == 3L] <- 0L
  negative_ll <- function(theta) {
    par <- setNames(plogis(theta), c("gamma","phi","exit","return"))
    val <- loglik(par, dat, obs, truth["psi"], use_recoveries)
    if (!is.finite(val)) return(1e12)
    -val
  }
  starts <- c(gamma=.12,phi=.80,exit=.20,return=.35)
  opt <- optim(qlogis(starts), negative_ll, method="BFGS",
               control=list(maxit=350, reltol=1e-9))
  list(estimate=setNames(plogis(opt$par),names(starts)),
       logLik=-opt$value, convergence=opt$convergence)
}
with_recoveries <- fit(y, TRUE)
without_recoveries <- fit(y, FALSE)
results <- data.frame(parameter=c("gamma","phi","exit","return"),
                      truth=unname(truth[c("gamma","phi","exit","return")]),
                      fit_with_deaths=unname(with_recoveries$estimate),
                      fit_without_deaths=unname(without_recoveries$estimate))
write.csv(results,file.path(out,"parameter_recovery.csv"),row.names=FALSE)
write.csv(data.frame(id=rep(seq_len(N),each=T),
                     year=rep(seq_len(T),times=N),
                     observed=as.vector(t(y))),
          file.path(out,"synthetic_observations.csv"),row.names=FALSE)
saveRDS(list(truth=truth, observation=obs, origin_truth=origin,
             states_truth=state, detections=y,
             with_deaths=with_recoveries, without_deaths=without_recoveries),
        file.path(out,"simulation_and_fits.rds"))
cat("\n=== SYNTHETIC IMMIGRATION / AVAILABILITY PROTOTYPE ===\n")
cat("Candidates:", N, "| Years:", T, "\n")
cat("Individuals ever detected alive:", sum(rowSums(y == 1L | y == 2L)>0), "\n")
cat("Dead recoveries:", sum(y == 3L), "\n")
cat("Convergence codes (0 expected):",
    with_recoveries$convergence, without_recoveries$convergence, "\n")
print(results, row.names=FALSE, digits=3)
cat("\nResults saved to", out, "\n")
cat("IMPORTANT: rates here are simulated, not Woodchester estimates.\n")
