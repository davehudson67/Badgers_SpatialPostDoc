# PHASE 3 P3_02 — Rogers/Vicente benchmark data build
# Builds historical-style movement and culture-excretion quantities only.
# No model is fitted here.

suppressPackageStartupMessages({library(tidyverse); library(lubridate)})

MEM <- "data/phase3/P3_annual_recorded_membership.rds"
ENC <- "data/badger_encounters_useful.rds"
DIS <- "data/badger_final_CMRready_wDisease.rds"
IND <- "data/badger_individuals.rds"
for(f in c(MEM,ENC,DIS,IND)) if(!file.exists(f)) stop("Missing: ",f)
dir.create("results/Phase3",recursive=TRUE,showWarnings=FALSE)
dir.create("data/phase3",recursive=TRUE,showWarnings=FALSE)

m <- readRDS(MEM)
enc <- as_tibble(readRDS(ENC))
dis <- as_tibble(readRDS(DIS))
ind <- as_tibble(readRDS(IND))

clean_sg <- function(x){
  z <- toupper(str_squish(as.character(x)))
  z <- str_replace_all(z,"[^A-Z0-9]","")
  z[z==""|z=="NA"] <- NA_character_
  recode(z,"CHESTNUT"="BEECH","HOLLOWTREE"="NETTLE",.default=z)
}

resident <- as_tibble(m$annual_membership) %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(year),
            resident_socg=clean_sg(candidate_resident_socg),
            assignment_criterion=assignment_criterion,
            n_live_records=n_live_records,n_distinct_socg=n_distinct_socg) %>%
  filter(!is.na(resident_socg))
stopifnot(!anyDuplicated(resident[c("tattoo","year")]))

traits <- ind %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            sex=toupper(str_squish(as.character(sex))),
            age_fc=toupper(str_squish(as.character(age_fc))),
            year_fc=as.integer(year_fc),
            birth_year=case_when(age_fc=="CUB"~year_fc,
                                 age_fc=="YEARLING"~year_fc-1L,
                                 TRUE~NA_integer_)) %>%
  distinct(tattoo,.keep_all=TRUE)

live <- enc %>%
  filter(has_live_capture %in% TRUE) %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            capture_date=as.Date(capture_date),
            year=year(capture_date),socg=clean_sg(socg)) %>%
  filter(tattoo!="",!is.na(capture_date),!is.na(socg)) %>%
  arrange(tattoo,capture_date) %>%
  group_by(tattoo) %>%
  mutate(prev_socg=lag(socg),next_socg=lead(socg),
         # Rogers: is NEXT capture in another SG?
         rogers_move=if_else(!is.na(next_socg),as.integer(socg!=next_socg),NA_integer_),
         # Vicente: has SG changed since PREVIOUS capture?
         vicente_move=if_else(!is.na(prev_socg),as.integer(socg!=prev_socg),NA_integer_)) %>%
  ungroup() %>%
  left_join(traits %>% select(tattoo,sex,birth_year),by="tattoo") %>%
  mutate(is_cub_year=!is.na(birth_year)&year==birth_year)

# Rogers 1978-1995 annual capture-transition series.
rogers <- live %>%
  filter(year>=1978L,year<=1995L,!is.na(rogers_move)) %>%
  group_by(year) %>%
  summarise(n_scorable=n(),n_moves=sum(rogers_move),
            movement_proportion=mean(rogers_move),
            female_prop=mean(rogers_move[sex=="FEMALE"],na.rm=TRUE),
            male_prop=mean(rogers_move[sex=="MALE"],na.rm=TRUE),
            .groups="drop")

# Culture-only excretor history, matching the older disease endpoint.
need <- c("tattoo","primary_year","culture_tested","culture_positive")
if(length(setdiff(need,names(dis)))) stop("Disease snapshot lacks culture fields.")
culture_year <- dis %>%
  transmute(tattoo=trimws(as.character(tattoo)),year=as.integer(primary_year),
            culture_tested=as.logical(culture_tested),
            culture_positive=as.logical(culture_positive)) %>%
  group_by(tattoo,year) %>%
  summarise(culture_tested=any(culture_tested,na.rm=TRUE),
            culture_positive=any(culture_positive,na.rm=TRUE),.groups="drop")
first_pos <- culture_year %>%
  group_by(tattoo) %>%
  summarise(first_culture_year=if(any(culture_positive))
    min(year[culture_positive]) else NA_integer_,.groups="drop")

# Vicente annual individual movement mean; cub-years excluded from group index.
ind_move <- live %>%
  filter(!is_cub_year,!is.na(vicente_move)) %>%
  group_by(tattoo,year) %>%
  summarise(individual_movement_mean=mean(vicente_move),
            n_move_scores=n(),.groups="drop")

iy <- resident %>%
  left_join(traits,by="tattoo") %>%
  left_join(culture_year,by=c("tattoo","year")) %>%
  left_join(first_pos,by="tattoo") %>%
  left_join(ind_move,by=c("tattoo","year")) %>%
  mutate(culture_tested=replace_na(culture_tested,FALSE),
         culture_positive=replace_na(culture_positive,FALSE),
         incident_excretor=!is.na(first_culture_year)&first_culture_year==year,
         prevalent_before=!is.na(first_culture_year)&first_culture_year<year,
         susceptible_start=!prevalent_before,
         is_cub_year=!is.na(birth_year)&year==birth_year) %>%
  arrange(tattoo,year) %>%
  group_by(tattoo) %>%
  mutate(prev_year=lag(year),prev_socg=lag(resident_socg),
         resident_switch=(year-prev_year==1L)&!is.na(prev_socg)&resident_socg!=prev_socg) %>%
  ungroup()

gmove <- iy %>%
  filter(!is_cub_year,is.finite(individual_movement_mean)) %>%
  group_by(year,resident_socg) %>%
  summarise(group_movement_index=mean(individual_movement_mean),
            group_movement_n=n(),.groups="drop")

gy <- iy %>%
  group_by(year,resident_socg) %>%
  summarise(resident_count=n(),
            incident_excretors=sum(incident_excretor),
            prevalent_excretors_start=sum(prevalent_before),
            susceptible_start=sum(susceptible_start),
            incident_prop=if_else(susceptible_start>0,
                                  incident_excretors/susceptible_start,NA_real_),
            prior_excretor_prevalence=mean(prevalent_before),
            culture_tested_residents=sum(culture_tested),
            incoming_resident_switches=sum(resident_switch,na.rm=TRUE),
            .groups="drop") %>%
  left_join(gmove,by=c("year","resident_socg")) %>%
  group_by(resident_socg) %>%
  arrange(year,.by_group=TRUE) %>%
  mutate(prev_resident_count=lag(resident_count),
         resident_count_trend_pct=if_else(!is.na(prev_resident_count)&prev_resident_count>0,
           100*(resident_count-prev_resident_count)/prev_resident_count,NA_real_),
         prev_group_movement_index=lag(group_movement_index)) %>%
  ungroup()

# Attach next-year culture incidence to Rogers annual movement.
pop <- iy %>% group_by(year) %>%
  summarise(incident_excretors=sum(incident_excretor),
            susceptible_start=sum(susceptible_start),
            culture_incidence=if_else(susceptible_start>0,
              incident_excretors/susceptible_start,NA_real_),.groups="drop")
rogers <- rogers %>%
  left_join(pop %>% transmute(year=year-1L,
                              next_year_culture_incidence=culture_incidence,
                              next_year_incident_excretors=incident_excretors),
            by="year")

vw <- gy %>% filter(year>=1990L,year<=2004L)
audit <- bind_rows(
  tibble(window="Rogers_1978_1995",years=n_distinct(rogers$year),
         groups=n_distinct(live$socg[live$year>=1978&live$year<=1995]),
         groupyears=NA_integer_,badgers=n_distinct(live$tattoo[live$year>=1978&live$year<=1995]),
         culture_incidents=sum(iy$incident_excretor[iy$year>=1978&iy$year<=1995])),
  tibble(window="Vicente_1990_2004",years=n_distinct(vw$year),
         groups=n_distinct(vw$resident_socg),groupyears=nrow(vw),
         badgers=n_distinct(iy$tattoo[iy$year>=1990&iy$year<=2004]),
         culture_incidents=sum(vw$incident_excretors)),
  tibble(window="Modern_2018_2025",years=n_distinct(gy$year[gy$year>=2018&gy$year<=2025]),
         groups=n_distinct(gy$resident_socg[gy$year>=2018&gy$year<=2025]),
         groupyears=sum(gy$year>=2018&gy$year<=2025),
         badgers=n_distinct(iy$tattoo[iy$year>=2018&iy$year<=2025]),
         culture_incidents=sum(gy$incident_excretors[gy$year>=2018&gy$year<=2025]))
)

cat("\n============================================================\n")
cat("P3_02 — LITERATURE BENCHMARK DATA BUILD\n")
cat("============================================================\n")
cat("Rogers 1978-1995: movement proportion = ",
    round(sum(rogers$n_moves)/sum(rogers$n_scorable),3),
    " (published reference ~0.12)\n",sep="")
cat("  NOTE: exact historical 22-core subset not imposed yet.\n")
cat("Vicente 1990-2004: group-years = ",nrow(vw),
    "; groups = ",n_distinct(vw$resident_socg),"\n",sep="")
yy <- vw %>% count(year)
cat("  groups/year median = ",median(yy$n),
    "; range = ",paste(range(yy$n),collapse="-"),"\n",sep="")
cat("  culture incident excretors = ",sum(vw$incident_excretors),"\n",sep="")
cat("  NOTE: resident_count is a transparent observed-resident proxy, NOT MNA.\n")
print(audit,n=Inf,width=Inf)

write_csv(rogers,"results/Phase3/P3_02_rogers_annual_benchmark.csv")
write_csv(gy,"results/Phase3/P3_02_vicente_groupyear_benchmark.csv")
write_csv(iy,"results/Phase3/P3_02_vicente_individualyear_benchmark.csv")
write_csv(audit,"results/Phase3/P3_02_window_audit.csv")
saveRDS(list(rogers=rogers,individual_year=iy,groupyear=gy,audit=audit,
             limitations=c("exact Rogers 22-core list not yet imposed",
                           "resident_count is not yet the published MNA group-size estimate")),
        "data/phase3/P3_literature_benchmark_panel.rds")

cat("P3_02 BUILD COMPLETE — inspect benchmark recovery before fitting models.\n")
