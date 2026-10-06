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
  s <- grep(start_pattern,x,fixed=TRUE)
  if(length(s)!=1L) stop("Could not uniquely identify start of ",label," in frozen base model.")
  e <- grep(end_pattern,x,fixed=TRUE)
  e <- e[e>=s]
  if(!length(e)) stop("Could not identify end of ",label," after its start in frozen base model.")
  e <- e[1L]
  c(x[seq_len(s-1L)],replacement,x[(e+1L):length(x)])
}
replace_section <- function(x,start_header,end_header,replacement,label){
  s <- grep(start_header,x,fixed=TRUE)
  e <- grep(end_header,x,fixed=TRUE)
  if(length(s)!=1L || length(e)!=1L || e<=s)
    stop("Could not uniquely identify section ",label," in frozen base model.")
  c(x[seq_len(s-1L)],replacement,x[e:length(x)])
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

# ---- sett cleaning: use EXACT inclusive-audit rules --------------------------
# Replace the complete frozen sett-cleaning section using unique section headers.
src <- replace_section(
  src,
  "# ---- sett cleaning -----------------------------------------------------------",
  "# ---- spatial inputs ----------------------------------------------------------",
  c(
    "# ---- sett cleaning -----------------------------------------------------------",
    'sett_aliases <- c("CHESTNUT"="CHESNUT","JACKS"="JACKSMIREY","GRAVEL"="GRAVELPIT",',
    '                  "BUCKHOLE"="BUCKHOLT","TOPSETT"="TOP","FOXCUB"="FOX","GULLEY"="GULLY",',
    '                  "BLACKBERRY"="BRAMBLE","BOC"="BOG","CEDARBANK"="CEDAR","CLAYTRAP"="CLAY",',
    '                  "CLIFF"="CLIFFFACE","DINGLEVALLEY"="DINGLE")',
    'clean_sett <- function(x){',
    '  z <- x %>% as.character() %>% toupper() %>%',
    '    str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%',
    '    str_remove_all("\\\\b(SETT|MAIN|OUTLIER)\\\\b") %>% str_replace_all("\\\\s+","")',
    '  for(a in names(sett_aliases)) z[z==a] <- sett_aliases[[a]]',
    '  z',
    '}',
    ""
  ),
  "sett cleaning"
)

# ---- standardise individual traits exactly as in the inclusive audit --------
# tattoo is the biological/model key; individual_id is retained as provenance.
src <- replace_block(
  src,
  "demog <- individuals %>%",
  "            entry_group=case_when(age_fc %in% c(\"Cub\",\"Yearling\")~1L,age_fc==\"Adult\"~2L,TRUE~NA_integer_))",
  c(
    "demog <- individuals %>%",
    "  transmute(individual_id=as.integer(individual_id),tattoo=toupper(trimws(as.character(tattoo))),age_fc_raw=as.character(age_fc)) %>%",
    "  mutate(age_fc=toupper(str_squish(age_fc_raw)),",
    "         entry_group=case_when(age_fc %in% c(\"CUB\",\"YEARLING\")~1L,age_fc==\"ADULT\"~2L,TRUE~NA_integer_))"
  ),
  "standardised demography"
)

src <- replace_block(
  src,
  "sex_lookup <- individuals %>%",
  "                            sex_clean %in% c(\"M\",\"MALE\")~1L,TRUE~NA_integer_))",
  c(
    "sex_lookup <- individuals %>%",
    "  transmute(individual_id=as.integer(individual_id),tattoo=toupper(trimws(as.character(tattoo))),sex_raw=as.character(sex)) %>%",
    "  mutate(sex_clean=toupper(str_squish(sex_raw)),",
    "         sex_code=case_when(sex_clean %in% c(\"F\",\"FEMALE\")~0L,",
    "                            sex_clean %in% c(\"M\",\"MALE\")~1L,TRUE~NA_integer_))"
  ),
  "standardised sex lookup"
)

# ---- replace old 1,285 selection with maximum movement population -----------
# Match the inclusive audit using tattoo as the biological/model identifier.
# Do not silently delete movement-informative animals for missing covariates.
src <- replace_block(
  src,
  "live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name=\"n_live_years\")",
  "nind <- nrow(eligible)",
  c(
    "live_year_counts <- live %>% distinct(tattoo,primary) %>% count(tattoo,name=\"n_live_years\")",
    "eligible <- live %>%",
    "  distinct(tattoo) %>%",
    "  inner_join(demog,by=\"tattoo\") %>%",
    "  left_join(sex_lookup %>% select(tattoo,sex_code),by=\"tattoo\") %>%",
    "  inner_join(live_year_counts,by=\"tattoo\") %>%",
    "  filter(n_live_years>=MIN_LIVE_YEARS) %>%",
    "  arrange(tattoo)",
    "",
    "if(nrow(eligible)!=EXPECTED_N)",
    "  stop(\"Expected \",EXPECTED_N,\" maximal-data movement badgers but reconstructed \",nrow(eligible),\". Re-run the population audit before fitting.\")",
    "",
    "if(anyNA(eligible$entry_group))",
    "  stop(\"Movement-eligible animals with unknown entry-age class are present. Extend the model for unknown entry age rather than silently excluding them.\")",
    "if(anyNA(eligible$sex_code))",
    "  stop(\"Movement-eligible animals with unknown sex are present. Extend the model for unknown sex rather than silently excluding them.\")",
    "",
    "ids <- eligible$tattoo",
    "individual_ids <- eligible$individual_id",
    "nind <- nrow(eligible)"
  ),
  "movement population"
)

# ---- biological observation indexing uses tattoo ----------------------------
src <- replace_once(src,
  "  arrange(individual_id,primary,trap_season,capture_date) %>%",
  "  arrange(tattoo,primary,trap_season,capture_date) %>%",
  "live-quarter ordering key")
src <- replace_once(src,
  "  group_by(individual_id,primary,trap_season) %>%",
  "  group_by(tattoo,primary,trap_season) %>%",
  "live-quarter grouping key")
src <- replace_once(src,
  "if(nrow(live %>% count(individual_id,primary,trap_season) %>% filter(n>1))) stop(\"Duplicate live quarter rows remain.\")",
  "if(nrow(live %>% count(tattoo,primary,trap_season) %>% filter(n>1))) stop(\"Duplicate live quarter rows remain.\")",
  "live-quarter duplicate check")
src <- replace_once(src,
  "live <- live %>% filter(individual_id %in% individual_ids)",
  "live <- live %>% filter(tattoo %in% ids)",
  "selected-live population filter")

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
