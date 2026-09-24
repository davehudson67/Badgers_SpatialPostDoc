# =============================================================================
# PHASE 3 / P3_01b — GROUP-CHANGE LINEAGE / RECONFIGURATION AUDIT
#
# Purpose
#   Explain why many annual recorded SOCG changes have little posterior spatial
#   displacement. Distinguish:
#     (i) named-SOCG change within the same static spatial core,
#     (ii) change between different static cores,
#     (iii) changes involving unmapped/uncertain SOCG labels.
#
# This is an audit, not a biological model and not a reclassification of
# published-style annual resident SOCG.
#
# Outputs
#   results/Phase3/P3_01b_group_change_lineage_summary.csv
#   results/Phase3/P3_01b_group_change_lineage_by_year.csv
#   results/Phase3/P3_01b_group_change_lineage_events.csv
# =============================================================================

suppressPackageStartupMessages(library(tidyverse))

INFILE <- "data/phase3/P3_annual_recorded_membership.rds"
if(!file.exists(INFILE)) stop("Missing required file: ", INFILE)
dir.create("results/Phase3", recursive=TRUE, showWarnings=FALSE)

x <- readRDS(INFILE)
req <- c("transition_audit","socg_static_mapping")
miss <- setdiff(req,names(x))
if(length(miss)) stop("P3 annual membership object missing: ",paste(miss,collapse=", "))

tr <- as_tibble(x$transition_audit)
mp <- as_tibble(x$socg_static_mapping)

req_tr <- c("tattoo","from_year","to_year","from_socg","to_socg",
            "observed_group_change","p_high","median_distance_m",
            "group_change_low_spatial_support")
miss <- setdiff(req_tr,names(tr))
if(length(miss)) stop("transition_audit missing: ",paste(miss,collapse=", "))

map_from <- mp %>%
  transmute(
    from_socg=socg_key,
    from_static_SG_id=static_SG_id,
    from_static_mapping_share=static_mapping_share,
    from_static_mapping_confident=static_mapping_confident
  )
map_to <- mp %>%
  transmute(
    to_socg=socg_key,
    to_static_SG_id=static_SG_id,
    to_static_mapping_share=static_mapping_share,
    to_static_mapping_confident=static_mapping_confident
  )

events <- tr %>%
  filter(observed_group_change %in% TRUE) %>%
  left_join(map_from,by="from_socg") %>%
  left_join(map_to,by="to_socg") %>%
  mutate(
    change_class=case_when(
      is.na(from_static_SG_id)|is.na(to_static_SG_id) ~ "UNMAPPED_STATIC_CORE",
      from_static_SG_id==to_static_SG_id ~ "NAMED_SOCG_CHANGE_SAME_STATIC_CORE",
      TRUE ~ "DIFFERENT_STATIC_CORE"
    ),
    confident_both=
      from_static_mapping_confident %in% TRUE &
      to_static_mapping_confident %in% TRUE,
    interval_era=if_else(to_year>=2018L,"TO_2018_PLUS","TO_PRE_2018")
  )

summary_tbl <- events %>%
  group_by(change_class) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    pct_all_changes=100*n()/nrow(events),
    pct_confident_both=100*mean(confident_both,na.rm=TRUE),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_distance_m=median(median_distance_m,na.rm=TRUE),
    q25_distance_m=quantile(median_distance_m,.25,na.rm=TRUE),
    q75_distance_m=quantile(median_distance_m,.75,na.rm=TRUE),
    low_spatial_support_n=sum(group_change_low_spatial_support,na.rm=TRUE),
    low_spatial_support_pct=100*mean(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

year_tbl <- events %>%
  group_by(to_year,interval_era,change_class) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    median_p_high=median(p_high,na.rm=TRUE),
    median_distance_m=median(median_distance_m,na.rm=TRUE),
    low_spatial_support_n=sum(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

era_tbl <- events %>%
  group_by(interval_era,change_class) %>%
  summarise(
    n_changes=n(),
    n_badgers=n_distinct(tattoo),
    pct_within_era=100*n()/sum(n()),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_distance_m=median(median_distance_m,na.rm=TRUE),
    low_spatial_support_pct=100*mean(group_change_low_spatial_support,na.rm=TRUE),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("P3_01b — GROUP-CHANGE LINEAGE / RECONFIGURATION AUDIT\n")
cat("============================================================\n")
cat("Recorded annual resident-group changes:",nrow(events),"\n\n")
cat("BY CHANGE CLASS\n")
print(summary_tbl,n=Inf,width=Inf)
cat("\nPRE/POST-2018 DESCRIPTIVE SPLIT (interval classified by ending year)\n")
print(era_tbl,n=Inf,width=Inf)

write_csv(summary_tbl,
          "results/Phase3/P3_01b_group_change_lineage_summary.csv")
write_csv(year_tbl,
          "results/Phase3/P3_01b_group_change_lineage_by_year.csv")
write_csv(events,
          "results/Phase3/P3_01b_group_change_lineage_events.csv")

cat("\nInterpretation rule:\n")
cat("- SAME_STATIC_CORE changes are candidate boundary/name/reconfiguration events, not assumed dispersal.\n")
cat("- DIFFERENT_STATIC_CORE changes are stronger candidates for genuine spatial relocation.\n")
cat("- Neither class overwrites the published annual resident SOCG assignment.\n")
cat("- The 2018 split is descriptive only at this stage.\n")
cat("\nP3_01b COMPLETE\n")
