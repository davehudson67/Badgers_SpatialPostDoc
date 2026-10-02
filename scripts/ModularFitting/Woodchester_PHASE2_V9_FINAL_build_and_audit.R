# =============================================================================
# WOODCHESTER PHASE 2 - V9 FINAL MOVEMENT -> PAIRED LATENT HISTORIES
#
# Uses the accepted long-run V9 maximal-data movement-state export for the final
# modular directional disease analyses. Exact movement-distance scale mixing is
# not used by these downstream models; they use coherent posterior draws of the
# binary local/high-mobility state, whose chain agreement is ~99%.
# =============================================================================

library(tidyverse)

MOVE_V9 <- "data/badger_movement_posterior_draws_1932_V9.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
MOVE_COMPAT <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
PAIR_OUT <- "data/badger_phase2_paired_latent_inputs_V9_FINAL.rds"
BASE_BUILDER <- "scripts/ModularFitting/Woodchester_PHASE2_build_and_audit_paired_histories.R"

for(f in c(MOVE_V9,INF_FILE,BASE_BUILDER)) if(!file.exists(f)) stop("Missing required file: ",f)

v9 <- readRDS(MOVE_V9)
inf <- readRDS(INF_FILE)

req_v9 <- c("movement_draws","draw_source","disp_index","sex_data")
if(!all(req_v9%in%names(v9))) stop("V9 movement export missing: ",paste(setdiff(req_v9,names(v9)),collapse=", "))
if(!all(c("tattoo","model_i","from_year","to_year")%in%names(v9$disp_index))) stop("V9 disp_index lacks required interval fields.")
if(!all(c("tattoo","infection_time","draws","start_year")%in%names(inf))) stop("Canonical infection trajectory fields are missing.")
if(ncol(v9$movement_draws)!=nrow(v9$disp_index)) stop("V9 movement_draws columns do not match disp_index rows.")

inf_ids <- trimws(as.character(inf$tattoo))
idx_all <- v9$disp_index %>% mutate(tattoo=trimws(as.character(tattoo)))
keep <- idx_all$tattoo%in%inf_ids
if(!any(keep)) stop("No V9 movement intervals match infection-trajectory tattoos.")

idx <- idx_all[keep,,drop=FALSE]
states <- v9$movement_draws[,keep,drop=FALSE]
all_move_ids <- unique(idx_all$tattoo); kept_ids <- unique(idx$tattoo); dropped_ids <- setdiff(all_move_ids,kept_ids)

cat("\n============================================================\n")
cat("V9 FINAL PHASE-2 MOVEMENT ADAPTER\n")
cat("============================================================\n")
cat("Original movement badgers:",length(all_move_ids),"\n")
cat("Disease-matched movement badgers:",length(kept_ids),"\n")
cat("Dropped because absent from infection snapshot:",length(dropped_ids),"\n")
cat("Retained movement intervals:",nrow(idx),"of",nrow(idx_all),"\n")
cat("Joint movement draws:",nrow(states),"\n")

src_chain <- if("source_chain"%in%names(v9$draw_source)) v9$draw_source$source_chain else rep(NA_integer_,nrow(states))
src_row <- if("source_iteration_row"%in%names(v9$draw_source)) v9$draw_source$source_iteration_row else seq_len(nrow(states))
draw_index <- tibble(chain=as.integer(src_chain),retained_draw=as.integer(src_row))

mov_compat <- list(
  state_draws=states,interval_index=idx,sex=as.integer(v9$sex_data),draw_index=draw_index,source_file=MOVE_V9,
  settings=list(model="V9 maximal-data 1932 accepted final state-history adapter",
                provisional=FALSE,
                movement_scale_note="downstream models use latent state draws, not exact sex-specific movement-distance scales",
                disease_subset="movement intervals retained only when tattoo exists in canonical infection snapshot")
)
saveRDS(mov_compat,MOVE_COMPAT,compress="xz")
cat("Saved Phase-2-compatible V9 movement object:",MOVE_COMPAT,"\n")

txt <- paste(readLines(BASE_BUILDER,warn=FALSE),collapse="\n")
txt <- gsub('MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"',
            paste0('MOVE_FILE <- "',MOVE_COMPAT,'"'),txt,fixed=TRUE)
txt <- gsub('OUT_FILE <- "data/badger_phase2_paired_latent_inputs.rds"',
            paste0('OUT_FILE <- "',PAIR_OUT,'"'),txt,fixed=TRUE)
txt <- gsub('movement_model="V7MCMHMMv6_FINAL30K"',
            'movement_model="V9_MAXDATA_1932_LONGRUN_FINAL_STATES"',txt,fixed=TRUE)

generated <- file.path(tempdir(),"Woodchester_PHASE2_V9_FINAL_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
cat("\nRunning established Phase-2 pairing/audit on V9 final states...\n")
source(generated,local=FALSE)
cat("\nV9 FINAL paired-history object:",PAIR_OUT,"\n")
