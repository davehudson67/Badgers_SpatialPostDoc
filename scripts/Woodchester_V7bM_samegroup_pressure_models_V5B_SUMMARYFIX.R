# =============================================================================
# WOODCHESTER V7b-M SAME-GROUP PRESSURE — V5B SUMMARY FIX
#
# V5 standalone successfully fits all five models. Its only remaining bug is
# post-fit summarisation: dplyr::bind_rows() creates union columns across models,
# filling model-specific coefficients with NA. The original summary loop tested
# only whether a column name existed, so it attempted quantiles of an all-NA
# pressure column for M0_FULL and stopped after the FIT AUDIT.
#
# This wrapper runs the scientifically unchanged V5 model, catches ONLY that
# known post-fit quantile error, then summarises coefficients using finite draws
# only and saves the complete output. No model fitting, risk-set construction,
# covariance calculation or scientific specification is changed.
# =============================================================================

library(tidyverse)

v5_file <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V5_STANDALONE.R"
if(!file.exists(v5_file)) stop("Missing V5 model script: ",v5_file)

v5_error <- tryCatch({
  source(v5_file,local=.GlobalEnv)
  NULL
},error=function(e)e)

if(is.null(v5_error)){
  message("V5 completed without the historical summary error; no V5B repair was needed.")
} else {
  msg <- conditionMessage(v5_error)
  expected <- grepl("missing values and NaN's not allowed",msg,fixed=TRUE) &&
              grepl("quantile",msg,fixed=TRUE)
  if(!expected) stop(v5_error)

  needed <- c("draws","diag","fit_audit","pair_index","MIN_GROUP_N","N_KEEP","RESULT_TAG")
  missing_objects <- needed[!vapply(needed,exists,logical(1),envir=.GlobalEnv,inherits=FALSE)]
  if(length(missing_objects)) stop("V5 stopped before required fitted objects existed: ",paste(missing_objects,collapse=", "))

  message("V5 fitted successfully; repairing only the post-fit coefficient summary.")

  summarise_parameter_safe <- function(df,param,label){
    if(!param %in% names(df)) return(NULL)
    x <- as.numeric(df[[param]])
    x <- x[is.finite(x)]
    if(!length(x)) return(NULL)
    tibble(model=unique(df$model),parameter=label,n_draws=length(x),mean=mean(x),sd=sd(x),median=median(x),
           q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),
           OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
  }

  summary_rows <- list(); ns <- 0L
  for(nm in unique(draws$model)){
    z <- draws %>% filter(model==nm)
    specs <- list(
      c("movement_state","beta_move"),
      c("pressure10","beta_pressure_per_10pp"),
      c("pressure_smooth10","beta_smoothed_pressure_per_10pp"),
      c("movement_state:pressure10","beta_move_x_pressure_per_10pp"),
      c("sex","beta_sex")
    )
    for(sp in specs){
      rr <- summarise_parameter_safe(z,sp[1],sp[2])
      if(!is.null(rr)){ns <- ns+1L; summary_rows[[ns]] <- rr}
    }
  }
  param_summary <- bind_rows(summary_rows)

  cat("\n============================================================\n")
  cat("POOLED COEFFICIENT SUMMARY — V5B SAFE SUMMARY\n")
  cat("============================================================\n")
  print(param_summary,n=Inf,width=Inf)

  interaction_derived <- tibble()
  if("M2_INTERACTION" %in% draws$model){
    z <- draws %>% filter(model=="M2_INTERACTION")
    keep <- is.finite(z$movement_state) & is.finite(z$`movement_state:pressure10`)
    if(any(keep)){
      bM <- z$movement_state[keep]
      bI <- z$`movement_state:pressure10`[keep]
      interaction_derived <- bind_rows(lapply(c(0,.10,.25,.50),function(p){
        lp <- bM+bI*(10*p)
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

  dir.create("results",showWarnings=FALSE,recursive=TRUE)
  out_rds <- paste0("results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,".rds")
  out_summary <- paste0("results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,"_summary.csv")
  out_fit <- paste0("results/V7bM_samegroup_pressure_",RESULT_TAG,"_minN",MIN_GROUP_N,"_fit_audit.csv")

  saveRDS(list(model="V7b-M same-social-group pressure mechanistic sensitivity V5B summary-fixed",
               coefficient_draws=draws,parameter_summary=param_summary,movement_comparison=movement_compare,
               interaction_derived=interaction_derived,fit_audit=fit_audit,fit_diagnostics=diag,
               settings=list(min_group_n=MIN_GROUP_N,paired_histories=nrow(pair_index),draws_per_history=N_KEEP,
                             pressure_time="Q4(t)",outcome_time="Q1-Q4(t+1)",pressure_scale="10 percentage points",
                             covariance="badger-cluster robust",complete_case_benchmark=TRUE,
                             v5b_change="summary only: finite model-specific coefficient draws")),out_rds)
  write_csv(param_summary,out_summary)
  write_csv(fit_audit,out_fit)

  cat("\nSaved:",out_rds,"\n")
  cat("Saved:",out_summary,"\n")
  cat("Saved:",out_fit,"\n")
}
