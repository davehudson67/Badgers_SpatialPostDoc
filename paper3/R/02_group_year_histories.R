#!/usr/bin/env Rscript
# Paper 3 step 2: annual group-year histories, 1980-2025.
# One row per badger x year from its first trapped year: resident group
# (Vicente rules) or NA if not trapped; plus sex, age class and known death.
# Detection windows (CaptEffort) are joined later; nothing is inferred here.
source("paper3/R/common.R")
s <- p3_snapshot()
res <- utils::read.csv(file.path(s$out, "annual_resident_social_group_vicente.csv"))
enc <- readRDS(file.path(s$dir, "encounters.rds"))
dead <- readRDS(file.path(s$dir, "candidate_deaths.rds"))
yrs <- 1980:2025
res$group <- p3_alias(p3_norm_group(res$resident_group))
res <- res[res$primary_year %in% yrs, ]
ind <- enc[!duplicated(enc$tattoo), c("tattoo", "sex_clean",
  "age_first_capture_clean", "year_first_capture")]
first <- tapply(res$primary_year, res$tattoo, min)
h <- do.call(rbind, lapply(names(first), function(id)
  data.frame(tattoo = id, year = first[[id]]:2025)))
k <- match(paste(h$tattoo, h$year), paste(res$tattoo, res$primary_year))
h$group <- res$group[k]
h$criterion <- res$assignment_criterion[k]
i <- match(h$tattoo, ind$tattoo)
h$sex <- ind$sex_clean[i]
cub1 <- grepl("CUB", toupper(ind$age_first_capture_clean[i]))
h$first_caught_as_cub <- cub1
h$first_year <- as.integer(first[h$tattoo])
age <- ifelse(cub1, h$year - h$first_year, NA)
h$age_class <- ifelse(is.na(age), "post_cub_at_entry",
  ifelse(age == 0, "cub", ifelse(age == 1, "yearling", "adult")))
dy <- tapply(as.integer(format(as.Date(dead$recorded_event_date), "%Y")),
             dead$tattoo, min)
h$death_year <- as.integer(dy[h$tattoo])
h <- h[is.na(h$death_year) | h$year <= h$death_year, ]
# Derived and deterministic: re-run after editing group_name_aliases.csv.
utils::write.csv(h, file.path(s$out, "group_year_histories.csv"), row.names = FALSE)

# ---- data checks ----------------------------------------------------------
cap <- h[!is.na(h$group), ]
cap <- cap[order(cap$tattoo, cap$year), ]
nxt <- c(cap$tattoo[-1] == cap$tattoo[-nrow(cap)], FALSE)
moved <- nxt & c(cap$group[-1] != cap$group[-nrow(cap)], FALSE)
b <- h[!duplicated(h$tattoo), ]
chk <- data.frame(check = c("badgers", "trapped badger-years",
  "share first caught as cub (doc: >0.85)", "unresolved badger-years",
  "consecutive-capture group changes", "badgers with recorded death",
  "missing sex"),
  value = c(nrow(b), nrow(cap), round(mean(b$first_caught_as_cub), 3),
    sum(is.na(res$resident_group)), sum(moved),
    sum(!is.na(b$death_year)), sum(is.na(b$sex))))
print(chk, row.names = FALSE)
utils::write.csv(chk, file.path(s$out, "check_histories.csv"), row.names = FALSE)
utils::write.csv(as.data.frame.matrix(table(cap$group, cap$year)),
  file.path(s$out, "trapped_badgers_by_group_year.csv"))
