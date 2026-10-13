# =============================================================================
# V5B RUNNER — SAME-GROUP PRESSURE MODEL
#
# Runs the validated V5 standalone model fitter, catches the known old reporting
# error that occurs only after all model fits have completed, verifies that all
# five models fitted successfully, then applies the safe finite-coefficient
# summary and saving step.
# =============================================================================

core <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V5_STANDALONE.R"
summary_fix <- "scripts/recover_V7bM_samegroup_pressure_V5_summary.R"
if(!file.exists(core)) stop("Missing core V5 script: ",core)
if(!file.exists(summary_fix)) stop("Missing V5B summary script: ",summary_fix)

core_result <- try(source(core),silent=TRUE)

# If V5 completed entirely, there is nothing else to do. At present the known
# V5 code stops only in its old pooled-summary block after all five fits succeed.
if(!inherits(core_result,"try-error")){
  message("V5 core completed without error.")
} else {
  needed <- c("draws","diag","fit_audit","pair_index")
  if(!all(vapply(needed,exists,logical(1),envir=.GlobalEnv,inherits=TRUE))){
    stop("V5 core stopped before successful model-fit objects were created. Original error: ",as.character(core_result))
  }

  expected <- c("M0_FULL","M0_CC","M1_RAW","M1_SMOOTH","M2_INTERACTION")
  chk <- fit_audit[fit_audit$model%in%expected,,drop=FALSE]
  if(nrow(chk)!=length(expected) || any(chk$failed>0) || any(chk$fitted!=chk$pairs)){
    stop("V5 core did not achieve successful fits for all five models. Original error: ",as.character(core_result))
  }

  message("All V5 model fits succeeded; applying V5B safe pooled-summary step.")
  source(summary_fix)
}
