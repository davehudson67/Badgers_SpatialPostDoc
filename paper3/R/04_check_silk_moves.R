#!/usr/bin/env Rscript
# Paper 3 step 4: reproduce the Silk draft's 462 between-group moves
# (20 groups, 1986-2006). The draft's exact move definition is not in the
# repo, so three candidate definitions are counted side by side:
#  A capture level: consecutive TRAP captures in different recorded groups
#  B as A, but within ten two-year windows (1986-87 ... 2004-05; CMRnet-style)
#  C residency: Vicente group differs between consecutive trapped years
# SILK_GROUPS = text file of the draft's 20 group names (one per line).
# Without it, the 20 most-trapped groups are used and the check is
# provisional.
source("paper3/R/common.R")
s <- p3_snapshot()
target <- 462
enc <- readRDS(file.path(s$out, "vicente_input_encounters.rds"))
enc$group <- p3_alias(p3_norm_group(enc$recorded_social_group_name))
enc <- enc[!is.na(enc$group) & enc$primary_year %in% 1986:2006, ]
h <- utils::read.csv(file.path(s$out, "group_year_histories.csv"))
h <- h[!is.na(h$group) & h$year %in% 1986:2006, ]
gf <- Sys.getenv("SILK_GROUPS")
if (nzchar(gf)) {
  groups <- p3_alias(p3_norm_group(readLines(gf)))
  if (length(unique(groups)) != 20L) p3_fail("SILK_GROUPS must list 20 groups")
  note <- "Silk group list supplied"
} else {
  groups <- names(sort(table(h$group), decreasing = TRUE))[1:20]
  note <- "PROVISIONAL: top-20 trapped groups, not the draft's list"
}
moves <- function(d, key, grp) {
  d <- d[order(d$tattoo, d[[key]]), ]
  n <- nrow(d); same <- d$tattoo[-1] == d$tattoo[-n]
  ch <- same & d[[grp]][-1] != d[[grp]][-n] &
    d[[grp]][-1] %in% groups & d[[grp]][-n] %in% groups
  d[-1, ][ch, ]
}
e <- enc[order(enc$tattoo, enc$capture_date), ]
A <- moves(e, "capture_date", "group")
e$window <- (e$primary_year - 1986) %/% 2
e$tw <- paste(e$tattoo, e$window)
B <- moves(transform(e[e$window <= 9, ], tattoo = tw), "capture_date", "group")
C <- moves(h, "year", "group")
out <- data.frame(definition = c("A capture-level", "B two-year windows",
  "C annual residency"), moves = c(nrow(A), nrow(B), nrow(C)),
  badgers = c(length(unique(A$tattoo)), length(unique(sub(" .*", "", B$tattoo))),
              length(unique(C$tattoo))))
out$diff_from_462 <- out$moves - target
out$match_2pct <- abs(out$diff_from_462) <= .02 * target
cat(note, "\n"); print(out, row.names = FALSE)
utils::write.csv(out, file.path(s$out, "check_silk_462_moves.csv"), row.names = FALSE)
writeLines(groups, file.path(s$out, "check_silk_groups_used.txt"))
cat(if (any(out$match_2pct)) "SILK MOVE CHECK: MATCH" else
  "SILK MOVE CHECK: NO MATCH (review definitions/groups)", "\n")
