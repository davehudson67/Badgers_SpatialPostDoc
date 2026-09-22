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
  "  'config_V7 <- configureMCMC(model_V7,monitors=unique(monitors),monitors2=unique(c(\"S\",core_monitors)),thin=1,thin2=SPATIAL_THIN)',",
  "  'spatial archive monitor2 configuration'",
  ")",
  "",
  "# Extract mvSamples2 after runMCMC and verify exact alignment with the primary",
  "# stream using a shared global parameter.",
  "src <- replace_once(",
  "  src,",
  "  'm <- as.matrix(samples_V7)',",
  "  paste(c(",
  "    'm <- as.matrix(samples_V7)',",
  "    'spatial_samples_V7 <- as.matrix(cMCMC_V7$mvSamples2)',",
  "    'if(!nrow(spatial_samples_V7)) stop(\"No secondary spatial samples were retained.\")',",
  "    'thin_ratio <- SPATIAL_THIN %/% THIN',",
  "    'spatial_primary_rows <- seq_len(nrow(spatial_samples_V7))*thin_ratio',",
  "    'if(max(spatial_primary_rows)>nrow(m)) stop(\"Spatial-to-primary draw mapping exceeds primary sample rows.\")',",
  "    'align_parameter <- intersect(c(\"alpha_RD\",\"beta_move_disp\",\"logmove_male_local\"),colnames(spatial_samples_V7))',",
  "    'align_parameter <- align_parameter[align_parameter %in% colnames(m)]',",
  "    'if(!length(align_parameter)) stop(\"No shared global parameter available to verify spatial draw alignment.\")',",
  "    'ap <- align_parameter[1]',",
  "    'alignment_error <- max(abs(spatial_samples_V7[,ap]-m[spatial_primary_rows,ap]))',",
  "    'if(!is.finite(alignment_error) || alignment_error>1e-10) stop(\"Secondary spatial samples do not align with expected primary draws. Max error=\",alignment_error)',",
  "    'cat(\"Spatial archive draws saved:\",nrow(spatial_samples_V7),\"| S columns:\",sum(grepl(\"^S\\\\[\",colnames(spatial_samples_V7))),\"| primary alignment max error:\",alignment_error,\"\\n\")'",
  "  ),collapse='\\n'),",
  "  'spatial archive extraction'",
  ")",
  "",
  "# Add the secondary samples and their exact primary-row mapping to each chain",
  "# object. This preserves coherent S + disp + global-parameter draws.",
  "src <- replace_once(",
  "  src,",
  "  '    samples=samples_V7,',",
  "  paste(c(",
  "    '    samples=samples_V7,',",
  "    '    spatial_samples=spatial_samples_V7,',",
  "    '    spatial_primary_rows=as.integer(spatial_primary_rows),',",
  "    '    spatial_thin=SPATIAL_THIN,',",
  "    '    spatial_monitors=c(\"S\",core_monitors),',",
  "    '    spatial_alignment_parameter=ap,',",
  "    '    spatial_alignment_max_error=alignment_error,'",
  "  ),collapse='\\n'),",
  "  'spatial samples in chain archive'",
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
  "src <- gsub(\"RD_SCR_V7M_MOVEMENT_ONLY_1932_CHAIN_\",\"RD_SCR_V9_SPATIAL_ARCHIVE_1932_CHAIN_\",src,fixed=TRUE)",
  "src <- gsub('model=\"V7M_movement_only_modular_source\"','model=\"V9_spatial_archive_exact_prior_reparam\"',src,fixed=TRUE)",
  ""
)
w <- c(w[seq_len(j - 1L)], post, w[j:length(w)])

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

cat("Generated V9 spatial-archive wrapper source:\n", archive_wrapper, "\n", sep = "")
cat("This rerun preserves the accepted V9 model and adds thinned S monitoring only.\n")
source(archive_wrapper, local = FALSE)
