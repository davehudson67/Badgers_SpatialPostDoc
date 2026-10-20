# =============================================================================
# Build a CENTRED annual-coordinate sampler check from the current V11 source.
#
# This changes ONLY computational coordinates/samplers for annual activity
# centres. V11 biology, priors, age/sex effects, badger random effect,
# transition structure, iid quarters and observation likelihood are unchanged.
# =============================================================================

base_file <- "scripts/ModularFitting/Woodchester_V11_RD_SCR_MULTILOC_IID_AGE_BADGERRE.R"
ref_file <- "scripts/ModularFitting/Woodchester_V10B_RD_SCR_MULTILOC_AR1_COLLAPSED_REPARAM_INTERWEAVE.R"
out_file <- "scripts/ModularFitting/Woodchester_V11_centered_annual_sampler_check.R"

stopifnot(file.exists(base_file), file.exists(ref_file))

v11 <- paste(readLines(base_file, warn = FALSE), collapse = "\n")
ref <- paste(readLines(ref_file, warn = FALSE), collapse = "\n")

replace_between <- function(x, start, end, replacement, label) {
  s <- regexpr(start, x, fixed = TRUE)[1]
  if (s < 0L) stop("Missing start marker: ", label)
  tail <- substring(x, s)
  e_rel <- regexpr(end, tail, fixed = TRUE)[1]
  if (e_rel < 0L) stop("Missing end marker: ", label)
  e <- s + e_rel - 1L
  paste0(substring(x, 1L, s - 1L), replacement, substring(x, e))
}

extract_between <- function(x, start, end, label) {
  s <- regexpr(start, x, fixed = TRUE)[1]
  if (s < 0L) stop("Missing reference start: ", label)
  tail <- substring(x, s)
  e_rel <- regexpr(end, tail, fixed = TRUE)[1]
  if (e_rel < 0L) stop("Missing reference end: ", label)
  substring(x, s, s + e_rel - 2L)
}

replace_once <- function(x, old, new, label) {
  hits <- gregexpr(old, x, fixed = TRUE)[[1]]
  n <- if (length(hits) == 1L && hits[1] == -1L) 0L else length(hits)
  if (n != 1L) stop(label, ": expected one match; found ", n)
  sub(old, new, x, fixed = TRUE)
}

# Distinct output stem, same model identity.
v11 <- replace_once(
  v11,
  'unset = "V11_RD_MULTILOC_IID_AGE_BADGERRE"',
  'unset = "V11_RD_MULTILOC_IID_AGE_BADGERRE_CENTEREDCHECK"',
  "output stem"
)

v11 <- replace_once(
  v11,
  'cat("WOODCHESTER V11: IID QUARTERS + AGE + BADGER MOVER PROPENSITY\\n")',
  'cat("WOODCHESTER V11: CENTRED ANNUAL-COORDINATE SAMPLER CHECK\\n")',
  "banner"
)

# Remove constants used only by the non-centred annual transformation.
v11 <- replace_between(
  v11,
  "# Non-centred annual-movement reference.",
  "encounter_file <-",
  "# Centred annual-coordinate sampler check: no annual NC reference density.\n\n",
  "annual NC constants"
)

# Replace only the displacement-density/annual-A coordinate part with the
# already validated centred implementation from the V10B sampler check.
centred_density <- extract_between(
  ref,
  "      # Reference density for the annual position.",
  "      col_A_raw[i, k] <-",
  "centred annual density"
)

v11 <- replace_between(
  v11,
  "      move_high_ratio[i, k] <-",
  "      col_A_raw[i, k] <-",
  paste0(centred_density, "\n"),
  "V11 annual coordinate block"
)

# Constants object: remove annual-NC reference pieces.
v11 <- replace_once(
  v11,
  "q_zero <- c(0, 0)\nq_prec <- diag(1, 2)\nu_ref_prec <- diag(1 / (U_REF_SD^2), 2)",
  "q_zero <- c(0, 0)\nq_prec <- diag(1, 2)",
  "u_ref_prec"
)
for (z in c(
  "  U_REF_SD = U_REF_SD,\n",
  "  LOG_U_REF_SD = LOG_U_REF_SD,\n",
  "  MOVE_NC_CORR_CONST = MOVE_NC_CORR_CONST,\n",
  "  u_ref_prec = u_ref_prec\n"
)) {
  v11 <- sub(z, "", v11, fixed = TRUE)
}
v11 <- sub("  q_prec = q_prec,\n)", "  q_prec = q_prec\n)", v11, fixed = TRUE)

# Initial values: all active annual A nodes are stochastic in centred form.
v11 <- replace_between(
  v11,
  "  # Only the first A for each individual is stochastic in the non-centred",
  "  qeps_target0 <-",
  paste0(
    "  # Every active annual activity centre is stochastic in the centred check.\n",
    "  A0 <- array(NA_real_, c(nind, 2L, n_prim))\n",
    "  qeps_target0 <-"
  ),
  "centred A initial arrays"
)

v11 <- replace_between(
  v11,
  "    A0[i, 1, first[i]] <-",
  "    for (k in first[i]:K[i]) {",
  paste0(
    "    for (k in first[i]:K[i]) {\n",
    "      A0[i, 1, k] <- target_A[i, 1, k]\n",
    "      A0[i, 2, k] <- target_A[i, 2, k]\n\n"
  ),
  "centred A initial values"
)

v11 <- sub("    u_move = u_move0,\n", "", v11, fixed = TRUE)

# Remove the non-centred change-of-variable code-level identity check.
v11 <- replace_between(
  v11,
  "# Verify the annual non-centred change of variables",
  "# ---- build -------------------------------------------------------------------",
  paste0(
    "# Centred annual coordinates use the original displacement-space mixture ",
    "directly; no annual change-of-variables identity is required.\n\n",
    "# ---- build -------------------------------------------------------------------"
  ),
  "annual NC self-check"
)

v11 <- replace_once(
  v11,
  "      A = c(nind, 2L, n_prim),\n      u_move = c(nind, 2L, n_prim),\n      qinnov = c(nind, 2L, J, n_prim),",
  "      A = c(nind, 2L, n_prim),\n      qinnov = c(nind, 2L, J, n_prim),",
  "u_move model dimension"
)

# Use the already-tested whole-badger centred trajectory update from V10B,
# while retaining V11's global samplers (including age and badger RE).
centred_traj <- extract_between(
  ref,
  "trajectory_block_dimensions <- integer(nind)",
  "cat(\n  \"\\nFinal sampler configuration:",
  "centred trajectory sampler"
)

centred_sampler_text <- paste0(
  "# Centred annual-trajectory updates. Same posterior model; different MCMC coordinates.\n",
  centred_traj,
  "\ncat(\n",
  "  \"\\nFinal sampler configuration:\\n\",\n",
  "  \"  Global AF_slice blocks: \", length(global_blocks), \"\\n\",\n",
  "  \"  Whole-badger centred annual-trajectory blocks: \", nind, \"\\n\",\n",
  "  \"  Trajectory block dimension: median=\", median(trajectory_block_dimensions),\n",
  "  \", p95=\", unname(quantile(trajectory_block_dimensions, 0.95)),\n",
  "  \", max=\", max(trajectory_block_dimensions), \"\\n\",\n",
  "  \"  alpha_logomega uses scalar slice; rho remains fixed to zero.\\n\",\n",
  "  \"  sigma_badger remains non-centred.\\n\",\n",
  "  \"  movement-scale updates remain interwoven before/after A sweep.\\n\",\n",
  "  sep = \"\"\n",
  ")\n\n"
)

v11 <- replace_between(
  v11,
  "# Overlapping local non-centred annual trajectory blocks.",
  "# Printing every sampler is useful only for tiny debugging fits",
  paste0(
    centred_sampler_text,
    "# Printing every sampler is useful only for tiny debugging fits"
  ),
  "annual trajectory samplers"
)

# Metadata only.
v11 <- gsub(
  "non-centred resident-scale annual increments with exact transformed two-state Gaussian HMM analytically collapsed",
  "centred annual activity-centre coordinates with exact two-state Gaussian HMM analytically collapsed",
  v11, fixed = TRUE
)
v11 <- gsub(
  "overlapping local annual-NC AF_slice blocks: first A + first u_move, adjacent u_move pairs, and terminal u_move endpoint",
  "whole-badger centred annual-trajectory AF_slice blocks",
  v11, fixed = TRUE
)
v11 <- gsub(
  "before and after annual-NC sweep",
  "before and after centred annual-A sweep",
  v11, fixed = TRUE
)
v11 <- gsub(
  "non-centred annual movement + overlapping local trajectory blocks + iid quarterly deviations + direct high-mobility scale + non-centred badger propensity; V11 biological extension is age plus individual entry propensity",
  "centred annual-coordinate sampler check; V11 biology, priors, iid quarters, age and badger propensity unchanged",
  v11, fixed = TRUE
)

# Fail loudly if annual-NC nodes/constants remain.
for (z in c("u_move[", "u_ref_prec", "MOVE_NC_CORR_CONST", "LOG_U_REF_SD", "U_REF_SD")) {
  if (grepl(z, v11, fixed = TRUE)) stop("Unexpected annual-NC remnant: ", z)
}

writeLines(strsplit(v11, "\n", fixed = TRUE)[[1]], out_file)
cat("Wrote centred V11 sampler check:\n", out_file, "\n", sep = "")
