#!/usr/bin/env Rscript
# =============================================================================
# WOODCHESTER - V11R2 DYNAMIC SOCIAL-GROUP / TERRITORY OVERLAY
#
# PURPOSE
# Combine the frozen V11R2 geographic movement engine with independent,
# year-specific territory geometry and capture-derived annual resident groups.
#
# CENTRAL MOVEMENT ENGINE
#   V11R2 resident mean = 50 m
#
# PRIMARY MOVEMENT SENSITIVITY
#   V11R2 resident mean = 25 m
#
# IMPORTANT INTERPRETATION
# - V11R2 relocation state is geographic movement, not social-group identity.
# - Territory polygons are annual spatial boundaries, not automatically verified
#   social-group IDs.
# - Capture-level SOCG / derived annual resident group is separate evidence.
# - No raw polygon name is rewritten to a canonical social-group name here.
# - Formatting-only territory keys remove case/punctuation/spacing for comparison.
# - PM recovery locations are NOT used in this overlay.
#
# For transition t -> t+1, each posterior draw evaluates:
#   G_t(A_t)
#   G_t(A_{t+1})
#   G_{t+1}(A_t)
#   G_{t+1}(A_{t+1})
#
# This distinguishes stable-boundary crossing from apparent reassignment caused
# by changing annual territory boundaries.
#
# ENVIRONMENT
#   MAX_BADGERS       default 1932
#   DRAWS_PER_CHAIN   default 25
#   CENTRAL_STEM      default V11R2 50 m stem
#   SENSITIVITY_STEM  default V11R2 25 m stem
#   TERRITORIES_FILE  default annual audited territory GeoPackage
#   RESIDENT_FILE     default Vicente annual resident-group CSV
#   PROSPECTING_FILE  optional prospecting-pathway CSV
#   OUTPUT_DIR        default outputs/V11R2_dynamic_social_group_overlay
#
# OUTPUTS
#   00_run_metadata.csv
#   01_movement_state_sensitivity.csv
#   02_posterior_annual_territory_draws.csv
#   03_badger_year_territory_summary.csv
#   04_posterior_transition_territory_draws.csv
#   05_transition_territory_summary.csv
#   06_master_movement_social_transition_table.csv
#   07_annual_overlay_diagnostics.csv
#   08_interpretive_class_summary.csv
#   V11R2_dynamic_social_group_overlay.rds
# =============================================================================

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(stringr)
  library(purrr)
  library(tibble)
})

MAX_BADGERS <- as.integer(Sys.getenv("MAX_BADGERS", unset = "1932"))
DRAWS_PER_CHAIN <- as.integer(Sys.getenv("DRAWS_PER_CHAIN", unset = "25"))

CENTRAL_STEM <- Sys.getenv(
  "CENTRAL_STEM",
  unset = "V11R2_RES50_RD_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE"
)
SENSITIVITY_STEM <- Sys.getenv(
  "SENSITIVITY_STEM",
  unset = "V11R2_RES25_RD_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE"
)

TERRITORIES_FILE <- Sys.getenv(
  "TERRITORIES_FILE",
  unset = "outputs/social_group_boundary_audit/annual_territories.gpkg"
)
RESIDENT_FILE <- Sys.getenv(
  "RESIDENT_FILE",
  unset = "results/annual_resident_social_group_vicente.csv"
)
PROSPECTING_FILE <- Sys.getenv(
  "PROSPECTING_FILE",
  unset = "results/prospecting_pathway_badger_years.csv"
)
OUTPUT_DIR <- Sys.getenv(
  "OUTPUT_DIR",
  unset = "outputs/V11R2_dynamic_social_group_overlay"
)

if (!is.finite(MAX_BADGERS) || MAX_BADGERS < 1L) {
  stop("MAX_BADGERS must be a positive integer.")
}
if (!is.finite(DRAWS_PER_CHAIN) || DRAWS_PER_CHAIN < 1L) {
  stop("DRAWS_PER_CHAIN must be a positive integer.")
}

dir.create(OUTPUT_DIR, recursive = TRUE, showWarnings = FALSE)

cat("\n============================================================\n")
cat("V11R2 DYNAMIC SOCIAL-GROUP / TERRITORY OVERLAY\n")
cat("============================================================\n")
cat("MAX_BADGERS:", MAX_BADGERS, "\n")
cat("Posterior AC draws per chain:", DRAWS_PER_CHAIN, "\n")
cat("Central movement stem:", CENTRAL_STEM, "\n")
cat("Sensitivity stem:", SENSITIVITY_STEM, "\n")
cat("Territory file:", TERRITORIES_FILE, "\n")
cat("Resident-group file:", RESIDENT_FILE, "\n")
cat("Output:", OUTPUT_DIR, "\n\n")

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

territory_key <- function(x) {
  z <- toupper(str_squish(as.character(x)))
  z <- str_replace_all(z, "[^A-Z0-9]", "")
  z[is.na(x) | z == ""] <- NA_character_
  z
}

group_clean <- function(x) {
  z <- toupper(str_squish(as.character(x)))
  z[z %in% c("", "NA", "N/A", "UNKNOWN", "UNK", "NOT KNOWN")] <- NA_character_
  z
}

is_unambiguous_territory <- function(x) {
  !is.na(x) &
    !x %in% c("OUTSIDE", "NO_MAP") &
    !str_detect(x, fixed("|"))
}

mode_and_probability <- function(x) {
  if (!length(x)) {
    return(list(mode = NA_character_, p = NA_real_))
  }
  x <- as.character(x)
  x[is.na(x)] <- "NA"
  tab <- sort(table(x), decreasing = TRUE)
  top <- names(tab)[tab == max(tab)]
  # deterministic tie representation rather than arbitrarily choosing one
  list(
    mode = paste(sort(top), collapse = " | "),
    p = as.numeric(max(tab) / length(x))
  )
}

even_draws <- function(n, want) {
  want <- min(n, want)
  if (want < 1L) return(integer())
  unique(as.integer(round(seq(1, n, length.out = want))))
}

read_states <- function(stem) {
  files <- file.path(
    "results",
    sprintf("%s_%d_CHAIN%d_STATES.rds", stem, MAX_BADGERS, 1:3)
  )
  if (!all(file.exists(files))) {
    stop(
      "Missing recovered-state file(s) for ", stem, ":\n",
      paste(files[!file.exists(files)], collapse = "\n")
    )
  }

  s <- lapply(files, readRDS)
  base <- as_tibble(s[[1]]$disp_index) %>%
    select(model_i, individual_id, tattoo, state_k, from_year, to_year)

  for (cc in 2:3) {
    z <- as_tibble(s[[cc]]$disp_index) %>%
      select(model_i, individual_id, tattoo, state_k, from_year, to_year)
    if (!identical(as.data.frame(base), as.data.frame(z))) {
      stop("Transition index differs among chains for ", stem, ".")
    }
  }

  P <- do.call(
    cbind,
    lapply(s, function(z) as.numeric(z$p_high_smoothed_chain))
  )

  if (nrow(P) != nrow(base)) {
    stop("State probability/index length mismatch for ", stem, ".")
  }

  base %>%
    mutate(
      p_relocation = rowMeans(P),
      relocation_chain_range = apply(P, 1, function(z) max(z) - min(z))
    )
}

# -----------------------------------------------------------------------------
# Movement-state probabilities: central 50 m + 25 m sensitivity
# -----------------------------------------------------------------------------

cat("Reading recovered V11R2 movement states...\n")
state50 <- read_states(CENTRAL_STEM) %>%
  rename(
    p_relocation_50 = p_relocation,
    relocation_chain_range_50 = relocation_chain_range
  )

state25 <- read_states(SENSITIVITY_STEM) %>%
  select(tattoo, from_year, to_year, p_relocation, relocation_chain_range) %>%
  rename(
    p_relocation_25 = p_relocation,
    relocation_chain_range_25 = relocation_chain_range
  )

movement_state <- state50 %>%
  left_join(
    state25,
    by = c("tattoo", "from_year", "to_year"),
    relationship = "one-to-one"
  ) %>%
  mutate(
    relocation_absdiff_25_50 = abs(p_relocation_50 - p_relocation_25),
    relocation_class_50 = p_relocation_50 >= 0.5,
    relocation_class_25 = p_relocation_25 >= 0.5,
    relocation_robustness = case_when(
      relocation_class_50 & relocation_class_25 ~ "ROBUST_RELOCATION",
      !relocation_class_50 & !relocation_class_25 ~ "ROBUST_RESIDENT",
      TRUE ~ "25_50_CLASSIFICATION_SWITCH"
    )
  )

if (anyNA(movement_state$p_relocation_25)) {
  stop("Could not align 25 m and 50 m transition-state probabilities.")
}

write_csv(
  movement_state,
  file.path(OUTPUT_DIR, "01_movement_state_sensitivity.csv")
)

cat(
  "Movement intervals:", nrow(movement_state),
  "| 25/50 classification switches:",
  sum(movement_state$relocation_robustness == "25_50_CLASSIFICATION_SWITCH"),
  "\n"
)

# -----------------------------------------------------------------------------
# Annual territory maps
# -----------------------------------------------------------------------------

if (!file.exists(TERRITORIES_FILE)) {
  stop(
    "Missing audited annual territory GeoPackage: ", TERRITORIES_FILE,
    "\nRun scripts/Spatial/01_audit_social_group_boundaries.R first."
  )
}

cat("Reading audited annual territory polygons...\n")
terr_raw <- st_read(TERRITORIES_FILE, quiet = TRUE)

need_terr <- c("year", "territory_name")
if (!all(need_terr %in% names(terr_raw))) {
  stop(
    "Territory GeoPackage missing: ",
    paste(setdiff(need_terr, names(terr_raw)), collapse = ", ")
  )
}
if (is.na(st_crs(terr_raw))) stop("Annual territory GeoPackage has no CRS.")

terr <- terr_raw %>%
  st_transform(27700) %>%
  mutate(
    year = as.integer(year),
    territory_name = as.character(territory_name),
    territory_key = territory_key(territory_name)
  ) %>%
  filter(!is.na(year), !is.na(territory_key))

# Formatting-only identity: same key may include disconnected pieces or source
# spelling/punctuation variants. Keep all original labels as provenance.
terr <- terr %>%
  group_by(year, territory_key) %>%
  summarise(
    territory_labels = paste(sort(unique(territory_name)), collapse = " | "),
    .groups = "drop"
  )

if (any(!st_is_valid(terr))) stop("Invalid annual territory geometry after dissolve.")

terr_by_year <- split(terr, as.character(terr$year))

assign_points <- function(df, map_year) {
  if (!nrow(df)) {
    return(tibble(
      territory_key_set = character(),
      territory_label_set = character()
    ))
  }

  out_key <- rep("NO_MAP", nrow(df))
  out_lab <- rep("NO_MAP", nrow(df))

  for (yr in unique(map_year)) {
    ii <- which(map_year == yr)
    tt <- terr_by_year[[as.character(yr)]]
    if (is.null(tt) || !nrow(tt)) next

    pts <- st_as_sf(
      df[ii, , drop = FALSE],
      coords = c("x", "y"),
      crs = 27700,
      remove = FALSE
    )
    hits <- st_intersects(pts, tt)

    out_key[ii] <- vapply(
      hits,
      function(k) {
        if (!length(k)) "OUTSIDE"
        else paste(sort(unique(tt$territory_key[k])), collapse = "|")
      },
      character(1)
    )

    out_lab[ii] <- vapply(
      hits,
      function(k) {
        if (!length(k)) "OUTSIDE"
        else paste(sort(unique(tt$territory_labels[k])), collapse = " | ")
      },
      character(1)
    )
  }

  tibble(
    territory_key_set = out_key,
    territory_label_set = out_lab
  )
}

# -----------------------------------------------------------------------------
# Posterior annual AC overlay from central V11R2-50 fit
# -----------------------------------------------------------------------------

fit_files <- file.path(
  "results",
  sprintf("%s_%d_CHAIN%d.rds", CENTRAL_STEM, MAX_BADGERS, 1:3)
)

if (!all(file.exists(fit_files))) {
  stop(
    "Missing central V11R2 fit file(s):\n",
    paste(fit_files[!file.exists(fit_files)], collapse = "\n")
  )
}

set.seed(20261025)
all_members <- vector("list", 3)
all_transitions <- vector("list", 3)

for (chain in 1:3) {
  cat("Central 50 m chain", chain, "...\n")
  fit <- readRDS(fit_files[chain])

  if (!identical(
    fit$model,
    "V11R2_RD_SCR_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE_COLLAPSED_HMM"
  )) {
    stop("Unexpected model ID in ", fit_files[chain], ": ", fit$model)
  }

  idx <- as_tibble(fit$annual_state_index)
  needed_idx <- c(
    "annual_active_index", "model_i", "individual_id", "tattoo", "year",
    "sample_column_x", "sample_column_y"
  )
  if (!all(needed_idx %in% names(idx))) {
    stop(
      "Central fit annual_state_index missing: ",
      paste(setdiff(needed_idx, names(idx)), collapse = ", ")
    )
  }
  if (anyDuplicated(idx$annual_active_index)) {
    stop("Duplicate annual_active_index in chain ", chain, ".")
  }

  mm <- as.matrix(fit$samples)
  ac_cols <- c(idx$sample_column_x, idx$sample_column_y)
  if (!all(ac_cols %in% colnames(mm))) {
    stop("Central fit missing indexed annual AC monitors in chain ", chain, ".")
  }

  take <- even_draws(nrow(mm), DRAWS_PER_CHAIN)
  cat("  posterior AC draws selected:", length(take), "of", nrow(mm), "\n")

  mem_chain <- vector("list", length(take))
  tr_chain <- vector("list", length(take))

  for (jj in seq_along(take)) {
    if (jj == 1L || jj %% 5L == 0L || jj == length(take)) {
      cat("  draw", jj, "/", length(take), "\n")
    }

    rr <- take[jj]

    d <- idx %>%
      transmute(
        model_i = as.integer(model_i),
        individual_id = as.integer(individual_id),
        tattoo = toupper(trimws(as.character(tattoo))),
        year = as.integer(year),
        x = as.numeric(mm[rr, sample_column_x]),
        y = as.numeric(mm[rr, sample_column_y])
      )

    if (!all(is.finite(d$x) & is.finite(d$y))) {
      stop("Non-finite annual AC coordinate in chain ", chain, " draw ", jj, ".")
    }

    current_assignment <- assign_points(d, d$year)

    d <- bind_cols(d, current_assignment) %>%
      rename(
        territory_key_current = territory_key_set,
        territory_label_current = territory_label_set
      ) %>%
      mutate(
        chain = chain,
        draw_in_chain = jj,
        posterior_row = rr
      )

    mem_chain[[jj]] <- d %>%
      select(
        chain, draw_in_chain, posterior_row,
        model_i, individual_id, tattoo, year,
        x, y,
        territory_key_current, territory_label_current
      )

    tr <- d %>%
      arrange(tattoo, year) %>%
      group_by(tattoo) %>%
      mutate(
        year_to = lead(year),
        x_to = lead(x),
        y_to = lead(y),
        territory_key_destination = lead(territory_key_current),
        territory_label_destination = lead(territory_label_current)
      ) %>%
      ungroup() %>%
      filter(!is.na(year_to), year_to == year + 1L)

    if (!nrow(tr)) {
      tr_chain[[jj]] <- tibble()
      next
    }

    # G_{t+1}(A_t)
    origin_next <- assign_points(
      tr %>% transmute(x = x, y = y),
      tr$year_to
    )

    # G_t(A_{t+1})
    destination_previous <- assign_points(
      tr %>% transmute(x = x_to, y = y_to),
      tr$year
    )

    tr <- tr %>%
      mutate(
        territory_key_origin = territory_key_current,
        territory_label_origin = territory_label_current,
        territory_key_origin_on_next_map = origin_next$territory_key_set,
        territory_label_origin_on_next_map = origin_next$territory_label_set,
        territory_key_destination_on_previous_map =
          destination_previous$territory_key_set,
        territory_label_destination_on_previous_map =
          destination_previous$territory_label_set,
        distance_m = sqrt((x_to - x)^2 + (y_to - y)^2)
      )

    # Require all four assignments to be one named territory before assigning
    # stable-boundary / boundary-change categories.
    four_unambiguous <-
      is_unambiguous_territory(tr$territory_key_origin) &
      is_unambiguous_territory(tr$territory_key_destination_on_previous_map) &
      is_unambiguous_territory(tr$territory_key_origin_on_next_map) &
      is_unambiguous_territory(tr$territory_key_destination)

    tr <- tr %>%
      mutate(
        all_four_unambiguous = four_unambiguous,

        # Did the two ACs lie in different territories under each fixed map?
        cross_on_origin_year_map =
          all_four_unambiguous &
          territory_key_origin != territory_key_destination_on_previous_map,

        cross_on_destination_year_map =
          all_four_unambiguous &
          territory_key_origin_on_next_map != territory_key_destination,

        # Stable-boundary crossing: both endpoint identities are invariant to
        # which year's map is used, and the two endpoints occupy different
        # territories.
        strict_stable_boundary_cross =
          all_four_unambiguous &
          territory_key_origin != territory_key_destination &
          territory_key_origin_on_next_map == territory_key_origin &
          territory_key_destination_on_previous_map == territory_key_destination,

        # Boundary-change-only reassignment: under the t map BOTH positions lie
        # in the old territory; under the t+1 map BOTH positions lie in the new
        # territory. The label change can therefore occur without a crossing
        # between A_t and A_{t+1} under either fixed annual map.
        boundary_change_only =
          all_four_unambiguous &
          territory_key_origin != territory_key_destination &
          territory_key_destination_on_previous_map == territory_key_origin &
          territory_key_origin_on_next_map == territory_key_destination,

        stable_same_territory =
          all_four_unambiguous &
          territory_key_origin == territory_key_destination &
          territory_key_origin_on_next_map == territory_key_origin &
          territory_key_destination_on_previous_map == territory_key_destination,

        map_dependent =
          all_four_unambiguous &
          (
            territory_key_origin != territory_key_origin_on_next_map |
            territory_key_destination_on_previous_map != territory_key_destination
          ),

        polygon_ambiguous =
          !all_four_unambiguous
      ) %>%
      transmute(
        chain,
        draw_in_chain,
        posterior_row,
        individual_id,
        tattoo,
        year_from = year,
        year_to,
        x_from = x,
        y_from = y,
        x_to,
        y_to,
        distance_m,
        territory_key_origin,
        territory_label_origin,
        territory_key_destination_on_previous_map,
        territory_label_destination_on_previous_map,
        territory_key_origin_on_next_map,
        territory_label_origin_on_next_map,
        territory_key_destination,
        territory_label_destination,
        all_four_unambiguous,
        cross_on_origin_year_map,
        cross_on_destination_year_map,
        strict_stable_boundary_cross,
        boundary_change_only,
        stable_same_territory,
        map_dependent,
        polygon_ambiguous
      )

    tr_chain[[jj]] <- tr
  }

  all_members[[chain]] <- bind_rows(mem_chain)
  all_transitions[[chain]] <- bind_rows(tr_chain)

  rm(fit, mm)
  invisible(gc(verbose = FALSE))
}

membership_draws <- bind_rows(all_members)
transition_draws <- bind_rows(all_transitions)

if (!nrow(membership_draws)) stop("No annual membership draws were generated.")
if (!nrow(transition_draws)) stop("No annual transition draws were generated.")

write_csv(
  membership_draws,
  file.path(OUTPUT_DIR, "02_posterior_annual_territory_draws.csv")
)
write_csv(
  transition_draws,
  file.path(OUTPUT_DIR, "04_posterior_transition_territory_draws.csv")
)

# -----------------------------------------------------------------------------
# Badger-year territory summaries
# -----------------------------------------------------------------------------

member_summary <- membership_draws %>%
  group_by(individual_id, tattoo, year) %>%
  summarise(
    n_spatial_draws = n(),
    p_single_territory = mean(is_unambiguous_territory(territory_key_current)),
    p_overlap = mean(str_detect(territory_key_current, fixed("|"))),
    p_outside = mean(territory_key_current == "OUTSIDE"),
    p_no_map = mean(territory_key_current == "NO_MAP"),
    mode_obj = list(mode_and_probability(territory_key_current)),
    label_mode_obj = list(mode_and_probability(territory_label_current)),
    .groups = "drop"
  ) %>%
  mutate(
    mode_territory_key = map_chr(mode_obj, "mode"),
    p_mode_territory = map_dbl(mode_obj, "p"),
    mode_territory_label = map_chr(label_mode_obj, "mode")
  ) %>%
  select(-mode_obj, -label_mode_obj)

write_csv(
  member_summary,
  file.path(OUTPUT_DIR, "03_badger_year_territory_summary.csv")
)

# -----------------------------------------------------------------------------
# Transition territory summaries
# -----------------------------------------------------------------------------

transition_summary <- transition_draws %>%
  group_by(individual_id, tattoo, year_from, year_to) %>%
  summarise(
    n_spatial_draws = n(),
    mean_distance_m = mean(distance_m),
    median_distance_m = median(distance_m),
    q025_distance_m = unname(quantile(distance_m, .025)),
    q975_distance_m = unname(quantile(distance_m, .975)),
    p_cross_origin_year_map = mean(cross_on_origin_year_map),
    p_cross_destination_year_map = mean(cross_on_destination_year_map),
    p_strict_stable_boundary_cross = mean(strict_stable_boundary_cross),
    p_boundary_change_only = mean(boundary_change_only),
    p_stable_same_territory = mean(stable_same_territory),
    p_map_dependent = mean(map_dependent),
    p_polygon_ambiguous = mean(polygon_ambiguous),
    origin_mode_obj = list(mode_and_probability(territory_key_origin)),
    destination_mode_obj = list(mode_and_probability(territory_key_destination)),
    origin_label_mode_obj = list(mode_and_probability(territory_label_origin)),
    destination_label_mode_obj = list(mode_and_probability(territory_label_destination)),
    .groups = "drop"
  ) %>%
  mutate(
    mode_origin_territory_key = map_chr(origin_mode_obj, "mode"),
    p_mode_origin_territory = map_dbl(origin_mode_obj, "p"),
    mode_destination_territory_key = map_chr(destination_mode_obj, "mode"),
    p_mode_destination_territory = map_dbl(destination_mode_obj, "p"),
    mode_origin_territory_label = map_chr(origin_label_mode_obj, "mode"),
    mode_destination_territory_label = map_chr(destination_label_mode_obj, "mode")
  ) %>%
  select(
    -origin_mode_obj,
    -destination_mode_obj,
    -origin_label_mode_obj,
    -destination_label_mode_obj
  )

write_csv(
  transition_summary,
  file.path(OUTPUT_DIR, "05_transition_territory_summary.csv")
)

# -----------------------------------------------------------------------------
# Capture-derived annual resident social groups
# -----------------------------------------------------------------------------

resident_join <- NULL

if (file.exists(RESIDENT_FILE)) {
  cat("Joining capture-derived annual resident groups...\n")
  resident_raw <- read_csv(RESIDENT_FILE, show_col_types = FALSE)

  need_res <- c("tattoo", "primary_year", "resident_group", "assignment_criterion")
  if (!all(need_res %in% names(resident_raw))) {
    stop(
      "Resident-group file missing: ",
      paste(setdiff(need_res, names(resident_raw)), collapse = ", ")
    )
  }

  resident <- resident_raw %>%
    transmute(
      tattoo = toupper(trimws(as.character(tattoo))),
      year = as.integer(primary_year),
      resident_group = group_clean(resident_group),
      resident_assignment_criterion = as.integer(assignment_criterion),
      resident_n_grouped_captures =
        if ("n_grouped_captures" %in% names(resident_raw)) {
          as.integer(n_grouped_captures)
        } else {
          NA_integer_
        }
    )

  resident_from <- resident %>%
    transmute(
      tattoo,
      year_from = year,
      resident_group_from = resident_group,
      resident_assignment_criterion_from = resident_assignment_criterion,
      resident_n_grouped_captures_from = resident_n_grouped_captures
    )

  resident_to <- resident %>%
    transmute(
      tattoo,
      year_to = year,
      resident_group_to = resident_group,
      resident_assignment_criterion_to = resident_assignment_criterion,
      resident_n_grouped_captures_to = resident_n_grouped_captures
    )

  resident_join <- list(from = resident_from, to = resident_to)
} else {
  warning("Resident-group file not found; resident SG columns will be absent.")
}

# -----------------------------------------------------------------------------
# Optional prospecting / temporary extra-group behaviour
# -----------------------------------------------------------------------------

prospecting <- NULL

if (file.exists(PROSPECTING_FILE)) {
  cat("Joining previously derived prospecting behaviour...\n")
  p <- read_csv(PROSPECTING_FILE, show_col_types = FALSE)

  if (all(c("tattoo", "focal_year") %in% names(p))) {
    prospecting <- p %>%
      transmute(
        tattoo = toupper(trimws(as.character(tattoo))),
        year_from = as.integer(focal_year),
        observed_extra_group_visit =
          if ("n_extra_capture_days" %in% names(p)) n_extra_capture_days > 0L else NA,
        closed_prospecting =
          if ("n_closed_prospecting_bouts" %in% names(p)) n_closed_prospecting_bouts > 0L else NA,
        n_extra_capture_days =
          if ("n_extra_capture_days" %in% names(p)) as.integer(n_extra_capture_days) else NA_integer_,
        n_closed_prospecting_bouts =
          if ("n_closed_prospecting_bouts" %in% names(p)) as.integer(n_closed_prospecting_bouts) else NA_integer_,
        closed_prospected_groups =
          if ("closed_prospected_groups" %in% names(p)) as.character(closed_prospected_groups) else NA_character_,
        future_matches_closed_prospected_group =
          if ("future_matches_closed_prospected_group" %in% names(p)) {
            as.logical(future_matches_closed_prospected_group)
          } else {
            NA
          },
        prospecting_pathway =
          if ("pathway" %in% names(p)) as.character(pathway) else NA_character_
      ) %>%
      distinct(tattoo, year_from, .keep_all = TRUE)
  }
}

# -----------------------------------------------------------------------------
# Master transition table
# -----------------------------------------------------------------------------

master <- movement_state %>%
  select(
    individual_id,
    tattoo,
    year_from = from_year,
    year_to = to_year,
    p_relocation_50,
    p_relocation_25,
    relocation_absdiff_25_50,
    relocation_chain_range_50,
    relocation_chain_range_25,
    relocation_robustness
  ) %>%
  left_join(
    transition_summary,
    by = c("individual_id", "tattoo", "year_from", "year_to"),
    relationship = "one-to-one"
  )

if (!is.null(resident_join)) {
  master <- master %>%
    left_join(
      resident_join$from,
      by = c("tattoo", "year_from"),
      relationship = "many-to-one"
    ) %>%
    left_join(
      resident_join$to,
      by = c("tattoo", "year_to"),
      relationship = "many-to-one"
    ) %>%
    mutate(
      resident_group_change = case_when(
        is.na(resident_group_from) | is.na(resident_group_to) ~ NA,
        TRUE ~ resident_group_from != resident_group_to
      )
    )
}

if (!is.null(prospecting)) {
  master <- master %>%
    left_join(
      prospecting,
      by = c("tattoo", "year_from"),
      relationship = "many-to-one"
    )
}

# Keep a stable output schema even when optional supporting products are absent.
if (!"resident_group_change" %in% names(master)) {
  master <- master %>%
    mutate(
      resident_group_from = NA_character_,
      resident_group_to = NA_character_,
      resident_assignment_criterion_from = NA_integer_,
      resident_assignment_criterion_to = NA_integer_,
      resident_n_grouped_captures_from = NA_integer_,
      resident_n_grouped_captures_to = NA_integer_,
      resident_group_change = NA
    )
}

if (!"closed_prospecting" %in% names(master)) {
  master <- master %>%
    mutate(
      observed_extra_group_visit = NA,
      closed_prospecting = NA,
      n_extra_capture_days = NA_integer_,
      n_closed_prospecting_bouts = NA_integer_,
      closed_prospected_groups = NA_character_,
      future_matches_closed_prospected_group = NA,
      prospecting_pathway = NA_character_
    )
}

# Conservative descriptive flags. These do not replace posterior probabilities.
master <- master %>%
  mutate(
    central_relocation = p_relocation_50 >= 0.5,
    strong_territory_cross = p_strict_stable_boundary_cross >= 0.5,
    strong_boundary_change_only = p_boundary_change_only >= 0.5,
    territory_overlay_ambiguous = p_polygon_ambiguous >= 0.5,

    interpretive_class = case_when(
      territory_overlay_ambiguous ~
        "POLYGON_ASSIGNMENT_AMBIGUOUS",

      strong_boundary_change_only ~
        "BOUNDARY_CHANGE_DOMINANT_REASSIGNMENT",

      central_relocation &
        strong_territory_cross &
        !is.na(resident_group_change) &
        resident_group_change ~
        "GEOGRAPHIC_RELOCATION_WITH_TERRITORY_AND_RESIDENT_SG_CHANGE",

      central_relocation & strong_territory_cross ~
        "GEOGRAPHIC_RELOCATION_WITH_STABLE_TERRITORY_CROSS",

      central_relocation ~
        "GEOGRAPHIC_RELOCATION_WITHOUT_STRONG_STABLE_TERRITORY_CROSS",

      !central_relocation &
        !is.na(resident_group_change) &
        resident_group_change ~
        "RESIDENT_SG_CHANGE_WITHOUT_CENTRAL_GEOGRAPHIC_RELOCATION",

      !central_relocation &
        coalesce(closed_prospecting, FALSE) ~
        "TEMPORARY_PROSPECTING_WITHOUT_CENTRAL_ANNUAL_RELOCATION",

      TRUE ~
        "NO_STRONG_ANNUAL_RELOCATION_OR_TERRITORY_CHANGE"
    )
  )

write_csv(
  master,
  file.path(OUTPUT_DIR, "06_master_movement_social_transition_table.csv")
)

# -----------------------------------------------------------------------------
# Diagnostics
# -----------------------------------------------------------------------------

annual_diag <- master %>%
  group_by(year_from) %>%
  summarise(
    n_intervals = n(),
    mean_p_relocation_50 = mean(p_relocation_50),
    n_central_relocation = sum(central_relocation),
    mean_p_strict_stable_boundary_cross =
      mean(p_strict_stable_boundary_cross, na.rm = TRUE),
    mean_p_boundary_change_only =
      mean(p_boundary_change_only, na.rm = TRUE),
    mean_p_polygon_ambiguous =
      mean(p_polygon_ambiguous, na.rm = TRUE),
    n_25_50_relocation_switch =
      sum(relocation_robustness == "25_50_CLASSIFICATION_SWITCH"),
    .groups = "drop"
  )

class_summary <- master %>%
  count(interpretive_class, name = "n_intervals") %>%
  mutate(proportion = n_intervals / sum(n_intervals)) %>%
  arrange(desc(n_intervals))

write_csv(
  annual_diag,
  file.path(OUTPUT_DIR, "07_annual_overlay_diagnostics.csv")
)
write_csv(
  class_summary,
  file.path(OUTPUT_DIR, "08_interpretive_class_summary.csv")
)

metadata <- tibble(
  item = c(
    "max_badgers",
    "draws_per_chain",
    "central_stem",
    "sensitivity_stem",
    "territories_file",
    "resident_file",
    "prospecting_file",
    "n_movement_intervals",
    "n_membership_draw_rows",
    "n_transition_draw_rows",
    "territory_identity_rule",
    "pm_location_rule"
  ),
  value = c(
    as.character(MAX_BADGERS),
    as.character(DRAWS_PER_CHAIN),
    CENTRAL_STEM,
    SENSITIVITY_STEM,
    TERRITORIES_FILE,
    RESIDENT_FILE,
    PROSPECTING_FILE,
    as.character(nrow(movement_state)),
    as.character(nrow(membership_draws)),
    as.character(nrow(transition_draws)),
    "formatting-only key; no automatic sett/SG biological aliasing",
    "PM recovery locations excluded from V11R2 territory overlay"
  )
)

write_csv(metadata, file.path(OUTPUT_DIR, "00_run_metadata.csv"))

saveRDS(
  list(
    metadata = metadata,
    movement_state = movement_state,
    membership_summary = member_summary,
    transition_summary = transition_summary,
    master_transition = master,
    annual_diagnostics = annual_diag,
    class_summary = class_summary
  ),
  file.path(OUTPUT_DIR, "V11R2_dynamic_social_group_overlay.rds")
)

cat("\n============================================================\n")
cat("V11R2 DYNAMIC SG / TERRITORY OVERLAY COMPLETE\n")
cat("============================================================\n")
cat("Movement intervals:", nrow(master), "\n")
cat(
  "25/50 relocation classification switches:",
  sum(master$relocation_robustness == "25_50_CLASSIFICATION_SWITCH"),
  "\n"
)
cat(
  "Mean central p(relocation):",
  round(mean(master$p_relocation_50), 4),
  "\n"
)
cat(
  "Mean p(stable territory cross):",
  round(mean(master$p_strict_stable_boundary_cross, na.rm = TRUE), 4),
  "\n"
)
cat(
  "Mean p(boundary-change only):",
  round(mean(master$p_boundary_change_only, na.rm = TRUE), 4),
  "\n"
)
cat(
  "Mean p(polygon ambiguous/outside):",
  round(mean(master$p_polygon_ambiguous, na.rm = TRUE), 4),
  "\n\n"
)
cat("Interpretive classes:\n")
print(class_summary, n = Inf)
cat("\nSaved outputs in:", OUTPUT_DIR, "\n")
cat(
  "NOTE: territory polygons, capture-derived resident SG and geographic ",
  "relocation remain separate evidence layers.\n",
  sep = ""
)
