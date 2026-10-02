# Final V9 wrapper for the frozen known-age V7a sensitivity.
BASE <- "scripts/ModularFitting/Woodchester_V8PROV_V7aM_knownage_age_sensitivity.R"
if(!file.exists(BASE)) stop("Missing base known-age V7a script: ",BASE)
txt <- paste(readLines(BASE,warn=FALSE),collapse="\n")
txt <- gsub("V8PROV","V9FINAL",txt,fixed=TRUE)
txt <- gsub("V8 PROVISIONAL","V9 FINAL",txt,fixed=TRUE)
txt <- gsub("V8 provisional","V9 final",txt,fixed=TRUE)
txt <- gsub("_V8_PROVISIONAL.rds","_V9_FINAL.rds",txt,fixed=TRUE)
txt <- gsub("development_only=TRUE","development_only=FALSE",txt,fixed=TRUE)
generated <- file.path(tempdir(),"Woodchester_V9FINAL_V7a_knownage_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
source(generated,local=FALSE)
