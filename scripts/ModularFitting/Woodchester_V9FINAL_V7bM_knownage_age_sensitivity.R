# Final V9 wrapper for the frozen known-age V7b sensitivity.
BASE <- "scripts/ModularFitting/Woodchester_V8PROV_V7bM_knownage_age_sensitivity.R"
if(!file.exists(BASE)) stop("Missing base known-age V7b script: ",BASE)
txt <- paste(readLines(BASE,warn=FALSE),collapse="\n")
txt <- gsub("V8PROV","V9FINAL",txt,fixed=TRUE)
txt <- gsub("V8 provisional","V9 final",txt,fixed=TRUE)
txt <- gsub('data/badger_phase2_paired_latent_inputs_V9FINAL.rds','data/badger_phase2_paired_latent_inputs_V9_FINAL.rds',txt,fixed=TRUE)
txt <- gsub('data/badger_movement_posterior_histories_1932_V9FINAL.rds','data/badger_movement_posterior_histories_1932_V9_FINAL.rds',txt,fixed=TRUE)
txt <- gsub("development_only=TRUE","development_only=FALSE",txt,fixed=TRUE)
generated <- file.path(tempdir(),"Woodchester_V9FINAL_V7b_knownage_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated)
source(generated,local=FALSE)
