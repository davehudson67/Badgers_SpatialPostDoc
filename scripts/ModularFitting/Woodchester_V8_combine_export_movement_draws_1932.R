# =============================================================================
# WOODCHESTER V8 - COMBINE 1,932-BADGER MOVEMENT CHAINS + EXPORT JOINT DRAWS
#
# Uses the existing checked V7M combine/export logic, changing only filenames and
# metadata for the maximal-data movement fit. Joint posterior movement histories
# are retained; downstream disease analyses should subset intervals/animals to
# their own eligibility rather than thresholding posterior state probabilities.
# =============================================================================

BASE_FILE <- "scripts/ModularFitting/Woodchester_V7M_combine_export_movement_draws.R"
if(!file.exists(BASE_FILE)) stop("Missing frozen combine/export source: ",BASE_FILE)

src <- readLines(BASE_FILE,warn=FALSE)
if(!any(grepl("MOVEMENT_ONLY_1285_CHAIN",src,fixed=TRUE)))
  stop("Frozen combine/export source no longer contains expected 1,285 chain filenames.")

src <- gsub("1285","1932",src,fixed=TRUE)
src <- gsub("V7M_movement_only_1932","V8_movement_maxdata_1932",src,fixed=TRUE)
src <- gsub("COMBINING V7M MOVEMENT-ONLY CHAINS","COMBINING V8 MAXIMAL-DATA MOVEMENT CHAINS",src,fixed=TRUE)
src <- gsub("V7M COMBINATION COMPLETE","V8 MAXIMAL-DATA COMBINATION COMPLETE",src,fixed=TRUE)

generated_file <- file.path(tempdir(),"Woodchester_V8_combine_export_movement_draws_1932_generated.R")
writeLines(src,generated_file)
cat("Generated checked maximal-data combine/export source:\n",generated_file,"\n",sep="")
source(generated_file,local=FALSE)
