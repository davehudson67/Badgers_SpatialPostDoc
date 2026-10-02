# PHASE 3 P3_02b — candidate historical core-area audit
# Uses the 27 recorded SOCG labels that map to a non-peripheral static SG as
# a candidate reconstruction of the intensively studied core area.
# This is an audit only; it does not fit a disease model.

suppressPackageStartupMessages({library(tidyverse); library(lubridate)})

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
BENCH <- "data/phase3/P3_literature_benchmark_panel.rds"
ENC <- "data/badger_encounters_useful.rds"
for(f in c(MEM,BENCH,ENC)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)

m <- readRDS(MEM)
b <- readRDS(BENCH)
enc <- as_tibble(readRDS(ENC))

core_labels <- as_tibble(m$socg_static_mapping) %>%
  distinct(socg_key) %>%
  pull(socg_key)

clean_sg <- function(x){
  z <- toupper(stringr::str_squish(as.character(x)))
  z <- stringr::str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  dplyr::recode(z,"CHESTNUT"="BEECH","HOLLOWTREE"="NETTLE",.default=z)
}

iy <- as_tibble(b$individual_year) %>%
  mutate(in_candidate_core=resident_socg %in% core_labels)

gy <- as_tibble(b$groupyear) %>%
  mutate(in_candidate_core=resident_socg %in% core_labels)

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            capture_date=as.Date(capture_date),
            year=lubridate::year(capture_date),
            socg=clean_sg(socg)) %>%
  filter(!is.na(socg))

vw <- gy %>% filter(year>=1990L,year<=2004L,in_candidate_core)
viy <- iy %>% filter(year>=1990L,year<=2004L,in_candidate_core)
vlive <- live %>% filter(year>=1990L,year<=2004L,socg %in% core_labels)

groups_by_year <- vw %>%
  count(year,name="n_groups") %>%
  complete(year=1990:2004,fill=list(n_groups=0L))

support_by_group <- vw %>%
  group_by(resident_socg) %>%
  summarise(first_year=min(year),last_year=max(year),n_years=n_distinct(year),
            median_residents=median(resident_count),.groups="drop") %>%
  arrange(first_year,resident_socg)

excluded <- gy %>%
  filter(year>=1990L,year<=2004L,!in_candidate_core) %>%
  group_by(resident_socg) %>%
  summarise(n_groupyears=n(),first_year=min(year),last_year=max(year),
            total_resident_records=sum(resident_count),.groups="drop") %>%
  arrange(desc(n_groupyears),resident_socg)

cat("\n============================================================\n")
cat("P3_02b — CANDIDATE HISTORICAL CORE-AREA AUDIT\n")
cat("============================================================\n")
cat("Candidate core SOCG labels:",length(core_labels),"\n")
cat("Vicente paper random-effect SG levels: 27\n")
cat("Candidate-core groups/year median:",median(groups_by_year$n_groups),
    "| range:",paste(range(groups_by_year$n_groups),collapse="-"),"\n")
cat("Vicente published bait-marked groups/year: mean 25, range 23-27\n")
cat("Candidate-core group-years:",nrow(vw),"\n")
cat("Candidate-core live capture events 1990-2004:",nrow(vlive),"\n")
cat("Vicente published live capture events: 8981\n")
cat("Candidate-core distinct badgers 1990-2004:",n_distinct(vlive$tattoo),"\n")
cat("Vicente published distinct badgers: 1859\n")
cat("Candidate-core culture incident excretors:",
    sum(vw$incident_excretors,na.rm=TRUE),"\n")

cat("\nGROUPS PER YEAR\n")
print(groups_by_year,n=Inf,width=Inf)
cat("\nEXCLUDED NON-CORE/UNMAPPED LABELS\n")
print(excluded,n=Inf,width=Inf)

write_csv(groups_by_year,
          "results/Phase3/P3_02b_candidate_core_groups_by_year.csv")
write_csv(support_by_group,
          "results/Phase3/P3_02b_candidate_core_group_support.csv")
write_csv(excluded,
          "results/Phase3/P3_02b_excluded_group_labels.csv")

saveRDS(list(core_labels=core_labels,groups_by_year=groups_by_year,
             support_by_group=support_by_group,excluded=excluded,
             individual_year_core=viy,groupyear_core=vw,
             note="Candidate core = recorded SOCG labels with a mapped non-peripheral static SG. Exact annual bait-marking core membership remains preferable if recovered."),
        "data/phase3/P3_candidate_core_benchmark.rds")

cat("\nP3_02b COMPLETE\n")
