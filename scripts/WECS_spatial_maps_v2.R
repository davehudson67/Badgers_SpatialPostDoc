# WECS spatial grid-reference audit — complete read-only mapping script
# Outputs: two interactive HTML maps, one static PNG and a CSV review table.
# Uses the BADGER_DB_* variables already present in your .Renviron.

pkgs <- c('DBI','RPostgres','dplyr','sf','leaflet','htmlwidgets','htmltools','ggplot2')
missing <- pkgs[!vapply(pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing)) stop('Install packages first: install.packages(c(',
                          paste(shQuote(missing), collapse = ', '), '))')

badger_db_connect <- function() {
  DBI::dbConnect(RPostgres::Postgres(),
    host = Sys.getenv('BADGER_DB_HOST'),
    port = as.integer(Sys.getenv('BADGER_DB_PORT', unset = '5432')),
    dbname = Sys.getenv('BADGER_DB_NAME', unset = 'postgres'),
    user = Sys.getenv('BADGER_DB_USER'),
    password = Sys.getenv('BADGER_DB_PASSWORD'),
    sslmode = 'require')
}

out <- file.path('outputs', 'spatial_location_audit')
dir.create(out, recursive = TRUE, showWarnings = FALSE)
con <- badger_db_connect()
data <- tryCatch({
  list(
    grids = DBI::dbGetQuery(con, "
      SELECT e.capture_id, e.tattoo, e.capture_date, e.is_pm, e.outcome,
             c.os_ref, c.capture_location_text, c.recorded_sett_name,
             e.location_quality, e.location_easting, e.location_northing,
             g.decision_status, g.decision_note,
             g.source_easting, g.source_northing,
             g.corrected_easting, g.corrected_northing,
             cl.grid_sw_easting, cl.grid_sw_northing
      FROM analysis.encounters_clean_v1 e
      JOIN research.captures c USING (capture_id)
      LEFT JOIN research.capture_grid_coordinate_decisions g USING (capture_id)
      LEFT JOIN analysis.capture_location_v1 cl USING (capture_id)
      WHERE NULLIF(BTRIM(c.os_ref), '') IS NOT NULL
         OR g.capture_id IS NOT NULL
         OR cl.grid_sw_easting IS NOT NULL
      ORDER BY e.capture_id"),
    setts = DBI::dbGetQuery(con, "
      SELECT sett_id, sett_name, easting, northing
      FROM research.setts
      WHERE easting IS NOT NULL AND northing IS NOT NULL"),
    cloud = DBI::dbGetQuery(con, "
      SELECT location_easting AS easting, location_northing AS northing,
             COUNT(*) AS n
      FROM analysis.encounters_clean_v1
      WHERE location_quality='SETT_POINT_PROVISIONAL'
        AND location_easting IS NOT NULL AND location_northing IS NOT NULL
      GROUP BY 1,2")
  )
}, finally = DBI::dbDisconnect(con))

g <- data$grids; s <- data$setts; cloud <- data$cloud
stopifnot(!anyDuplicated(g$capture_id), nrow(s) > 0)
for (nm in c('location_easting','location_northing','source_easting',
             'source_northing','corrected_easting','corrected_northing',
             'grid_sw_easting','grid_sw_northing'))
  g[[nm]] <- suppressWarnings(as.numeric(g[[nm]]))
for (nm in c('easting','northing')) {
  s[[nm]] <- as.numeric(s[[nm]])
  cloud[[nm]] <- as.numeric(cloud[[nm]])
}

g <- dplyr::mutate(g,
  status = dplyr::case_when(
    decision_status == 'CORRECTED' ~ 'Corrected provisional',
    decision_status == 'WITHHELD' ~ 'Withheld original',
    !is.na(location_easting) & !is.na(location_northing) ~ 'Other grid reference',
    TRUE ~ 'No usable coordinate'),
  map_e = dplyr::if_else(decision_status == 'WITHHELD',
           dplyr::coalesce(source_easting, grid_sw_easting), location_easting),
  map_n = dplyr::if_else(decision_status == 'WITHHELD',
           dplyr::coalesce(source_northing, grid_sw_northing), location_northing)
)

# Preserve any previously completed manual review CSV.
review_path <- file.path(out, 'grid_reference_review_queue.csv')
review <- dplyr::mutate(g, review_status = 'NOT_REVIEWED',
                         reviewer_note = '', approved_by = '')
if (!file.exists(review_path)) {
  write.csv(review, review_path, row.names = FALSE, na = '')
} else {
  write.csv(review, file.path(out, 'grid_reference_latest_snapshot.csv'),
            row.names = FALSE, na = '')
  message('Existing manual review CSV preserved.')
}

# British National Grid metres (EPSG:27700) -> longitude/latitude for Leaflet.
to_sf <- function(df, east, north) {
  df <- df[is.finite(df[[east]]) & is.finite(df[[north]]), , drop = FALSE]
  if (!nrow(df)) return(NULL)
  sf::st_transform(sf::st_as_sf(df, coords = c(east, north),
                                crs = 27700, remove = FALSE), 4326)
}
pts <- to_sf(g, 'map_e', 'map_n')
setts <- to_sf(s, 'easting', 'northing')
settcloud <- to_sf(cloud, 'easting', 'northing')

# HTML-escape imported field text before putting it into popups.
escape <- function(x) htmltools::htmlEscape(ifelse(is.na(x), '', as.character(x)))
g$popup <- paste0(
  '<b>Capture ', escape(g$capture_id), ' · ', escape(g$tattoo), '</b><br>',
  'Date: ', escape(g$capture_date), '<br>',
  'Original OS: ', escape(g$os_ref), '<br>',
  'Recorded location: ', escape(g$capture_location_text), '<br>',
  'Named sett: ', escape(g$recorded_sett_name), '<br>',
  'Outcome: ', escape(g$outcome), '<br>',
  'Status: ', escape(g$status), '<br>',
  'Quality: ', escape(g$location_quality), '<br>',
  'Source XY: ', escape(g$source_easting), ', ', escape(g$source_northing), '<br>',
  'Clean XY: ', escape(g$location_easting), ', ', escape(g$location_northing), '<br>',
  'Decision note: ', escape(g$decision_note))
if (!is.null(pts)) pts$popup <- g$popup[match(pts$capture_id, g$capture_id)]

# Spatial shift lines are only for the OVERVIEW; they make 100-km errors visible.
shift <- dplyr::filter(g, decision_status == 'CORRECTED',
              is.finite(source_easting), is.finite(source_northing),
              is.finite(corrected_easting), is.finite(corrected_northing),
              source_easting != corrected_easting |
              source_northing != corrected_northing)
old <- to_sf(shift, 'source_easting', 'source_northing')
if (!is.null(old)) old$popup <- shift$popup
lines <- NULL
if (nrow(shift)) {
  geoms <- lapply(seq_len(nrow(shift)), function(i) {
    sf::st_linestring(matrix(c(shift$source_easting[i], shift$source_northing[i],
                                 shift$corrected_easting[i], shift$corrected_northing[i]),
                               ncol = 2, byrow = TRUE))
  })
  lines <- sf::st_transform(sf::st_sf(geometry = sf::st_sfc(geoms, crs = 27700)), 4326)
}

add_group <- function(m, status, colour, radius) {
  x <- if (is.null(pts)) NULL else pts[pts$status == status, , drop = FALSE]
  if (is.null(x) || !nrow(x)) return(m)
  leaflet::addCircleMarkers(m, data = x, group = status,
    color = colour, fillColor = colour, radius = radius,
    weight = 1, fillOpacity = 0.8, popup = ~popup,
    clusterOptions = leaflet::markerClusterOptions(showCoverageOnHover = FALSE))
}

make_map <- function(local = FALSE) {
  # Explicit OpenStreetMap tiles, no CartoDB provider and no API key.
  m <- leaflet::leaflet() |>
    leaflet::addTiles('https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      group = 'OpenStreetMap',
      attribution = '&copy; OpenStreetMap contributors')
  if (!is.null(settcloud)) m <- leaflet::addCircleMarkers(m, data = settcloud,
    group = 'Existing capture locations', radius = 2.5,
    stroke = FALSE, fillColor = '#aaaaaa', fillOpacity = 0.25,
    popup = ~paste0(n, ' source captures at this point'))
  m <- leaflet::addCircleMarkers(m, data = setts,
    group = 'Known setts', radius = 4, color = '#111111',
    fillColor = '#ffffff', fillOpacity = 0.9,
    popup = ~paste0('Sett: ', escape(sett_name)))
  m <- add_group(m, 'Corrected provisional', '#239769', 6)
  m <- add_group(m, 'Withheld original', '#e04e43', 7)
  m <- add_group(m, 'Other grid reference', '#336bc2', 4)
  if (!local && !is.null(old)) {
    m <- leaflet::addCircleMarkers(m, data = old,
      group = 'Original before correction', radius = 4,
      color = '#9944aa', fillOpacity = 0.2, popup = ~popup)
  }
  if (!local && !is.null(lines)) m <- leaflet::addPolylines(m,
    data = lines, group = '100-km correction lines', color = '#9944aa',
    opacity = 0.4, weight = 1)
  overlays <- c('Existing capture locations', 'Known setts',
                'Corrected provisional', 'Withheld original', 'Other grid reference')
  if (!local) overlays <- c(overlays, 'Original before correction',
                            '100-km correction lines')
  m <- leaflet::addLayersControl(m, baseGroups = 'OpenStreetMap',
    overlayGroups = overlays, options = leaflet::layersControlOptions(collapsed = FALSE))
  if (local) {
    bb <- sf::st_bbox(sf::st_buffer(sf::st_transform(setts, 27700), 3500))
    corners <- sf::st_as_sf(data.frame(x = c(bb[['xmin']], bb[['xmax']]),
                                       y = c(bb[['ymin']], bb[['ymax']])),
                            coords = c('x','y'), crs = 27700)
    xy <- sf::st_coordinates(sf::st_transform(corners, 4326))
  } else {
    pieces <- Filter(Negate(is.null), list(pts, old, setts))
    xy <- do.call(rbind, lapply(pieces, sf::st_coordinates))
  }
  leaflet::fitBounds(m, min(xy[, 1]), min(xy[, 2]), max(xy[, 1]), max(xy[, 2]))
}

full <- make_map(FALSE)
local <- make_map(TRUE)
htmlwidgets::saveWidget(full, file.path(out, 'grid_references_overview.html'), selfcontained = FALSE)
htmlwidgets::saveWidget(local, file.path(out, 'grid_references_woodchester.html'), selfcontained = FALSE)

# Static fallback: draws without ANY internet map tiles or browser network access.
# A plot of spatial records with British National Grid metres on its axes.
static <- dplyr::filter(g, is.finite(map_e), is.finite(map_n),
                         map_e > 365000, map_e < 400000,
                         map_n > 185000, map_n < 220000)
fig <- ggplot2::ggplot() +
  ggplot2::geom_point(data = cloud,
    ggplot2::aes(easting, northing), color = 'grey80', size = 0.5) +
  ggplot2::geom_point(data = s,
    ggplot2::aes(easting, northing), shape = 3, size = 1, color = 'grey30') +
  ggplot2::geom_point(data = static,
    ggplot2::aes(map_e, map_n, colour = status), size = 1.5, alpha = 0.8) +
  ggplot2::coord_equal() +
  ggplot2::theme_minimal() +
  ggplot2::labs(title = 'WECS grid reference audit (local area)',
    subtitle = 'Static fallback — no map service/API key required',
    x = 'BNG Easting (m)', y = 'BNG Northing (m)', colour = 'Grid status')
ggplot2::ggsave(file.path(out, 'grid_references_static.png'),
                fig, width = 12, height = 9, dpi = 160)

cat('\nFinished. Files saved under:', normalizePath(out), '\n')
cat('Grid records:', nrow(g), '\n')
print(table(g$status, useNA = 'ifany'))
cat('If HTML maps lack background tiles, open grid_references_static.png.\n')
cat('No database records were modified.\n')
