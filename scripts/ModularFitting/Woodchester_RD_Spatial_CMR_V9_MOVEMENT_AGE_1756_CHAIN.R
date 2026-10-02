# =============================================================================
# WOODCHESTER V9 - CHRONOLOGICAL-AGE MOVEMENT MODEL, EXACT-PRIOR REPARAMETERISATION
#
# Retains the V8 age model exactly, including the single chronological-age effect
# on initial high-mobility probability and later local->high transitions. Only
# the movement-scale sampling coordinates are changed.
#
# V9 samples the two biologically well-identified movement combinations directly:
#   logmove_male_local  = alpha_logmove + beta_move_sex
#   logmove_female_high = alpha_logmove + beta_move_disp
# while beta_move_disp remains the positive high-vs-local contrast.
#
# The conditional priors are the exact change-of-variables representation of the
# original V8 independent priors, with unit Jacobian. Therefore this is a pure
# computational reparameterisation, not a different biological model or prior.
# =============================================================================

BASE_WRAPPER <- "scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V8_MOVEMENT_AGE_1756_CHAIN.R"
if(!file.exists(BASE_WRAPPER)) stop("Missing V8 chronological-age wrapper: ",BASE_WRAPPER)

w <- readLines(BASE_WRAPPER,warn=FALSE)

i <- grep("# ---- output metadata ---------------------------------------------------------",w,fixed=TRUE)
if(length(i)!=1L) stop("Could not uniquely locate V8 age output-metadata section.")

patch <- c(
  "# ---- V9 exact-prior movement reparameterisation -----------------------------",
  "txt <- replace_txt_once(",
  "  txt,",
  "  paste(c(",
  "    '  alpha_logmove ~ dnorm(MOVE_PRIOR_LOGMEAN,sd=1)',",
  "    '  beta_move_sex ~ dnorm(0,sd=.50)',",
  "    '  beta_move_disp ~ dexp(1)   # state 1 = higher movement'",
  "  ),collapse=\"\\n\"),",
  "  paste(c(",
  "    '  # Exact-prior reparameterisation: identified movement-scale coordinates',",
  "    '  beta_move_disp ~ dexp(1)   # state 1 = higher movement',",
  "    '  logmove_female_high ~ dnorm(MOVE_PRIOR_LOGMEAN+beta_move_disp,sd=1)',",
  "    '  logmove_male_local ~ dnorm(logmove_female_high-beta_move_disp,sd=.50)',",
  "    '  alpha_logmove <- logmove_female_high-beta_move_disp',",
  "    '  beta_move_sex <- logmove_male_local-alpha_logmove'",
  "  ),collapse=\"\\n\"),",
  "  \"movement-scale exact-prior reparameterisation\"",
  ")",
  "",
  "txt <- replace_txt_once(",
  "  txt,",
  "  '       alpha_logmove=a_move,beta_move_sex=b_sex,beta_move_disp=b_disp,',",
  "  '       logmove_female_high=a_move+b_disp,logmove_male_local=a_move+b_sex,beta_move_disp=b_disp,',",
  "  \"movement-scale initial values\"",
  ")",
  "",
  "txt <- replace_txt_once(",
  "  txt,",
  "  '  \"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\",',",
  "  '  \"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\",\"logmove_female_high\",\"logmove_male_local\",',",
  "  \"movement-scale monitors\"",
  ")",
  "",
  "txt <- replace_txt_once(",
  "  txt,",
  "  'move_global <- c(\"alpha_logmove\",\"beta_move_sex\",\"beta_move_disp\")',",
  "  'move_global <- c(\"logmove_female_high\",\"logmove_male_local\",\"beta_move_disp\")',",
  "  \"movement-scale sampler block\"",
  ")",
  ""
)

w <- c(w[seq_len(i-1L)],patch,w[i:length(w)])

# Add a V9 identity after the V8 age filename/model substitutions and before the
# generated model is written to disk.
j <- grep('generated_file <- file.path(tempdir(),"Woodchester_RD_Spatial_CMR_V8_MOVEMENT_AGE_1756_CHAIN_generated.R")',w,fixed=TRUE)
if(length(j)!=1L) stop("Could not uniquely locate V8 age generated-file line.")
post <- c(
  "# ---- V9 output identity ------------------------------------------------------",
  "txt <- gsub(\"RD_SCR_V8_MOVEMENT_AGE_1756_CHAIN_\",\"RD_SCR_V9_MOVEMENT_AGE_1756_CHAIN_\",txt,fixed=TRUE)",
  "txt <- gsub('model=\"V8_movement_chronological_age\"','model=\"V9_movement_chronological_age_exact_prior_reparam\"',txt,fixed=TRUE)",
  ""
)
w <- c(w[seq_len(j-1L)],post,w[j:length(w)])

w <- gsub(
  "Woodchester_RD_Spatial_CMR_V8_MOVEMENT_AGE_1756_CHAIN_generated.R",
  "Woodchester_RD_Spatial_CMR_V9_MOVEMENT_AGE_1756_CHAIN_generated.R",
  w,fixed=TRUE
)
w <- gsub(
  "Generated checked chronological-age model source:",
  "Generated V9 exact-prior reparameterized chronological-age model source:",
  w,fixed=TRUE
)

v9_wrapper <- file.path(tempdir(),"Woodchester_RD_Spatial_CMR_V9_MOVEMENT_AGE_1756_wrapper_generated.R")
writeLines(w,v9_wrapper)
cat("Generated V9 age wrapper source:\n",v9_wrapper,"\n",sep="")
source(v9_wrapper,local=FALSE)
