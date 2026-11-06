# WECS: review-only map for all withheld grid references (2026-11-05)
# Requires existing badger_db_connect() and your BADGER_DB_* .Renviron settings.
# READ ONLY: No updates to Supabase and no changes to accepted coordinates.

packages <- c('DBI', 'RPostgres', 'sf', 'leaflet', 'htmlwidgets', 'htmltools')
missing_pkgs <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs)) install.packages(missing_pkgs)

if (!exists('badger_db_connect', mode = 'function')) {
  badger_db_connect <- function() {
    DBI::dbConnect(
      RPostgres::Postgres(),
      host = Sys.getenv('BADGER_DB_HOST'),
      port = as.integer(Sys.getenv('BADGER_DB_PORT', unset = '5432')),
      dbname = Sys.getenv('BADGER_DB_NAME', unset = 'postgres'),
      user = Sys.getenv('BADGER_DB_USER'),
      password = Sys.getenv('BADGER_DB_PASSWORD'),
      sslmode = 'require'
    )
  }
}

out_dir <- file.path('outputs', 'spatial_location_audit')
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
con <- badger_db_connect()

review <- DBI::dbGetQuery(con, '
select capture_id, tattoo, capture_date, is_pm, encounter_type, outcome,
       original_grid_reference, original_place_description,
       source_easting, source_northing, accepted_easting, accepted_northing,
       decision_status, map_review_status, proposed_review_group,
       test_easting, test_northing, test_warning, decision_note, map_review_note
from analysis.grid_withheld_candidate_review_v1
order by proposed_review_group, capture_id
')
stopifnot(nrow(review) >= 39L)
message('Retrieved ', nrow(review), ' withheld grid cases; ',
        sum(!is.na(review$test_easting) & !is.na(review$test_northing)),
        ' have hypothetical test-only coordinates.')

# A separate review CSV; don't overwrite previous manual decisions.
review$your_decision <- ''
review$your_evidence <- ''
review$reviewer <- ''
review$review_date <- ''
csv_file <- file.path(out_dir, 'remaining_grid_reference_review.csv')
if (!file.exists(csv_file)) {
  write.csv(review, csv_file, row.names = FALSE, na = '')
} else {
  message('Existing review CSV preserved: ', csv_file)
}

html <- function(x) htmltools::htmlEscape(ifelse(is.na(x), '(not recorded)', as.character(x)))
point_data <- function(dat, xcol, ycol) {
  ok <- !is.na(dat[[xcol]]) & !is.na(dat[[ycol]])
  dat <- dat[ok, , drop = FALSE]
  if (!nrow(dat)) return(dat)
  shp <- sf::st_as_sf(dat, coords = c(xcol, ycol), crs = 27700, remove = FALSE)
  lonlat <- sf::st_coordinates(sf::st_transform(shp, 4326))
  dat$lng <- lonlat[,1]
  dat$lat <- lonlat[,2]
  dat
}
originals <- point_data(review, 'source_easting', 'source_northing')
tests <- point_data(review, 'test_easting', 'test_northing')

popup <- function(d, hypothetical = FALSE) {
  val <- function(name) html(d[[name]])
  paste0('<strong>Capture ', val('capture_id'), ' · ', val('tattoo'), '</strong>',
         '<br>Date: ', val('capture_date'),
         '<br>Original OS: ', val('original_grid_reference'),
         '<br>Place: ', val('original_place_description'),
         '<br>Outcome: ', val('outcome'),
         '<br>Review group: ', val('proposed_review_group'),
         '<br>Map review: ', val('map_review_status'),
         '<br><b>', if(hypothetical) 'HYPOTHETICAL POINT: NOT APPROVED' else 'ORIGINAL PARSED POINT: WITHHELD', '</b>',
         '<br>Decision: ', val('decision_note'))
}

m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) |>
  leaflet::addTiles(group = 'OpenStreetMap',
                    urlTemplate = 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    attribution = '&copy; OpenStreetMap contributors')

# No clustering: each marker remains individually clickable.
if (nrow(originals)) {
  m <- m |> leaflet::addCircleMarkers(
    data = originals, lng = ~lng, lat = ~lat,
    radius = 5, weight = 1.5, color = '#a32b28', fillColor = '#e17065', fillOpacity = .8,
    layerId = ~paste0('original_', capture_id),
    label = ~paste0('Original (withheld) ', capture_id, ' · ', tattoo),
    popup = popup(originals), group = 'Original parsed (WITHHELD)')
}
if (nrow(tests)) {
  m <- m |> leaflet::addCircleMarkers(
    data = tests, lng = ~lng, lat = ~lat,
    radius = 7, weight = 2, color = '#145a32', fillColor = '#74d69d', fillOpacity = .9,
    layerId = ~paste0('test_', capture_id),
    label = ~paste0('TEST ONLY ', capture_id, ' · ', tattoo),
    popup = popup(tests, hypothetical = TRUE),
    group = 'Test -100km northing (NOT approved)')
}

# Optional connectors between original erroneous positions and test candidates.
if (nrow(tests)) {
  match_orig <- match(tests$capture_id, originals$capture_id)
  for (i in seq_len(nrow(tests))) {
    j <- match_orig[i]
    if (!is.na(j)) {
      m <- m |> leaflet::addPolylines(
        lng = c(originals$lng[j], tests$lng[i]),
        lat = c(originals$lat[j], tests$lat[i]),
        color = '#a868d1', weight = 1.2, opacity = 0.45,
        group = '100km displacement lines')
    }
  }
}

m <- m |> leaflet::addLayersControl(
  overlayGroups = c('Original parsed (WITHHELD)',
                    'Test -100km northing (NOT approved)',
                    '100km displacement lines'),
  options = leaflet::layersControlOptions(collapsed = FALSE)) |>
  leaflet::hideGroup('Original parsed (WITHHELD)') |>
  leaflet::hideGroup('100km displacement lines') |>
  leaflet::setView(lng = -2.26, lat = 51.70, zoom = 11) |>
  leaflet::addControl(
    html = '<div style="background:white;padding:8px;border:1px solid #bbb;max-width:290px"><strong>WECS — unapproved grid alternatives</strong><br>Green markers = test only. Red markers = rejected original parsed locations. Turn on layers above. No coordinate changes made.</div>',
    position = 'bottomleft')

outfile <- file.path(out_dir, 'remaining_grid_reference_candidates.html')
htmlwidgets::saveWidget(m, outfile, selfcontained = FALSE)
message('Open map: ', normalizePath(outfile, mustWork = TRUE))
message('Review CSV: ', normalizePath(csv_file, mustWork = TRUE))
DBI::dbDisconnect(con)
