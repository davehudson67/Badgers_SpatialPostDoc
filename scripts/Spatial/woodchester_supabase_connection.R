# Supabase Postgres connection for Woodchester analytical scripts.
# Secrets are supplied from ~/.Renviron, not stored in the repository.
woodchester_supabase_connect <- function() {
  if (!requireNamespace("DBI", quietly=TRUE) ||
      !requireNamespace("RPostgres", quietly=TRUE)) {
    stop("Install DBI and RPostgres: install.packages(c('DBI','RPostgres'))")
  }
  vars <- c("SUPABASE_DB_HOST","SUPABASE_DB_USER","SUPABASE_DB_PASSWORD")
  missing <- vars[!nzchar(Sys.getenv(vars))]
  if (length(missing)) stop("Missing environment variable(s): ",
                            paste(missing, collapse=", "),
                            ". Configure ~/.Renviron; do not commit it.")
  port <- suppressWarnings(as.integer(Sys.getenv("SUPABASE_DB_PORT","5432")))
  if (is.na(port)) stop("SUPABASE_DB_PORT must be a number")
  con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host=Sys.getenv("SUPABASE_DB_HOST"),
    port=port,
    dbname=Sys.getenv("SUPABASE_DB_NAME","postgres"),
    user=Sys.getenv("SUPABASE_DB_USER"),
    password=Sys.getenv("SUPABASE_DB_PASSWORD"),
    sslmode="require",
    connect_timeout=12
  )
  # Use a dedicated read-only role where possible; also set session read-only.
  tryCatch(
    DBI::dbExecute(con,"SET default_transaction_read_only = on"),
    error=function(e) {
      DBI::dbDisconnect(con)
      stop("Could not make session read-only: ",conditionMessage(e))
    }
  )
  con
}
