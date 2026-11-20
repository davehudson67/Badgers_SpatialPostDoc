#!/usr/bin/env Rscript
# Paper 3 step 0: capture-level recorded social group for every capture in
# the frozen snapshot. The V12 freezer did not export this field, so it is
# read here (SELECT only) and keyed to the snapshot's capture IDs.
# Credentials as for scripts/database/freeze_woodchester_v12_inputs.R.
source("paper3/R/common.R")
s <- p3_snapshot()
enc <- readRDS(file.path(s$dir, "encounters.rds"))
con <- DBI::dbConnect(RPostgres::Postgres(),
  host = Sys.getenv("BADGER_DB_HOST", "db.klpvihubzlyzubyyubtw.supabase.co"),
  port = as.integer(Sys.getenv("BADGER_DB_PORT", "5432")),
  dbname = Sys.getenv("BADGER_DB_NAME", "postgres"),
  user = Sys.getenv("BADGER_DB_USER"),
  password = Sys.getenv("BADGER_DB_PASSWORD"), sslmode = "require")
on.exit(DBI::dbDisconnect(con), add = TRUE)
g <- DBI::dbGetQuery(con, "
  SELECT capture_id, recorded_social_group_name, social_group_name_clean
  FROM research.captures")
g <- g[g$capture_id %in% enc$capture_id, ]
if (nrow(g) != nrow(enc) || anyDuplicated(g$capture_id))
  p3_fail("Group fields do not match snapshot capture IDs one-to-one")
dir.create(s$out, recursive = TRUE, showWarnings = FALSE)
f <- file.path(s$out, "group_fields.rds")
if (file.exists(f)) p3_fail("Exists, not overwriting: ", f)
saveRDS(g, f, version = 3)
writeLines(c(paste0("snapshot_id=", s$id),
  paste0("utc_extracted=", format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")),
  paste0("n_captures=", nrow(g)),
  paste0("n_with_recorded_group=", sum(!is.na(p3_norm_group(g$recorded_social_group_name)))),
  paste0("sha256=", digest::digest(f, algo = "sha256", file = TRUE))),
  file.path(s$out, "group_fields_MANIFEST.txt"))
cat("Saved", f, ":", nrow(g), "captures\n")
