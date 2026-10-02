# =============================================================================
# PHASE 3 / P3_01c — GROUP-CHANGE SUPPORT / PERSISTENCE AUDIT
#
# Purpose
#   Explain why many published-style annual SOCG changes do not coincide with
#   large V9 annual activity-centre shifts.
#
# Key distinction
#   Historical "inter-group movement" from capture histories can include
#   temporary visits/forays and sparse-capture assignment changes.
#   V9 high mobility is an annual activity-centre relocation state.
#   These are related but not equivalent biological quantities.
#
# Outputs
#   results/Phase3/P3_01c_group_change_support_summary.csv
#   results/Phase3/P3_01c_group_change_persistence_summary.csv
#   results/Phase3/P3_01c_group_change_era_summary.csv
#   results/Phase3/P3_01c_group_change_events.csv
# =============================================================================

suppressPackageStartupMessages(library(tidyverse))

MEM_FILE <- "data/phase3/P3_annual_recorded_membership.rds"
OBS_FILE <- "results/badger_annual_observed_sett_locations.csv"

for(f in c(MEM_FILE,OBS_FILE))
  if(!file.exists(f)) stop("Missing required file: ",f)

dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

x <- readRDS(MEM_FILE)
annual <- as_tibble(x$annual_membership)
tr <- as_tibble(x$transition_audit)
obs <- readr::read_csv(OBS_FILE,show_col_types=FALSE)

req_a <- c("tattoo","year","candidate_resident_socg","n_live_records",
           "n_socg_records","n_distinct_socg","assignment_criterion")
miss <- setdiff(req_a,names(annual))
if(length(miss)) stop("annual_membership missing: ",paste(miss,collapse=", "))

req_t <- c("tattoo","from_year","to_year","from_socg","to_socg",
           "observed_group_change","p_high","median_distance_m",
           "group_change_low_spatial_support")
miss <- setdiff(req_t,names(tr))
if(length(miss)) stop("transition_audit missing: ",paste(miss,collapse=", "))

req_o <- c("tattoo","year","annual_x","annual_y","has_annual_xy")
miss <- setdiff(req_o,names(obs))
if(length(miss)) stop("Observed annual-location file missing: ",paste(miss,collapse=", "))

annual_small <- annual %>%
  transmute(
    tattoo=as.character(tattoo),year=as.integer(year),
    resident_socg=candidate_resident_socg,
    n_live_records=as.integer(n_live_records),
    n_socg_records=as.integer(n_socg_records),
    n_distinct_socg=as.integer(n_distinct_socg),
    assignment_criterion=as.integer(assignment_criterion)
  )

obs_small <- obs %>%
  transmute(
    tattoo=trimws(as.character(tattoo)),
    year=as.integer(year),
    annual_x=as.numeric(annual_x),
    annual_y=as.numeric(annual_y),
    has_annual_xy=as.logical(has_annual_xy)
  )

events <- tr %>%
  filter(observed_group_change %in% TRUE) %>%
  mutate(
    tattoo=as.character(tattoo),
    from_year=as.integer(from_year),
    to_year=as.integer(to_year)
  ) %>%
  left_join(
    annual_small %>%
      rename(
        from_socg_assigned=resident_socg,
        from_n_live_records=n_live_records,
        from_n_socg_records=n_socg_records,
        from_n_distinct_socg=n_distinct_socg,
        from_assignment_criterion=assignment_criterion
      ),
    by=c("tattoo","from_year"="year")
  ) %>%
  left_join(
    annual_small %>%
      rename(
        to_socg_assigned=resident_socg,
        to_n_live_records=n_live_records,
        to_n_socg_records=n_socg_records,
        to_n_distinct_socg=n_distinct_socg,
        to_assignment_criterion=assignment_criterion
      ),
    by=c("tattoo","to_year"="year")
  ) %>%
  left_join(
    annual_small %>%
      transmute(
        tattoo,
        to_year=year-1L,
        next_year_socg=resident_socg,
        next_year_n_live_records=n_live_records
      ),
    by=c("tattoo","to_year")
  ) %>%
  left_join(
    obs_small %>%
      rename(
        from_observed_x=annual_x,
        from_observed_y=annual_y,
        from_has_xy=has_annual_xy
      ),
    by=c("tattoo","from_year"="year")
  ) %>%
  left_join(
    obs_small %>%
      rename(
        to_observed_x=annual_x,
        to_observed_y=annual_y,
        to_has_xy=has_annual_xy
      ),
    by=c("tattoo","to_year"="year")
  ) %>%
  mutate(
    observed_capture_centroid_move_m=
      sqrt((to_observed_x-from_observed_x)^2+
           (to_observed_y-from_observed_y)^2),
    observed_capture_centroid_move_m=
      if_else(from_has_xy %in% TRUE & to_has_xy %in% TRUE,
              observed_capture_centroid_move_m,NA_real_),
    min_annual_live_records=pmin(from_n_live_records,to_n_live_records,na.rm=TRUE),
    capture_support=case_when(
      is.na(from_n_live_records)|is.na(to_n_live_records) ~ "UNKNOWN",
      from_n_live_records>=2L & to_n_live_records>=2L ~ "GE2_BOTH_YEARS",
      TRUE ~ "ONE_OR_MORE_SPARSE_YEAR"
    ),
    assignment_support=case_when(
      from_assignment_criterion==1L & to_assignment_criterion==1L ~ "C1_BOTH_YEARS",
      TRUE ~ "C2_TO_C5_INVOLVED"
    ),
    destination_persistence=case_when(
      is.na(next_year_socg) ~ "NO_NEXT_YEAR_ASSIGNMENT",
      next_year_socg==to_socg ~ "DESTINATION_PERSISTS",
      next_year_socg==from_socg ~ "RETURNS_TO_ORIGIN",
      TRUE ~ "MOVES_TO_OTHER_GROUP"
    ),
    interval_era=if_else(to_year>=2018L,"TO_2018_PLUS","TO_PRE_2018")
  )

cat("\n============================================================\n")
cat("P3_01c — GROUP-CHANGE SUPPORT / PERSISTENCE AUDIT\n")
cat("============================================================\n")
cat("Annual resident-group changes:",nrow(events),"\n")

support_summary <- events %>%
  group_by(capture_support,assignment_support) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_latent_AC_move_m=median(median_distance_m,na.rm=TRUE),
    median_observed_capture_centroid_move_m=
      median(observed_capture_centroid_move_m,na.rm=TRUE),
    low_spatial_support_pct=
      100*mean(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

persistence_summary <- events %>%
  group_by(destination_persistence) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_latent_AC_move_m=median(median_distance_m,na.rm=TRUE),
    median_observed_capture_centroid_move_m=
      median(observed_capture_centroid_move_m,na.rm=TRUE),
    low_spatial_support_pct=
      100*mean(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

era_summary <- events %>%
  group_by(interval_era) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    pct_sparse_capture_support=
      100*mean(capture_support=="ONE_OR_MORE_SPARSE_YEAR",na.rm=TRUE),
    pct_C1_both_years=
      100*mean(assignment_support=="C1_BOTH_YEARS",na.rm=TRUE),
    pct_destination_persists=
      100*mean(destination_persistence=="DESTINATION_PERSISTS",na.rm=TRUE),
    pct_returns_origin=
      100*mean(destination_persistence=="RETURNS_TO_ORIGIN",na.rm=TRUE),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_latent_AC_move_m=median(median_distance_m,na.rm=TRUE),
    median_observed_capture_centroid_move_m=
      median(observed_capture_centroid_move_m,na.rm=TRUE),
    low_spatial_support_pct=
      100*mean(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

cat("\nBY CAPTURE / ASSIGNMENT SUPPORT\n")
print(support_summary,n=Inf,width=Inf)
cat("\nBY NEXT-YEAR PERSISTENCE\n")
print(persistence_summary,n=Inf,width=Inf)
cat("\nPRE/POST-2018 DESCRIPTIVE SUMMARY\n")
print(era_summary,n=Inf,width=Inf)

write_csv(support_summary,
          "results/Phase3/P3_01c_group_change_support_summary.csv")
write_csv(persistence_summary,
          "results/Phase3/P3_01c_group_change_persistence_summary.csv")
write_csv(era_summary,
          "results/Phase3/P3_01c_group_change_era_summary.csv")
write_csv(events,
          "results/Phase3/P3_01c_group_change_events.csv")

cat("\nInterpretation rule:\n")
cat("- capture-history inter-group movement and V9 annual AC relocation are not assumed equivalent.\n")
cat("- sparse annual capture support can make resident-group assignment sensitive to temporary visits.\n")
cat("- destination persistence helps distinguish likely relocation from temporary/unstable assignment.\n")
cat("- post-2018 contrasts remain descriptive until support differences are ruled out.\n")
cat("\nP3_01c COMPLETE\n")
