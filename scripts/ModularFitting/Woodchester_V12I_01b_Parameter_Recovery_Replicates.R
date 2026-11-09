#!/usr/bin/env Rscript
# V12I-01b: repeated synthetic parameter-recovery experiment.
# This reuses the exact simulator and likelihood from V12I-01.
# It does not use Supabase or real Woodchester observations.
# Running sys.source() reruns the fixed-seed V12I-01 example once.
base <- "scripts/ModularFitting/Woodchester_V12I_01_Immigration_Availability_Simulation.R"
if (!file.exists(base)) stop("Run from the repository root")
e <- new.env(parent = globalenv())
sys.source(base, envir = e)

reps <- as.integer(Sys.getenv("V12I_NSIM", "20"))
if (is.na(reps) || reps < 2L || reps > 200L)
  stop("V12I_NSIM must be between 2 and 200")
set.seed(20261110)
N <- nrow(e$y)
T <- ncol(e$y)
A <- e$transition(e$truth)
out <- "outputs/v12_immigration_prototype"
rows <- vector("list", reps)

simulate_one <- function() {
  st <- matrix(1L, N, T)
  yy <- matrix(0L, N, T)
  st[,1] <- sample.int(2L, N, replace = TRUE,
                       prob = c(1-e$truth["psi"], e$truth["psi"]))
  for (i in seq_len(N))
    yy[i,1] <- e$draw_observation(1L, st[i,1])
  for (tt in 2:T) for (i in seq_len(N)) {
    old <- st[i,tt-1]
    st[i,tt] <- sample.int(4L, 1L, prob = A[old,])
    yy[i,tt] <- e$draw_observation(old, st[i,tt])
  }
  yy
}

for (b in seq_len(reps)) {
  yy <- simulate_one()
  fit1 <- e$fit(yy, TRUE)
  fit0 <- e$fit(yy, FALSE)
  for (model in c("with_deaths", "without_deaths")) {
    v <- if (model == "with_deaths") fit1 else fit0
    rows[[b]] <- if (model == "with_deaths") {
      data.frame(replicate=b, model=model,
                 n_alive_detected=sum(rowSums(yy == 1L | yy == 2L) > 0L),
                 n_dead_recoveries=sum(yy == 3L),
                 convergence=v$convergence,
                 gamma=unname(v$estimate["gamma"]), phi=unname(v$estimate["phi"]),
                 exit=unname(v$estimate["exit"]), return_prob=unname(v$estimate["return"]))
    } else rows[[b]]
    if (model == "without_deaths")
      rows[[b]] <- rbind(rows[[b]],
        data.frame(replicate=b, model=model,
                   n_alive_detected=sum(rowSums(yy == 1L | yy == 2L) > 0L),
                   n_dead_recoveries=sum(yy == 3L),
                   convergence=v$convergence,
                   gamma=unname(v$estimate["gamma"]), phi=unname(v$estimate["phi"]),
                   exit=unname(v$estimate["exit"]), return_prob=unname(v$estimate["return"])))
  }
  cat(sprintf("Replication %d/%d: recoveries=%d, return fits %.3f / %.3f\n",
              b, reps, sum(yy == 3L),
              fit1$estimate["return"], fit0$estimate["return"]))
}
result <- do.call(rbind, rows)
rownames(result) <- NULL
write.csv(result, file.path(out, "parameter_recovery_replicates.csv"),
          row.names=FALSE)
cat("\n=== PARAMETER RECOVERY OVER REPLICATES ===\n")
truth_vals <- c(gamma=unname(e$truth["gamma"]), phi=unname(e$truth["phi"]),
                exit=unname(e$truth["exit"]), return_prob=unname(e$truth["return"]))
summary_rows <- list()
for (model in unique(result$model)) {
  d <- result[result$model == model,]
  for (key in names(truth_vals)) {
    if (!key %in% names(d)) stop("Missing numeric parameter column: ", key)
    estimates <- d[[key]]
    if (!is.numeric(estimates)) stop("Non-numeric parameter column: ", key)
    true <- unname(truth_vals[key])
    summary_rows[[length(summary_rows)+1L]] <- data.frame(
      model=model, parameter=key, truth=true,
      mean_fit=mean(estimates),
      mean_bias=mean(estimates-true),
      rmse=sqrt(mean((estimates-true)^2)),
      q05=unname(quantile(estimates, 0.05)),
      q95=unname(quantile(estimates, 0.95)),
      convergence_ok=sum(d$convergence == 0L),
      n_reps=nrow(d))
  }
}
summ <- do.call(rbind, summary_rows)
write.csv(summ, file.path(out, "parameter_recovery_replicates_summary.csv"),
          row.names=FALSE)
print(summ, digits=3, row.names=FALSE)
cat("\nNote: empirical 5th/95th quantiles of point estimates are NOT\n",
    "confidence or credible intervals for a single fit.\n", sep="")
cat("This experiment assumes known candidate count, psi and detection.\n")
