#!/usr/bin/env Rscript
# Woodchester: compare annual V11S spatial territory assignments to recorded
# social-group names at live captures. Descriptive concordance, not independent
# validation (both evidence streams use the same capture histories).
suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(readr); library(stringr); library(ggplot2)
})

input_dir <- Sys.getenv('OVERLAY_DIR', 'outputs/V11S_social_group_overlay')
out_dir <- Sys.getenv('VALIDATION_DIR', 'outputs/V11S_social_group_validation')
dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)
file_mem <- file.path(input_dir, 'posterior_draw_memberships.csv')
enc_file <- 'data/badger_encounters_useful.rds'
pop_file <- 'results/V7_population_inclusion_audit.rds'
for(f in c(file_mem,enc_file,pop_file)) if (!file.exists(f)) stop('Missing input: ',f)

normalize <- function(x) {
  z <- str_squish(str_to_upper(as.character(x)))
  z[z %in% c('', 'NA', 'N/A', 'UNKNOWN', 'UNK', 'NOT KNOWN', 'NULL')] <- NA_character_
  z
}
# Preserve original strings. No fuzzy matching of e.g. compound group labels.
enc <- readRDS(enc_file)
pop <- readRDS(pop_file)$population
required_pop <- c('tattoo','individual_id','movement_eligible')
if (!all(required_pop %in% names(pop))) stop('Population file missing: ',paste(setdiff(required_pop,names(pop)),collapse=', '))
lookup <- pop %>% filter(movement_eligible) %>%
  transmute(individual_id=as.character(individual_id),tattoo=normalize(tattoo)) %>% distinct()
if(anyDuplicated(lookup$individual_id) || anyDuplicated(lookup$tattoo)) stop('Non-unique individual ID / tattoo mapping in population audit')
name_candidates <- c('recorded_social_group_name','socg','social_group','normalized_social_group_name')
name_field <- intersect(name_candidates, names(enc))[1]
if(is.na(name_field)) stop('No historical recorded group field; encountered fields: ',paste(names(enc),collapse=', '))
need <- c('tattoo','primary_year','has_live_capture')
if(!all(need %in% names(enc))) stop('Encounters missing: ',paste(setdiff(need,names(enc)),collapse=', '))
message('Observed group source: ',name_field)
cap <- enc %>% transmute(tattoo=normalize(tattoo),year=as.integer(primary_year),
                         live=as.logical(has_live_capture),recorded_raw=as.character(.data[[name_field]]),
                         recorded_group=normalize(.data[[name_field]])) %>%
  filter(live %in% TRUE, !is.na(year), !is.na(tattoo)) %>%
  inner_join(lookup,by='tattoo')
# Keep possible sett/group miscoding visible as flags, not silently call it a match.
cap <- cap %>% mutate(flag_legacy_sett_as_group=recorded_group %in% c('CHESTNUT','HOLLOW TREE'))
cap_valid <- cap %>% filter(!is.na(recorded_group), !flag_legacy_sett_as_group)

observed <- cap_valid %>% count(individual_id, year, recorded_group, name='n_captures_group') %>%
  group_by(individual_id,year) %>% mutate(n_recorded=sum(n_captures_group),
    share=n_captures_group/n_recorded, n_group_names=n(), max_n=max(n_captures_group),
    modal_tie=sum(n_captures_group==max_n)>1L,
    is_unique_modal=n_captures_group==max_n & !modal_tie) %>% ungroup()
observed_summary <- observed %>% group_by(individual_id,year) %>% summarise(
  n_recorded=first(n_recorded),n_recorded_groups=first(n_group_names),
  observed_unique_modal=if(any(is_unique_modal)) recorded_group[which(is_unique_modal)[1]] else NA_character_,
  observed_modal_tie=first(modal_tie),.groups='drop')

# Overlaid membership strings are sorted 'NAME | NAME'; split into set membership.
mem <- read_csv(file_mem, show_col_types=FALSE, col_types=cols(
  chain=col_integer(),draw=col_integer(),individual_id=col_character(),year=col_integer(),membership=col_character()))
if(anyDuplicated(mem[c('chain','draw','individual_id','year')])) stop('Repeated posterior draw/individual/year rows')
mem <- mem %>% mutate(membership=normalize(membership),
  polygon_status=case_when(membership=='OUTSIDE'~'outside',membership=='NO_MAP'~'no_map',
    is.na(membership)~'missing',str_detect(membership, fixed('|'))~'overlap',TRUE~'single'))

# Group comparison: observed group appears anywhere among matching polygons.
# No implicit alias creation or nearest-neighbour assignment.
compare <- mem %>% left_join(observed_summary,by=c('individual_id','year')) %>%
  left_join(observed %>% select(individual_id,year,recorded_group,share,n_captures_group),
            by=c('individual_id','year'), relationship='many-to-many') %>%
  mutate(has_observation=!is.na(recorded_group),
    polygon_contains_recorded=case_when(!has_observation~NA, 
      polygon_status %in% c('outside','no_map','missing')~FALSE,
      TRUE~vapply(seq_along(membership),function(k) {
        if (is.na(membership[k]) || is.na(recorded_group[k])) return(FALSE)
        recorded_group[k] %in% str_trim(str_split(membership[k], fixed('|'))[[1]])
      },logical(1))))
# collapse to one row / draw / badger-year to avoid capture-count weighting;
# capture-weighted agreement is a separate metric.
by_draw <- compare %>% group_by(chain,draw,individual_id,year) %>% summarise(
  polygon_status=first(polygon_status),n_recorded=first(n_recorded),
  n_recorded_groups=first(n_recorded_groups), observed_modal_tie=first(observed_modal_tie),
  observed_unique_modal=first(observed_unique_modal),
  any_recorded_matches=if(all(is.na(polygon_contains_recorded))) NA else any(polygon_contains_recorded,na.rm=TRUE),
  capture_weighted_match=if(all(is.na(polygon_contains_recorded))) NA_real_ else
    sum(share * as.numeric(polygon_contains_recorded),na.rm=TRUE),
  modal_matches=if(is.na(first(observed_unique_modal))) NA else
    first(observed_unique_modal) %in% str_trim(str_split(first(membership),fixed('|'))[[1]]),
  .groups='drop') %>% mutate(observed= !is.na(n_recorded))
by_year <- by_draw %>% group_by(year) %>% summarise(
  n_badger_years=n_distinct(individual_id),
  n_observed_badger_years=n_distinct(individual_id[observed]),
  fraction_with_recorded=mean(observed),
  fraction_single=mean(polygon_status=='single'),
  fraction_overlap=mean(polygon_status=='overlap'),
  fraction_outside=mean(polygon_status=='outside'),
  mean_any_recorded_match=if(all(is.na(any_recorded_matches))) NA_real_ else mean(any_recorded_matches,na.rm=TRUE),
  mean_capture_weighted_match=if(all(is.na(capture_weighted_match))) NA_real_ else mean(capture_weighted_match,na.rm=TRUE),
  mean_modal_match=if(all(is.na(modal_matches))) NA_real_ else mean(modal_matches,na.rm=TRUE),
  .groups='drop')
by_badger_year <- by_draw %>% group_by(individual_id,year) %>% summarise(
  n_draws=n(),has_recorded=first(observed),n_recorded=first(n_recorded),
  n_recorded_groups=first(n_recorded_groups),observed_unique_modal=first(observed_unique_modal),
  p_single=mean(polygon_status=='single'),p_overlap=mean(polygon_status=='overlap'),
  p_outside=mean(polygon_status=='outside'),
  p_any_recorded_match=if(all(is.na(any_recorded_matches))) NA_real_ else mean(any_recorded_matches,na.rm=TRUE),
  p_modal_match=if(all(is.na(modal_matches))) NA_real_ else mean(modal_matches,na.rm=TRUE),
  p_capture_weighted_match=if(all(is.na(capture_weighted_match))) NA_real_ else mean(capture_weighted_match,na.rm=TRUE),.groups='drop')

# Focus review on mismatch in mapped single territories, avoiding misleading
# conclusions from outside/overlap or compound name equivalences.
review <- compare %>% filter(has_observation, polygon_status=='single',!polygon_contains_recorded) %>%
  count(year,recorded_group,membership,sort=TRUE,name='posterior_draw_capture_group_rows')
source_names <- observed %>% distinct(year,recorded_group) %>% rename(source_group=recorded_group)
poly_names <- mem %>% filter(polygon_status %in% c('single','overlap')) %>%
  select(year,membership) %>% distinct() %>% separate_rows(membership,sep='\\s*\\|\\s*') %>%
  distinct(year,polygon_group=membership)
names_missing_from_polygons <- source_names %>% anti_join(poly_names,by=c('year','source_group'='polygon_group'))

write_csv(observed, file.path(out_dir,'01_capture_group_counts_by_badger_year.csv'))
write_csv(observed_summary,file.path(out_dir,'02_observed_group_summary.csv'))
write_csv(by_badger_year,file.path(out_dir,'03_badger_year_validation.csv'))
write_csv(by_year,file.path(out_dir,'04_annual_validation.csv'))
write_csv(review,file.path(out_dir,'05_single_polygon_disagreement_review.csv'))
write_csv(names_missing_from_polygons,file.path(out_dir,'06_recorded_names_absent_from_sampled_polygons.csv'))
write_csv(cap %>% count(year,flag_legacy_sett_as_group,name='n_captures'),file.path(out_dir,'07_legacy_name_flags.csv'))

p <- ggplot(by_year,aes(year)) +
  geom_line(aes(y=fraction_single,colour='Exactly one mapped territory')) +
  geom_line(aes(y=mean_any_recorded_match,colour='At least one recorded group agrees')) +
  geom_line(aes(y=mean_modal_match,colour='Unique modal group agrees')) +
  scale_y_continuous(limits=c(0,1),labels=function(x) paste0(round(100*x),'%')) +
  labs(title='Annual spatial / capture-group concordance',x='Year',y='Fraction of posterior draws',colour=NULL) + theme_minimal()
ggsave(file.path(out_dir,'08_annual_concordance.png'),p,width=11,height=6,dpi=200)
cat('Validation done. Outputs: ',normalizePath(out_dir),'\n',sep='')
cat('Recorded group field: ',name_field,'\n',sep='')
cat('Unique eligible animals in overlay: ',n_distinct(mem$individual_id),'\n',sep='')
cat('Badger-years with contemporary recorded group: ',sum(by_badger_year$has_recorded),' of ',nrow(by_badger_year),'\n',sep='')
