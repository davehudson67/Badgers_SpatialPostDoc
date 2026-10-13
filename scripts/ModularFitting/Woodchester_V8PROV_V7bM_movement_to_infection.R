# =============================================================================
# V8 PROVISIONAL V7b-M: HIGH MOBILITY -> SUBSEQUENT INFECTION ACQUISITION
#
# Thin wrapper around the established V7b-M model. It changes only the paired
# history/movement inputs and output prefix so the current V8 movement-state
# posterior can be used for provisional pipeline testing.
# =============================================================================

BASE <- "scripts/ModularFitting/Woodchester_V7bM_movement_to_infection_modular_IS.R"
if(!file.exists(BASE)) stop("Missing base V7b-M script: ",BASE)

txt <- paste(readLines(BASE,warn=FALSE),collapse="\n")
txt <- gsub(
  'PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"',
  'PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"',
  txt,fixed=TRUE
)
txt <- gsub(
  'MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"',
  'MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"',
  txt,fixed=TRUE
)
txt <- gsub(
  'results/V7bM_movement_to_infection_',
  'results/V8PROV_V7bM_movement_to_infection_',
  txt,fixed=TRUE
)
txt <- gsub(
  'model="V7b-M modular high mobility -> subsequent infection acquisition"',
  'model="V8PROV V7b-M high mobility -> subsequent infection acquisition"',
  txt,fixed=TRUE
)
txt <- gsub(
  'WOODCHESTER V7b-M: HIGH MOBILITY -> INFECTION',
  'WOODCHESTER V8PROV V7b-M: HIGH MOBILITY -> INFECTION',
  txt,fixed=TRUE
)

generated <- file.path(tempdir(),"Woodchester_V8PROV_V7bM_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
source(generated,local=FALSE)
