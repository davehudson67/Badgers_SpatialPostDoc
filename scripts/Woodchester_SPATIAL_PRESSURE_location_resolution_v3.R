# =============================================================================
# WOODCHESTER SPATIAL PRESSURE LOCATION RESOLUTION v3
#
# IMPORTANT CORRECTION
# --------------------
# from_primary / to_primary are TEMPORAL PRIMARY-OCCASION INDICES, not detector
# row numbers. This script proves that against chain$years and does NOT map them
# to ch$detectors.
#
# The correct spatial sources available without re-running Stage 1 are:
#   1. ch$annual_obs : observed annual x/y locations for the 1,285 movement set
#   2. sett lookup files : observed sett coordinates for all encounter badgers
#   3. social-group histories : available at high annual coverage
#
# This script resolves and audits those sources, then writes explicit observed-
# location tables. No activity-centre coordinates are reconstructed or imputed.
# =============================================================================

library(tidyverse)

CHAIN_FILE <- "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_1_FINAL30K.rds"
MOVE_FILE  <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
ENC_FILE   <- "data/badger_encounters_useful.rds"
INF_FILE   <- "data/badger_infection_trajectories_all_tests_inferred.rds"

SETT_MASTER <- "data/movement_audit/sett_master.csv"
SETT_LOC    <- "data/WoodchesterSettLocations.csv"

for(f in c(CHAIN_FILE,MOVE_FILE,ENC_FILE,INF_FILE,SETT_MASTER))
  if(!file.exists(f)) stop("Missing required file: ",f)

ch <- readRDS(CHAIN_FILE)
mov <- readRDS(MOVE_FILE)
enc <- as_tibble(readRDS(ENC_FILE))
inf <- readRDS(INF_FILE)

dir.create("results",showWarnings=FALSE,recursive=TRUE)

norm <- function(x)
  gsub("[^A-Z0-9]","",toupper(trimws(as.character(x))))

# =============================================================================
# A. PROVE WHAT from_primary / to_primary ARE
# =============================================================================

cat("\n============================================================\n")
cat("A. PRIMARY INDEX INTERPRETATION\n")
cat("============================================================\n")

idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number())

yrs <- as.integer(ch$years)

cat("chain$years length:",length(yrs),"\n")
cat("chain$years:\n")
print(yrs)

valid_from <- idx$from_primary >= 1 & idx$from_primary <= length(yrs)
valid_to   <- idx$to_primary   >= 1 & idx$to_primary   <= length(yrs)

mapped_from_year <- rep(NA_integer_,nrow(idx))
mapped_to_year   <- rep(NA_integer_,nrow(idx))

mapped_from_year[valid_from] <- yrs[idx$from_primary[valid_from]]
mapped_to_year[valid_to]     <- yrs[idx$to_primary[valid_to]]

from_match <- mapped_from_year == idx$from_year
to_match   <- mapped_to_year == idx$to_year

cat("\nfrom_primary -> chain$years exact match:",
    sum(from_match,na.rm=TRUE),"/",nrow(idx),
    sprintf("(%.2f%%)",100*mean(from_match,na.rm=TRUE)),"\n")
cat("to_primary -> chain$years exact match:",
    sum(to_match,na.rm=TRUE),"/",nrow(idx),
    sprintf("(%.2f%%)",100*mean(to_match,na.rm=TRUE)),"\n")

temporal_index_confirmed <-
  all(from_match,na.rm=TRUE) && all(to_match,na.rm=TRUE)

cat("\nTEMPORAL PRIMARY INDEX CONFIRMED:",
    temporal_index_confirmed,"\n")

if(!temporal_index_confirmed)
  stop("Primary indices did not map exactly to chain$years; inspect before proceeding.")

cat("\nExample:\n")
print(
  idx %>%
    transmute(
      tattoo,from_primary,
      mapped_from_year=yrs[from_primary],
      from_year,
      to_primary,
      mapped_to_year=yrs[to_primary],
      to_year
    ) %>%
    head(20),
  n=20,width=Inf
)

# =============================================================================
# B. STAGE-1 annual_obs = OBSERVED ANNUAL LOCATION SUPPORT
# =============================================================================

cat("\n============================================================\n")
cat("B. STAGE-1 OBSERVED ANNUAL LOCATIONS\n")
cat("============================================================\n")

ao <- as_tibble(ch$annual_obs)

needed_ao <- c("tattoo","primary","x","y")
if(!all(needed_ao%in%names(ao)))
  stop("annual_obs missing: ",paste(setdiff(needed_ao,names(ao)),collapse=", "))

ao <- ao %>%
  mutate(
    tattoo=trimws(as.character(tattoo)),
    primary=as.integer(primary),
    year=yrs[primary],
    x=as.numeric(x),
    y=as.numeric(y),
    has_xy=is.finite(x)&is.finite(y)
  )

cat("annual_obs rows:",nrow(ao),"\n")
cat("annual_obs badgers:",n_distinct(ao$tattoo),"\n")
cat("annual_obs finite XY:",
    sum(ao$has_xy),"/",nrow(ao),"\n")
cat("annual_obs year range:",
    min(ao$year,na.rm=TRUE),"-",max(ao$year,na.rm=TRUE),"\n")
cat("Duplicate tattoo-year rows:",
    sum(duplicated(ao[c("tattoo","year")])),"\n")

# Check how many Phase-2 interval endpoints were actually observed in that year.
endpoints <- bind_rows(
  idx %>%
    transmute(
      interval_col,
      tattoo=trimws(as.character(tattoo)),
      endpoint="origin",
      primary=as.integer(from_primary),
      year=as.integer(from_year)
    ),
  idx %>%
    transmute(
      interval_col,
      tattoo=trimws(as.character(tattoo)),
      endpoint="destination",
      primary=as.integer(to_primary),
      year=as.integer(to_year)
    )
) %>%
  left_join(
    ao %>% select(tattoo,primary,obs_x=x,obs_y=y,has_obs_xy=has_xy),
    by=c("tattoo","primary")
  )

endpoint_obs_coverage <- endpoints %>%
  group_by(endpoint) %>%
  summarise(
    endpoints=n(),
    exact_observed_annual_location=sum(has_obs_xy %in% TRUE),
    pct=100*mean(has_obs_xy %in% TRUE),
    .groups="drop"
  )

cat("\nObserved annual location coverage for Phase-2 interval endpoints:\n")
print(endpoint_obs_coverage,n=Inf,width=Inf)

# =============================================================================
# C. BUILD A ROBUST SETT COORDINATE LOOKUP
# =============================================================================

cat("\n============================================================\n")
cat("C. SETT COORDINATE LOOKUP\n")
cat("============================================================\n")

sm <- readr::read_csv(SETT_MASTER,show_col_types=FALSE)

required_sm <- c("Sett_original","Sett_Clean","x","y")
if(!all(required_sm%in%names(sm)))
  stop("sett_master missing expected fields: ",
       paste(setdiff(required_sm,names(sm)),collapse=", "))

# Map BOTH original and cleaned spelling variants to the same coordinates.
sett_lookup <- bind_rows(
  sm %>%
    transmute(
      sett_key=norm(Sett_Clean),
      sett_canonical=as.character(Sett_Clean),
      x=as.numeric(x),y=as.numeric(y),
      SG_id=if("SG_id"%in%names(sm)) SG_id else NA_real_,
      source="sett_master:clean"
    ),
  sm %>%
    transmute(
      sett_key=norm(Sett_original),
      sett_canonical=as.character(Sett_Clean),
      x=as.numeric(x),y=as.numeric(y),
      SG_id=if("SG_id"%in%names(sm)) SG_id else NA_real_,
      source="sett_master:original"
    )
)

# Add WoodchesterSettLocations aliases if available.
if(file.exists(SETT_LOC)){
  sl <- readr::read_csv(SETT_LOC,show_col_types=FALSE)

  if(all(c("Sett_Upper","SETT","SettX","SettY")%in%names(sl))){
    sett_lookup <- bind_rows(
      sett_lookup,
      sl %>%
        transmute(
          sett_key=norm(Sett_Upper),
          sett_canonical=as.character(SETT),
          x=as.numeric(SettX),y=as.numeric(SettY),
          SG_id=NA_real_,
          source="WoodchesterSettLocations:Sett_Upper"
        ),
      sl %>%
        transmute(
          sett_key=norm(SETT),
          sett_canonical=as.character(SETT),
          x=as.numeric(SettX),y=as.numeric(SettY),
          SG_id=NA_real_,
          source="WoodchesterSettLocations:SETT"
        )
    )
  }
}

# Ensure duplicate aliases agree spatially before collapsing.
lookup_conflicts <- sett_lookup %>%
  filter(sett_key!="",is.finite(x),is.finite(y)) %>%
  group_by(sett_key) %>%
  summarise(
    n=n(),
    n_xy=n_distinct(paste(x,y,sep="|")),
    examples=paste(unique(sett_canonical),collapse=" | "),
    .groups="drop"
  ) %>%
  filter(n_xy>1)

cat("Lookup rows before collapse:",nrow(sett_lookup),"\n")
cat("Coordinate-conflicting aliases:",nrow(lookup_conflicts),"\n")

if(nrow(lookup_conflicts)){
  print(lookup_conflicts,n=50,width=Inf)
  stop("Sett aliases map to conflicting coordinates; resolve before proceeding.")
}

sett_lookup <- sett_lookup %>%
  filter(sett_key!="",is.finite(x),is.finite(y)) %>%
  group_by(sett_key) %>%
  summarise(
    sett_canonical=first(sett_canonical),
    x=first(x),y=first(y),
    SG_id=first(SG_id[!is.na(SG_id)],default=NA_real_),
    aliases=paste(unique(source),collapse=" | "),
    .groups="drop"
  )

cat("Unique resolvable sett aliases:",nrow(sett_lookup),"\n")
cat("Unique coordinate pairs:",
    n_distinct(paste(sett_lookup$x,sett_lookup$y,sep="|")),"\n")

# =============================================================================
# D. MAP ENCOUNTERS TO SETT COORDINATES
# =============================================================================

cat("\n============================================================\n")
cat("D. ENCOUNTER -> SETT COORDINATE COVERAGE\n")
cat("============================================================\n")

needed_enc <- c("tattoo","capture_date","sett","socg")
if(!all(needed_enc%in%names(enc)))
  stop("encounters_useful missing: ",
       paste(setdiff(needed_enc,names(enc)),collapse=", "))

enc_sp <- enc %>%
  mutate(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=as.integer(format(capture_date,"%Y")),
    sett_raw=trimws(as.character(sett)),
    sett_key=norm(sett_raw),
    socg=trimws(as.character(socg))
  ) %>%
  left_join(sett_lookup,by="sett_key") %>%
  mutate(has_xy=is.finite(x)&is.finite(y))

cat("Encounter rows:",nrow(enc_sp),"\n")
cat("Rows with nonblank sett:",
    sum(!is.na(enc_sp$sett_raw)&enc_sp$sett_raw!=""),"\n")
cat("Rows mapped to finite sett XY:",
    sum(enc_sp$has_xy),"/",nrow(enc_sp),
    sprintf("(%.2f%%)",100*mean(enc_sp$has_xy)),"\n")

missing_setts <- enc_sp %>%
  filter(!is.na(sett_raw),sett_raw!="",!has_xy) %>%
  count(sett_raw,sort=TRUE)

cat("\nUnmapped sett names (top 40):\n")
print(head(missing_setts,40),n=40,width=Inf)

# =============================================================================
# E. CANONICAL ANNUAL OBSERVED-SETT LOCATION TABLE
# =============================================================================

cat("\n============================================================\n")
cat("E. ANNUAL OBSERVED-SETT LOCATION TABLE\n")
cat("============================================================\n")

# Explicit rule:
# 1. Choose the sett with the largest number of encounter records within tattoo-year.
# 2. If tied, choose the sett whose latest encounter is latest in that year.
# This creates an observed annual representative; it is NOT a latent AC.
annual_sett_candidates <- enc_sp %>%
  filter(
    tattoo!="",!is.na(year),
    has_xy
  ) %>%
  group_by(tattoo,year,sett_key,sett_canonical,x,y) %>%
  summarise(
    n_encounters=n(),
    latest_date=max(capture_date,na.rm=TRUE),
    .groups="drop"
  )

annual_sett <- annual_sett_candidates %>%
  arrange(tattoo,year,desc(n_encounters),desc(latest_date),sett_key) %>%
  group_by(tattoo,year) %>%
  slice(1L) %>%
  ungroup() %>%
  rename(
    annual_sett=sett_canonical,
    annual_x=x,
    annual_y=y
  )

annual_meta <- enc_sp %>%
  filter(tattoo!="",!is.na(year)) %>%
  group_by(tattoo,year) %>%
  summarise(
    n_year_encounters=n(),
    n_distinct_setts=n_distinct(sett_key[sett_key!=""]),
    n_distinct_socg=n_distinct(socg[!is.na(socg)&socg!=""]),
    # modal social group, tie broken lexically for determinism
    annual_socg={
      z <- socg[!is.na(socg)&socg!=""]
      if(!length(z)) NA_character_ else {
        tt <- sort(table(z),decreasing=TRUE)
        names(tt)[1]
      }
    },
    .groups="drop"
  )

annual_sett <- annual_meta %>%
  left_join(
    annual_sett %>%
      select(
        tattoo,year,annual_sett,annual_x,annual_y,
        annual_sett_n_encounters=n_encounters,
        annual_sett_latest_date=latest_date
      ),
    by=c("tattoo","year")
  ) %>%
  mutate(
    has_annual_xy=is.finite(annual_x)&is.finite(annual_y),
    in_infection_model=tattoo%in%trimws(as.character(inf$tattoo)),
    in_phase2=tattoo%in%trimws(as.character(mov$ids))
  )

cat("Annual observed rows:",nrow(annual_sett),"\n")
cat("Annual badgers:",n_distinct(annual_sett$tattoo),"\n")
cat("Annual rows with sett XY:",
    sum(annual_sett$has_annual_xy),"/",nrow(annual_sett),
    sprintf("(%.2f%%)",100*mean(annual_sett$has_annual_xy)),"\n")
cat("Annual rows with >1 observed sett:",
    sum(annual_sett$n_distinct_setts>1),"\n")
cat("Annual rows with >1 observed social group:",
    sum(annual_sett$n_distinct_socg>1),"\n")

cat("\nInfection-model annual observed rows:\n")
print(
  annual_sett %>%
    filter(in_infection_model) %>%
    summarise(
      badgers=n_distinct(tattoo),
      annual_rows=n(),
      has_xy=sum(has_annual_xy),
      xy_pct=100*mean(has_annual_xy),
      has_socg=sum(!is.na(annual_socg)&annual_socg!=""),
      socg_pct=100*mean(!is.na(annual_socg)&annual_socg!="")
    ),
  width=Inf
)

cat("\nPhase-2 annual observed rows:\n")
print(
  annual_sett %>%
    filter(in_phase2) %>%
    summarise(
      badgers=n_distinct(tattoo),
      annual_rows=n(),
      has_xy=sum(has_annual_xy),
      xy_pct=100*mean(has_annual_xy),
      has_socg=sum(!is.na(annual_socg)&annual_socg!=""),
      socg_pct=100*mean(!is.na(annual_socg)&annual_socg!="")
    ),
  width=Inf
)

# =============================================================================
# F. VALIDATE annual_obs x/y AGAINST ENCOUNTER-SETT LOCATIONS
# =============================================================================

cat("\n============================================================\n")
cat("F. VALIDATE STAGE-1 annual_obs x/y\n")
cat("============================================================\n")

# For every Stage-1 observed annual point, calculate its distance to the nearest
# observed sett coordinate for that same tattoo-year.
enc_year_points <- enc_sp %>%
  filter(has_xy) %>%
  distinct(tattoo,year,sett_key,x,y)

validation <- ao %>%
  filter(has_xy) %>%
  select(tattoo,year,stage1_x=x,stage1_y=y) %>%
  inner_join(enc_year_points,by=c("tattoo","year")) %>%
  mutate(
    distance_m=sqrt((stage1_x-x)^2+(stage1_y-y)^2)
  ) %>%
  group_by(tattoo,year,stage1_x,stage1_y) %>%
  summarise(
    nearest_observed_sett_m=min(distance_m),
    n_candidate_setts=n(),
    .groups="drop"
  )

cat("Stage-1 annual points with same-year mapped encounter sett:",
    nrow(validation),"/",sum(ao$has_xy),"\n")

if(nrow(validation)){
  cat("Nearest same-year sett distance summary (m):\n")
  print(
    validation %>%
      summarise(
        median=median(nearest_observed_sett_m),
        q75=quantile(nearest_observed_sett_m,.75),
        q90=quantile(nearest_observed_sett_m,.90),
        q95=quantile(nearest_observed_sett_m,.95),
        pct_exact_1m=100*mean(nearest_observed_sett_m<=1),
        pct_within_50m=100*mean(nearest_observed_sett_m<=50),
        pct_within_100m=100*mean(nearest_observed_sett_m<=100)
      ),
    width=Inf
  )
}

# =============================================================================
# G. PRESSURE-ANALYSIS COVERAGE AT V7b RELEVANT YEARS
# =============================================================================

cat("\n============================================================\n")
cat("G. V7b-RELEVANT SPATIAL PRESSURE COVERAGE\n")
cat("============================================================\n")

# V7b uses movement ending year t and predicts infection in t+1.
v7b_years <- idx %>%
  group_by(model_i,tattoo) %>%
  arrange(from_year,to_year,.by_group=TRUE) %>%
  mutate(is_last=row_number()==n()) %>%
  ungroup() %>%
  filter(!is_last) %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    pressure_year=as.integer(to_year)
  ) %>%
  distinct()

focal_pressure_support <- v7b_years %>%
  left_join(
    annual_sett %>%
      select(tattoo,year,has_annual_xy,annual_socg),
    by=c("tattoo"="tattoo","pressure_year"="year")
  ) %>%
  summarise(
    focal_badger_years=n(),
    exact_sett_xy=sum(has_annual_xy %in% TRUE),
    exact_sett_xy_pct=100*mean(has_annual_xy %in% TRUE),
    exact_socg=sum(!is.na(annual_socg)&annual_socg!=""),
    exact_socg_pct=100*mean(!is.na(annual_socg)&annual_socg!="")
  )

cat("Focal Phase-2 locations at movement-ending year t:\n")
print(focal_pressure_support,width=Inf)

# Source support is all infection-model badgers observed in each pressure year.
source_support <- annual_sett %>%
  filter(in_infection_model) %>%
  group_by(year) %>%
  summarise(
    source_badgers=n(),
    source_with_xy=sum(has_annual_xy),
    source_with_socg=sum(!is.na(annual_socg)&annual_socg!=""),
    .groups="drop"
  )

cat("\nAll-infection-badger source-location support by year summary:\n")
print(
  source_support %>%
    summarise(
      years=n(),
      median_source_badgers=median(source_badgers),
      median_xy=median(source_with_xy),
      q025_xy=quantile(source_with_xy,.025),
      median_socg=median(source_with_socg),
      q025_socg=quantile(source_with_socg,.025)
    ),
  width=Inf
)

# =============================================================================
# H. SAVE CANONICAL OBSERVED LOCATION INPUTS
# =============================================================================

cat("\n============================================================\n")
cat("H. SAVE / DECISION\n")
cat("============================================================\n")

saveRDS(
  ao,
  "data/badger_stage1_observed_annual_locations_1285.rds"
)

saveRDS(
  annual_sett,
  "data/badger_annual_observed_sett_locations.rds"
)

write_csv(
  annual_sett,
  "results/badger_annual_observed_sett_locations.csv"
)

write_csv(
  validation,
  "results/stage1_annual_obs_vs_sett_validation.csv"
)

saveRDS(
  list(
    temporal_primary_index_confirmed=temporal_index_confirmed,
    endpoint_observed_coverage=endpoint_obs_coverage,
    sett_lookup=sett_lookup,
    missing_setts=missing_setts,
    annual_sett=annual_sett,
    stage1_validation=validation,
    focal_pressure_support=focal_pressure_support,
    source_support=source_support
  ),
  "results/spatial_pressure_location_resolution_v3_audit.rds"
)

cat("Saved: data/badger_stage1_observed_annual_locations_1285.rds\n")
cat("Saved: data/badger_annual_observed_sett_locations.rds\n")
cat("Saved: results/badger_annual_observed_sett_locations.csv\n")
cat("Saved: results/stage1_annual_obs_vs_sett_validation.csv\n")
cat("Saved: results/spatial_pressure_location_resolution_v3_audit.rds\n")

cat("\nDECISION RULE:\n")
cat("- Do NOT use from_primary/to_primary as detector indices.\n")
cat("- Do NOT claim posterior activity-centre coordinates are available.\n")
cat("- Same-social-group pressure can use observed annual social groups.\n")
cat("- Distance-weighted pressure can use exact observed sett coordinates where available.\n")
cat("- Missing annual locations remain missing in the primary pressure analysis.\n")
cat("- Stage-1 annual_obs can be used as a focal-location sensitivity where observed.\n")

cat("\nLOCATION RESOLUTION v3 COMPLETE\n")
