# =============================================================================
# WOODCHESTER SPATIAL INFECTION-PRESSURE INPUT AUDIT
# =============================================================================

library(tidyverse)

MOVE_FILE <- "data/badger_movement_posterior_histories_1285_V6_FINAL30K.rds"
PAIR_FILE <- "data/badger_phase2_paired_latent_inputs.rds"
INF_FILE  <- "data/badger_infection_trajectories_all_tests_inferred.rds"
ENC_FILE  <- "data/badger_encounters_useful.rds"
CHAIN_FILES <- c(
  "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_1_FINAL30K.rds",
  "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_2_FINAL30K.rds",
  "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_3_FINAL30K.rds"
)

for(f in c(MOVE_FILE,PAIR_FILE,INF_FILE,ENC_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)
mov <- readRDS(MOVE_FILE); paired <- readRDS(PAIR_FILE); inf <- readRDS(INF_FILE); enc <- readRDS(ENC_FILE)
if(!is.data.frame(enc)) stop("badger_encounters_useful.rds is not a data.frame/tibble.")
dir.create("results",showWarnings=FALSE,recursive=TRUE)

norm_name <- function(x) gsub("[^a-z0-9]","",tolower(x))
pick_col <- function(df,candidates,label,required=FALSE){
  nn <- setNames(names(df),norm_name(names(df))); cand <- norm_name(candidates); hit <- cand[cand%in%names(nn)]
  if(length(hit)){ out <- unname(nn[hit[1]]); cat(label,":",out,"\n"); return(out) }
  cat(label,": NOT FOUND\n")
  if(required) stop("Required column not found for ",label,". Available names:\n",paste(names(df),collapse=", "))
  NULL
}
object_inventory <- function(x){
  if(!is.list(x)) return(tibble())
  bind_rows(lapply(names(x),function(nm){ z <- x[[nm]]; tibble(element=nm,class=paste(class(z),collapse="/"),dim=if(is.null(dim(z))) NA_character_ else paste(dim(z),collapse=" x "),length=length(z),has_colnames=!is.null(colnames(z))) }))
}
find_named_matrix_columns <- function(x,patterns){
  out <- list(); if(!is.list(x)) return(tibble())
  for(nm in names(x)){
    z <- x[[nm]]
    if(is.matrix(z) || is.data.frame(z)){
      cn <- colnames(z)
      if(!is.null(cn)){
        keep <- Reduce(`|`,lapply(patterns,function(p) grepl(p,cn,ignore.case=TRUE)))
        if(any(keep)) out[[length(out)+1L]] <- tibble(element=nm,nrow=nrow(z),ncol=ncol(z),n_matching=sum(keep),examples=paste(head(cn[keep],8),collapse=" | "))
      }
    }
  }
  bind_rows(out)
}
nearest_year_distance <- function(observed_years,target_year){ if(!length(observed_years)) return(NA_integer_); min(abs(observed_years-target_year)) }

cat("\n============================================================\nA. MOVEMENT POSTERIOR OBJECT\n============================================================\n")
print(object_inventory(mov),n=Inf,width=Inf)
if(is.null(mov$interval_index)) stop("Movement posterior object has no interval_index.")
idx <- as_tibble(mov$interval_index) %>% mutate(interval_col=row_number())
cat("\ninterval_index columns:\n"); print(names(idx))
tattoo_idx <- pick_col(idx,c("tattoo","id","animal_id","badger_id"),"Movement interval tattoo",TRUE)
from_year_idx <- pick_col(idx,c("from_year","origin_year","year_from","start_year"),"Movement interval from-year",TRUE)
to_year_idx <- pick_col(idx,c("to_year","destination_year","year_to","end_year"),"Movement interval to-year",TRUE)
idx <- idx %>% mutate(audit_tattoo=trimws(as.character(.data[[tattoo_idx]])),audit_from_year=as.integer(.data[[from_year_idx]]),audit_to_year=as.integer(.data[[to_year_idx]]))
cat("Movement intervals:",nrow(idx),"\nMovement badgers:",n_distinct(idx$audit_tattoo),"\nMovement year range:",min(idx$audit_from_year,na.rm=TRUE),"-",max(idx$audit_to_year,na.rm=TRUE),"\n")
coord_like_idx <- names(idx)[grepl("(^x$|^y$|east|north|coord|activity|centre|center|from.*x|from.*y|to.*x|to.*y)",names(idx),ignore.case=TRUE)]
cat("\nCoordinate-like interval_index fields:\n"); if(length(coord_like_idx)) print(coord_like_idx) else cat("NONE\n")
move_matrix_hits <- find_named_matrix_columns(mov,c("^S\\[","activity","centre","center","AC\\[","^X\\[","^Y\\["))
cat("\nTop-level movement object matrices with AC/coordinate-like columns:\n"); if(nrow(move_matrix_hits)) print(move_matrix_hits,n=Inf,width=Inf) else cat("NONE FOUND\n")

cat("\n============================================================\nB. FINAL MOVEMENT CHAIN FILES\n============================================================\n")
chain_audit <- list(); chain_ac_hits <- list()
for(cc in seq_along(CHAIN_FILES)){
  f <- CHAIN_FILES[cc]
  if(!file.exists(f)){ cat("\nCHAIN",cc,": MISSING:",f,"\n"); chain_audit[[cc]] <- tibble(chain=cc,file=f,exists=FALSE,top_elements=NA_integer_,ac_matching_columns=NA_integer_); next }
  cat("\nCHAIN",cc,":",f,"\n"); ch <- readRDS(f); inv <- object_inventory(ch); print(inv,n=Inf,width=Inf)
  hits <- find_named_matrix_columns(ch,c("^S\\[","activity","centre","center","AC\\[","^X\\[","^Y\\["))
  cat("Potential stored activity-centre columns:\n")
  if(nrow(hits)){ print(hits,n=Inf,width=Inf); hits$chain <- cc; chain_ac_hits[[cc]] <- hits } else cat("NONE FOUND AT TOP LEVEL\n")
  sample_names <- names(ch)[grepl("sample|mcmc|draw|posterior",names(ch),ignore.case=TRUE)]
  if(length(sample_names)){
    cat("Samples/draw-like elements:",paste(sample_names,collapse=", "),"\n")
    for(sn in sample_names){ z <- ch[[sn]]; if((is.matrix(z)||is.data.frame(z))&&!is.null(colnames(z))){ cat("  ",sn," first 25 columns:\n",sep=""); print(head(colnames(z),25)) } }
  }
  chain_audit[[cc]] <- tibble(chain=cc,file=f,exists=TRUE,top_elements=nrow(inv),ac_matching_columns=if(nrow(hits)) sum(hits$n_matching) else 0L)
  rm(ch); invisible(gc())
}
chain_audit <- bind_rows(chain_audit); chain_ac_hits <- bind_rows(chain_ac_hits)

cat("\n============================================================\nC. ENCOUNTER-LEVEL SPATIAL FIELDS\n============================================================\n")
cat("Encounter rows:",nrow(enc),"\nEncounter columns:\n"); print(names(enc))
tattoo_col <- pick_col(enc,c("tattoo","id","animal_id","badger_id"),"Encounter tattoo",TRUE)
year_col <- pick_col(enc,c("year","capture_year","capyear"),"Encounter year",FALSE)
date_col <- pick_col(enc,c("capdate","capture_date","date","capturedate"),"Encounter date",FALSE)
if(is.null(year_col)&&is.null(date_col)) stop("Could not find encounter year or date.")
enc$audit_year <- if(is.null(year_col)) as.integer(format(as.Date(enc[[date_col]]),"%Y")) else as.integer(enc[[year_col]])
enc$audit_tattoo <- trimws(as.character(enc[[tattoo_col]]))
sett_col <- pick_col(enc,c("sett","sett_name","settname","sett_id","settid"),"Encounter sett",FALSE)
socg_col <- pick_col(enc,c("socg","social_group","socialgroup","recorded_social_group","recordedsocialgroup"),"Encounter social group",FALSE)
x_col <- pick_col(enc,c("x","easting","eastings","east","x_coord","xcoord","sett_x","settx","os_easting","oseasting"),"Encounter X/Easting",FALSE)
y_col <- pick_col(enc,c("y","northing","northings","north","y_coord","ycoord","sett_y","setty","os_northing","osnorthing"),"Encounter Y/Northing",FALSE)
coord_available <- !is.null(x_col)&&!is.null(y_col)
if(coord_available){ enc$audit_x <- suppressWarnings(as.numeric(enc[[x_col]])); enc$audit_y <- suppressWarnings(as.numeric(enc[[y_col]])); enc$audit_has_xy <- is.finite(enc$audit_x)&is.finite(enc$audit_y); cat("Rows with finite XY:",sum(enc$audit_has_xy),"/",nrow(enc),sprintf("(%.1f%%)",100*mean(enc$audit_has_xy)),"\n") } else { enc$audit_x <- NA_real_; enc$audit_y <- NA_real_; enc$audit_has_xy <- FALSE; cat("No explicit XY coordinate pair found in encounters_useful.\n") }
enc$audit_sett <- if(!is.null(sett_col)) trimws(as.character(enc[[sett_col]])) else NA_character_
enc$audit_socg <- if(!is.null(socg_col)) trimws(as.character(enc[[socg_col]])) else NA_character_
if(!is.null(sett_col)) cat("Rows with sett:",sum(!is.na(enc$audit_sett)&enc$audit_sett!=""),"\n")
if(!is.null(socg_col)) cat("Rows with social group:",sum(!is.na(enc$audit_socg)&enc$audit_socg!=""),"\n")

cat("\n============================================================\nD. ANNUAL LOCATION SUPPORT BETWEEN FIRST AND LAST ENCOUNTER\n============================================================\n")
annual_obs <- enc %>% filter(!is.na(audit_tattoo),audit_tattoo!="",!is.na(audit_year)) %>% group_by(audit_tattoo,audit_year) %>% summarise(n_encounters=n(),has_exact_xy=any(audit_has_xy),n_distinct_xy=if(any(audit_has_xy)) n_distinct(paste(audit_x[audit_has_xy],audit_y[audit_has_xy],sep="|")) else 0L,has_sett=any(!is.na(audit_sett)&audit_sett!=""),n_sett=n_distinct(audit_sett[!is.na(audit_sett)&audit_sett!=""]),has_socg=any(!is.na(audit_socg)&audit_socg!=""),n_socg=n_distinct(audit_socg[!is.na(audit_socg)&audit_socg!=""]),.groups="drop")
bounds <- annual_obs %>% group_by(audit_tattoo) %>% summarise(first_year=min(audit_year),last_year=max(audit_year),.groups="drop")
annual_grid <- bounds %>% rowwise() %>% mutate(audit_year=list(seq(first_year,last_year))) %>% unnest(audit_year) %>% ungroup() %>% left_join(annual_obs,by=c("audit_tattoo","audit_year")) %>% mutate(across(c(n_encounters,n_distinct_xy,n_sett,n_socg),~replace_na(.x,0)),across(c(has_exact_xy,has_sett,has_socg),~replace_na(.x,FALSE)))
obs_years_xy <- split(annual_obs$audit_year[annual_obs$has_exact_xy],annual_obs$audit_tattoo[annual_obs$has_exact_xy])
obs_years_socg <- split(annual_obs$audit_year[annual_obs$has_socg],annual_obs$audit_tattoo[annual_obs$has_socg])
annual_grid$nearest_xy_year_distance <- mapply(function(id,yr){ yrs <- obs_years_xy[[id]]; if(is.null(yrs)) NA_integer_ else nearest_year_distance(yrs,yr) },annual_grid$audit_tattoo,annual_grid$audit_year)
annual_grid$nearest_socg_year_distance <- mapply(function(id,yr){ yrs <- obs_years_socg[[id]]; if(is.null(yrs)) NA_integer_ else nearest_year_distance(yrs,yr) },annual_grid$audit_tattoo,annual_grid$audit_year)
movement_ids <- unique(idx$audit_tattoo); infection_ids <- trimws(as.character(inf$tattoo))
annual_grid <- annual_grid %>% mutate(in_movement_1285=audit_tattoo%in%movement_ids,in_infection_model=audit_tattoo%in%infection_ids)
coverage_summary <- function(d,label){
  if(!nrow(d)) return(tibble(population=label,badgers=0L,badger_years=0L,exact_xy_pct=NA_real_,xy_within_1yr_pct=NA_real_,xy_within_2yr_pct=NA_real_,exact_socg_pct=NA_real_,socg_within_1yr_pct=NA_real_,socg_within_2yr_pct=NA_real_))
  tibble(population=label,badgers=n_distinct(d$audit_tattoo),badger_years=nrow(d),exact_xy_pct=100*mean(d$has_exact_xy),xy_within_1yr_pct=100*mean(d$nearest_xy_year_distance<=1,na.rm=TRUE),xy_within_2yr_pct=100*mean(d$nearest_xy_year_distance<=2,na.rm=TRUE),exact_socg_pct=100*mean(d$has_socg),socg_within_1yr_pct=100*mean(d$nearest_socg_year_distance<=1,na.rm=TRUE),socg_within_2yr_pct=100*mean(d$nearest_socg_year_distance<=2,na.rm=TRUE))
}
coverage <- bind_rows(coverage_summary(annual_grid%>%filter(in_infection_model),"All infection-model badgers"),coverage_summary(annual_grid%>%filter(in_movement_1285),"Phase-2 movement badgers"),coverage_summary(annual_grid%>%filter(in_movement_1285,in_infection_model),"Matched Phase-2 movement+infection"))
cat("\nAnnual coverage summary:\n"); print(coverage,n=Inf,width=Inf)
annual_calendar <- annual_grid %>% filter(in_infection_model) %>% group_by(audit_year) %>% summarise(alive_grid_badgers=n(),exact_xy=sum(has_exact_xy),xy_within_1yr=sum(nearest_xy_year_distance<=1,na.rm=TRUE),xy_within_2yr=sum(nearest_xy_year_distance<=2,na.rm=TRUE),exact_socg=sum(has_socg),socg_within_1yr=sum(nearest_socg_year_distance<=1,na.rm=TRUE),.groups="drop") %>% mutate(exact_xy_pct=100*exact_xy/alive_grid_badgers,xy_within_1yr_pct=100*xy_within_1yr/alive_grid_badgers,xy_within_2yr_pct=100*xy_within_2yr/alive_grid_badgers,exact_socg_pct=100*exact_socg/alive_grid_badgers,socg_within_1yr_pct=100*socg_within_1yr/alive_grid_badgers)

cat("\n============================================================\nE. PHASE-2 MOVEMENT-INTERVAL ENDPOINT SUPPORT\n============================================================\n")
phase2_endpoints <- bind_rows(idx%>%transmute(audit_tattoo,audit_year=audit_from_year,endpoint="origin"),idx%>%transmute(audit_tattoo,audit_year=audit_to_year,endpoint="destination")) %>% distinct() %>% left_join(annual_grid%>%select(audit_tattoo,audit_year,has_exact_xy,nearest_xy_year_distance,has_socg,nearest_socg_year_distance),by=c("audit_tattoo","audit_year"))
endpoint_coverage <- phase2_endpoints %>% group_by(endpoint) %>% summarise(rows=n(),exact_xy_pct=100*mean(has_exact_xy,na.rm=TRUE),xy_within_1yr_pct=100*mean(nearest_xy_year_distance<=1,na.rm=TRUE),xy_within_2yr_pct=100*mean(nearest_xy_year_distance<=2,na.rm=TRUE),exact_socg_pct=100*mean(has_socg,na.rm=TRUE),socg_within_1yr_pct=100*mean(nearest_socg_year_distance<=1,na.rm=TRUE),.groups="drop")
print(endpoint_coverage,n=Inf,width=Inf)

cat("\n============================================================\nF. SOCIAL-GROUP/YEAR SUPPORT\n============================================================\n")
group_year_support <- tibble()
if(!is.null(socg_col)){
  group_year_support <- enc %>% filter(!is.na(audit_tattoo),audit_tattoo!="",!is.na(audit_year),!is.na(audit_socg),audit_socg!="",audit_tattoo%in%infection_ids) %>% distinct(audit_tattoo,audit_year,audit_socg) %>% count(audit_year,audit_socg,name="observed_badgers") %>% arrange(audit_year,audit_socg)
  cat("Observed infection-model group-year cells:",nrow(group_year_support),"\nMedian observed badgers/group-year:",median(group_year_support$observed_badgers),"\nGroup-years with >=2 observed badgers:",sum(group_year_support$observed_badgers>=2),"\nGroup-years with >=5 observed badgers:",sum(group_year_support$observed_badgers>=5),"\n")
}else cat("No social-group field available; group-pressure route unavailable from this RDS alone.\n")

cat("\n============================================================\nG. OTHER POSSIBLE SPATIAL FILES\n============================================================\n")
candidate_files <- c(list.files("data",recursive=TRUE,full.names=TRUE),list.files("results",recursive=TRUE,full.names=TRUE))
candidate_files <- candidate_files[grepl("sett|coord|spatial|location|detector|activity|centre|center|grid|lookup",basename(candidate_files),ignore.case=TRUE)]
if(length(candidate_files)) print(candidate_files) else cat("No obviously named spatial support files found.\n")

cat("\n============================================================\nH. DECISION SUMMARY\n============================================================\n")
ac_saved <- nrow(chain_ac_hits)>0L || nrow(move_matrix_hits)>0L
cat("Posterior activity-centre coordinates apparently saved:",ifelse(ac_saved,"YES - inspect hits above","NO obvious saved AC columns found"),"\n")
cat("Encounter XY coordinate pair available:",ifelse(coord_available,"YES","NO"),"\n")
cat("Encounter social-group field available:",ifelse(!is.null(socg_col),"YES","NO"),"\n")
cat("\nInterpretation guide:\n")
cat("1. If posterior annual AC coordinates are saved, use them for focal 1,285 movement badgers.\n")
cat("2. Infection pressure sources extend beyond those 1,285; inspect all-infection-badger coverage.\n")
cat("3. +/-1y and +/-2y values are diagnostics only; this script does NOT endorse LOCF.\n")
cat("4. Same-group and distance-weighted pressure should remain separate candidate mechanisms.\n")

audit <- list(movement_object_inventory=object_inventory(mov),movement_interval_index=idx,movement_matrix_ac_hits=move_matrix_hits,chain_audit=chain_audit,chain_ac_hits=chain_ac_hits,encounter_fields=list(tattoo=tattoo_col,year=year_col,date=date_col,sett=sett_col,social_group=socg_col,x=x_col,y=y_col),annual_observed=annual_obs,annual_grid=annual_grid,annual_coverage=coverage,annual_calendar_coverage=annual_calendar,phase2_endpoint_coverage=endpoint_coverage,group_year_support=group_year_support,candidate_spatial_files=candidate_files)
saveRDS(audit,"results/spatial_pressure_input_audit.rds")
write_csv(coverage,"results/spatial_pressure_input_audit_summary.csv")
write_csv(annual_calendar,"results/spatial_pressure_annual_coverage.csv")
if(nrow(group_year_support)) write_csv(group_year_support,"results/spatial_pressure_group_year_support.csv")
cat("\nSaved: results/spatial_pressure_input_audit.rds\nSaved: results/spatial_pressure_input_audit_summary.csv\nSaved: results/spatial_pressure_annual_coverage.csv\n")
if(nrow(group_year_support)) cat("Saved: results/spatial_pressure_group_year_support.csv\n")
cat("\nAUDIT COMPLETE\n")
