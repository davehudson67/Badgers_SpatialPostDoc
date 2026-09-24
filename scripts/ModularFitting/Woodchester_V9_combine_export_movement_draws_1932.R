# =============================================================================
# WOODCHESTER V9 - COMBINE 1,932-BADGER MOVEMENT CHAINS + EXPORT JOINT DRAWS
#
# Reuses the established checked V7M combine/export logic, changing only input
# and output names/metadata for the V9 exact-prior reparameterised fit.
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
  '"results/RD_SCR_V9_MOVEMENT_MAXDATA_1932_CHAIN_%d.rds"',
  "V9 maximal chain files")
txt <- replace_once(txt,
  'combined_file <- "results/RD_SCR_V7M_MOVEMENT_ONLY_1285_COMBINED.rds"',
  'combined_file <- "results/RD_SCR_V9_MOVEMENT_MAXDATA_1932_COMBINED.rds"',
  "V9 maximal combined file")
txt <- replace_once(txt,
  'movement_export_file <- "data/badger_movement_posterior_draws_1285.rds"',
  'movement_export_file <- "data/badger_movement_posterior_draws_1932_V9.rds"',
  "V9 maximal movement export")

txt <- gsub("COMBINING V7M MOVEMENT-ONLY CHAINS","COMBINING V9 MAXIMAL-DATA MOVEMENT CHAINS",txt,fixed=TRUE)
txt <- gsub("V7M COMBINATION COMPLETE","V9 MAXIMAL-DATA COMBINATION COMPLETE",txt,fixed=TRUE)
txt <- gsub('model="V7M_movement_only_combined"','model="V9_movement_maxdata_exact_prior_reparam_combined"',txt,fixed=TRUE)
txt <- gsub('model_source="V7M_movement_only_1285"','model_source="V9_movement_maxdata_1932_exact_prior_reparam"',txt,fixed=TRUE)

generated_file <- file.path(tempdir(),"Woodchester_V9_combine_export_movement_draws_1932_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated_file)
cat("Generated checked V9 maximal-data combine/export source:\n",generated_file,"\n",sep="")
source(generated_file,local=FALSE)
