# =============================================================================
# V8 PROVISIONAL V7b-M SAME-GROUP PRESSURE DEVELOPMENT WRAPPER
#
# Reuses the already-built pressure matrices from the historical 1,285-badger
# pressure analysis, but maps those interval rows onto the matching intervals in
# the current 1,932-badger V8 provisional movement posterior. Thus this is a
# DEVELOPMENT/SUBSET analysis only: it tests model behaviour and the movement x
# pressure interaction without rebuilding pressure for the final population.
# Final inference must be rebuilt from the frozen V9 movement histories.
# =============================================================================

BASE_V5 <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V5_STANDALONE.R"
BASE_V5B <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V5B_SUMMARYFIX.R"
for(f in c(BASE_V5,BASE_V5B)) if(!file.exists(f)) stop("Missing base pressure script: ",f)

replace_once <- function(x,old,new,label){
  loc <- gregexpr(old,x,fixed=TRUE)[[1]]; n <- if(length(loc)==1L && loc[1]==-1L) 0L else length(loc)
  if(n!=1L) stop("Expected one match for ",label,", found ",n)
  sub(old,new,x,fixed=TRUE)
}

v5 <- paste(readLines(BASE_V5,warn=FALSE),collapse="\n")
v5 <- replace_once(v5,'MOVE_FILE  <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"','MOVE_FILE  <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"',"movement file")
v5 <- replace_once(v5,'PAIR_FILE  <- "data/badger_phase2_paired_latent_inputs.rds"','PAIR_FILE  <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"',"paired file")

inject <- paste(c(
  '# ---- V8 provisional remap of historical pressure rows ---------------------',
  '# Pressure matrices retain the 1,285-row-set interval order. Remap only the',
  '# movement-state lookup (model_i/interval_col) to the matching V8 interval.',
  'v8_idx <- as_tibble(mov$interval_index) %>%',
  '  mutate(v8_interval_col=row_number(),v8_model_i=as.integer(model_i),',
  '         tattoo=trimws(as.character(tattoo)),to_year=as.integer(to_year))',
  'dups <- v8_idx %>% count(tattoo,to_year) %>% filter(n>1L)',
  'if(nrow(dups)) stop("V8 interval key tattoo+to_year is not unique.")',
  'v8_key <- paste(v8_idx$tattoo,v8_idx$to_year,sep="|")',
  'old_key <- paste(pidx$tattoo,pidx$pressure_year,sep="|")',
  'mm <- match(old_key,v8_key)',
  'if(anyNA(mm)) stop(sum(is.na(mm))," historical pressure intervals could not be mapped to V8 movement intervals.")',
  'pidx$model_i <- v8_idx$v8_model_i[mm]',
  'pidx$interval_col <- v8_idx$v8_interval_col[mm]',
  'cat("Mapped",nrow(pidx),"historical pressure intervals to V8 provisional movement histories.\\n")',
  '# ---------------------------------------------------------------------------'
),collapse="\n")
v5 <- replace_once(v5,'P_RAW <- press$matrices$samegroup_prev',paste0(inject,'\n\nP_RAW <- press$matrices$samegroup_prev'),"pressure matrix insertion")
v5_file <- file.path(tempdir(),"Woodchester_V8PROV_pressure_V5_generated.R")
writeLines(strsplit(v5,"\n",fixed=TRUE)[[1]],v5_file)

v5b <- paste(readLines(BASE_V5B,warn=FALSE),collapse="\n")
v5b <- replace_once(v5b,'v5_file <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V5_STANDALONE.R"',paste0('v5_file <- "',v5_file,'"'),"generated V5 file")
v5b <- gsub('results/V7bM_samegroup_pressure_','results/V8PROV_V7bM_samegroup_pressure_SUBSET1285_',v5b,fixed=TRUE)
v5b <- gsub('V7b-M same-social-group pressure mechanistic sensitivity V5B summary-fixed','V8PROV V7b-M same-group pressure subset-1285 development sensitivity',v5b,fixed=TRUE)
v5b_file <- file.path(tempdir(),"Woodchester_V8PROV_pressure_V5B_generated.R")
writeLines(strsplit(v5b,"\n",fixed=TRUE)[[1]],v5b_file)

cat("\nV8PROV pressure development analysis\n")
cat("- movement states: V8 provisional 1,932 posterior\n")
cat("- pressure support: historical 1,285 interval subset mapped by tattoo+year\n")
cat("- purpose: development/model architecture only; NOT final inference\n\n")
source(v5b_file,local=FALSE)
