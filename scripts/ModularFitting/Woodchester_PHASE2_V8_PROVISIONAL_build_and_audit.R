# =============================================================================
# WOODCHESTER PHASE 2 - V8 PROVISIONAL MOVEMENT -> PAIRED LATENT HISTORIES
#
# Purpose
#   Use the current V8 1,932-badger movement posterior export to exercise the
#   downstream directional disease models while V9 is being finalised.
#
# IMPORTANT
#   These are PROVISIONAL downstream analyses because V8 movement-scale
#   parameters have imperfect mixing. The latent movement-state histories are
#   nevertheless highly consistent across chains and are suitable for testing
#   the Phase-2 pipeline and provisional biological effects.
#
#   The script converts the V8 export into the legacy Phase-2 movement-object
#   shape, subsets only animals represented in the canonical infection snapshot,
#   then runs the established paired-history builder unchanged apart from input/
#   output filenames.
# =============================================================================

library(tidyverse)

MOVE_V8 <- "data/badger_movement_posterior_draws_1932.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
MOVE_COMPAT <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"
PAIR_OUT <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"
BASE_BUILDER <- "scripts/ModularFitting/Woodchester_PHASE2_build_and_audit_paired_histories.R"

for(f in c(MOVE_V8,INF_FILE,BASE_BUILDER))
  if(!file.exists(f)) stop("Missing required file: ",f)

v8 <- readRDS(MOVE_V8)
inf <- readRDS(INF_FILE)

req_v8 <- c("movement_draws","draw_source","disp_index","sex_data")
if(!all(req_v8%in%names(v8)))
  stop("V8 movement export missing: ",paste(setdiff(req_v8,names(v8)),collapse=", "))
if(!all(c("tattoo","model_i","from_year","to_year")%in%names(v8$disp_index)))
  stop("V8 disp_index lacks required interval fields.")
if(!all(c("tattoo","infection_time","draws","start_year")%in%names(inf)))
  stop("Canonical infection trajectory fields are missing.")
if(ncol(v8$movement_draws)!=nrow(v8$disp_index))
  stop("V8 movement_draws columns do not match disp_index rows.")

inf_ids <- trimws(as.character(inf$tattoo))
idx_all <- v8$disp_index %>%
  mutate(tattoo=trimws(as.character(tattoo)))
keep <- idx_all$tattoo%in%inf_ids

if(!any(keep)) stop("No V8 movement intervals match infection-trajectory tattoos.")

idx <- idx_all[keep,,drop=FALSE]
states <- v8$movement_draws[,keep,drop=FALSE]

all_move_ids <- unique(idx_all$tattoo)
kept_ids <- unique(idx$tattoo)
dropped_ids <- setdiff(all_move_ids,kept_ids)

cat("\n============================================================\n")
cat("V8 PROVISIONAL PHASE-2 MOVEMENT ADAPTER\n")
cat("============================================================\n")
cat("Original movement badgers:",length(all_move_ids),"\n")
cat("Disease-matched movement badgers:",length(kept_ids),"\n")
cat("Dropped because absent from infection snapshot:",length(dropped_ids),"\n")
cat("Retained movement intervals:",nrow(idx),"of",nrow(idx_all),"\n")
cat("Joint movement draws:",nrow(states),"\n")

src_chain <- if("source_chain"%in%names(v8$draw_source)) v8$draw_source$source_chain else rep(NA_integer_,nrow(states))
src_row <- if("source_iteration_row"%in%names(v8$draw_source)) v8$draw_source$source_iteration_row else seq_len(nrow(states))

draw_index <- tibble(
  chain=as.integer(src_chain),
  retained_draw=as.integer(src_row)
)

mov_compat <- list(
  state_draws=states,
  interval_index=idx,
  sex=as.integer(v8$sex_data),
  draw_index=draw_index,
  source_file=MOVE_V8,
  settings=list(
    model="V8 maximal-data 1932 PROVISIONAL downstream adapter",
    provisional=TRUE,
    reason="movement-scale parameters not fully converged; latent-state histories highly consistent across chains",
    disease_subset="movement intervals retained only when tattoo exists in canonical infection snapshot"
  )
)

saveRDS(mov_compat,MOVE_COMPAT,compress="xz")
cat("Saved Phase-2-compatible provisional movement object:",MOVE_COMPAT,"\n")

# Run the established paired-history builder with only file identity changed.
txt <- paste(readLines(BASE_BUILDER,warn=FALSE),collapse="\n")
txt <- gsub(
  'MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"',
  paste0('MOVE_FILE <- "',MOVE_COMPAT,'"'),txt,fixed=TRUE
)
txt <- gsub(
  'OUT_FILE <- "data/badger_phase2_paired_latent_inputs.rds"',
  paste0('OUT_FILE <- "',PAIR_OUT,'"'),txt,fixed=TRUE
)
txt <- gsub(
  'movement_model="V7MCMHMMv6_FINAL30K"',
  'movement_model="V8_MAXDATA_1932_PROVISIONAL"',txt,fixed=TRUE
)

generated <- file.path(tempdir(),"Woodchester_PHASE2_V8_PROVISIONAL_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
cat("\nRunning established Phase-2 pairing/audit on V8 provisional states...\n")
source(generated,local=FALSE)
cat("\nV8 PROVISIONAL paired-history object:",PAIR_OUT,"\n")
