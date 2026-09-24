# =============================================================================
# WOODCHESTER V9 FINAL — PPC AVAILABILITY AUDIT
#
# Purpose
#   Check which saved objects already contain everything needed for targeted
#   posterior-predictive / model-calibration checks, before deciding whether
#   anything needs to be refitted.
#
# This script is READ-ONLY. It does not fit models or modify existing outputs.
# =============================================================================

options(width = 140)

cat("\n============================================================\n")
cat("WOODCHESTER V9 FINAL — PPC AVAILABILITY AUDIT\n")
cat("============================================================\n\n")

show_file <- function(path) {
  cat(sprintf("%-85s %s\n", path, if (file.exists(path)) "FOUND" else "MISSING"))
}

safe_read <- function(path) {
  if (!file.exists(path)) return(NULL)
  tryCatch(readRDS(path), error = function(e) {
    cat("  ERROR reading ", path, ": ", conditionMessage(e), "\n", sep = "")
    NULL
  })
}

cat("1. EXPECTED CORE FILES\n")
cat("----------------------\n")

chain_files <- sprintf("results/RD_SCR_V9_MOVEMENT_MAXDATA_1932_CHAIN_%d.rds", 1:3)
core_files <- c(
  chain_files,
  "results/RD_SCR_V9_MOVEMENT_MAXDATA_1932_COMBINED.rds",
  "data/badger_movement_posterior_draws_1932_V9.rds",
  "data/badger_movement_posterior_histories_1932_V9_FINAL.rds",
  "data/badger_phase2_paired_latent_inputs_V9_FINAL.rds",
  "results/V9FINAL_V7aM_infection_to_movement_FULL_1500.rds",
  "results/V9FINAL_V7bM_movement_to_infection_FULL_1500.rds"
)

invisible(lapply(core_files, show_file))

cat("\n2. MOVEMENT CHAIN CONTENTS\n")
cat("--------------------------\n")

ch <- safe_read(chain_files[1])

if (!is.null(ch)) {
  cat("Top-level fields:\n  ", paste(names(ch), collapse = ", "), "\n", sep = "")

  if (!is.null(ch$samples)) {
    sm <- as.matrix(ch$samples)
    cn <- colnames(sm)

    cat("\nMCMC sample dimensions: ", nrow(sm), " draws x ", ncol(sm), " monitored columns\n", sep = "")
    cat("Monitored latent movement-state columns (disp): ", sum(grepl("^disp\\[", cn)), "\n", sep = "")
    cat("Monitored latent activity-centre columns (S):    ", sum(grepl("^S\\[", cn)), "\n", sep = "")
    cat("Monitored movement residual columns (eps):       ", sum(grepl("^eps\\[", cn)), "\n", sep = "")
    cat("Monitored latent move-distance columns:          ", sum(grepl("^moveDist\\[", cn)), "\n", sep = "")

    needed_globals <- c(
      "alpha_logmove", "beta_move_sex", "beta_move_disp",
      "logmove_female_high", "logmove_male_local",
      "alpha_RD", "beta_RD_sex", "alpha_DD", "beta_DD_sex",
      "alpha_disp_init", "beta_disp_adult", "beta_disp_init_sex",
      "alpha_p", "beta_p_sex", "alpha_logsigma", "beta_sigma_sex",
      "beta_sg", "beta_peripheral"
    )
    cat("\nUseful global parameters present:\n")
    for (z in needed_globals) cat(sprintf("  %-28s %s\n", z, if (z %in% cn) "YES" else "NO"))
  }

  cat("\nSaved observed/support objects:\n")
  if (!is.null(ch$annual_obs)) {
    cat("  annual_obs: ", nrow(ch$annual_obs), " rows; columns = ",
        paste(names(ch$annual_obs), collapse = ", "), "\n", sep = "")
  } else cat("  annual_obs: MISSING\n")

  if (!is.null(ch$detectors)) {
    cat("  detectors: ", nrow(ch$detectors), " rows\n", sep = "")
  } else cat("  detectors: MISSING\n")

  if (!is.null(ch$H)) {
    cat("  H dimensions: ", paste(dim(ch$H), collapse = " x "), "\n", sep = "")
  } else cat("  H: MISSING\n")

  if (!is.null(ch$disp_index)) {
    cat("  disp_index: ", nrow(ch$disp_index), " intervals\n", sep = "")
  } else cat("  disp_index: MISSING\n")
}

cat("\n3. FINAL MOVEMENT EXPORT\n")
cat("------------------------\n")

mv <- safe_read("data/badger_movement_posterior_draws_1932_V9.rds")
if (!is.null(mv)) {
  cat("Fields: ", paste(names(mv), collapse = ", "), "\n", sep = "")
  if (!is.null(mv$movement_draws))
    cat("movement_draws: ", nrow(mv$movement_draws), " coherent draws x ",
        ncol(mv$movement_draws), " intervals\n", sep = "")
  if (!is.null(mv$disp_index))
    cat("disp_index: ", nrow(mv$disp_index), " intervals\n", sep = "")
}

cat("\n4. V7a FINAL OBJECT\n")
cat("-------------------\n")

v7a_path <- "results/V9FINAL_V7aM_infection_to_movement_FULL_1500.rds"
a <- safe_read(v7a_path)
if (!is.null(a)) {
  cat("Fields: ", paste(names(a), collapse = ", "), "\n", sep = "")
  if (!is.null(a$coefficient_draws))
    cat("coefficient_draws: ", nrow(a$coefficient_draws), " rows\n", sep = "")
  if (!is.null(a$pair_counts)) {
    cat("pair_counts: ", nrow(a$pair_counts), " paired histories\n", sep = "")
    cat("pair_counts columns: ", paste(names(a$pair_counts), collapse = ", "), "\n", sep = "")
  }
}

cat("\n5. V7b FINAL OBJECT\n")
cat("-------------------\n")

v7b_path <- "results/V9FINAL_V7bM_movement_to_infection_FULL_1500.rds"
b <- safe_read(v7b_path)
if (!is.null(b)) {
  cat("Fields: ", paste(names(b), collapse = ", "), "\n", sep = "")
  if (!is.null(b$coefficient_draws))
    cat("coefficient_draws: ", nrow(b$coefficient_draws), " rows\n", sep = "")
  if (!is.null(b$pair_counts)) {
    cat("pair_counts fields: ", paste(names(b$pair_counts), collapse = ", "), "\n", sep = "")
    if (!is.null(b$pair_counts$n))
      cat("n matrix: ", paste(dim(b$pair_counts$n), collapse = " x "), "\n", sep = "")
    if (!is.null(b$pair_counts$y))
      cat("y matrix: ", paste(dim(b$pair_counts$y), collapse = " x "), "\n", sep = "")
    if (!is.null(b$pair_counts$cells))
      cat("cells: ", nrow(b$pair_counts$cells), " grouped-binomial cells\n", sep = "")
  }
  if (!is.null(b$design))
    cat("design matrix: ", paste(dim(b$design), collapse = " x "), "\n", sep = "")
}

cat("\n6. SAME-GROUP PRESSURE OUTPUT CANDIDATES\n")
cat("---------------------------------------\n")

pressure_files <- list.files(
  "results",
  pattern = "^V9FINAL_V7bM_samegroup_pressure.*\\.rds$",
  full.names = TRUE
)

if (!length(pressure_files)) {
  cat("No V9FINAL same-group pressure RDS files found.\n")
} else {
  for (p in pressure_files) {
    cat("\n", p, "\n", sep = "")
    z <- safe_read(p)
    if (!is.null(z)) {
      cat("  Fields: ", paste(names(z), collapse = ", "), "\n", sep = "")
      if (!is.null(z$coefficient_draws))
        cat("  coefficient_draws: ", nrow(z$coefficient_draws), " rows\n", sep = "")
      if (!is.null(z$fit_audit))
        cat("  fit_audit: ", nrow(z$fit_audit), " rows\n", sep = "")
      if (!is.null(z$retention_by_pair))
        cat("  retention_by_pair: ", nrow(z$retention_by_pair), " rows\n", sep = "")
    }
  }
}

cat("\n7. EXISTING OBSERVED-MOVEMENT DATA\n")
cat("----------------------------------\n")

movement_candidates <- c(
  "data/movement_audit/all_observed_movements.csv",
  "data/movement_audit/movement_adjacent_quarters.csv",
  "data/movement_audit/movement_summary_all.csv",
  "results/badger_annual_observed_sett_locations.csv"
)
invisible(lapply(movement_candidates, show_file))

cat("\n============================================================\n")
cat("INTERPRETATION GUIDE\n")
cat("============================================================\n")
cat(
  paste0(
    "\nA. If S / eps / moveDist counts above are zero (expected from the V9 code),\n",
    "   the saved V9 MCMC files do NOT contain posterior activity-centre trajectories.\n",
    "   Therefore a full generative spatial/capture PPC cannot be reconstructed directly\n",
    "   from the saved posterior samples without rebuilding the latent spatial layer.\n",
    "\n",
    "B. This does NOT stop us doing useful closure checks without refitting V9.\n",
    "   We already have observed annual movement, global movement parameters and 1,500\n",
    "   coherent latent state histories. These support targeted state/movement consistency\n",
    "   checks and observed-movement sensitivities.\n",
    "\n",
    "C. V7a should already contain the grouped observed counts plus coefficient draws.\n",
    "   V7b should already contain grouped n/y counts, cell definitions, design matrix and\n",
    "   coefficient draws. Those are sufficient for genuine posterior-predictive outcome\n",
    "   checks WITHOUT rerunning either disease model.\n",
    "\n",
    "D. The same-group pressure object retains coefficient draws and pair identities but\n",
    "   not every reconstructed risk row. Calibration can still be rebuilt cheaply from\n",
    "   the frozen paired histories/annual group data; no NIMBLE movement refit is needed.\n"
  )
)

cat("\nAudit complete.\n")
