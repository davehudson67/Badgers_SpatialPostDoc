# =============================================================================
# WOODCHESTER V8 - MAXIMAL-DATA MOVEMENT PRODUCTION MODEL
#
# Purpose
#   Run the established V7M/V6c movement model on EVERY badger with at least two
#   spatially usable live years (expected n = 1,932 from the population audit).
#
#   This deliberately removes the old restriction to animals that could also
#   contribute to V7a/V7b. Disease analyses should subset the resulting movement
#   histories downstream rather than restricting the movement fit itself.
#
#   The previous 1,285-badger production script is left untouched. This wrapper
#   makes a small, checked set of edits to that frozen source at run time, writes
#   the generated source to a temporary file, and runs it. If the frozen source
#   changes so that an expected edit can no longer be made exactly, this script
#   stops rather than silently fitting a different model.
# =============================================================================

BASE_FILE <- "scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V7M_MOVEMENT_ONLY_1285_CHAIN.R"
EXPECTED_N <- 1932L

if(!file.exists(BASE_FILE)) stop("Missing frozen base model: ",BASE_FILE)
src <- readLines(BASE_FILE,warn=FALSE)

replace_block <- function(x,start_pattern,end_pattern,replacement,label){
  s <- grep(start_pattern,x,fixed=TRUE); e <- grep(end_pattern,x,fixed=TRUE)
  if(length(s)!=1L || length(e)!=1L || e<s) stop("Could not uniquely patch ",label," in frozen base model.")
  c(x[seq_len(s-1L)],replacement,x[(e+1L):length(x)])
}
replace_once <- function(x,old,new,label){
  hit <- grep(old,x,fixed=TRUE)
  if(length(hit)!=1L) stop("Expected exactly one match for ",label,", found ",length(hit),".")
  x[hit] <- sub(old,new,x[hit],fixed=TRUE); x
}

# ---- remove directional-audit dependency ------------------------------------
src <- src[!grepl('AUDIT_FILE <- "results/V7_all_badger_all_trajectory_information_audit.rds"',src,fixed=TRUE)]
src <- replace_block(src,"required_files <- c(encounter_file,individual_file,sett_file,spatial_file,","                    V6C_RESULT_FILE,AUDIT_FILE)",c("required_files <- c(encounter_file,individual_file,sett_file,spatial_file,V6C_RESULT_FILE)"),"required file list")
src <- replace_block(src,"audit_obj <- readRDS(AUDIT_FILE)","          \" directional-analysis badgers rather than 1285.\")",character(),"old directional population lookup")

# ---- replace old 1,285 selection with maximum movement population -----------
# Match the inclusive audit using individual_id as the canonical cross-snapshot
# identifier. Historical tattoo text is not required to match between snapshots.
src <- replace_block(
  src,
  "live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name=\"n_live_years\")",
  "nind <- nrow(eligible)",
  c(
    "live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name=\"n_live_years\")",
    "eligible <- live %>%",
    "  distinct(individual_id) %>%",
    "  inner_join(demog,by=\"individual_id\") %>%",
    "  left_join(sex_lookup %>% select(individual_id,sex_code),by=\"individual_id\") %>%",
    "  inner_join(live_year_counts,by=\"individual_id\") %>%",
    "  filter(entry_group %in% 1:2,n_live_years>=MIN_LIVE_YEARS) %>%",
    "  arrange(individual_id)",
    "",
    "if(nrow(eligible)!=EXPECTED_N)",
    "  stop(\"Expected \",EXPECTED_N,\" maximal-data movement badgers but reconstructed \",nrow(eligible),\". Re-run the population audit before fitting.\")",
    "",
    "ids <- eligible$tattoo",
    "individual_ids <- eligible$individual_id",
    "nind <- nrow(eligible)"
  ),
  "movement population"
)

src <- replace_once(src,"Directional population should have known sex for every badger.","Maximal movement population should have known sex for every badger under the current audited snapshot.","sex assertion text")

# ---- metadata/output names ---------------------------------------------------
src <- gsub("1285","1932",src,fixed=TRUE)
src <- gsub("all 1,932 badgers that can contribute to the directional V7 analyses","all 1,932 badgers with at least two spatially usable live years",src,fixed=TRUE)
src <- gsub("exact directional-analysis population from the all-badger audit","maximum movement-informative population from the inclusive population audit",src,fixed=TRUE)
src <- gsub("all_directional_badgers_from_V7_audit","all_badgers_with_at_least_2_usable_spatial_live_years",src,fixed=TRUE)
src <- gsub("audit_file=AUDIT_FILE","population_definition=\"results/V7_population_inclusion_audit.rds\"",src,fixed=TRUE)
src <- append(src,values="",after=0L); src <- append(src,values=paste0("EXPECTED_N <- ",EXPECTED_N,"L"),after=0L)

# ---- execute generated model -------------------------------------------------
generated_file <- file.path(tempdir(),"Woodchester_RD_Spatial_CMR_V8_MOVEMENT_MAXDATA_1932_CHAIN_generated.R")
writeLines(src,generated_file)
cat("Generated checked maximal-data model source:\n",generated_file,"\n",sep="")
cat("Expected production population:",EXPECTED_N,"badgers\n")
source(generated_file,local=FALSE)
