# =============================================================================
# RECOVER / COMPLETE V5 SAME-GROUP PRESSURE SUMMARY
#
# Use this after a V5 run in which all five models fitted successfully but the
# old pooled-summary step stopped on NA columns created by bind_rows().
#
# This script DOES NOT refit any models. It uses the successful objects already
# in the current R session: draws, diag, fit_audit and pair_index.
# =============================================================================

library(tidyverse)

needed <- c("draws","diag","fit_audit","pair_index","MIN_GROUP_N","N_KEEP","RESULT_TAG")
missing_objects <- needed[!vapply(needed,exists,logical(1),envir=.GlobalEnv,inherits=TRUE)]
if(length(missing_objects)) stop("Missing objects from the completed V5 fit: ",paste(missing_objects,collapse=", "),
                                 ". Re-run through the V5B launcher instead.")

expected_models <- c("M0_FULL","M0_CC","M1_RAW","M1_SMOOTH","M2_INTERACTION")
audit_check <- fit_audit %>% filter(model%in%expected_models)
if(nrow(audit_check)!=length(expected_models) || any(audit_check$failed>0) || any(audit_check$fitted!=audit_check$pairs))
  stop("The V5 fit audit is not fully successful; summary recovery has been stopped.")

summarise_parameter_safe <- function(df,param,label){
  if(!param%in%names(df)) return(tibble())
  x <- as.numeric(df[[param]])
  x <- x[is.finite(x)]
  if(!length(x)) return(tibble())
  tibble(model=unique(df$model)[1],parameter=label,n_draws=length(x),mean=mean(x),sd=sd(x),median=median(x),
         q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),
         OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
}

summary_rows <- list(); ns <- 0L
for(nm in expected_models){
  z <- draws %>% filter(model==nm)
  candidates <- list(
    c("movement_state","beta_move"),
    c("pressure10","beta_pressure_per_10pp"),
    c("pressure_smooth10","beta_smoothed_pressure_per_10pp"),
    c("movement_state:pressure10","beta_move_x_pressure_per_10pp"),
    c("sex","beta_sex")
  )
  for(cc in candidates){
    ss <- summarise_parameter_safe(z,cc[1],cc[2])
    if(nrow(ss)){ns <- ns+1L; summary_rows[[ns]] <- ss}
  }
}
param_summary <- bind_rows(summary_rows)

cat("\n============================================================\n")
cat("POOLED COEFFICIENT SUMMARY — SAFE V5B REPORTING\n")
cat("============================================================\n")
print(param_summary,n=Inf,width=Inf)

interaction_derived <- tibble()
z <- draws %>% filter(model=="M2_INTERACTION")
if(all(c("movement_state","movement_state:pressure10")%in%names(z))){
  keep <- is.finite(z$movement_state) & is.finite(z$`movement_state:pressure10`)
  z <- z[keep,,drop=FALSE]
  if(nrow(z)){
    interaction_derived <- bind_rows(lapply(c(0,.10,.25,.50),function(p){
      lp <- z$movement_state+z$`movement_state:pressure10`*(10*p)
      tibble(pressure_prevalence=p,n_draws=length(lp),OR_move_median=median(exp(lp)),
             OR_move_q025=unname(quantile(exp(lp),.025)),OR_move_q975=unname(quantile(exp(lp),.975)),
             P_move_positive=mean(lp>0))
    }))
    cat("\n============================================================\n")
    cat("INTERACTION: MOVEMENT OR AT SELECTED SAME-GROUP PRESSURES\n")
    cat("============================================================\n")
    print(interaction_derived,n=Inf,width=Inf)
  }
}

movement_compare <- param_summary %>% filter(parameter=="beta_move") %>%
  select(model,n_draws,median,q025,q975,P_gt_0,OR_median,OR_q025,OR_q975)
cat("\n============================================================\n")
cat("MOVEMENT EFFECT COMPARISON\n")
cat("============================================================\n")
print(movement_compare,n=Inf,width=Inf)

cat("\nINTERPRETATION GUIDE\n")
cat("- Frozen primary V7b-M -> M0_FULL: estimation-framework calibration.\n")
cat("- M0_FULL -> M0_CC: pressure-support sample restriction in the same engine.\n")
cat("- M0_CC -> M1_RAW/M1_SMOOTH: pressure adjustment on identical rows.\n")
cat("- beta_pressure is per +10 percentage-points same-group prevalence at Q4(t).\n")
cat("- M2 interaction is exploratory and may be imprecise.\n")
cat("- M1/M2 are mechanistic/direct-effect sensitivities, not total-effect replacements.\n")

result_tag_safe <- as.character(RESULT_TAG)
if(grepl("_V5$",result_tag_safe)) result_tag_safe <- sub("_V5$","_V5B",result_tag_safe)

dir.create("results",showWarnings=FALSE,recursive=TRUE)
out_rds <- paste0("results/V7bM_samegroup_pressure_",result_tag_safe,"_minN",MIN_GROUP_N,".rds")
out_summary <- paste0("results/V7bM_samegroup_pressure_",result_tag_safe,"_minN",MIN_GROUP_N,"_summary.csv")
out_fit <- paste0("results/V7bM_samegroup_pressure_",result_tag_safe,"_minN",MIN_GROUP_N,"_fit_audit.csv")

saveRDS(list(model="V7b-M same-social-group pressure mechanistic sensitivity V5B safe summary",
             coefficient_draws=draws,parameter_summary=param_summary,movement_comparison=movement_compare,
             interaction_derived=interaction_derived,fit_audit=fit_audit,fit_diagnostics=diag,
             settings=list(min_group_n=MIN_GROUP_N,paired_histories=nrow(pair_index),draws_per_history=N_KEEP,
                           pressure_time="Q4(t)",outcome_time="Q1-Q4(t+1)",pressure_scale="10 percentage points",
                           covariance="badger-cluster robust",complete_case_benchmark=TRUE,
                           summary_fix="finite coefficients only after bind_rows")),out_rds)
write_csv(param_summary,out_summary)
write_csv(fit_audit,out_fit)
cat("\nSaved:",out_rds,"\nSaved:",out_summary,"\nSaved:",out_fit,"\n")
