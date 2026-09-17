# =============================================================================
# V8PROV V7a KNOWN-AGE AGE SENSITIVITY — SAFE SUMMARY WRAPPER
#
# The scientific fit in Woodchester_V8PROV_V7aM_knownage_age_sensitivity.R is
# unchanged. That script fits both models successfully, but bind_rows() creates
# a beta_age column filled with NA for the baseline model, and the original
# summary then calls quantile() on those NAs. This wrapper catches ONLY that
# known post-fit summary error, summarises finite model-specific coefficients,
# and saves the fitted objects/results.
# =============================================================================

library(tidyverse)

Sys.setenv(MAX_PAIRS=Sys.getenv("MAX_PAIRS","100"),
           N_PROP=Sys.getenv("N_PROP","3000"),
           N_KEEP=Sys.getenv("N_KEEP","50"),
           SEED=Sys.getenv("SEED","7092061"),
           RESULT_TAG=Sys.getenv("RESULT_TAG","SMOKE_100"))

base_file <- "scripts/ModularFitting/Woodchester_V8PROV_V7aM_knownage_age_sensitivity.R"
err <- tryCatch({source(base_file,local=.GlobalEnv); NULL},error=function(e)e)

if(is.null(err)){
  message("Base script completed without the historical summary error; no repair needed.")
} else {
  msg <- conditionMessage(err)
  expected <- grepl("missing values and NaN's not allowed",msg,fixed=TRUE) && grepl("quantile",msg,fixed=TRUE)
  if(!expected) stop(err)

  needed <- c("draws","diagnostics","cells","pair_index","AGE_CENTER","N_PROP","N_KEEP","RESULT_TAG")
  miss <- needed[!vapply(needed,exists,logical(1),envir=.GlobalEnv,inherits=FALSE)]
  if(length(miss)) stop("Fit stopped before required objects existed: ",paste(miss,collapse=", "))

  summarise_safe <- function(z,param){
    if(!param %in% names(z)) return(NULL)
    x <- as.numeric(z[[param]]); x <- x[is.finite(x)]
    if(!length(x)) return(NULL)
    tibble(parameter=param,mean=mean(x),sd=sd(x),median=median(x),
           q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),
           OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))
  }

  summary <- bind_rows(lapply(unique(draws$model),function(mm){
    z <- filter(draws,model==mm)
    bind_rows(lapply(c("beta_inf","beta_sex","beta_age"),function(p) summarise_safe(z,p))) %>%
      mutate(model=mm,.before=1)
  }))

  cat("\n============================================================\n")
  cat("V8PROV V7a KNOWN-AGE AGE SENSITIVITY — SAFE SUMMARY\n")
  cat("============================================================\n")
  print(summary,n=Inf,width=Inf)
  cat("\nDiagnostics:\n")
  print(diagnostics %>% group_by(model) %>% summarise(pairs=n(),min_ESS=min(IS_ESS),median_ESS=median(IS_ESS),
        max_weight=max(max_weight),optim_fail=sum(optim_code!=0),.groups="drop"),n=Inf,width=Inf)

  out <- paste0("results/V8PROV_V7aM_knownage_age_",RESULT_TAG,".rds")
  csv <- paste0("results/V8PROV_V7aM_knownage_age_",RESULT_TAG,"_summary.csv")
  saveRDS(list(model="V8PROV V7a known-age baseline vs chronological-age adjustment",
               draws=draws,summary=summary,diagnostics=diagnostics,cells=cells,pair_index=pair_index,
               settings=list(age_center=AGE_CENTER,n_pairs=nrow(pair_index),N_PROP=N_PROP,N_KEEP=N_KEEP,
                             development_only=TRUE,summary_fix="finite model-specific coefficients only")),out)
  write_csv(summary,csv)
  cat("Saved:",out,"\nSaved:",csv,"\n")
}
