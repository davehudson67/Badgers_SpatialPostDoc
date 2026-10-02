# PHASE 3 P3_02d — published historical core-anchor audit
#
# Purpose:
#   Use published Woodchester core-group anchors rather than the modern V9
#   static SG raster to understand which recorded SOCG labels belong to the
#   historical intensively studied core.
#
# IMPORTANT:
#   This is an audit only. The union of published anchors is NOT automatically
#   imposed as the final core definition because territories split/merge through
#   time and Vicente et al. used annual bait-marking.
#
# Literature anchors:
#   - Rogers et al. (1997): 21 core social groups studied 1978-1993.
#   - A published/repository-rendered 2003 Woodchester bait-marking map provides
#     a later core configuration.
#
# Outputs:
#   results/Phase3/P3_02d_published_anchor_groups.csv
#   results/Phase3/P3_02d_anchor_counts_by_year.csv
#   results/Phase3/P3_02d_anchor_group_support.csv
#   results/Phase3/P3_02d_nonanchor_groups.csv

suppressPackageStartupMessages({library(tidyverse); library(lubridate)})

ENC <- "data/badger_encounters_useful.rds"
MEM <- "data/phase3/P3_annual_recorded_membership.rds"
BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
for(f in c(ENC,MEM,BENCH)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

enc <- as_tibble(readRDS(ENC))
m <- readRDS(MEM)
b <- readRDS(BENCH)

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(z,"CHESTNUT"="BEECH","HOLLOWTREE"="NETTLE",
                "JACKS"="JACKSMIREY","COLLIERS"="COLLIERSWOOD",
                .default=z)
}

# 21 groups shown for the Rogers et al. (1997) 1978-1993 core population.
core_1978_1993 <- clean_sg(c(
  "Arthurs","Beech","Cedar","Cole Park","Colliers Wood","Hedge",
  "Honeywell","Inchbrook","Jacks Mirey","Junction","Kennel","Larch",
  "Nettle","Old Oak","Peglars","Septic Tank","Top","West",
  "Windsor Edge","Wood Farm","Yew"
))

# Group labels shown on the 2003 Woodchester bait-marking map available in the
# later population/disease dynamics thesis. Keep separate from the early anchor.
core_2003 <- clean_sg(c(
  "Arthurs","Beech","Box","Breakheart","Cedar","Cole Park",
  "Colliers Wood","Field Farm","Hedge","Honeywell","Jacks Mirey",
  "Junction","Kennel","Nettle","Old Oak","Parkmill","Peglars",
  "Septic Tank","Thistle Wood Bank","Top","West","Wood Farm",
  "Woodrush","Wych Elm","Yew"
))

anchor <- tibble(
  socg=sort(unique(c(core_1978_1993,core_2003)))
) %>%
  mutate(
    in_core_1978_1993=socg %in% core_1978_1993,
    in_core_2003=socg %in% core_2003,
    anchor_class=case_when(
      in_core_1978_1993 & in_core_2003 ~ "BOTH_ANCHORS",
      in_core_1978_1993 ~ "EARLY_ONLY",
      in_core_2003 ~ "2003_ONLY",
      TRUE ~ "NONE"
    )
  )

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            capture_date=as.Date(capture_date),
            year=lubridate::year(capture_date),
            socg=clean_sg(socg)) %>%
  filter(year>=1990L,year<=2004L,!is.na(socg))

annual <- as_tibble(m$annual_membership) %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),
            socg=clean_sg(candidate_resident_socg)) %>%
  filter(year>=1990L,year<=2004L,!is.na(socg))

all_year <- live %>%
  distinct(year,socg) %>%
  count(year,name="all_recorded_groups")

anchor_year <- live %>%
  distinct(year,socg) %>%
  mutate(
    early=socg %in% core_1978_1993,
    map2003=socg %in% core_2003,
    union=socg %in% anchor$socg
  ) %>%
  group_by(year) %>%
  summarise(
    early_anchor_groups=sum(early),
    map2003_anchor_groups=sum(map2003),
    union_anchor_groups=sum(union),
    .groups="drop"
  ) %>%
  complete(year=1990:2004,fill=list(
    early_anchor_groups=0L,map2003_anchor_groups=0L,union_anchor_groups=0L
  )) %>%
  left_join(all_year,by="year") %>%
  mutate(
    vicente_range_low=23L,
    vicente_range_high=27L,
    union_within_vicente_range=
      union_anchor_groups>=vicente_range_low &
      union_anchor_groups<=vicente_range_high
  )

support <- live %>%
  group_by(socg) %>%
  summarise(
    first_live_year=min(year),
    last_live_year=max(year),
    n_live_records=n(),
    n_badgers=n_distinct(tattoo),
    n_years=n_distinct(year),
    .groups="drop"
  ) %>%
  full_join(
    annual %>%
      group_by(socg) %>%
      summarise(n_resident_badger_years=n(),
                resident_first_year=min(year),
                resident_last_year=max(year),.groups="drop"),
    by="socg"
  ) %>%
  left_join(anchor,by="socg") %>%
  mutate(
    in_core_1978_1993=replace_na(in_core_1978_1993,FALSE),
    in_core_2003=replace_na(in_core_2003,FALSE),
    anchor_class=replace_na(anchor_class,"NON_ANCHOR")
  ) %>%
  arrange(factor(anchor_class,
                 levels=c("BOTH_ANCHORS","EARLY_ONLY","2003_ONLY","NON_ANCHOR")),
          socg)

nonanchor <- support %>%
  filter(anchor_class=="NON_ANCHOR") %>%
  arrange(desc(n_years),desc(n_live_records))

# Benchmark-panel coverage under the anchor union; descriptive only.
iy <- as_tibble(b$individual_year) %>%
  mutate(in_anchor_union=resident_socg %in% anchor$socg)
gy <- as_tibble(b$groupyear) %>%
  mutate(in_anchor_union=resident_socg %in% anchor$socg)

vw <- gy %>% filter(year>=1990L,year<=2004L,in_anchor_union)
viy <- iy %>% filter(year>=1990L,year<=2004L,in_anchor_union)

cat("\n============================================================\n")
cat("P3_02d — PUBLISHED HISTORICAL CORE-ANCHOR AUDIT\n")
cat("============================================================\n")
cat("Early Rogers-style core anchor labels:",length(core_1978_1993),"\n")
cat("2003 bait-marking map anchor labels:",length(core_2003),"\n")
cat("Union of anchor labels:",nrow(anchor),"\n")
cat("Shared between anchors:",sum(anchor$anchor_class=="BOTH_ANCHORS"),"\n")
cat("Early-only:",sum(anchor$anchor_class=="EARLY_ONLY"),
    "| 2003-only:",sum(anchor$anchor_class=="2003_ONLY"),"\n\n")

cat("GROUP COUNTS BY YEAR\n")
print(anchor_year,n=Inf,width=Inf)

cat("\nANCHOR-UNION BENCHMARK COVERAGE 1990-2004\n")
cat("Group-years:",nrow(vw),"\n")
cat("Distinct resident groups:",n_distinct(vw$resident_socg),"\n")
cat("Resident badger-years:",nrow(viy),"\n")
cat("Culture incident excretors:",sum(vw$incident_excretors,na.rm=TRUE),"\n")

cat("\nNON-ANCHOR GROUPS OBSERVED 1990-2004\n")
print(nonanchor,n=Inf,width=Inf)

write_csv(anchor,"results/Phase3/P3_02d_published_anchor_groups.csv")
write_csv(anchor_year,"results/Phase3/P3_02d_anchor_counts_by_year.csv")
write_csv(support,"results/Phase3/P3_02d_anchor_group_support.csv")
write_csv(nonanchor,"results/Phase3/P3_02d_nonanchor_groups.csv")

saveRDS(list(anchor=anchor,counts_by_year=anchor_year,support=support,
             nonanchor=nonanchor,
             note=paste(
               "Published anchor audit only. Do not treat anchor union as exact",
               "annual core membership without checking annual bait-marking/group lineage."
             )),
        "data/phase3/P3_published_core_anchor_audit.rds")

cat("\nInterpretation:\n")
cat("- If the anchor union reproduces roughly 23-27 groups/year, it is a useful historical core scaffold.\n")
cat("- Early-only / 2003-only groups are candidate territory loss/fission/reconfiguration lineages.\n")
cat("- Remaining non-anchor groups are candidate outer-study-area groups.\n")
cat("- Annual bait-marking remains the preferred exact definition where recoverable.\n")
cat("\nP3_02d COMPLETE\n")
