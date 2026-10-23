# Woodchester: inspect sett names, recorded capture SGs and annual polygon labels.
# Read-only: no source files or database records are modified.
suppressPackageStartupMessages({library(sf); library(dplyr); library(readr); library(stringr); library(tidyr); library(purrr)})
source_dir <- 'data/spatial/social_group_boundaries'
enc_file <- 'data/badger_encounters_useful.rds'
resident_file <- 'results/annual_resident_social_group_vicente.csv'
out <- 'outputs/social_group_identity_audit'
dir.create(out, showWarnings = FALSE, recursive = TRUE)
stopifnot(file.exists(enc_file), dir.exists(source_dir))
canon <- function(x) {
  x <- toupper(str_squish(as.character(x)))
  x[is.na(x) | x %in% c('', 'NA','N/A','UNKNOWN','UNK','NOT KNOWN')] <- NA_character_
  x
}
key <- function(x) str_replace_all(canon(x), '[^A-Z0-9]', '')
files <- list.files(source_dir, '^territories_[0-9]{4}\\.shp$', full.names = TRUE)
if (!length(files)) stop('No annual territory .shp files found')
polys <- map_dfr(files, function(f) {
  z <- st_drop_geometry(st_read(f, quiet=TRUE))
  name_col <- intersect(c('SocialName','Social_grp','Sett','SETT'), names(z))
  if (length(name_col)!=1) stop('Cannot unambiguously find territory name field: ',f)
  tibble(year=as.integer(str_extract(basename(f),'[0-9]{4}')),
         polygon_name=as.character(z[[name_col]]), name_field=name_col,
         polygon_row=seq_len(nrow(z)))
}) %>% mutate(polygon_key=key(polygon_name))
write_csv(polys, file.path(out,'01_polygon_name_by_year.csv'))
enc <- as_tibble(readRDS(enc_file))
first_col <- function(candidates) {a <- intersect(candidates,names(enc)); if(length(a)) a[1] else NA_character_}
sett_col <- first_col(c('recorded_sett_name','sett','normalized_sett_name','Sett'))
sg_col <- first_col(c('recorded_social_group_name','socg','social_group','normalized_social_group_name'))
needed <- c('tattoo','primary_year', 'has_live_capture')
if (any(!needed %in% names(enc)) || is.na(sett_col) || is.na(sg_col)) stop('Inspect names(readRDS("',enc_file,'")): required capture columns missing')
cap <- enc %>% transmute(tattoo=toupper(str_squish(as.character(tattoo))),
 year=as.integer(primary_year), live=as.logical(has_live_capture),
 sett_original=as.character(.data[[sett_col]]), group_original=as.character(.data[[sg_col]])) %>%
 filter(live %in% TRUE, !is.na(year)) %>%
 mutate(sett_key=key(sett_original), group_key=key(group_original))
# We preserve raw values and do not assume that equal strings prove biological identity.
sett_names <- cap %>% filter(!is.na(sett_key)) %>% count(sett_key,sort=TRUE,name='n_sett_captures') %>%
 left_join(cap %>% filter(!is.na(sett_key)) %>% group_by(sett_key) %>% summarise(sett_examples=paste(head(sort(unique(sett_original)),5),collapse=' | '),.groups='drop'),by='sett_key')
group_names <- cap %>% filter(!is.na(group_key)) %>% count(group_key,sort=TRUE,name='n_group_captures') %>%
 left_join(cap %>% filter(!is.na(group_key)) %>% group_by(group_key) %>% summarise(group_examples=paste(head(sort(unique(group_original)),5),collapse=' | '),.groups='drop'),by='group_key')
inventory <- polys %>% group_by(polygon_key) %>% summarise(polygon_examples=paste(head(sort(unique(polygon_name)),5),collapse=' | '),
 first_year=min(year),last_year=max(year),n_polygon_years=n_distinct(year),n_polygons=n(),.groups='drop') %>%
 left_join(sett_names,by=c('polygon_key'='sett_key')) %>% left_join(group_names,by=c('polygon_key'='group_key')) %>%
 mutate(found_as_capture_sett=!is.na(n_sett_captures),found_as_capture_SG=!is.na(n_group_captures),
  match_type=case_when(found_as_capture_sett & found_as_capture_SG ~ 'both',
                    found_as_capture_sett ~ 'sett only',found_as_capture_SG ~ 'SG only',TRUE ~ 'neither')) %>%
 arrange(match_type,polygon_examples)
write_csv(inventory,file.path(out,'02_polygon_label_inventory_vs_capture_names.csv'))
# Historical capture-level sett <-> recorded group, by year. Unique capture counts are not evidence of exclusivity.
links <- cap %>% filter(!is.na(sett_key),!is.na(group_key)) %>%
 count(year,sett_key,group_key,sort=TRUE,name='n_captures') %>%
 group_by(year,sett_key) %>% mutate(n_sett_year_captures=sum(n_captures),
   share_within_sett_year=n_captures/n_sett_year_captures,
   n_recorded_groups_at_sett=n()) %>% ungroup() %>% arrange(year,sett_key,desc(n_captures))
write_csv(links,file.path(out,'03_sett_to_capture_SG_by_year.csv'))
# Show source strings for links; separate raw text from comparison key.
examples <- cap %>% filter(!is.na(sett_key),!is.na(group_key)) %>%
 group_by(year,sett_key,group_key) %>% summarise(
  sett_examples=paste(head(sort(unique(sett_original)),3),collapse=' | '),
  group_examples=paste(head(sort(unique(group_original)),3),collapse=' | '),.groups='drop')
write_csv(left_join(links,examples,by=c('year','sett_key','group_key')),
 file.path(out,'04_sett_SG_links_with_raw_names.csv'))
# Within-year capture record consistency: badgers frequently recorded under >1 SG.
by_badger <- cap %>% filter(!is.na(group_key)) %>% count(tattoo,year,group_key,name='n_captures') %>%
 group_by(tattoo,year) %>% mutate(n_groups=n(), max_captures=max(n_captures),modal_tied=sum(n_captures==max_captures)>1) %>% ungroup()
write_csv(by_badger,file.path(out,'05_badger_year_capture_SG_counts.csv'))
if (file.exists(resident_file)) {
 resident <- read_csv(resident_file,show_col_types=FALSE)
 write_csv(resident %>% count(assignment_criterion, resident_group_resolved,name='n_badger_years'),
  file.path(out,'06_resident_assignment_criterion_summary.csv'))
} else message('Annual resident SG file absent; run scripts/behaviour/Woodchester_assign_annual_resident_social_group.R separately.')
cat('\nDATA SOURCES: SG field=',sg_col,'; sett field=',sett_col,'\n',sep='')
cat('POLYGON LABELS: ',nrow(inventory),' distinct formatting keys\n',sep='')
print(inventory %>% count(match_type,name='n_names'))
cat('\nBadger-years with >1 recorded SG: ',by_badger %>% distinct(tattoo,year,n_groups) %>% filter(n_groups>1) %>% nrow(),'\n',sep='')
cat('Output: ',out,'\n',sep='')
