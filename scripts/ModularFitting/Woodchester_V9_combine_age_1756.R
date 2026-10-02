# =============================================================================
# WOODCHESTER V9 - COMBINE 1,756-BADGER CHRONOLOGICAL-AGE MOVEMENT CHAINS
#
# Reuses the established checked V7M combine/export logic for the V9 age fit.
# =============================================================================

BASE_FILE <- "scripts/ModularFitting/Woodchester_V7M_combine_export_movement_draws.R"
if(!file.exists(BASE_FILE)) stop("Missing frozen combine/export source: ",BASE_FILE)

txt <- paste(readLines(BASE_FILE,warn=FALSE),collapse="\n")

replace_once <- function(x,old,new,label){
  loc <- gregexpr(old,x,fixed=TRUE)[[1]]
  n <- if(length(loc)==1L && loc[1]==-1L) 0L else length(loc)
  if(n!=1L) stop("Expected exactly one match for ",label,", found ",n,".")
  sub(old,new,x,fixed=TRUE)
}

txt <- replace_once(txt,
  '"results/RD_SCR_V7M_MOVEMENT_ONLY_1285_CHAIN_%d.rds"',
  '"results/RD_SCR_V9_MOVEMENT_AGE_1756_CHAIN_%d.rds"',
  "V9 age chain files")
txt <- replace_once(txt,
  'combined_file <- "results/RD_SCR_V7M_MOVEMENT_ONLY_1285_COMBINED.rds"',
  'combined_file <- "results/RD_SCR_V9_MOVEMENT_AGE_1756_COMBINED.rds"',
  "V9 age combined file")
txt <- replace_once(txt,
  'movement_export_file <- "data/badger_movement_posterior_draws_1285.rds"',
  'movement_export_file <- "data/badger_movement_posterior_draws_1756_AGE_V9.rds"',
  "V9 age movement export")

txt <- gsub("COMBINING V7M MOVEMENT-ONLY CHAINS","COMBINING V9 CHRONOLOGICAL-AGE MOVEMENT CHAINS",txt,fixed=TRUE)
txt <- gsub("V7M COMBINATION COMPLETE","V9 CHRONOLOGICAL-AGE COMBINATION COMPLETE",txt,fixed=TRUE)
txt <- gsub('model="V7M_movement_only_combined"','model="V9_movement_age_exact_prior_reparam_combined"',txt,fixed=TRUE)
txt <- gsub('model_source="V7M_movement_only_1285"','model_source="V9_movement_age_1756_exact_prior_reparam"',txt,fixed=TRUE)

generated_file <- file.path(tempdir(),"Woodchester_V9_combine_age_1756_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated_file)
cat("Generated checked V9 age-model combine/export source:\n",generated_file,"\n",sep="")
source(generated_file,local=FALSE)
