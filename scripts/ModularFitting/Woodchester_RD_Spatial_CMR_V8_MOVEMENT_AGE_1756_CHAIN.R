# =============================================================================
# WOODCHESTER V8 - CHRONOLOGICAL AGE MOVEMENT MODEL
#
# Population
#   Every movement-informative badger whose chronological age can be reconstructed
#   from first-capture age (expected n = 1,756):
#     Cub first captured in year y      -> born Q1 of y
#     Yearling first captured in year y -> born Q1 of y-1
#   Badgers first caught as adults are NOT deleted from the main movement model;
#   they are excluded only from this age-specific fit because exact age is unknown.
#
# Age effect
#   One parsimonious per-year chronological-age coefficient modifies initiation
#   of a high-mobility episode: the first modelled movement interval and later
#   local->high transitions. Age is not added to movement magnitude, high-state
#   persistence, detection or landscape effects.
# =============================================================================

BASE_FILE <- "scripts/ModularFitting/Woodchester_RD_Spatial_CMR_V7M_MOVEMENT_ONLY_1285_CHAIN.R"
EXPECTED_N <- 1756L
AGE_CENTER <- 3

if(!file.exists(BASE_FILE)) stop("Missing frozen base model: ",BASE_FILE)
txt <- paste(readLines(BASE_FILE,warn=FALSE),collapse="\n")

replace_txt_once <- function(x,old,new,label){
  loc <- gregexpr(old,x,fixed=TRUE)[[1]]
  n <- if(length(loc)==1L && loc[1]==-1L) 0L else length(loc)
  if(n!=1L) stop("Expected exactly one match for ",label,", found ",n,".")
  sub(old,new,x,fixed=TRUE)
}

# ---- remove old directional-audit restriction/dependency --------------------
txt <- replace_txt_once(txt,'AUDIT_FILE <- "results/V7_all_badger_all_trajectory_information_audit.rds"\n','',"old audit filename")
txt <- replace_txt_once(txt,paste(c('required_files <- c(encounter_file,individual_file,sett_file,spatial_file,','                    V6C_RESULT_FILE,AUDIT_FILE)'),collapse="\n"),'required_files <- c(encounter_file,individual_file,sett_file,spatial_file,V6C_RESULT_FILE)',"required file list")
txt <- replace_txt_once(txt,paste(c('audit_obj <- readRDS(AUDIT_FILE)','','directional_ids <- audit_obj$history %>%','  filter(v7a_contributor) %>%','  pull(tattoo) %>%','  as.character()','','cat("Directional-analysis IDs from audit:",length(directional_ids),"\\n")','if(length(directional_ids)!=1285L)','  warning("Audit currently contains ",length(directional_ids),','          " directional-analysis badgers rather than 1285.")'),collapse="\n"),'',"old directional population lookup")

# ---- sett cleaning: use EXACT inclusive-audit rules --------------------------
txt <- replace_txt_once(
  txt,
  paste(c(
    'sett_aliases <- c("\\\\bCHESTNUT\\\\b"="CHESNUT","\\\\bJACKS\\\\b"="JACKSMIREY","\\\\bGRAVEL\\\\b"="GRAVELPIT",',
    '                  "\\\\bBUCKHOLE\\\\b"="BUCKHOLT","\\\\bTOPSETT\\\\b"="TOP","\\\\bFOXCUB\\\\b"="FOX",',
    '                  "\\\\bGULLEY\\\\b"="GULLY","\\\\bBLACKBERRY\\\\b"="BRAMBLE","\\\\bBOC\\\\b"="BOG",',
    '                  "\\\\bCEDARBANK\\\\b"="CEDAR","\\\\bCLAYTRAP\\\\b"="CLAY","\\\\bCLIFF\\\\b"="CLIFFFACE",',
    '                  "\\\\bDINGLEVALLEY\\\\b"="DINGLE")',
    'clean_sett <- function(x) x %>% as.character() %>% toupper() %>%',
    '  str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%',
    '  str_remove_all("\\\\b(SETT|MAIN|OUTLIER)\\\\b") %>% str_replace_all(sett_aliases) %>%',
    '  str_replace_all("\\\\s+","")'
  ),collapse="\n"),
  paste(c(
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
    '}'
  ),collapse="\n"),
  "sett cleaning"
)

# ---- chronological birth year from first-capture age ------------------------
txt <- replace_txt_once(
  txt,
  paste(c('demog <- individuals %>%','  transmute(individual_id=as.integer(individual_id),tattoo=as.character(tattoo),age_fc=as.character(age_fc),','            entry_group=case_when(age_fc %in% c("Cub","Yearling")~1L,age_fc=="Adult"~2L,TRUE~NA_integer_))'),collapse="\n"),
  paste(c('demog <- individuals %>%','  transmute(individual_id=as.integer(individual_id),tattoo=as.character(tattoo),','            age_fc_raw=as.character(age_fc),year_fc=as.integer(year_fc)) %>%','  mutate(age_fc=toupper(str_squish(age_fc_raw)),','         entry_group=case_when(age_fc %in% c("CUB","YEARLING")~1L,age_fc=="ADULT"~2L,TRUE~NA_integer_),','         birth_year=case_when(age_fc=="CUB" & !is.na(year_fc)~year_fc,','                              age_fc=="YEARLING" & !is.na(year_fc)~year_fc-1L,','                              TRUE~NA_integer_))'),collapse="\n"),
  "demography/birth-year block"
)

# ---- maximum known-age movement population ----------------------------------
txt <- replace_txt_once(
  txt,
  paste(c('live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name="n_live_years")','eligible <- live %>%','  distinct(individual_id,tattoo) %>%','  inner_join(demog,by=c("individual_id","tattoo")) %>%','  left_join(sex_lookup %>% select(individual_id,tattoo,sex_code),by=c("individual_id","tattoo")) %>%','  inner_join(live_year_counts,by="individual_id") %>%','  filter(entry_group %in% 1:2,n_live_years>=MIN_LIVE_YEARS,!tattoo %in% "007V")','','# ---- exact all-directional-badger population ---------------------------------','eligible <- eligible %>%','  filter(tattoo %in% directional_ids) %>%','  mutate(audit_order=match(tattoo,directional_ids)) %>%','  arrange(audit_order)','','missing_directional <- setdiff(directional_ids,eligible$tattoo)','if(length(missing_directional))','  stop(length(missing_directional),','       " audit-selected directional IDs are no longer model-eligible.")','','if(nrow(eligible)!=length(directional_ids))','  stop("Could not reconstruct exact directional-analysis population.")','','ids <- eligible$tattoo','individual_ids <- eligible$individual_id','nind <- nrow(eligible)'),collapse="\n"),
  paste(c('live_year_counts <- live %>% distinct(individual_id,primary) %>% count(individual_id,name="n_live_years")','eligible <- live %>%','  distinct(individual_id) %>%','  inner_join(demog,by="individual_id") %>%','  left_join(sex_lookup %>% select(individual_id,sex_code),by="individual_id") %>%','  inner_join(live_year_counts,by="individual_id") %>%','  filter(!is.na(birth_year),n_live_years>=MIN_LIVE_YEARS) %>%','  arrange(individual_id)','','if(nrow(eligible)!=EXPECTED_N)','  stop("Expected ",EXPECTED_N," known-age movement badgers but reconstructed ",nrow(eligible),". Re-run the population audit before fitting.")','','ids <- eligible$tattoo','individual_ids <- eligible$individual_id','nind <- nrow(eligible)'),collapse="\n"),
  "age-model population"
)

txt <- gsub("Directional population should have known sex for every badger.","Known-age movement population should have known sex for every badger under the current audited snapshot.",txt,fixed=TRUE)

# ---- construct time-varying chronological age at movement origin ------------
txt <- replace_txt_once(txt,'if(anyNA(first) || anyNA(K) || any(K<=first)) stop("Invalid first/K histories.")',paste(c('if(anyNA(first) || anyNA(K) || any(K<=first)) stop("Invalid first/K histories.")','','# Chronological age at the ORIGIN of each annual movement interval.','# Cub first capture y -> birth Q1 y; yearling first capture y -> birth Q1 y-1.','birth_year <- as.integer(eligible$birth_year)','age_origin <- matrix(NA_real_,nind,n_prim)','age_c <- matrix(0,nind,n_prim)','for(i in seq_len(nind)) for(k in (first[i]+1L):K[i]){','  age_origin[i,k] <- years[k-1L]-birth_year[i]','  age_c[i,k] <- age_origin[i,k]-AGE_CENTER','}','age_active <- unlist(lapply(seq_len(nind),function(i) age_origin[i,(first[i]+1L):K[i]]))','if(any(!is.finite(age_active)) || any(age_active<0)) stop("Invalid reconstructed chronological ages.")','age_init <- vapply(seq_len(nind),function(i) age_c[i,first[i]+1L],numeric(1))','cat("  known-age subset:",nind,"badgers | origin-age range:",min(age_active),"to",max(age_active),"years\\n")'),collapse="\n"),"chronological age construction")

# ---- remove adult-entry effect ----------------------------------------------
txt <- replace_txt_once(txt,'  beta_disp_adult ~ dnorm(0,sd=1)\n','',"adult-entry prior")
txt <- replace_txt_once(txt,'    p_disp_init[i] <- ilogit(alpha_disp_init+beta_disp_adult*adult_entry[i]+beta_disp_init_sex*sex[i])','    p_disp_init[i] <- ilogit(alpha_disp_init+beta_disp_init_sex*sex[i]+beta_age*age_init[i])',"initial-state age effect")

# ---- one chronological-age coefficient for high-mobility initiation ---------
txt <- replace_txt_once(txt,'  beta_RD_sex ~ dnorm(0,sd=1)',paste(c('  beta_RD_sex ~ dnorm(0,sd=1)','  beta_age ~ dnorm(0,sd=.35)','  OR_age_per_year <- exp(beta_age)'),collapse="\n"),"age prior")
txt <- replace_txt_once(txt,paste(c('      p_RD_i[i,k] <- ilogit(','        alpha_RD+','        beta_RD_sex*sex[i]','      )'),collapse="\n"),paste(c('      p_RD_i[i,k] <- ilogit(','        alpha_RD+','        beta_RD_sex*sex[i]+','        beta_age*age_c[i,k]','      )'),collapse="\n"),"local-to-high age effect")

# ---- constants, warm starts, monitoring and sampler -------------------------
txt <- replace_txt_once(txt,'               adult_entry=as.integer(adult_entry),sex=as.integer(sex_data),','               sex=as.integer(sex_data),age_c=age_c,age_init=as.numeric(age_init),',"age constants")
txt <- replace_txt_once(txt,'  alpha_disp_init=v6_post_mean("alpha_disp_init",-3.29),beta_disp_adult=v6_post_mean("beta_disp_adult",-.15),','  alpha_disp_init=v6_post_mean("alpha_disp_init",-3.29),beta_age=0,',"age warm start")
txt <- replace_txt_once(txt,'       beta_disp_adult=warm$beta_disp_adult+rnorm(1,0,.05),\n       beta_disp_init_sex=warm$beta_disp_init_sex+rnorm(1,0,.05),','       beta_age=warm$beta_age+rnorm(1,0,.03),\n       beta_disp_init_sex=warm$beta_disp_init_sex+rnorm(1,0,.05),',"age initial value")
txt <- replace_txt_once(txt,'  "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",','  "alpha_disp_init","beta_disp_init_sex","beta_age","OR_age_per_year",',"age monitor")
txt <- replace_txt_once(txt,'RD_global <- c("alpha_RD","beta_RD_sex")','RD_global <- c("alpha_RD","beta_RD_sex","beta_age")',"age sampler block")
txt <- replace_txt_once(txt,'init_global <- c("alpha_disp_init","beta_disp_adult","beta_disp_init_sex")','init_global <- c("alpha_disp_init","beta_disp_init_sex")',"initial-state sampler block")

txt <- replace_txt_once(txt,'         is_initial_interval=ks==(first[i]+1L),\n         node=paste0("disp[",i,", ",ks,"]"))','         is_initial_interval=ks==(first[i]+1L),age_years=age_origin[i,ks],\n         node=paste0("disp[",i,", ",ks,"]"))',"age in interval index")
txt <- replace_txt_once(txt,'    "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex",','    "alpha_RD","beta_RD_sex","beta_age","OR_age_per_year","alpha_DD","beta_DD_sex",',"age quick summary")

# ---- output metadata ---------------------------------------------------------
txt <- gsub("1,285","1,756",txt,fixed=TRUE)
txt <- gsub("RD_SCR_V7M_MOVEMENT_ONLY_1285_CHAIN_","RD_SCR_V8_MOVEMENT_AGE_1756_CHAIN_",txt,fixed=TRUE)
txt <- gsub("all 1,756 badgers that can contribute to the directional V7 analyses","all 1,756 movement-informative badgers with reconstructable chronological age",txt,fixed=TRUE)
txt <- gsub("exact directional-analysis population from the all-badger audit","maximum known-age movement population from the inclusive population audit",txt,fixed=TRUE)
txt <- gsub('model="V7M_movement_only_modular_source"','model="V8_movement_chronological_age"',txt,fixed=TRUE)
txt <- gsub('sample_source="all_directional_badgers_from_V7_audit"','sample_source="movement_badgers_first_caught_as_cub_or_yearling"',txt,fixed=TRUE)
txt <- gsub('adult_entry_effect="initial_state_probability_only"','age_effect="chronological age in years; shared slope for initial high-mobility probability and later local-to-high transitions"',txt,fixed=TRUE)
txt <- gsub('audit_file=AUDIT_FILE','population_definition="results/V7_population_inclusion_audit.rds",birth_rule="Cub: Q1 first-capture year; Yearling: Q1 previous year",age_center_years=AGE_CENTER',txt,fixed=TRUE)

txt <- paste0("EXPECTED_N <- ",EXPECTED_N,"L\nAGE_CENTER <- ",AGE_CENTER,"\n",txt)

generated_file <- file.path(tempdir(),"Woodchester_RD_Spatial_CMR_V8_MOVEMENT_AGE_1756_CHAIN_generated.R")
writeLines(strsplit(txt,"\n",fixed=TRUE)[[1]],generated_file)
cat("Generated checked chronological-age model source:\n",generated_file,"\n",sep="")
cat("Expected known-age population:",EXPECTED_N,"badgers\n")
source(generated_file,local=FALSE)
