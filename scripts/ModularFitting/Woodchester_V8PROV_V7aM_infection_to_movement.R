# =============================================================================
# V8 PROVISIONAL V7a-M: PRIOR INFECTION -> SUBSEQUENT HIGH MOBILITY
#
# Thin wrapper around the established V7a-M model. It changes only the paired
# history/movement inputs and output prefix so the current V8 movement-state
# posterior can be used for provisional pipeline testing.
# =============================================================================

BASE <- "scripts/ModularFitting/Woodchester_V7aM_infection_to_movement_modular_IS.R"
if(!file.exists(BASE)) stop("Missing base V7a-M script: ",BASE)

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
  'results/V7aM_infection_to_movement_',
  'results/V8PROV_V7aM_infection_to_movement_',
  txt,fixed=TRUE
)
txt <- gsub(
  'model="V7a-M modular infection -> subsequent high mobility"',
  'model="V8PROV V7a-M infection -> subsequent high mobility"',
  txt,fixed=TRUE
)
txt <- gsub(
  'WOODCHESTER V7a-M: INFECTION -> HIGH MOBILITY',
  'WOODCHESTER V8PROV V7a-M: INFECTION -> HIGH MOBILITY',
  txt,fixed=TRUE
)

generated <- file.path(tempdir(),"Woodchester_V8PROV_V7aM_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
source(generated,local=FALSE)
