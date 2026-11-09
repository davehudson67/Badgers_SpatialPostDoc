# Woodchester V12A: rapid conditional CJS benchmark
# Source: frozen Supabase V12 encounter snapshot
# No changes to Supabase, snapshots, or historical models.

root <- "data/model_snapshots/v12_20261106T103144Z_1079872"
out <- "outputs/v12a_baseline"
dir.create(out, recursive = TRUE, showWarnings = FALSE)

x <- readRDS(file.path(root, "qualifying_live.rds"))
x$capture_date <- as.Date(x$capture_date)
x <- x[!is.na(x$capture_date) &
         x$capture_date <= as.Date("2025-12-31"), ]

stopifnot(!anyNA(x$tattoo))

year <- as.integer(format(x$capture_date, "%Y"))
q <- (as.integer(format(x$capture_date, "%m")) - 1L) %/% 3L + 1L
occasion <- (year - 1976L) * 4L + q

stopifnot(all(occasion >= 1L & occasion <= 200L))

ids <- sort(unique(as.character(x$tattoo)))
n <- length(ids)
T <- 200L

# Binary detection history: one per tattoo-quarter.
y <- matrix(FALSE, nrow = n, ncol = T)
y[cbind(match(as.character(x$tattoo), ids), occasion)] <- TRUE

first <- max.col(y, ties.method = "first")
stopifnot(all(rowSums(y) > 0), n == 3214L)

years <- rep(1976:2025, each = 4)
quarters <- rep(1:4, times = 50)

# Conditional CJS likelihood after the first live capture.
# Alive and dead states are summed over by forward recursion.
# Death is an absorbing state and cannot produce live captures.

nll <- function(theta, era = FALSE) {
  phi <- plogis(theta[1])

  lp <- theta[2] +
    theta[3] * (quarters == 2L) +
    theta[4] * (quarters == 3L) +
    theta[5] * (quarters == 4L)

  if (era) {
    lp <- lp +
      theta[6] * (years <= 1981) +
      theta[7] * (years >= 2016)
  }

  p <- plogis(lp)

  alive <- rep(1, n)
  dead <- rep(0, n)
  ll <- 0

  for (t in 2:T) {
    ii <- which(first < t)
    if (!length(ii)) next

    a <- alive[ii] * phi
    d <- dead[ii] + alive[ii] * (1 - phi)

    detected <- y[ii, t]
    a <- a * ifelse(detected, p[t], 1 - p[t])
    d[detected] <- 0

    total <- a + d
    if (any(!is.finite(total)) || any(total <= 0))
      return(1e100)

    ll <- ll + sum(log(total))
    alive[ii] <- a / total
    dead[ii] <- d / total
  }

  -ll
}

cat("Individuals:", n, "\n")
cat("Observed badger-quarters:", sum(y), "\n")
cat("One-quarter individuals:", sum(rowSums(y) == 1L), "\n")

cat("\nFitting V12A-0...\n")
m0 <- optim(
  rep(0, 5),
  nll,
  era = FALSE,
  method = "BFGS",
  control = list(maxit = 400, reltol = 1e-9)
)

cat("Fitting V12A-1...\n")
m1 <- optim(
  c(m0$par, 0, 0),
  nll,
  era = TRUE,
  method = "BFGS",
  control = list(maxit = 400, reltol = 1e-9)
)

results <- data.frame(
  model = c("V12A-0", "V12A-1"),
  converged = c(m0$convergence == 0, m1$convergence == 0),
  logLik = c(-m0$value, -m1$value),
  n_parameters = c(length(m0$par), length(m1$par)),
  AIC = c(2 * length(m0$par) + 2 * m0$value,
          2 * length(m1$par) + 2 * m1$value),
  quarterly_phi = plogis(c(m0$par[1], m1$par[1])),
  annual_phi_equivalent =
    plogis(c(m0$par[1], m1$par[1]))^4
)

cat("\n=== MODEL COMPARISON ===\n")
print(results, row.names = FALSE, digits = 5)

cat("\n=== V12A-1 DETECTION ESTIMATES ===\n")
for (period in c("1976-81", "1982-2015", "2016-25")) {
  offset <- switch(
    period,
    "1976-81" = m1$par[6],
    "1982-2015" = 0,
    "2016-25" = m1$par[7]
  )

  p <- plogis(
    m1$par[2] + offset +
      c(0, m1$par[3:5])
  )

  cat(period, ":", paste(round(p, 3), collapse = ", "),
      "(Q1-Q4)\n")
}

saveRDS(
  list(
    comparison = results,
    m0 = m0,
    m1 = m1,
    snapshot = root,
    observation_end = "2025-12-31"
  ),
  file.path(out, "v12a_first_fits.rds")
)

write.csv(
  results,
  file.path(out, "v12a_model_comparison.csv"),
  row.names = FALSE
)

cat("\nSaved results in:", normalizePath(out), "\n")
