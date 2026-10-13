# =============================================================================
# WOODCHESTER V9 — SPATIAL ARCHIVE RERUN (1,932 BADGERS)
#
# Purpose
#   Refit the accepted V9 biological/statistical model unchanged, but additionally
#   retain thinned posterior draws of latent annual activity centres S.
#
# IMPORTANT
#   - This is an archival extension of V9, not a new biological model.
#   - The accepted V9 results remain the inferential reference.
#   - S is monitored only in monitors2 at a much coarser thinning interval.
#   - Primary monitors and samplers remain the same as accepted V9.
#   - No activity centres are extrapolated beyond each badger's first:K history.
#
# Recommended production settings:
#   NITER=48000 NBURN=16000 THIN=4 SPATIAL_THIN=64
#
# This yields:
#   8,000 primary retained draws / chain
#     500 spatial S draws / chain
#
# NIMBLE monitor2 documentation:
#   monitors2 and thin2 are independent from the primary monitor stream.
# =============================================================================

BASE_WRAPPER <- "scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V8_MOVEMENT_MAXDATA_1932_CHAIN.R"
if(!file.exists(BASE_WRAPPER)) stop("Missing V8 maximal-data wrapper: ", BASE_WRAPPER)

ARCHIVE_RUN_TAG <- toupper(trimws(Sys.getenv("ARCHIVE_RUN_TAG", "")))
if(nzchar(ARCHIVE_RUN_TAG) && !grepl("^[A-Z0-9_]+$", ARCHIVE_RUN_TAG))
  stop("ARCHIVE_RUN_TAG may contain only A-Z, 0-9 and underscore.")
ARCHIVE_FILE_STEM <- if(nzchar(ARCHIVE_RUN_TAG)) {
  paste0("RD_SCR_V9_SPATIAL_ARCHIVE_1932_", ARCHIVE_RUN_TAG, "_CHAIN_")
} else {
  "RD_SCR_V9_SPATIAL_ARCHIVE_1932_CHAIN_"
}

w <- readLines(BASE_WRAPPER, warn = FALSE)

# -----------------------------------------------------------------------------
# Utility functions used to patch the generated V7/V8 source safely.
# -----------------------------------------------------------------------------

i <- grep("# ---- metadata/output names ---------------------------------------------------", w, fixed = TRUE)
if(length(i) != 1L) stop("Could not uniquely locate V8 metadata section.")

patch <- c(
  "# ---- V9 exact-prior movement reparameterisation -----------------------------",
  "src <- replace_block(",
  "  src,",
  "  \"  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=1)\",",
  "  \"  beta_move_disp ~ dexp(1)   # state 1 = higher movement\",",
  "  c(",
  "    \"  # Exact-prior reparameterisation: identified movement-scale coordinates\",",
  "    \"  beta_move_disp ~ dexp(1)   # state 1 = higher movement\",",
  "    \"  logmove_female_high ~ dnorm(MOVE_PRIOR_LOGMEAN+beta_move_disp,sd=1)\",",
  "    \"  logmove_male_local ~ dnorm(logmove_female_high-beta_move_disp,sd=.50)\",",
  "    \"  alpha_logmove <- logmove_female_high-beta_move_disp\",",
  "    \"  beta_move_sex <- logmove_male_local-alpha_logmove\"",
  "  ),",
  "  \"movement-scale exact-prior reparameterisation\"",
  ")",
  "",
  "src <- replace_once(",
  "  src,",
  "  '       alpha_logmove=a_move,beta_move_sex=b_sex,beta_move_disp=b_disp,',",
  "  '       logmove_female_high=a_move+b_disp,logmove_male_local=a_move+b_sex,beta_move_disp=b_disp,',",
  "  \"movement-scale initial values\"",
  ")",
  "",
  "src <- replace_once(",
  "  src,",
  "  '  \"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\",',",
  "  '  \"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\",\"logmove_female_high\",\"logmove_male_local\",',",
  "  \"movement-scale monitors\"",
  ")",
  "",
  "src <- replace_once(",
  "  src,",
  "  'move_global <- c(\"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\")',",
  "  'move_global <- c(\"logmove_female_high\",\"logmove_male_local\",\"beta_move_disp\")',",
  "  \"movement-scale sampler block\"",
  ")",
  "",
  "# ---- SPATIAL ARCHIVE: secondary monitor stream ------------------------------",
  "# Add SPATIAL_THIN immediately after the ordinary THIN option.",
  "ii_spthin <- grep('THIN <- as.integer(Sys.getenv(\"THIN\",unset=\"4\"))', src, fixed=TRUE)",
  "if(length(ii_spthin)!=1L) stop('Could not uniquely locate THIN option for spatial archive.')",
  "src <- append(src, c(",
  "  'SPATIAL_THIN <- as.integer(Sys.getenv(\"SPATIAL_THIN\",unset=\"64\"))',",
  "  'if(SPATIAL_THIN < THIN || SPATIAL_THIN %% THIN != 0L) stop(\"SPATIAL_THIN must be an integer multiple of THIN.\")'",
  "), after=ii_spthin)",
  "",
  "# Primary stream is unchanged. Secondary stream retains S plus the small set",
  "# of core global parameters so every spatial draw is self-contained.",
  "src <- replace_once(",
  "  src,",
  "  'config_V7 <- configureMCMC(model_V7,monitors=unique(monitors),thin=1)',",
  "  'config_V7 <- configureMCMC(model_V7,monitors=unique(monitors),monitors2=unique(c(\"S\",\"disp\",core_monitors)),thin=1,thin2=SPATIAL_THIN)',",
  "  'spatial archive monitor2 configuration'",
  ")",
  "",
  "# Make the secondary thinning explicit at runtime as well as configuration.",
  "# Match the exact runMCMC line rather than a substring because thin=THIN also",
  "# appears later in the settings list.",
  "ii_run_thin <- which(src == '    thin=THIN,')",
  "if(length(ii_run_thin)!=1L) stop('Could not uniquely locate runMCMC thin line; found ',length(ii_run_thin),'.')",
  "src <- append(src,'    thin2=SPATIAL_THIN,',after=ii_run_thin)",
  "",
  "# Extract mvSamples2 after runMCMC and compact the self-contained joint stream.",
  "# S, disp and core global parameters are all recorded in monitors2 at the same",
  "# iterations, so no cross-stream row mapping is needed.",
  "src <- replace_once(",
  "  src,",
  "  'm <- as.matrix(samples_V7)',",
  "  paste(c(",
  "    'm <- as.matrix(cMCMC_V7$mvSamples)',",
  "    'if(is.null(colnames(m))) stop(\"Primary compiled monitor stream has no column names.\")',",
  "    'expected_primary_rows <- floor((NITER-NBURN)/THIN)',",
  "    'if(nrow(m)!=expected_primary_rows) stop(\"Unexpected number of primary samples: got \",nrow(m),\" expected \",expected_primary_rows)',",
  "    'spatial_samples_full <- as.matrix(cMCMC_V7$mvSamples2)',",
  "    'if(!nrow(spatial_samples_full)) stop(\"No secondary spatial samples were retained.\")',",
  "    'expected_spatial_rows <- floor((NITER-NBURN)/SPATIAL_THIN)',",
  "    'if(nrow(spatial_samples_full)!=expected_spatial_rows) stop(\"Unexpected number of secondary samples: got \",nrow(spatial_samples_full),\" expected \",expected_spatial_rows)',",
  "    '',",
  "    '# Keep only activity centres inside the supported first:K history for each badger.',",
  "    'ac_index <- bind_rows(lapply(seq_len(nind),function(ii){',",
  "    '  kk <- first[ii]:K[ii]',",
  "    '  tibble(model_i=ii,individual_id=individual_ids[ii],tattoo=ids[ii],state_k=kk,year=years[kk],',",
  "    '         x_node=paste0(\"S[\",ii,\", 1, \",kk,\"]\"),',",
  "    '         y_node=paste0(\"S[\",ii,\", 2, \",kk,\"]\"))',",
  "    '}))',",
  "    'needed_S <- c(ac_index$x_node,ac_index$y_node)',",
  "    'missing_S <- setdiff(needed_S,colnames(spatial_samples_full))',",
  "    'if(length(missing_S)) stop(\"Missing expected valid S nodes from monitor2; first missing: \",missing_S[1])',",
  "    'missing_disp <- setdiff(disp_nodes,colnames(spatial_samples_full))',",
  "    'if(length(missing_disp)) stop(\"Missing expected disp nodes from monitor2; first missing: \",missing_disp[1])',",
  "    'spatial_disp_draws <- matrix(as.integer(spatial_samples_full[,disp_nodes,drop=FALSE]),',",
  "    '                              nrow=nrow(spatial_samples_full),ncol=length(disp_nodes),',",
  "    '                              dimnames=list(NULL,disp_nodes))',",
  "    'spatial_global_cols <- colnames(spatial_samples_full)[!startsWith(colnames(spatial_samples_full),\"S[\") & !startsWith(colnames(spatial_samples_full),\"disp[\")]',",
  "    'spatial_samples_V7 <- spatial_samples_full[,c(spatial_global_cols,needed_S),drop=FALSE]',",
  "    'primary_global_samples <- m[,!startsWith(colnames(m),\"disp[\"),drop=FALSE]',",
  "    'cat(\"Spatial archive draws:\",nrow(spatial_samples_V7),',",
  "    '    \"| valid ACs:\",nrow(ac_index),',",
  "    '    \"| retained S columns:\",sum(startsWith(colnames(spatial_samples_V7),\"S[\")),',",
  "    '    \"| coherent disp intervals:\",ncol(spatial_disp_draws),',",
  "    '    \"| secondary stream is self-contained: S + disp + globals\\n\")',",
  "    'rm(spatial_samples_full)'",
  "  ),collapse='\\n'),",
  "  'spatial archive extraction and compaction'",
  ")",
  "",
  "# Replace the huge ordinary primary sample archive with compact components.",
  "# Accepted V9 already preserves the full 8,000 x full-disp primary chains.",
  "src <- replace_once(",
  "  src,",
  "  '    samples=samples_V7,',",
  "  paste(c(",
  "    '    primary_global_samples=primary_global_samples,',",
  "    '    spatial_samples=spatial_samples_V7,',",
  "    '    spatial_disp_draws=spatial_disp_draws,',",
  "    '    spatial_thin=SPATIAL_THIN,',",
  "    '    spatial_monitors=c(\"S\",\"disp\",core_monitors),',",
  "    '    ac_index=ac_index,',",
  "    '    spatial_stream_self_contained=TRUE,'",
  "  ),collapse='\\n'),",
  "  'compact spatial archive in chain output'",
  ")",
  ""
)

w <- c(w[seq_len(i - 1L)], patch, w[i:length(w)])

# -----------------------------------------------------------------------------
# Give the archival rerun its own identity and filenames.
# -----------------------------------------------------------------------------

j <- grep("# ---- execute generated model -------------------------------------------------", w, fixed = TRUE)
if(length(j) != 1L) stop("Could not uniquely locate V8 execute section.")

post <- c(
  "# ---- V9 spatial-archive output identity -------------------------------------",
  paste0("src <- gsub(\"RD_SCR_V7M_MOVEMENT_ONLY_1932_CHAIN_\",\"", ARCHIVE_FILE_STEM, "\",src,fixed=TRUE)"),
  "src <- gsub('model=\"V7M_movement_only_modular_source\"','model=\"V9_spatial_archive_exact_prior_reparam\"',src,fixed=TRUE)",
  ""
)
w <- c(w[seq_len(j - 1L)], post, w[j:length(w)])

# Add a cheap validation-only mode so all nested source transformations can be
# checked before paying the several-minute NIMBLE build/compile cost.
ii_exec_generated <- which(w == "source(generated_file,local=FALSE)")
if(length(ii_exec_generated) != 1L)
  stop("Could not uniquely locate generated-model execution line.")
replacement_exec <- c(
  'invisible(parse(file=generated_file))',
  'if(tolower(Sys.getenv("ARCHIVE_VALIDATE_ONLY","false")) %in% c("true","1","yes")) {',
  '  cat("ARCHIVE VALIDATION ONLY: generated V9 spatial model parsed successfully.\\n")',
  '} else {',
  '  source(generated_file,local=FALSE)',
  '}'
)
tail_after_exec <- if(ii_exec_generated < length(w)) w[(ii_exec_generated + 1L):length(w)] else character()
w <- c(
  if(ii_exec_generated > 1L) w[seq_len(ii_exec_generated - 1L)] else character(),
  replacement_exec,
  tail_after_exec
)

# Keep generated temporary files clearly separate.
w <- gsub(
  "Woodchester_RD_Spatial_CMR_V8_MOVEMENT_MAXDATA_1932_CHAIN_generated.R",
  "Woodchester_RD_Spatial_CMR_V9_SPATIAL_ARCHIVE_1932_CHAIN_generated.R",
  w, fixed = TRUE
)
w <- gsub(
  "Generated checked maximal-data model source:",
  "Generated V9 spatial-archive maximal-data model source:",
  w, fixed = TRUE
)

archive_wrapper <- file.path(
  tempdir(),
  "Woodchester_RD_Spatial_CMR_V9_SPATIAL_ARCHIVE_1932_wrapper_generated.R"
)
writeLines(w, archive_wrapper)

# Fail immediately on any generated-source syntax problem before the expensive
# model build/compile begins.
invisible(parse(file = archive_wrapper))

cat("Generated V9 spatial-archive wrapper source:\n", archive_wrapper, "\n", sep = "")
cat("This rerun preserves the accepted V9 model and adds thinned S monitoring only.\n")
cat("Archive output stem: ", ARCHIVE_FILE_STEM, "\n", sep = "")
source(archive_wrapper, local = FALSE)
