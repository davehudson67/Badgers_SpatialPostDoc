#!/usr/bin/env Rscript
# Woodchester: exploratory year-specific territory overlay of V11S posterior annual AC draws.
# No NIMBLE refit. Does not treat polygon membership as verified social membership.
suppressPackageStartupMessages({library(sf); library(dplyr); library(tidyr); library(readr)})

stem <- Sys.getenv('FILE_STEM', 'V11S_RD_ANNUALAC_DIRECT_MULTILOC_AGE_BADGERRE')
n_badgers <- Sys.getenv('MAX_BADGERS', '1932')
n_per_chain <- as.integer(Sys.getenv('DRAWS_PER_CHAIN', '25'))
if (is.na(n_per_chain) || n_per_chain < 1) stop('DRAWS_PER_CHAIN must be positive')
root <- 'outputs/social_group_boundary_audit'
out <- 'outputs/V11S_social_group_overlay'
dir.create(out, recursive = TRUE, showWarnings = FALSE)
territories_file <- file.path(root, 'annual_territories.gpkg')
if (!file.exists(territories_file)) stop('Missing: ', territories_file)
terr <- st_read(territories_file, quiet = TRUE)
stopifnot(all(c('year','territory_name') %in% names(terr)))
if (is.na(st_crs(terr))) stop('Annual territory GeoPackage missing CRS')
terr <- st_transform(terr, 27700)
terr <- terr[!is.na(terr$territory_name) & nzchar(terr$territory_name), ]
# Collapse duplicate names within a year into the named territory's combined geometry.
terr <- terr %>% group_by(year, territory_name) %>% summarise(.groups='drop')
terr_by_year <- split(terr, as.character(terr$year))

# Produce a comma-separated sorted set of intersecting territories, or explicit outside/unknown.
# st_intersects includes boundary contacts, which are ambiguous by design.
assign_points <- function(df, map_year, prefix) {
  result <- rep('NO_MAP', nrow(df))
  if (!nrow(df)) return(result)
  for (yr in unique(map_year)) {
    ii <- which(map_year == yr)
    tt <- terr_by_year[[as.character(yr)]]
    if (is.null(tt) || !nrow(tt)) next
    pts <- st_as_sf(df[ii, , drop=FALSE], coords=c('x','y'), crs=27700, remove=FALSE)
    idx <- st_intersects(pts, tt)
    result[ii] <- vapply(idx, function(k) {
      if (!length(k)) 'OUTSIDE' else paste(sort(unique(tt$territory_name[k])), collapse=' | ')
    }, character(1))
  }
  result
}

files <- file.path('results', sprintf('%s_%s_CHAIN%d.rds', stem, n_badgers, 1:3))
if (!all(file.exists(files))) stop('Missing chain fit(s): ', paste(files[!file.exists(files)], collapse=', '))
set.seed(20261022)
all_members <- vector('list', 3)
all_trans <- vector('list', 3)
for (chain in 1:3) {
  message('Reading chain ', chain)
  fit <- readRDS(files[chain]); idx <- as_tibble(fit$annual_state_index)
  needed <- c('annual_active_index','individual_id','year','sample_column_x','sample_column_y')
  if (!all(needed %in% names(idx))) stop('Missing index fields: ', paste(setdiff(needed, names(idx)), collapse=', '))
  if (anyDuplicated(idx$annual_active_index)) stop('Duplicate annual index')
  m <- as.matrix(fit$samples)
  if (!all(c(idx$sample_column_x, idx$sample_column_y) %in% colnames(m))) stop('Fit missing indexed AC monitors')
  take <- sort(sample(seq_len(nrow(m)), min(n_per_chain, nrow(m))))
  memberships <- vector('list', length(take)); transitions <- vector('list', length(take))
  for (jj in seq_along(take)) {
    if (jj %% 5L == 0L) message('  draw ', jj, '/', length(take))
    d <- idx %>% transmute(individual_id=as.character(individual_id), year=as.integer(year),
          x=as.numeric(m[take[jj], sample_column_x]), y=as.numeric(m[take[jj], sample_column_y]))
    if (!all(is.finite(d$x) & is.finite(d$y))) stop('Non-finite annual locations')
    d$membership <- assign_points(d, d$year, 'current')
    d <- d %>% mutate(chain=chain, draw=jj)
    memberships[[jj]] <- d %>% select(chain,draw,individual_id,year,membership)
    tr <- d %>% arrange(individual_id,year) %>% group_by(individual_id) %>%
      mutate(year_to=lead(year), x_to=lead(x), y_to=lead(y), membership_to=lead(membership)) %>%
      ungroup() %>% filter(!is.na(year_to), year_to == year+1L)
    if (nrow(tr)) {
      # Classify *both* endpoints under *both* annual boundary maps.
      tr$origin_on_destination_map <- assign_points(tr, tr$year_to, 'destination_map')
      dest_pts <- tr %>% transmute(x=x_to,y=y_to)
      tr$destination_on_origin_map <- assign_points(dest_pts, tr$year, 'origin_map')
      tr <- tr %>% mutate(
        distance_m=sqrt((x_to-x)^2+(y_to-y)^2),
        strict_cross=membership != membership_to &
          !grepl('\\|',membership) & !grepl('\\|',membership_to) &
          !membership %in% c('NO_MAP','OUTSIDE') &
          !membership_to %in% c('NO_MAP','OUTSIDE') &
          origin_on_destination_map == membership &
          destination_on_origin_map == membership_to,
        stable_same=membership==membership_to &
          origin_on_destination_map==membership &
          destination_on_origin_map==membership_to &
          !membership %in% c('NO_MAP','OUTSIDE') & !grepl('\\|',membership),
        map_dependent=membership != origin_on_destination_map |
                      membership_to != destination_on_origin_map,
        ambiguous=grepl('\\|',membership) | grepl('\\|',membership_to) |
          membership %in% c('NO_MAP','OUTSIDE') |
          membership_to %in% c('NO_MAP','OUTSIDE')) %>%
        transmute(chain,draw,individual_id,year_from=year,year_to,distance_m,
          origin_groups=membership,destination_groups=membership_to,
          origin_on_destination_map,destination_on_origin_map,
          strict_cross,stable_same,map_dependent,ambiguous)
    }
    transitions[[jj]] <- tr
  }
  all_members[[chain]] <- bind_rows(memberships)
  all_trans[[chain]] <- bind_rows(transitions)
  rm(fit,m); gc(verbose=FALSE)
}
mem <- bind_rows(all_members); tr <- bind_rows(all_trans)
write_csv(mem, file.path(out,'posterior_draw_memberships.csv'))
write_csv(tr, file.path(out,'posterior_draw_transitions.csv'))
member_summary <- mem %>% group_by(individual_id,year) %>% summarise(
  n_draws=n(), p_single_group=mean(!grepl('\\|',membership) & !membership %in% c('NO_MAP','OUTSIDE')),
  p_overlap=mean(grepl('\\|',membership)),p_outside=mean(membership=='OUTSIDE'),
  p_unmapped=mean(membership=='NO_MAP'),.groups='drop')
transition_summary <- tr %>% group_by(individual_id,year_from,year_to) %>% summarise(
  n_draws=n(), mean_distance_m=mean(distance_m),p_strict_cross=mean(strict_cross),
  p_stable_same=mean(stable_same),p_map_dependent=mean(map_dependent),
  p_ambiguous=mean(ambiguous),.groups='drop')
annual <- tr %>% group_by(year_from) %>% summarise(n_draws=n(),
  strict_cross_fraction=mean(strict_cross),ambiguous_fraction=mean(ambiguous),
  map_dependent_fraction=mean(map_dependent),.groups='drop')
write_csv(member_summary,file.path(out,'badger_year_membership_summary.csv'))
write_csv(transition_summary,file.path(out,'badger_transition_summary.csv'))
write_csv(annual,file.path(out,'annual_transition_diagnostics.csv'))
message('DONE: ', normalizePath(out), '\nNOTE: exploratory posterior polygon overlay; NOT social identity or HMM state probabilities.')
