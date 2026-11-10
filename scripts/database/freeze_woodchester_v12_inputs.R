#!/usr/bin/env Rscript
# Woodchester: audited Supabase -> immutable run snapshot.
# READ ONLY. Does NOT run or refit a model. Run from repository root.
# Rscript scripts/database/freeze_woodchester_v12_inputs.R
#
# Credentials: BADGER_DB_USER, BADGER_DB_PASSWORD; optional BADGER_DB_HOST,
# BADGER_DB_PORT, BADGER_DB_NAME. Use a SELECT-only PostgreSQL role.
# Snapshots contain research data and MUST NOT be committed to Git.

for (pkg in c("DBI", "RPostgres", "digest")) {
  if (!requireNamespace(pkg, quietly = TRUE)) stop("Install R package: ", pkg)
}
if (!nzchar(Sys.getenv("BADGER_DB_USER")) ||
    !nzchar(Sys.getenv("BADGER_DB_PASSWORD"))) {
  stop("BADGER_DB_USER and BADGER_DB_PASSWORD must be set")
}
main <- function() {
host <- Sys.getenv("BADGER_DB_HOST",
  unset = "db.klpvihubzlyzubyyubtw.supabase.co")
con <- DBI::dbConnect(RPostgres::Postgres(),
  host = host, port = as.integer(Sys.getenv("BADGER_DB_PORT", "5432")),
  dbname = Sys.getenv("BADGER_DB_NAME", "postgres"),
  user = Sys.getenv("BADGER_DB_USER"),
  password = Sys.getenv("BADGER_DB_PASSWORD"), sslmode = "require")
on.exit(DBI::dbDisconnect(con), add = TRUE)

# All data sources are vetted, read-only, existing analysis/research objects.
# REPEATABLE READ holds a coherent database snapshot across the three queries.
DBI::dbExecute(con, "BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ READ ONLY")
transaction_open <- TRUE
on.exit(if (transaction_open) try(DBI::dbExecute(con, "ROLLBACK"), silent = TRUE),
        add = TRUE)

# The audited views are complex. Range filtering by capture_id avoids a full
# unrestricted query that exceeds the default 2-minute Supabase timeout.
# All ranges share ONE repeatable-read transaction, so the combined input is
# a coherent snapshot even if live data change concurrently.
bounds <- DBI::dbGetQuery(con, "
  SELECT min(capture_id) AS first_id, max(capture_id) AS last_id,
         count(*) AS n_capture_rows FROM research.captures
")
if (!nrow(bounds) || is.na(bounds$first_id[1]) || is.na(bounds$last_id[1]))
  stop("No capture records in research.captures")
step <- as.integer(Sys.getenv("WOODCHESTER_BATCH_IDS", "2000"))
if (is.na(step) || step < 1L || step > 5000L)
  stop("WOODCHESTER_BATCH_IDS must be between 1 and 5000")
start_ids <- seq(from = as.numeric(bounds$first_id[1]),
                 to = as.numeric(bounds$last_id[1]), by = step)

get_batches <- function(sql_template, label) {
  parts <- vector("list", length(start_ids))
  for (j in seq_along(start_ids)) {
    lo <- start_ids[j]
    hi <- min(lo + step - 1, as.numeric(bounds$last_id[1]))
    cat(sprintf("%s: capture IDs %.0f-%.0f (%d/%d)\n",
                label, lo, hi, j, length(start_ids)))
    parts[[j]] <- DBI::dbGetQuery(con, sprintf(sql_template, lo, hi))
  }
  do.call(rbind, parts)
}

enc <- get_batches("
 SELECT e.capture_id, upper(trim(e.tattoo)) AS tattoo,
        e.capture_date, e.is_pm, e.sett_id,
        e.episode_primary_capture_id, e.episode_record_role,
        e.encounter_type, e.outcome, e.location_type,
        e.location_easting, e.location_northing, e.location_quality,
        c.recorded_sett_name AS source_recorded_sett_name,
        c.capture_location_text AS source_capture_location_text,
        c.moc AS source_moc, c.os_ref AS source_os_ref,
        c.comment AS source_comment,
        i.sex_clean, i.age_first_capture_clean, i.year_first_capture
 FROM analysis.encounters_clean_v1 e
 JOIN research.captures c ON c.capture_id = e.capture_id
 JOIN research.individuals i ON i.individual_id = c.individual_id
 WHERE e.capture_id BETWEEN %.0f AND %.0f
", "encounters")
mort <- get_batches("
 SELECT capture_id, upper(trim(tattoo)) AS tattoo, recorded_event_date,
        mortality_outcome, encounter_type, source_is_pm,
        linked_pm_capture_id, linked_pm_date, next_live_capture_date,
        mortality_review_status, terminal_model_status, terminal_model_note
 FROM analysis.mortality_model_candidate_v1
 WHERE capture_id BETWEEN %.0f AND %.0f
", "mortality")
enc <- enc[order(enc$capture_id), , drop = FALSE]
mort <- mort[order(mort$capture_id), , drop = FALSE]
# Match the source captures exactly; this also detects missing rows from joins
# and protects against partial extraction or accidental range omissions.
if (nrow(enc) != as.numeric(bounds$n_capture_rows[1]))
  stop("Encounter row count differs from source captures: ",
       nrow(enc), " vs ", bounds$n_capture_rows[1])
DBI::dbExecute(con, "SAVEPOINT migration_metadata")
migration <- tryCatch(DBI::dbGetQuery(con, "
 SELECT version, name FROM supabase_migrations.schema_migrations
 ORDER BY version DESC LIMIT 1
"), error = function(e) {
 DBI::dbExecute(con, "ROLLBACK TO SAVEPOINT migration_metadata")
 warning("Read-only role cannot inspect migration history; version is UNKNOWN")
 data.frame(version = NA_character_, name = NA_character_)
})
DBI::dbExecute(con, "RELEASE SAVEPOINT migration_metadata")
DBI::dbExecute(con, "COMMIT")
transaction_open <- FALSE

# Fail closed if identity or row-grain assumptions do not hold.
if (!nrow(enc) || anyNA(enc$capture_id) || anyDuplicated(enc$capture_id))
  stop("Encounter dataset has missing/duplicated capture IDs")
if (anyNA(enc$tattoo) || any(!nzchar(enc$tattoo)))
  stop("Encounter dataset contains missing tattoo")
if (anyNA(enc$capture_date)) stop("Encounter dates missing: review before fitting")
if (anyNA(enc$is_pm)) stop("Missing PM classification: review before fitting")
if (anyNA(mort$capture_id) || anyDuplicated(mort$capture_id))
  stop("Mortality candidates have missing/duplicated primary capture IDs")
if (anyNA(mort$tattoo) || any(!nzchar(mort$tattoo)))
  stop("Mortality candidates have missing tattoo")
if (any(mort$terminal_model_status == "CANDIDATE_TERMINAL_DEATH" &
        is.na(mort$recorded_event_date), na.rm = TRUE))
  stop("A candidate terminal death has no date")

# Classify qualifying live evidence, without discarding missing XY.
live_type <- c("TRAP", "NET", "SNARE", "DART", "FOUND_ALIVE")
live <- enc[
  !is.na(enc$is_pm) & !enc$is_pm &
    !is.na(enc$episode_record_role) &
    enc$episode_record_role != "PM_COMPANION" &
    !is.na(enc$encounter_type) & enc$encounter_type %in% live_type,
  , drop = FALSE
]
# Missing role must be reviewed, not silently removed from eligibility.
unknown_role <- enc[!enc$is_pm & is.na(enc$episode_record_role) &
                      !is.na(enc$encounter_type) &
                      enc$encounter_type %in% live_type, , drop = FALSE]
held <- mort[is.na(mort$terminal_model_status) |
  mort$terminal_model_status != "CANDIDATE_TERMINAL_DEATH", , drop = FALSE]
candidate <- mort[!is.na(mort$terminal_model_status) &
  mort$terminal_model_status == "CANDIDATE_TERMINAL_DEATH", , drop = FALSE]

# Never quietly treat unsettled cases as fitted terminal deaths.
if (nrow(unknown_role))
  warning(nrow(unknown_role), " potentially live rows have unknown episode role")
if (nrow(held))
  message(nrow(held), " mortality candidates held for review (not inferred death)")

# Local run artefacts are deliberately untracked, no fixed file overwritten.
stamp <- format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")
id <- paste0("v12_", stamp, "_", Sys.getpid())
dir <- file.path("data", "model_snapshots", id)
if (dir.exists(dir)) stop("Snapshot directory already exists: ", dir)
dir.create(dir, recursive = TRUE, showWarnings = FALSE)
files <- list(encounters = enc, qualifying_live = live,
              mortality_candidates = mort, candidate_deaths = candidate,
              held_mortality = held, live_unknown_episode_role = unknown_role)
for (nm in names(files)) saveRDS(files[[nm]], file.path(dir, paste0(nm, ".rds")),
                                  version = 3)
paths <- file.path(dir, paste0(names(files), ".rds"))
hashes <- vapply(paths, digest::digest, character(1), algo = "sha256", file = TRUE)
git_sha <- tryCatch(
  trimws(system2("git", c("rev-parse", "HEAD"), stdout = TRUE, stderr = FALSE)),
  error = function(e) "UNKNOWN")
manifest <- c(
  paste("snapshot_id", id, sep = "="),
  paste("utc_extracted", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"), sep = "="),
  paste("git_commit", git_sha[1], sep = "="),
  paste("last_recorded_migration", if(nrow(migration)) as.character(migration$version[1]) else "UNKNOWN", sep = "="),
  "source_encounters=analysis.encounters_clean_v1 + research.captures + research.individuals",
  "source_record_evidence=research.captures recorded_sett_name capture_location_text moc os_ref comment, preserved without updates",
  "source_mortality=analysis.mortality_model_candidate_v1",
  "rule_live=non-PM non-companion TRAP/NET/SNARE/DART/FOUND_ALIVE; unknown episode role held",
  "rule_death=CANDIDATE_TERMINAL_DEATH; held candidates not treated as confirmed",
  "scope=pre-fit scientific evidence extraction; NOT an approved likelihood",
  paste("batch_id_width", step, sep = "="),
  paste("n_source_captures", bounds$n_capture_rows[1], sep = "="),
  paste("n_encounters", nrow(enc), sep = "="),
  paste("n_qualifying_live", nrow(live), sep = "="),
  paste("n_candidate_deaths", nrow(candidate), sep = "="),
  paste("n_held_mortality", nrow(held), sep = "="),
  paste("n_live_unknown_episode_role", nrow(unknown_role), sep = "="),
  paste("n_qualifying_live_without_xy",
    sum(is.na(live$location_easting) | is.na(live$location_northing)), sep = "="),
  paste0("sha256_", names(files), "=", hashes)
)
writeLines(manifest, file.path(dir, "MANIFEST.txt"), useBytes = TRUE)
cat(paste(manifest, collapse = "\n"), "\n")
cat("\nSnapshot saved: ", dir, "\n", sep = "")
cat("NOT model-fit-ready until unresolved cases and model assumptions are reviewed.\n")
}
main()
