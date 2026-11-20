#!/usr/bin/env Rscript
# Paper 3 step 1: re-run the Vicente et al. 2007 residency rules
# (scripts/behaviour/Woodchester_assign_annual_resident_social_group.R,
# unchanged logic) on the frozen snapshot. Input = live TRAP captures only:
# netting and other off-sett captures have never been used to assign groups.
source("paper3/R/common.R")
s <- p3_snapshot()
live <- readRDS(file.path(s$dir, "qualifying_live.rds"))
g <- readRDS(file.path(s$out, "group_fields.rds"))
cat("Qualifying live captures by encounter type:\n")
print(table(live$encounter_type, useNA = "ifany"))
trap <- live[live$encounter_type == "TRAP", ]
trap$recorded_social_group_name <-
  g$recorded_social_group_name[match(trap$capture_id, g$capture_id)]
d <- as.Date(trap$capture_date)
enc <- data.frame(tattoo = trap$tattoo, capture_date = d,
  primary_year = as.integer(format(d, "%Y")), has_live_capture = TRUE,
  recorded_social_group_name = trap$recorded_social_group_name)
pop <- list(population = data.frame(tattoo = unique(enc$tattoo),
                                     movement_eligible = TRUE))
fe <- file.path(s$out, "vicente_input_encounters.rds")
fp <- file.path(s$out, "vicente_input_population.rds")
fo <- file.path(s$out, "annual_resident_social_group_vicente.csv")
if (file.exists(fo)) p3_fail("Exists, not overwriting: ", fo)
saveRDS(enc, fe); saveRDS(pop, fp)
st <- system2("Rscript",
  "scripts/behaviour/Woodchester_assign_annual_resident_social_group.R",
  env = c(paste0("VICENTE_ENCOUNTERS=", fe), paste0("VICENTE_POPULATION=", fp),
          paste0("VICENTE_OUT=", fo)))
if (st != 0) p3_fail("Vicente assignment failed (exit ", st, ")")
