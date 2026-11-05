#!/usr/bin/env Rscript
# WECS V12 / frozen V11R2 input reconciliation (READ ONLY, 2026-11-05).
# Run from the repository root on the RStudio server where historic RDS files live.
# This is a comparison of observed live evidence, NOT a refit or model-selection step.
# No raw Supabase rows, V11R2 outputs or earlier CSVs are modified.

stopifnot(requireNamespace("DBI", quietly=TRUE),
          requireNamespace("RPostgres", quietly=TRUE),
          requireNamespace("dplyr", quietly=TRUE),
          requireNamespace("readr", quietly=TRUE))

legacy_enc_file <- "data/badger_encounters_useful.rds"
legacy_pop_file <- "results/V7_population_inclusion_audit.rds"
legacy_sett_file <- "data/WoodchesterSettLocations.csv"
needed <- c(legacy_enc_file, legacy_pop_file, legacy_sett_file)
if (any(!file.exists(needed))) {
 stop("Historic V11R2 inputs missing on this server:\n",
      paste(needed[!file.exists(needed)],collapse="\n"))
}

if (!exists("badger_db_connect", mode="function")) {
 badger_db_connect <- function() DBI::dbConnect(
   RPostgres::Postgres(),
   host=Sys.getenv("BADGER_DB_HOST"),
   port=as.integer(Sys.getenv("BADGER_DB_PORT", unset="5432")),
   dbname=Sys.getenv("BADGER_DB_NAME",unset="postgres"),
   user=Sys.getenv("BADGER_DB_USER"),
   password=Sys.getenv("BADGER_DB_PASSWORD"),sslmode="require"
 )
}

enc <- as.data.frame(readRDS(legacy_enc_file))
obj <- readRDS(legacy_pop_file)
stopifnot(!is.null(obj$population))
pop <- as.data.frame(obj$population)
sett <- readr::read_csv(legacy_sett_file,show_col_types=FALSE)

require_columns <- function(d, columns, label) {
  missing <- setdiff(columns,names(d))
  if(length(missing)) stop(label," is missing columns: ",
    paste(missing,collapse=", "), "\nAvailable: ",paste(names(d),collapse=", "))
}
require_columns(enc,c("tattoo","capture_date","sett","primary_year",
                      "trap_season","has_live_capture"),legacy_enc_file)
require_columns(pop,c("tattoo","movement_eligible"),legacy_pop_file)

pick <- function(options, available,label) {
  col <- intersect(options,available)[1]
  if(is.na(col)) stop("Cannot identify ",label,
                     " in historic sett CSV; columns: ",paste(available,collapse=", "))
  col
}
name_col <- pick(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett),"sett name")
x_col <- pick(c("SettX","sett_x","X","x","Easting","easting"),names(sett),"easting")
y_col <- pick(c("SettY","sett_y","Y","y","Northing","northing"),names(sett),"northing")

# Replicate V11R2's historic key solely to examine what that fit originally used.
# This is NOT a recommendation to carry aliases into the audited V12 dataset.
norm <- function(x) {
  z <- toupper(trimws(as.character(x)))
  z <- gsub("[[:punct:]]"," ",z)
  z <- gsub("\\b(SETT|MAIN|OUTLIER)\\b","",z,perl=TRUE)
  z <- gsub("\\s+","",z,perl=TRUE)
  z[is.na(x)] <- NA_character_
  z
}
alias <- c(CHESTNUT="CHESNUT",JACKS="JACKSMIREY",
  GRAVEL="GRAVELPIT",BUCKHOLE="BUCKHOLT",TOPSETT="TOP",
  FOXCUB="FOX",GULLEY="GULLY",BLACKBERRY="BRAMBLE",
  BOC="BOG",CEDARBANK="CEDAR",CLAYTRAP="CLAY",
  CLIFF="CLIFFFACE",DINGLEVALLEY="DINGLE")
legacy_key <- function(x) {
  z <- norm(x)
  idx <- which(!is.na(z) & z %in% names(alias))
  z[idx] <- unname(alias[z[idx]])
  z
}
pop_ids <- unique(toupper(trimws(as.character(pop$tattoo[which(pop$movement_eligible %in% TRUE)]))))
cat("Legacy V11R2 movement-eligible tattoos:",length(pop_ids),"\n")

old_xy <- data.frame(
 key=legacy_key(sett[[name_col]]),
 x=suppressWarnings(as.numeric(sett[[x_col]])),
 y=suppressWarnings(as.numeric(sett[[y_col]])))
old_xy <- dplyr::distinct(old_xy)
old_xy <- dplyr::filter(old_xy,!is.na(key),nzchar(key),
                        is.finite(x),is.finite(y))
n_by_key <- table(old_xy$key)
if (any(n_by_key>1)) stop("Historic file contains a sett key with multiple XY: ",
                         paste(names(n_by_key)[n_by_key>1],collapse=", "))
old_xy <- old_xy[!duplicated(old_xy$key),]

old <- data.frame(
 tattoo=toupper(trimws(as.character(enc$tattoo))),
 event_date=as.Date(enc$capture_date),
 original_sett=as.character(enc$sett),
 primary_year=suppressWarnings(as.integer(enc$primary_year)),
 quarter=suppressWarnings(as.integer(enc$trap_season)),
 is_live=as.logical(enc$has_live_capture))
old <- dplyr::filter(old,is_live %in% TRUE,
                     !is.na(primary_year),primary_year<=2025,
                     quarter %in% 1:4,tattoo %in% pop_ids)
old$legacy_key <- legacy_key(old$original_sett)
old <- dplyr::left_join(old,old_xy,by=c("legacy_key"="key"))
old$in_old_movement_likelihood <- is.finite(old$x) & is.finite(old$y)

con <- badger_db_connect()
new <- DBI::dbGetQuery(con,"
 select upper(trim(i.tattoo)) as tattoo,
 c.capture_id,c.capture_date as event_date,
 c.recorded_sett_name as original_sett,
 e.sett_id,e.location_easting,e.location_northing,e.location_quality,
 e.encounter_type
 from research.captures c
 join research.individuals i using(individual_id)
 join analysis.encounters_clean_v1 e using(capture_id)
 where e.is_pm=false and e.episode_record_role<>'PM_COMPANION'
 and e.encounter_type in ('TRAP','NET','SNARE','DART','FOUND_ALIVE')
 and c.capture_date < '2026-01-01'
")
DBI::dbDisconnect(con)
new <- dplyr::filter(new,tattoo %in% pop_ids)
new$event_date <- as.Date(new$event_date)
new$has_accepted_xy <- is.finite(new$location_easting) & is.finite(new$location_northing)

# Tattoo+date is a conservative *screening* key, not proof of row-level identity:
# multiple same-day capture events require the original capture ID/source match.
old_dates <- old |>
 dplyr::group_by(tattoo,event_date) |>
 dplyr::summarise(old_rows=dplyr::n(),
 old_mapped=sum(in_old_movement_likelihood),
 old_setts=paste(sort(unique(original_sett[!is.na(original_sett)])),collapse="; "),
 .groups="drop")
new_dates <- new |>
 dplyr::group_by(tattoo,event_date) |>
 dplyr::summarise(new_rows=dplyr::n(),
 new_mapped=sum(has_accepted_xy),
 new_ids=paste(capture_id,collapse="; "),
 new_setts=paste(sort(unique(original_sett[!is.na(original_sett)])),collapse="; "),
 .groups="drop")
comparison <- dplyr::full_join(old_dates,new_dates,by=c("tattoo","event_date"))
comparison$review_reason <- dplyr::case_when(
 is.na(comparison$old_rows) ~ "ONLY_IN_AUDITED_SUPABASE",
 is.na(comparison$new_rows) ~ "ONLY_IN_LEGACY_INPUT",
 comparison$old_rows != comparison$new_rows ~ "DIFFERENT_SAME_DAY_ROW_COUNTS",
 comparison$old_mapped != comparison$new_mapped ~ "SPATIAL_ELIGIBILITY_CHANGED",
 comparison$old_setts != comparison$new_setts ~ "SOURCE_SETT_TEXT_CHANGED",
 TRUE ~ "MATCHED_DATE_COUNTS"
)
out_dir <- "outputs/v12_input_audit"
dir.create(out_dir,recursive=TRUE,showWarnings=FALSE)
readr::write_csv(comparison,file.path(out_dir,"legacy_V11R2_vs_Supabase_capture_dates.csv"))
readr::write_csv(
 dplyr::filter(new,!has_accepted_xy),
 file.path(out_dir,"V11R2_cohort_missing_cleaned_live_xy.csv"))
readr::write_csv(dplyr::filter(comparison,review_reason!="MATCHED_DATE_COUNTS"),
 file.path(out_dir,"V11R2_capture_input_changes_for_manual_review.csv"))
cat("\nOLD INPUT SCREEN:\n")
print(c(n_legacy_captures=nrow(old),
        n_legacy_mapped=sum(old$in_old_movement_likelihood),
        old_tattoos=length(unique(old$tattoo))))
cat("\nAUDITED SUPABASE SAME COHORT SCREEN:\n")
print(c(n_clean_live=nrow(new),
        n_clean_mapped=sum(new$has_accepted_xy),
        n_clean_tattoos=length(unique(new$tattoo))))
cat("\nDATE-LEVEL REVIEW COUNTS:\n")
print(table(comparison$review_reason,useNA="ifany"))
cat("\nOutputs in ",out_dir,"\n",sep="")
cat("IMPORTANT: Historical row count and explicit same-day source/sett identity must be checked manually.\n",
    "Do not rerun V11R2 automatically or equate a novel mapped PM recovery with a live detector.\n",sep="")
