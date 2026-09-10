# BadgerDatabase.R

library(DBI)
library(RPostgres)
library(dplyr)
library(dbplyr)

badger_db_connect <- function() {
  dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("BADGER_DB_HOST"),
    port = as.integer(Sys.getenv("BADGER_DB_PORT")),
    dbname = Sys.getenv("BADGER_DB_NAME"),
    user = Sys.getenv("BADGER_DB_USER"),
    password = Sys.getenv("BADGER_DB_PASSWORD"),
    sslmode = "require"
  )
}

capture_history_db <- function(con) {
  tbl(con, dbplyr::in_schema("analysis", "capture_history"))
}

diagnostic_results_db <- function(con) {
  tbl(con, dbplyr::in_schema("analysis", "diagnostic_results"))
}

load_capture_history <- function(con, start_date = NULL, end_date = NULL, live_only = FALSE) {
  x <- capture_history_db(con)
  
  if (!is.null(start_date)) {
    x <- x %>%
      filter(capture_date >= as.Date(start_date))
  }
  
  if (!is.null(end_date)) {
    x <- x %>%
      filter(capture_date <= as.Date(end_date))
  }
  
  if (live_only) {
    x <- x %>%
      filter(is_pm == FALSE)
  }
  
  x %>%
    collect()
}

load_diagnostics <- function(con, test_family = NULL, start_date = NULL, end_date = NULL) {
  x <- diagnostic_results_db(con)
  
  if (!is.null(test_family)) {
    x <- x %>%
      filter(.data$test_family %in% !!test_family)
  }
  
  if (!is.null(start_date)) {
    x <- x %>%
      filter(capture_date >= as.Date(start_date))
  }
  
  if (!is.null(end_date)) {
    x <- x %>%
      filter(capture_date <= as.Date(end_date))
  }
  
  x %>%
    collect()
}