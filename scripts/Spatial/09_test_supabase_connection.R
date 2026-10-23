#!/usr/bin/env Rscript
source("scripts/Spatial/woodchester_supabase_connection.R")
cat("Testing Woodchester Supabase PostgreSQL connection ...\n")
con <- woodchester_supabase_connect()
on.exit(if(DBI::dbIsValid(con)) DBI::dbDisconnect(con), add=TRUE)
x <- DBI::dbGetQuery(con,
 "select current_database() as database_name,
    current_user as database_user,
    current_setting('default_transaction_read_only') as session_read_only,
    (select count(*) from research.setts) as n_canonical_setts,
    (select count(*) from research.captures) as n_captures")
stopifnot(nrow(x)==1, identical(x$session_read_only[[1]],"on"))
print(x)
cat("Connection successful; read-only session active.\n")
