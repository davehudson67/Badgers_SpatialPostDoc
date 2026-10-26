#!/usr/bin/env Rscript
# Read-only QA of 1977–2025 annual fixed-sett/polygon matches.
suppressPackageStartupMessages({library(readr);library(dplyr);library(tidyr)})
dir <- "outputs/V1_annual_sett_polygon_membership"
x <- read_csv(file.path(dir,"annual_sett_polygon_all_matches.csv"),
              show_col_types=FALSE,col_types=cols(.default=col_character()))
if(nrow(x)==0)stop("Crosswalk is empty")
x$year <- as.integer(x$year)
key <- x %>% group_by(year,sett_id) %>%
 summarise(n_polygon_matches=sum(!is.na(polygon_id)),
  n_polygon_names=n_distinct(territory_name,na.rm=TRUE),
  has_boundary=any(match_status=="ON_BOUNDARY"),
  n_multiple_rows=sum(match_status=="MULTIPLE_POLYGONS"),
  n_single_rows=sum(match_status=="ONE_POLYGON"),
  n_no_coord=sum(match_status=="NO_COORDINATE"),
  n_outside=sum(match_status=="OUTSIDE_ALL"),
  polygon_names=paste(sort(unique(na.omit(territory_name))),collapse=" | "),
  .groups="drop") %>%
 mutate(category=case_when(
  n_no_coord>0~"NO_COORDINATE",
  n_outside>0~"OUTSIDE_ALL",
  has_boundary~"ON_BOUNDARY",
  n_polygon_matches>1~"MULTIPLE_POLYGONS",
  n_polygon_matches==1~"ONE_POLYGON",
  TRUE~"REVIEW"))
if(nrow(key)!=176*49)stop("Unexpected count of unique sett-years: ",nrow(key))
if(any(key$n_no_coord>0 & key$n_polygon_matches>0) ||
 any(key$n_outside>0 & key$n_polygon_matches>0))stop("Contradictory match statuses")
annual <- key %>% count(year,category,name="n_sett_years") %>%
 pivot_wider(names_from=category,values_from=n_sett_years,values_fill=0) %>%
 arrange(year)
ambiguous <- key %>% filter(n_polygon_matches>1 | has_boundary) %>%
 arrange(desc(n_polygon_matches),year,sett_id)
nontrivial <- x %>% filter(!is.na(polygon_id)) %>%
 group_by(year,sett_id,territory_name) %>% 
 summarise(n_polygon_features=n_distinct(polygon_id),.groups="drop") %>%
 filter(n_polygon_features>1) %>% arrange(desc(n_polygon_features),year,sett_id)
write_csv(annual,file.path(dir,"audit_unique_sett_years_by_year.csv"))
write_csv(ambiguous,file.path(dir,"audit_ambiguous_sett_years.csv"))
write_csv(nontrivial,file.path(dir,"audit_duplicate_territory_names_at_sett.csv"))
cat("\nCOUNTS OF DISTINCT SETT-YEARS BY CATEGORY (not polygon rows):\n")
print(as.data.frame(key %>% count(category, name="n_sett_years")),row.names=FALSE)
cat("\nYEARLY QA (especially 2017 onward):\n")
print(as.data.frame(annual %>% filter(year>=2015)),row.names=FALSE)
cat("\nTOP 25 AMBIGUOUS SETT-YEARS:\n")
print(as.data.frame(head(ambiguous,25)),row.names=FALSE)
cat("\nSETT-YEARS WITH MULTIPLE POLYGON FEATURES USING THE SAME TERRITORY NAME: ",
 nrow(nontrivial),"\n",sep="")
cat("\nWrote 3 audit CSVs under ",dir,"\n",sep="")
