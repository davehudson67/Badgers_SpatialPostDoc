# WECS grid-reference mapping and review
# Read-only: no changes are made to Supabase.
# Run in RStudio from any working directory with your BADGER_DB_* environment variables.
# Output: outputs/spatial_location_audit/grid_references_overview.html
#         outputs/spatial_location_audit/grid_references_woodchester.html
#         outputs/spatial_location_audit/grid_reference_review_queue.csv

packages <- c("DBI", "RPostgres", "dplyr", "sf", "leaflet", "htmlwidgets", "htmltools")
missing_packages <- packages[!vapply(packages, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_packages)) {
  stop("Install these packages first: install.packages(c(",
       paste(sprintf('"%s"', missing_packages), collapse = ", "), "))")
}

library(DBI)
library(dplyr)
library(sf)
library(leaflet)

badger_db_connect <- function() {
  DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("BADGER_DB_HOST"),
    port = as.integer(Sys.getenv("BADGER_DB_PORT", unset = "5432")),
    dbname = Sys.getenv("BADGER_DB_NAME", unset = "postgres"),
    user = Sys.getenv("BADGER_DB_USER"),
    password = Sys.getenv("BADGER_DB_PASSWORD"),
    sslmode = "require"
  )
}

out_dir <- file.path("outputs", "spatial_location_audit")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
con <- badger_db_connect()
on.exit_placeholder <- NULL  # Close connection explicitly after reading, including on error.

read_data <- function() {
  # Every grid-referenced row, including ones whose parser could not recover XY.
  # Grid audit values are kept separate from final clean XY.
  grids <- DBI::dbGetQuery(con, "
    SELECT e.capture_id, e.tattoo, e.capture_date, e.is_pm, e.outcome,
           e.location_type, e.location_quality,
           e.location_easting, e.location_northing,
           c.os_ref, c.recorded_sett_name, c.capture_location_text,
           c.moc AS original_moc, c.comment AS original_comment,
           ga.decision_status, ga.decision_note,
           ga.source_easting, ga.source_northing,
           ga.corrected_easting, ga.corrected_northing,
           cl.grid_sw_easting, cl.grid_sw_northing,
           cl.newly_parsed_cell_width_m
    FROM analysis.encounters_clean_v1 e
    JOIN research.captures c USING (capture_id)
    LEFT JOIN analysis.grid_reference_audit_v1 ga USING (capture_id)
    LEFT JOIN analysis.capture_location_v1 cl USING (capture_id)
    WHERE NULLIF(BTRIM(c.os_ref), '') IS NOT NULL
       OR ga.capture_id IS NOT NULL
       OR cl.grid_sw_easting IS NOT NULL
    ORDER BY e.capture_id
  ")

  setts <- DBI::dbGetQuery(con, "
    SELECT sett_id, sett_name, easting, northing
    FROM research.setts
    WHERE easting IS NOT NULL AND northing IS NOT NULL
  ")

  # Only distinct locations, not ~16,000 identical markers over the setts.
  background <- DBI::dbGetQuery(con, "
    SELECT location_easting AS easting, location_northing AS northing,
           COUNT(*) AS encounters
    FROM analysis.encounters_clean_v1
    WHERE location_quality = 'SETT_POINT_PROVISIONAL'
      AND location_easting IS NOT NULL AND location_northing IS NOT NULL
    GROUP BY location_easting, location_northing
  ")
  list(grids = grids, setts = setts, background = background)
}

result <- tryCatch(read_data(), finally = DBI::dbDisconnect(con))
grids <- result$grids
setts <- result$setts
background <- result$background

if (anyDuplicated(grids$capture_id)) {
  stop("Grid SQL returned duplicate capture IDs. Check join cardinality before plotting.")
}
if (!nrow(setts)) stop("No canonical sett coordinates returned.")

# Coordinate columns are BNG metres (EPSG:27700). They must be transformed
# before use with leaflet, which displays longitude/latitude (EPSG:4326).
num <- function(x) suppressWarnings(as.numeric(x))
for (v in c("location_easting", "location_northing", "source_easting",
            "source_northing", "corrected_easting", "corrected_northing",
            "grid_sw_easting", "grid_sw_northing")) grids[[v]] <- num(grids[[v]])
setts$easting <- num(setts$easting)
setts$northing <- num(setts$northing)
background$easting <- num(background$easting)
background$northing <- num(background$northing)

# The primary plotted point is the FINAL analysis coordinate if one is accepted;
# for WITHHELD records, show the ORIGINAL suspect parsed location separately.
# Raw grid values without parsed XY still appear in the review CSV.
grids <- grids %>%
  mutate(
    review_layer = case_when(
      decision_status == "WITHHELD" ~ "WITHHELD (original suspect XY)",
      decision_status == "CORRECTED" ~ "CORRECTED (provisional)",
      !is.na(location_easting) & !is.na(location_northing) ~ "OTHER PARSED GRID",
      TRUE ~ "NO PLOTTABLE XY"
    ),
    plot_easting = if_else(decision_status == "WITHHELD",
                           coalesce(source_easting, grid_sw_easting), location_easting),
    plot_northing = if_else(decision_status == "WITHHELD",
                            coalesce(source_northing, grid_sw_northing), location_northing),
    # This records what we KNOW about precision, not implied survey accuracy.
    grid_precision_note = case_when(
      !is.na(newly_parsed_cell_width_m) ~ paste0("Parsed grid cell: ",
                                                   newly_parsed_cell_width_m, " m"),
      grepl("100M", coalesce(location_quality, "")) ~ "Grid square: nominally 100 m",
      TRUE ~ "Precision not independently verified"
    )
  )

safe <- function(x) htmltools::htmlEscape(ifelse(is.na(x) | !nzchar(as.character(x)),
                                                "—", as.character(x)))
# HTML escaping is essential: original text is untrusted database content.
grids$popup <- vapply(seq_len(nrow(grids)), function(i) {
  g <- grids[i, , drop = FALSE]
  paste0(
    "<strong>Capture ", safe(g$capture_id), " · ", safe(g$tattoo), "</strong><br>",
    "Date: ", safe(g$capture_date), "<br>",
    "Original OS ref: ", safe(g$os_ref), "<br>",
    "Recorded location: ", safe(g$capture_location_text), "<br>",
    "Original sett/name: ", safe(g$recorded_sett_name), "<br>",
    "Method / outcome: ", safe(g$original_moc), " / ", safe(g$outcome), "<br>",
    "Review layer: ", safe(g$review_layer), "<br>",
    "Clean quality: ", safe(g$location_quality), "<br>",
    "Precision: ", safe(g$grid_precision_note), "<br>",
    "Source parsed BNG: ", safe(g$source_easting), ", ", safe(g$source_northing), "<br>",
    "Final BNG: ", safe(g$location_easting), ", ", safe(g$location_northing), "<br>",
    "Decision: ", safe(g$decision_status), "<br>",
    "Audit note: ", safe(g$decision_note), "<br>",
    "Source comment: ", safe(g$original_comment)
  )
}, character(1))

# Only make sf points where both coordinate components exist.
points_sf <- function(df, east, north) {
  df <- df[!is.na(df[[east]]) & !is.na(df[[north]]), , drop = FALSE]
  if (!nrow(df)) return(NULL)
  sf::st_transform(sf::st_as_sf(df, coords = c(east, north), crs = 27700,
                               remove = FALSE), 4326)
}
sett_sf <- points_sf(setts, "easting", "northing")
background_sf <- points_sf(background, "easting", "northing")
plot_sf <- points_sf(grids, "plot_easting", "plot_northing")

# A second marker shows the PRE-CORRECTION location, if independently stored.
old <- grids %>% filter(decision_status == "CORRECTED",
                        !is.na(source_easting), !is.na(source_northing),
                        source_easting != corrected_easting |
                          source_northing != corrected_northing)
old_sf <- points_sf(old, "source_easting", "source_northing")

# Connect shifted original and cleaned locations with a thin line, showing
# systematic 100 km square errors on the overview map.
shift_lines <- NULL
if (nrow(old)) {
  line_geoms <- lapply(seq_len(nrow(old)), function(i) {
    sf::st_linestring(matrix(c(old$source_easting[i], old$source_northing[i],
                               old$corrected_easting[i], old$corrected_northing[i]),
                             ncol = 2, byrow = TRUE))
  })
  shift_lines <- sf::st_transform(
    sf::st_sf(capture_id = old$capture_id,
              geometry = sf::st_sfc(line_geoms, crs = 27700)), 4326)
}

# Create the review CSV ONCE; avoid overwriting your manually entered decisions
# when you rerun the mapping script.
review_csv <- file.path(out_dir, "grid_reference_review_queue.csv")
queue <- grids %>%
  transmute(capture_id, tattoo, capture_date, is_pm, outcome,
            os_ref, recorded_sett_name, capture_location_text,
            original_moc, decision_status, location_quality, review_layer,
            source_easting, source_northing, corrected_easting, corrected_northing,
            analysis_easting = location_easting,
            analysis_northing = location_northing,
            grid_precision_note, decision_note,
            review_decision = "NOT_REVIEWED",
            reviewer_note = "",
            evidence_source = "")
if (!file.exists(review_csv)) {
  utils::write.csv(queue, review_csv, row.names = FALSE, na = "")
} else {
  # Write current extraction separately so previous manual reviews are safe.
  utils::write.csv(queue, file.path(out_dir, "grid_reference_current_snapshot.csv"),
                   row.names = FALSE, na = "")
  message("Existing review queue preserved: ", review_csv)
}

# Small layer factory. Distinct symbols prevent accepted and withheld points
# from being mistaken for the same sort of spatial evidence.
add_point_layer <- function(map, d, name, colour, radius = 5, opacity = 0.9) {
  if (is.null(d) || !nrow(d)) return(map)
  leaflet::addCircleMarkers(map, data = d, group = name,
                            radius = radius, color = colour, fillColor = colour,
                            fillOpacity = opacity, weight = 1,
                            popup = ~popup, label = ~as.character(capture_id),
                            clusterOptions = leaflet::markerClusterOptions(
                              showCoverageOnHover = FALSE))
}

make_map <- function(local = FALSE) {
  m <- leaflet::leaflet(options = leaflet::leafletOptions(preferCanvas = TRUE)) %>%
    leaflet::addProviderTiles("CartoDB.Positron", group = "Simple base map") %>%
    leaflet::addProviderTiles("OpenStreetMap.Mapnik", group = "OpenStreetMap")

  if (!is.null(background_sf)) {
    m <- leaflet::addCircleMarkers(m, data = background_sf,
                                  group = "Accepted sett-point cloud",
                                  radius = 3, color = "#b8b8b8", weight = 0,
                                  fillOpacity = 0.35,
                                  popup = ~paste0(encounters, " records at this coordinate"))
  }
  m <- leaflet::addCircleMarkers(m, data = sett_sf, group = "Canonical setts",
                                radius = 4, color = "#202020", fillColor = "#ffffff",
                                weight = 1.5, fillOpacity = 0.9,
                                popup = ~paste0("Sett: ", htmltools::htmlEscape(sett_name),
                                                "<br>BNG: ", easting, ", ", northing))

  layer_defs <- list(
    list(name = "CORRECTED (provisional)", colour = "#1c9b68", radius = 6),
    list(name = "WITHHELD (original suspect XY)", colour = "#e05a47", radius = 7),
    list(name = "OTHER PARSED GRID", colour = "#326bc0", radius = 4)
  )
  for (def in layer_defs) {
    layer_data <- if (is.null(plot_sf)) NULL else
      plot_sf[plot_sf$review_layer == def$name, , drop = FALSE]
    m <- add_point_layer(m, layer_data, def$name, def$colour, def$radius)
  }

  if (!is.null(old_sf)) {
    m <- leaflet::addCircleMarkers(m, data = old_sf,
                                  group = "Original pre-correction XY",
                                  radius = 5, color = "#9a46ad", weight = 2,
                                  fillOpacity = 0.15, popup = ~popup)
  }
  if (!is.null(shift_lines)) {
    m <- leaflet::addPolylines(m, data = shift_lines,
                              group = "Original-to-corrected shifts",
                              color = "#9a46ad", weight = 1, opacity = 0.45)
  }
  m <- leaflet::addLayersControl(
    m,
    baseGroups = c("Simple base map", "OpenStreetMap"),
    overlayGroups = c("Accepted sett-point cloud", "Canonical setts",
                      "CORRECTED (provisional)",
                      "WITHHELD (original suspect XY)",
                      "OTHER PARSED GRID", "Original pre-correction XY",
                      "Original-to-corrected shifts"),
    options = leaflet::layersControlOptions(collapsed = FALSE)
  )

  if (local) {
    # The site extent is defined by known setts, NOT by suspect grid points.
    b <- sf::st_bbox(sf::st_buffer(sf::st_transform(sett_sf, 27700), 3500))
    corners <- sf::st_transform(
      sf::st_as_sf(data.frame(x = c(b["xmin"], b["xmax"]),
                              y = c(b["ymin"], b["ymax"])),
                   coords = c("x", "y"), crs = 27700), 4326)
    xy <- sf::st_coordinates(corners)
    m <- leaflet::fitBounds(m, min(xy[, 1]), min(xy[, 2]),
                            max(xy[, 1]), max(xy[, 2]))
    m <- leaflet::hideGroup(m, c("Original pre-correction XY",
                                "Original-to-corrected shifts"))
  } else {
    # Full extent includes obvious wrong-square points and their corrected partners.
    candidates <- list(plot_sf, old_sf, sett_sf)
    candidates <- candidates[!vapply(candidates, is.null, logical(1))]
    xy <- do.call(rbind, lapply(candidates, sf::st_coordinates))
    m <- leaflet::fitBounds(m, min(xy[, 1]), min(xy[, 2]),
                            max(xy[, 1]), max(xy[, 2]))
  }
  m
}

full_map <- make_map(local = FALSE)
local_map <- make_map(local = TRUE)
htmlwidgets::saveWidget(full_map, file.path(out_dir, "grid_references_overview.html"),
                        selfcontained = FALSE)
htmlwidgets::saveWidget(local_map, file.path(out_dir, "grid_references_woodchester.html"),
                        selfcontained = FALSE)

cat("\nCompleted WECS grid-reference mapping\n")
cat("Grid-referenced source rows:", nrow(grids), "\n")
print(as.data.frame(table(grids$review_layer)))
cat("Rows without plottable XY:", sum(is.na(grids$plot_easting) |
                                          is.na(grids$plot_northing)), "\n")
cat("Files in:", normalizePath(out_dir), "\n")
cat("NOTE: mapping feasibility alone does not approve any source correction.\n")
