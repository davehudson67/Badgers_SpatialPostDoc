# Paper 3 shared helpers. Source from the repository root.
p3_fail <- function(...) stop(paste0(...), call. = FALSE)

# Snapshot id: SNAPSHOT_ID, or the only folder in data/model_snapshots.
p3_snapshot <- function() {
  id <- Sys.getenv("SNAPSHOT_ID")
  if (!nzchar(id)) {
    ids <- basename(list.dirs("data/model_snapshots", recursive = FALSE))
    if (length(ids) != 1L)
      p3_fail("Set SNAPSHOT_ID; found ", length(ids), " snapshots")
    id <- ids
  }
  dir <- file.path("data", "model_snapshots", id)
  if (!file.exists(file.path(dir, "MANIFEST.txt")))
    p3_fail("No frozen snapshot manifest in ", dir)
  list(id = id, dir = dir,
       out = file.path("outputs", "paper3", id))
}

# One spelling for group names from captures and polygons:
# upper case, letters/digits only ("Windsor Edge" == "WINDSOREDGE").
p3_norm_group <- function(x) {
  z <- gsub("[^A-Z0-9]", "", toupper(trimws(as.character(x))))
  z[z %in% c("", "NA", "NONE", "UNKNOWN", "UNK", "NOTKNOWN")] <- NA
  z
}

# Hand-checked aliases (paper3/group_name_aliases.csv: from,to), applied
# after normalisation. Empty file = no aliases.
p3_alias <- function(x) {
  f <- "paper3/group_name_aliases.csv"
  a <- utils::read.csv(f, stringsAsFactors = FALSE)
  if (!nrow(a)) return(x)
  a$from <- p3_norm_group(a$from); a$to <- p3_norm_group(a$to)
  i <- match(x, a$from)
  ifelse(is.na(i), x, a$to[i])
}
