# Woodchester annual social-group boundary audit and animation
# Run from Badgers_SpatialPostDoc project root.
# Dependencies: install.packages(c('sf','dplyr','purrr','tidyr','readr',
#                 'stringr','ggplot2','gifski','tibble'))
# Raw shapefiles are NEVER edited.

suppressPackageStartupMessages({
  library(sf); library(dplyr); library(purrr); library(tidyr)
  library(readr); library(stringr); library(ggplot2)
  library(gifski); library(tibble)
})

input_dir <- 'data/spatial/social_group_boundaries'
out_dir <- 'outputs/social_group_boundary_audit'
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
stopifnot(dir.exists(input_dir))

files <- list.files(input_dir, pattern = '^territories_[0-9]{4}\\.shp$',
                    full.names = TRUE, ignore.case = TRUE)
stopifnot(length(files) > 0)
yr <- as.integer(str_match(basename(files), 'territories_([0-9]{4})\\.shp')[,2])
stopifnot(!anyNA(yr), !anyDuplicated(yr))
files <- files[order(yr)]; years <- sort(yr)
message('Years: ', min(years), '–', max(years), ' (', length(years), ' files)')

# Read and keep an explicit audit of each source's original columns and CRS.
read_year <- function(path) {
  year <- as.integer(str_match(basename(path), 'territories_([0-9]{4})\\.shp')[,2])
  x <- st_read(path, quiet = TRUE, stringsAsFactors = FALSE)
  src_fields <- names(st_drop_geometry(x))
  name_candidates <- c('SocialName','Sett','SETT','Social_grp')
  name_field <- name_candidates[name_candidates %in% src_fields][1]
  if (length(name_field) == 0 || is.na(name_field))
    stop('No recognised territory-name field in ', basename(path),
         '. Fields: ', paste(src_fields, collapse = ', '))
  source_crs <- st_crs(x)
  crs_inferred <- is.na(source_crs)
  if (!crs_inferred && !is.na(source_crs$epsg) && source_crs$epsg != 27700)
    message('Transforming source CRS in ', basename(path), ': ', source_crs$input)
  if (crs_inferred) {
    # Assumes coordinate values use BNG. Confirm against trusted point data.
    bb <- st_bbox(x)
    if (bb[['xmin']] < 10000 || bb[['xmax']] > 700000 ||
        bb[['ymin']] < 0 || bb[['ymax']] > 1300000)
      stop('Missing CRS and implausible British National Grid bounds: ', path)
    st_crs(x) <- 27700
  }
  x <- st_transform(x, 27700)
  raw_name <- as.character(st_drop_geometry(x)[[name_field]])
  name_clean <- str_squish(raw_name)
  name_clean[tolower(name_clean) %in% c('na', 'null', 'unknown', '0')] <- NA_character_
  name_clean[name_clean == ''] <- NA_character_
  conf <- if ('Confidence' %in% src_fields) as.character(x[['Confidence']]) else rep(NA_character_, nrow(x))
  valid_before <- st_is_valid(x)
  valid_before[is.na(valid_before)] <- FALSE
  # Keep one row per source feature. Don't dissolve polygons or silently fix bad names.
  if (any(!valid_before)) x <- st_make_valid(x)
  geometry <- st_geometry(x)
  output <- st_sf(
    year = rep(year, nrow(x)),
    polygon_id = seq_len(nrow(x)),
    territory_name = name_clean,
    name_original = raw_name,
    name_field = rep(name_field, nrow(x)),
    confidence_original = conf,
    crs_inferred = rep(crs_inferred, nrow(x)),
    valid_before = valid_before,
    valid_after = st_is_valid(x),
    source_file = rep(basename(path), nrow(x)),
    source_shape_area_m2 = if ('Shape_Area' %in% src_fields)
      suppressWarnings(as.numeric(x[['Shape_Area']])) else rep(NA_real_, nrow(x)),
    geometry = geometry
  )
  output$area_m2 <- as.numeric(st_area(output))
  output$area_ha <- output$area_m2 / 10000
  audit <- tibble(
    year = year, source_file = basename(path), n_polygons = nrow(x),
    name_field = name_field, source_fields = paste(src_fields, collapse = ', '),
    crs_original = if (crs_inferred) 'MISSING' else source_crs$input,
    crs_inferred = crs_inferred, n_invalid_before = sum(!valid_before),
    n_invalid_after = sum(!st_is_valid(x), na.rm = TRUE),
    n_missing_names = sum(is.na(name_clean)),
    n_distinct_names = n_distinct(name_clean, na.rm = TRUE),
    n_duplicate_name_rows = sum(duplicated(name_clean) & !is.na(name_clean)),
    bbox_xmin = as.numeric(st_bbox(output)[['xmin']]),
    bbox_ymin = as.numeric(st_bbox(output)[['ymin']]),
    bbox_xmax = as.numeric(st_bbox(output)[['xmax']]),
    bbox_ymax = as.numeric(st_bbox(output)[['ymax']])
  )
  list(spatial = output, audit = audit)
}

message('Reading annual layers...')
read_results <- map(files, read_year)
sg <- do.call(rbind, map(read_results, 'spatial'))
file_audit <- bind_rows(map(read_results, 'audit'))
write_csv(file_audit, file.path(out_dir, '01_file_and_field_audit.csv'))
write_csv(tibble(year = seq(min(years),max(years)), present =
                    seq(min(years),max(years)) %in% years),
          file.path(out_dir, '02_year_coverage.csv'))

# Annual polygon summaries. Summed area counts overlapping polygons twice;
# union area does not. This distinction is important.
message('Summarising annual geometries...')
annual <- map_dfr(years, function(y) {
  x <- filter(sg, year == y)
  union_geom <- st_union(st_geometry(x))
  tibble(year = y, n_polygons = nrow(x),
         n_named_territories = n_distinct(x$territory_name, na.rm = TRUE),
         sum_polygon_area_ha = sum(x$area_ha),
         mapped_union_area_ha = as.numeric(st_area(union_geom))/10000,
         overlap_excess_ha = sum(x$area_ha) - as.numeric(st_area(union_geom))/10000,
         min_polygon_area_ha = min(x$area_ha),
         max_polygon_area_ha = max(x$area_ha),
         n_crs_inferred = sum(x$crs_inferred))
})
write_csv(annual, file.path(out_dir, '03_annual_summary.csv'))

# By-year names and polygons. Multiple same-name polygons remain separate.
territory_history <- sg |> st_drop_geometry() |>
  select(year, polygon_id, territory_name, name_original, name_field,
         confidence_original, area_ha, valid_before, valid_after,
         crs_inferred, source_file, source_shape_area_m2) |>
  arrange(year, territory_name)
write_csv(territory_history, file.path(out_dir, '04_territory_polygon_history.csv'))

names_all <- sg |> st_drop_geometry() |> filter(!is.na(territory_name)) |>
  distinct(year, territory_name)
name_summary <- names_all |> group_by(territory_name) |>
  summarise(first_year = min(year), last_year = max(year),
            n_years_mapped = n(), .groups = 'drop') |>
  arrange(first_year, territory_name)
write_csv(name_summary, file.path(out_dir, '05_territory_name_history.csv'))

# Apparent first/last appearances only; not proof of group founding/extinction.
changes <- map_dfr(seq_along(years)[-1], function(i) {
  p <- years[i-1]; y <- years[i]
  pnames <- names_all$territory_name[names_all$year == p]
  ynames <- names_all$territory_name[names_all$year == y]
  tibble(year_from = p, year_to = y,
         interval_years = y-p,
         appeared = paste(setdiff(ynames,pnames), collapse = ' | '),
         disappeared = paste(setdiff(pnames,ynames), collapse = ' | '),
         n_appeared = length(setdiff(ynames,pnames)),
         n_disappeared = length(setdiff(pnames,ynames)))
})
write_csv(changes, file.path(out_dir, '06_name_appearances_disappearances.csv'))

# Consecutive-year named territory transitions: intersections are area-based.
# For the same named territory across years, compare overlap and area changes.
# A geometry with no intersection produces 0, not NA.
message('Measuring annual boundary persistence...')
transition <- map_dfr(seq_along(years)[-1], function(i) {
  y0 <- years[i-1]; y1 <- years[i]
  a <- filter(sg, year == y0, !is.na(territory_name)) |>
    group_by(territory_name) |> summarise(.groups = 'drop')
  b <- filter(sg, year == y1, !is.na(territory_name)) |>
    group_by(territory_name) |> summarise(.groups = 'drop')
  common <- intersect(a$territory_name, b$territory_name)
  map_dfr(common, function(nm) {
    ga <- st_geometry(a[a$territory_name == nm, ])
    gb <- st_geometry(b[b$territory_name == nm, ])
    area0 <- as.numeric(st_area(ga)); area1 <- as.numeric(st_area(gb))
    intersect <- suppressWarnings(st_intersection(ga, gb))
    overlap <- if (length(intersect) == 0) 0 else sum(as.numeric(st_area(intersect)))
    tibble(year_from = y0, year_to = y1, territory_name = nm,
           area_from_ha = area0/10000, area_to_ha = area1/10000,
           change_ha = (area1-area0)/10000,
           intersection_ha = overlap/10000,
           retained_fraction_from = if (area0 > 0) overlap/area0 else NA_real_,
           jaccard_overlap = if (area0+area1-overlap > 0)
             overlap/(area0+area1-overlap) else NA_real_)
  })
})
write_csv(transition, file.path(out_dir, '07_same_name_boundary_changes.csv'))

# Important: Save combined layer with original audit data preserved.
st_write(sg, file.path(out_dir, 'annual_territories.gpkg'),
         layer = 'annual_territories', delete_dsn = TRUE, quiet = TRUE)

# Flags to investigate, not automatically classified errors.
flags <- sg |> st_drop_geometry() |>
  filter(is.na(territory_name) | !valid_before |
           (!is.na(source_shape_area_m2) &
            abs(source_shape_area_m2 - area_m2) > pmax(1,area_m2 * 0.01))) |>
  select(year, polygon_id, territory_name, name_original, valid_before,
         area_m2, source_shape_area_m2)
write_csv(flags, file.path(out_dir, '08_polygon_review_flags.csv'))

# Large overlaps are not invalid geometries but can make group assignment
# ambiguous. Flag their magnitude independently of the validity audit.
overlap_audit <- annual |>
  mutate(overlap_excess_fraction_of_summed_area =
           if_else(sum_polygon_area_ha > 0,
                   overlap_excess_ha / sum_polygon_area_ha, NA_real_),
         review_overlap = overlap_excess_fraction_of_summed_area > 0.10)
write_csv(overlap_audit,
          file.path(out_dir, '09_annual_overlap_review.csv'))
message('Years with overlap excess >10% of summed area: ',
        paste(overlap_audit$year[overlap_audit$review_overlap], collapse = ', '))

p_count <- ggplot(annual, aes(year, n_polygons)) +
  geom_line() + geom_point() +
  labs(title = 'Mapped Woodchester territory polygons', x = 'Year', y = 'Polygon count') +
  theme_minimal(base_size = 13)
ggsave(file.path(out_dir, 'annual_polygon_counts.png'), p_count,
       width = 9, height = 5, dpi = 220)

p_area <- ggplot(annual, aes(year, mapped_union_area_ha)) +
  geom_line() + geom_point() +
  labs(title = 'Total mapped extent (union of polygons)', x = 'Year', y = 'Area (ha)') +
  theme_minimal(base_size = 13)
ggsave(file.path(out_dir, 'annual_mapped_extent.png'), p_area,
       width = 9, height = 5, dpi = 220)

# GIF: keep exactly one map frame for every observed year. No morphing or
# interpolation between annual snapshots. Static geographic limits and named
# territory colour mapping over the entire period.
message('Rendering discrete-year GIF...')
bb <- st_bbox(sg)
xl <- as.numeric(bb[c('xmin','xmax')]); yl <- as.numeric(bb[c('ymin','ymax')])
xpad <- max(100, diff(xl)*0.04); ypad <- max(100, diff(yl)*0.04)
sg_anim <- sg |>
  mutate(territory_name = if_else(is.na(territory_name), 'UNNAMED', territory_name),
         territory_name = factor(territory_name,
           levels = sort(unique(c(sg$territory_name[!is.na(sg$territory_name)], 'UNNAMED')))))
# Render each year as a standard static ggplot with an explicit subtitle.
# This avoids gganimate's frame-label interpolation (which returned NA on
# the HPC server even while polygon frames rendered correctly).
frame_dir <- file.path(out_dir, '_gif_frames')
dir.create(frame_dir, recursive = TRUE, showWarnings = FALSE)
frame_paths <- file.path(frame_dir, sprintf('territories_%04d.png', years))

for (i in seq_along(years)) {
  this_year <- years[[i]]
  this_map <- sg_anim[sg_anim$year == this_year, , drop = FALSE]
  p_frame <- ggplot(this_map) +
    geom_sf(aes(fill = territory_name), colour = 'grey25', linewidth = 0.28,
            show.legend = FALSE) +
    coord_sf(xlim = xl + c(-xpad, xpad),
             ylim = yl + c(-ypad, ypad), expand = FALSE) +
    scale_fill_hue(na.value = 'grey80', drop = FALSE) +
    labs(title = 'Woodchester: mapped social-group territories',
         subtitle = paste0('Year: ', this_year,
                           '  •  annual mapped boundaries (not interpolated)'),
         caption = 'Names as recorded in source shapefiles; boundaries are annual snapshots') +
    theme_minimal(base_size = 14) +
    theme(axis.title = element_blank(), axis.text = element_blank(),
          panel.grid.major = element_blank())
  ggsave(filename = frame_paths[[i]], plot = p_frame,
         width = 11, height = 7.8, units = 'in', dpi = 100,
         bg = 'white')
}

# Ensure every frame was created and has nonzero size before encoding.
stopifnot(all(file.exists(frame_paths)), all(file.info(frame_paths)$size > 0))
gif_path <- file.path(out_dir, 'social_group_boundaries_1977_2025.gif')
gifski::gifski(png_files = frame_paths, gif_file = gif_path,
               width = 1100, height = 780, delay = 0.5, loop = TRUE)
message('GIF created with literal year labels: ', gif_path)
# Keep PNG frames for troubleshooting; safe to remove _gif_frames once checked.

# Final-year static map for quick review.
p_final <- ggplot(filter(sg_anim, year == max(years))) +
  geom_sf(aes(fill = territory_name), colour = 'grey25', linewidth = 0.35,
          show.legend = FALSE) +
  coord_sf(xlim = xl + c(-xpad,xpad), ylim = yl + c(-ypad,ypad), expand = FALSE) +
  labs(title = paste('Mapped Woodchester territories:', max(years))) +
  theme_minimal()
ggsave(file.path(out_dir, 'latest_territory_map.png'), p_final,
       width = 9, height = 7, dpi = 220)

message('\nDONE: ', normalizePath(out_dir),
        '\nReview 01_file_and_field_audit.csv, 03_annual_summary.csv,',
        '\n08_polygon_review_flags.csv and the GIF before modelling.')
