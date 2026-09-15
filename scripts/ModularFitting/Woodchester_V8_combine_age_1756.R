# =============================================================================
# WOODCHESTER V8 - COMBINE CHRONOLOGICAL-AGE MOVEMENT CHAINS
#
# Reuses the established movement-chain combination/diagnostic logic for the
# 1,756-badger chronological-age fit. The exported joint state draws are retained
# for reproducibility, although the primary purpose of this fit is inference on
# beta_age / OR_age_per_year.
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

txt <- replace_once(
  txt,
  '"results/RD_SCR_V7M_MOVEMENT_ONLY_1285_CHAIN_%d.rds"',
  '"results/RD_SCR_V8_MOVEMENT_AGE_1756_CHAIN_%d.rds"',
  "age chain files"
)
txt <- replace_once(
  txt,
  'combined_file <- "results/RD_SCR_V7M_MOVEMENT_ONLY_1285_COMBINED.rds"',
  'combined_file <- "results/RD_SCR_V8_MOVEMENT_AGE_1756_COMBINED.rds"',
  "age combined file"
)
txt <- replace_once(
  txt,
  'movement_export_file <- "data/badger_movement_posterior_draws_1285.rds"',
  'movement_export_file <- "data/badger_movement_posterior_draws_1756_AGE.rds"',
  "age movement export file"
)
txt <- gsub("COMBINING V7M MOVEMENT-ONLY CHAINS","COMBINING V8 CHRONOLOGICAL-AGE MOVEMENT CHAINS",txt,fixed=TRUE)
txt <- gsub("V7M COMBINATION COMPLETE","V8 CHRONOLOGICAL-AGE COMBINATION COMPLETE",txt,fixed=TRUE)
txt <- gsub('model="V7M_movement_only_combined"','model="V8_movement_age_combined"',txt,fixed=TRUE)
txt <- gsub('model_source="V7M_movement_only_1285"','model_source="V8_movement_age_1756"',txt,fixed=TRUE)

generated_file <- file.path(tempdir(),"Woodchester_V8_combine_age_1756_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated_file)
cat("Generated checked age-model combine source:\n",generated_file,"\n",sep="")
source(generated_file,local=FALSE)
