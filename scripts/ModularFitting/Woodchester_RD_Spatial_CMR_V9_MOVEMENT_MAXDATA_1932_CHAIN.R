# =============================================================================
# WOODCHESTER V9 - MAXIMAL-DATA MOVEMENT MODEL, EXACT-PRIOR REPARAMETERISATION
#
# Purpose
#   Retain the V8 biological/statistical model exactly, but sample movement-scale
#   parameters in coordinates that match the combinations the data identify well.
#
# Original V8 movement-scale parameterisation:
#   alpha_logmove ~ Normal(MOVE_PRIOR_LOGMEAN, 1)
#   beta_move_sex ~ Normal(0, 0.5)
#   beta_move_disp ~ Exponential(1)
#
#   log(sigma_move) = alpha_logmove + beta_move_sex*sex + beta_move_disp*disp
#
# V9 sampling coordinates:
#   logmove_male_local   = alpha_logmove + beta_move_sex
#   logmove_female_high  = alpha_logmove + beta_move_disp
#   beta_move_disp       unchanged
#
# The conditional priors below are the exact linear change-of-variables form of
# the V8 priors (Jacobian = 1). Thus V9 changes MCMC geometry, not the scientific
# model or prior. The familiar alpha_logmove and beta_move_sex are retained as
# deterministic monitored quantities for direct comparison with V8.
# =============================================================================

BASE_WRAPPER <- "scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V8_MOVEMENT_MAXDATA_1932_CHAIN.R"
if(!file.exists(BASE_WRAPPER)) stop("Missing V8 maximal-data wrapper: ",BASE_WRAPPER)

w <- readLines(BASE_WRAPPER,warn=FALSE)

# Insert exact-prior reparameterisation into the V8 wrapper before its metadata
# substitutions. The inserted code operates on the generated model source `src`.
i <- grep("# ---- metadata/output names ---------------------------------------------------",w,fixed=TRUE)
if(length(i)!=1L) stop("Could not uniquely locate V8 metadata section.")

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
  ""
)

w <- c(w[seq_len(i-1L)],patch,w[i:length(w)])

# After the V8 filename substitutions, give V9 its own result/model identity.
j <- grep("# ---- execute generated model -------------------------------------------------",w,fixed=TRUE)
if(length(j)!=1L) stop("Could not uniquely locate V8 execute section.")
post <- c(
  "# ---- V9 output identity ------------------------------------------------------",
  "src <- gsub(\"RD_SCR_V7M_MOVEMENT_ONLY_1932_CHAIN_\",\"RD_SCR_V9_MOVEMENT_MAXDATA_1932_CHAIN_\",src,fixed=TRUE)",
  "src <- gsub('model=\"V7M_movement_only_modular_source\"','model=\"V9_movement_maxdata_exact_prior_reparam\"',src,fixed=TRUE)",
  ""
)
w <- c(w[seq_len(j-1L)],post,w[j:length(w)])

# Keep generated temporary files clearly separated from V8.
w <- gsub(
  "Woodchester_RD_Spatial_CMR_V8_MOVEMENT_MAXDATA_1932_CHAIN_generated.R",
  "Woodchester_RD_Spatial_CMR_V9_MOVEMENT_MAXDATA_1932_CHAIN_generated.R",
  w,fixed=TRUE
)
w <- gsub(
  "Generated checked maximal-data model source:",
  "Generated V9 exact-prior reparameterized maximal-data model source:",
  w,fixed=TRUE
)

v9_wrapper <- file.path(tempdir(),"Woodchester_RD_Spatial_CMR_V9_MOVEMENT_MAXDATA_1932_wrapper_generated.R")
writeLines(w,v9_wrapper)
cat("Generated V9 wrapper source:\n",v9_wrapper,"\n",sep="")
source(v9_wrapper,local=FALSE)
