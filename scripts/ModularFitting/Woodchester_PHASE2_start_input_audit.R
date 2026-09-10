# =============================================================================
# WOODCHESTER PHASE 2 START: MOVEMENT + INFECTION DIRECTION AUDIT
#
# This is the first Phase-2 script. It checks the two posterior-history objects,
# matches badgers, identifies the infection-time representation and produces a
# directional-analysis audit BEFORE fitting the modular regressions.
# =============================================================================
library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"

if(!file.exists(MOVE_FILE)) stop("Missing movement file: ",MOVE_FILE)
if(!file.exists(INF_FILE)) stop("Missing infection file: ",INF_FILE)

mov <- readRDS(MOVE_FILE)
inf <- readRDS(INF_FILE)

cat("\n============================================================\n")
cat("PHASE 2 INPUT AUDIT\n")
cat("============================================================\n")
cat("Movement histories:",nrow(mov$state_draws),"\n")
cat("Movement intervals:",ncol(mov$state_draws),"\n")
cat("Movement badgers:",length(unique(mov$interval_index$tattoo)),"\n")
cat("Infection object class:",paste(class(inf),collapse=", "),"\n")

# Recognise the common trajectory formats used in this project.
extract_inf <- function(x){
  if(is.matrix(x))
    return(list(mat=x,ids=rownames(x),format="matrix"))

  if(is.data.frame(x) && all(c("tattoo","draw","infection_time")%in%names(x))){
    w <- x %>%
      select(tattoo,draw,infection_time) %>%
      distinct() %>%
      pivot_wider(names_from=draw,values_from=infection_time) %>%
      arrange(tattoo)
    m <- as.matrix(w[,-1,drop=FALSE])
    storage.mode(m) <- "numeric"
    return(list(mat=m,ids=as.character(w$tattoo),format="long_data_frame"))
  }

  if(is.list(x)){
    for(nm in c("infection_time_matrix","infection_times","infection_time","trajectory_matrix")){
      if(!is.null(x[[nm]]) && is.matrix(x[[nm]])){
        ids <- if(!is.null(x$ids)) as.character(x$ids) else rownames(x[[nm]])
        return(list(mat=x[[nm]],ids=ids,format=paste0("list$",nm)))
      }
    }
    if(!is.null(x$trajectories) && is.data.frame(x$trajectories) &&
       all(c("tattoo","draw","infection_time")%in%names(x$trajectories))){
      return(extract_inf(x$trajectories))
    }
  }

  stop(
    "Infection trajectory representation was not recognised automatically.\n",
    "Run: str(readRDS('",INF_FILE,"'),max.level=2)\n",
    "and paste the output back before Phase 2 fitting. No time-scale assumptions were guessed."
  )
}

ix <- extract_inf(inf)
if(is.null(ix$ids)) stop("Infection trajectories do not contain tattoo/row IDs.")

move_ids <- unique(as.character(mov$interval_index$tattoo))
inf_ids <- as.character(ix$ids)
common <- intersect(move_ids,inf_ids)

cat("Recognised infection format:",ix$format,"\n")
cat("Infection badgers:",length(unique(inf_ids)),"\n")
cat("Matched movement/infection badgers:",length(common),"\n")
cat("Infection trajectory draws:",ncol(ix$mat),"\n")

# Basic infection-time summaries; this intentionally does not convert to
# calendar years until the infection-time origin is explicitly confirmed.
vals <- as.numeric(ix$mat)
cat("Finite positive infection times:",sum(is.finite(vals)&vals>0),"\n")
cat("Never/zero infection times:",sum(vals==0,na.rm=TRUE),"\n")
cat("Missing infection times:",sum(is.na(vals)),"\n")
if(any(is.finite(vals)&vals>0)){
  cat("Positive infection-time range:",
      min(vals[is.finite(vals)&vals>0]),"to",
      max(vals[is.finite(vals)&vals>0]),"\n")
}

saveRDS(
  list(
    movement_file=MOVE_FILE,
    infection_file=INF_FILE,
    infection_format=ix$format,
    infection_time_matrix=ix$mat,
    infection_ids=inf_ids,
    matched_ids=common,
    movement_interval_index=mov$interval_index,
    settings=list(
      next_step="confirm infection-time calendar origin, then build V7a-M and V7b-M paired posterior datasets",
      V7a_M="infection status at origin-year Q4 -> subsequent local-to-high transition",
      V7b_M="movement ending year t -> infection acquisition in Q1-Q4 of year t+1"
    )
  ),
  "data/badger_phase2_input_audit.rds"
)
cat("\nSaved: data/badger_phase2_input_audit.rds\n")
