# =============================================================================
# PHASE 3 / P3_01 — SOCIAL-GROUP ASSIGNMENT AUDIT
#
# Purpose
#   Decide how social-group membership should be represented BEFORE building the
#   group-year epidemiological panel.
#
# Principles
#   1. Recorded SOCG is the primary empirical membership source.
#   2. Multiple recorded groups within a badger-year are retained and audited;
#      a modal group is produced only as a candidate resident assignment.
#   3. Posterior V9 activity centres (S) are mapped to the static SG raster only
#      as a spatial consistency diagnostic. They are NOT allowed to overwrite
#      recorded SOCG, because the V9 movement model already contains the SG
#      resistance surface and that would be partly circular.
#   4. Consecutive recorded SOCG changes are checked against posterior movement
#      distance and high-mobility probability. This helps separate genuine
#      spatial movement from possible label/boundary changes.
#
# Outputs
#   results/Phase3/P3_01_annual_recorded_membership.csv
#   results/Phase3/P3_01_socg_to_static_sg_mapping.csv
#   results/Phase3/P3_01_archive_membership_comparison.csv
#   results/Phase3/P3_01_group_transition_spatial_audit.csv
#   data/phase3/P3_annual_recorded_membership.rds
#
# No biological model is fitted here.
# =============================================================================

suppressPackageStartupMessages(library(tidyverse))

ARCHIVE_FILE <- "data/badger_V9_spatial_activity_centre_archive_1500.rds"
ENC_FILE <- "data/badger_encounters_useful.rds"
SPATIAL_FILE <- "data/spatial/V3_spatial_inputs_50m_2km.rds"
SETT_MASTER <- "data/movement_audit/sett_master.csv"

for(f in c(ARCHIVE_FILE, ENC_FILE, SPATIAL_FILE, SETT_MASTER))
  if(!file.exists(f)) stop("Missing required file: ", f)

dir.create("results/Phase3", recursive=TRUE, showWarnings=FALSE)
dir.create("data/phase3", recursive=TRUE, showWarnings=FALSE)

archive <- readRDS(ARCHIVE_FILE)
enc <- as_tibble(readRDS(ENC_FILE))
sp <- readRDS(SPATIAL_FILE)
sett_master <- readr::read_csv(SETT_MASTER, show_col_types=FALSE)

required_archive <- c("Sx_draws","Sy_draws","movement_draws","ac_index","disp_index")
miss <- setdiff(required_archive,names(archive))
if(length(miss)) stop("Spatial archive missing: ",paste(miss,collapse=", "))

required_enc <- c("tattoo","capture_date","sett","socg")
miss <- setdiff(required_enc,names(enc))
if(length(miss)) stop("Encounter data missing: ",paste(miss,collapse=", "))

required_sp <- c("SG_mat","xmin","xmax","ymin","ymax","cell_size","n_rows","n_cols")
miss <- setdiff(required_sp,names(sp))
if(length(miss)) stop("Spatial object missing: ",paste(miss,collapse=", "))

norm_key <- function(x)
  gsub("[^A-Z0-9]","",toupper(trimws(as.character(x))))

# Known historical label harmonisations already used in the project.
canonical_socg <- function(x){
  z <- norm_key(x)
  dplyr::recode(z,
    "CHESTNUT"="BEECH",
    "HOLLOWTREE"="NETTLE",
    .default=z
  )
}

cat("\n============================================================\n")
cat("P3_01 — SOCIAL-GROUP ASSIGNMENT AUDIT\n")
cat("============================================================\n")

# =============================================================================
# A. OBSERVED ANNUAL SOCIAL-GROUP MEMBERSHIP
#    Published Woodchester rule: Vicente et al. (2007), extending Rogers et al.
# =============================================================================

live <- enc
if("has_live_capture" %in% names(live))
  live <- live %>% filter(has_live_capture %in% TRUE)

live <- live %>%
  mutate(
    tattoo=trimws(as.character(tattoo)),
    capture_date=as.Date(capture_date),
    year=as.integer(format(capture_date,"%Y")),
    socg_raw=trimws(as.character(socg)),
    socg_key=canonical_socg(socg_raw),
    sett_key=norm_key(sett)
  ) %>%
  filter(tattoo!="",!is.na(year))

alias_audit <- live %>%
  filter(!is.na(socg_raw),socg_raw!="",norm_key(socg_raw)!=socg_key) %>%
  count(socg_raw,socg_key,sort=TRUE)

cat("\nA. RECORDED ANNUAL MEMBERSHIP — PUBLISHED WOODCHESTER RULE\n")
cat("Live encounter rows:",nrow(live),"\n")
cat("Badgers:",n_distinct(live$tattoo),"\n")
cat("Years:",min(live$year,na.rm=TRUE),"-",max(live$year,na.rm=TRUE),"\n")
cat("Rows affected by known SOCG aliases:",sum(alias_audit$n,na.rm=TRUE),"\n")
if(nrow(alias_audit)) print(alias_audit,n=Inf,width=Inf)

# Rogers et al. (1998): annual membership/group size used the group in which an
# animal appeared most often across captures that year; a two-capture/two-group
# tie was assigned to the first capture group.
#
# Vicente et al. (2007) formalised a five-step hierarchy:
#   1) group most frequently caught in current year;
#   2) use adjacent-year allocation(s);
#   3) use capture frequency across current + adjacent years;
#   4) use nearest last/first capture around the year's boundaries, among the
#      groups still tied after step 3;
#   5) first relevant capture if still indeterminate.
#
# We implement that hierarchy transparently. Criterion 2 is operationalised
# using the unique modal capture group in each adjacent year, because those raw
# capture records are available directly and avoid circular recursive allocation.

live_sg <- live %>%
  filter(!is.na(socg_key),socg_key!="",!is.na(capture_date)) %>%
  arrange(tattoo,capture_date)

annual_all <- live %>%
  group_by(tattoo,year) %>%
  summarise(
    n_live_records=n(),
    n_socg_records=sum(!is.na(socg_key)&socg_key!=""),
    n_distinct_socg=n_distinct(socg_key[!is.na(socg_key)&socg_key!=""]),
    .groups="drop"
  )

assign_published_group <- function(tat,y){
  h <- live_sg %>% filter(tattoo==tat)
  cur <- h %>% filter(year==y)
  if(!nrow(cur))
    return(tibble(
      annual_socg=NA_character_,assignment_criterion=NA_integer_,
      assignment_rule="NO_RECORDED_SOCG",annual_socg_n=0L,
      annual_socg_share=NA_real_,n_tied_current=NA_integer_
    ))

  cur_counts <- cur %>% count(socg_key,name="n",sort=TRUE)
  top_n <- max(cur_counts$n)
  current_candidates <- cur_counts %>% filter(n==top_n) %>% pull(socg_key)
  current_share <- top_n/sum(cur_counts$n)

  # Criterion 1: unique current-year modal group.
  if(length(current_candidates)==1L)
    return(tibble(
      annual_socg=current_candidates,assignment_criterion=1L,
      assignment_rule="C1_CURRENT_YEAR_MODE",annual_socg_n=top_n,
      annual_socg_share=current_share,n_tied_current=1L
    ))

  candidates <- current_candidates

  # Criterion 2: adjacent-year unique modal allocations as tie-break evidence.
  adj_unique_mode <- function(yy){
    z <- h %>% filter(year==yy) %>% count(socg_key,name="n",sort=TRUE)
    if(!nrow(z)) return(NA_character_)
    ztop <- z %>% filter(n==max(n))
    if(nrow(ztop)==1L) ztop$socg_key[1] else NA_character_
  }
  adj <- c(adj_unique_mode(y-1L),adj_unique_mode(y+1L))
  adj <- adj[!is.na(adj) & adj %in% candidates]
  if(length(adj)){
    tt <- sort(table(adj),decreasing=TRUE)
    if(length(tt)==1L || as.numeric(tt[1])>as.numeric(tt[2]))
      return(tibble(
        annual_socg=names(tt)[1],assignment_criterion=2L,
        assignment_rule="C2_ADJACENT_YEAR_ALLOCATION",annual_socg_n=top_n,
        annual_socg_share=current_share,n_tied_current=length(current_candidates)
      ))
  }

  # Criterion 3: combined current + both adjacent-year capture frequency.
  tri <- h %>%
    filter(year %in% (y-1L):(y+1L),socg_key %in% candidates) %>%
    count(socg_key,name="n",sort=TRUE)
  if(nrow(tri)){
    tri_top <- tri %>% filter(n==max(n))
    candidates <- tri_top$socg_key
    if(length(candidates)==1L)
      return(tibble(
        annual_socg=candidates,assignment_criterion=3L,
        assignment_rule="C3_THREE_YEAR_CAPTURE_MODE",annual_socg_n=top_n,
        annual_socg_share=current_share,n_tied_current=length(current_candidates)
      ))
  }

  # Criterion 4: nearest relevant capture before/after the current year.
  y_start <- as.Date(sprintf("%d-01-01",y))
  y_end <- as.Date(sprintf("%d-12-31",y))
  around <- bind_rows(
    h %>%
      filter(capture_date<y_start,socg_key %in% candidates) %>%
      arrange(desc(capture_date)) %>%
      slice(1L) %>%
      transmute(socg_key,gap=as.numeric(y_start-capture_date)),
    h %>%
      filter(capture_date>y_end,socg_key %in% candidates) %>%
      arrange(capture_date) %>%
      slice(1L) %>%
      transmute(socg_key,gap=as.numeric(capture_date-y_end))
  )
  if(nrow(around)){
    around_top <- around %>% filter(gap==min(gap))
    if(n_distinct(around_top$socg_key)==1L)
      return(tibble(
        annual_socg=around_top$socg_key[1],assignment_criterion=4L,
        assignment_rule="C4_NEAREST_BOUNDARY_CAPTURE",annual_socg_n=top_n,
        annual_socg_share=current_share,n_tied_current=length(current_candidates)
      ))
  }

  # Criterion 5: first relevant current-year capture among remaining candidates.
  first_rel <- cur %>%
    filter(socg_key %in% candidates) %>%
    arrange(capture_date) %>%
    slice(1L)
  tibble(
    annual_socg=first_rel$socg_key[1],assignment_criterion=5L,
    assignment_rule="C5_FIRST_RELEVANT_CAPTURE",annual_socg_n=top_n,
    annual_socg_share=current_share,n_tied_current=length(current_candidates)
  )
}

annual_assignment <- annual_all %>%
  select(tattoo,year) %>%
  mutate(.assigned=map2(tattoo,year,assign_published_group)) %>%
  unnest(.assigned)

annual_membership <- annual_all %>%
  left_join(annual_assignment,by=c("tattoo","year")) %>%
  mutate(
    membership_class=case_when(
      is.na(annual_socg) ~ "NO_RECORDED_SOCG",
      assignment_criterion==1L & n_distinct_socg==1L ~ "SINGLE_RECORDED_SOCG",
      assignment_criterion==1L ~ "MULTIPLE_UNIQUE_MODE",
      TRUE ~ paste0("TIE_RESOLVED_C",assignment_criterion)
    ),
    candidate_resident_socg=annual_socg
  )

# Keep the raw annual group counts so later analyses can distinguish residency
# from excursions rather than throwing the non-resident captures away.
annual_counts <- live_sg %>%
  count(tattoo,year,socg_key,name="n_records") %>%
  group_by(tattoo,year) %>%
  mutate(
    total_socg_records=sum(n_records),
    share=n_records/total_socg_records
  ) %>%
  ungroup()

membership_summary <- annual_membership %>%
  count(assignment_criterion,assignment_rule,membership_class,name="badger_years") %>%
  mutate(pct=100*badger_years/sum(badger_years))

print(membership_summary,n=Inf,width=Inf)
cat("Percent allocated by published criterion 1:",
    sprintf("%.2f%%",100*mean(annual_membership$assignment_criterion==1L,na.rm=TRUE)),"\n")
cat("Badger-years requiring criteria 2-5:",
    sum(annual_membership$assignment_criterion %in% 2:5,na.rm=TRUE),"\n")

# =============================================================================
# B. RECORDED SOCG VERSUS STATIC SG RASTER IDENTIFIER
# =============================================================================

needed_sm <- c("Sett_original","Sett_Clean","SG_id")
miss <- setdiff(needed_sm,names(sett_master))
if(length(miss)) stop("sett_master missing: ",paste(miss,collapse=", "))

sett_lookup <- bind_rows(
  sett_master %>% transmute(sett_key=norm_key(Sett_original),SG_id=as.integer(SG_id)),
  sett_master %>% transmute(sett_key=norm_key(Sett_Clean),SG_id=as.integer(SG_id))
) %>%
  filter(sett_key!="",!is.na(SG_id)) %>%
  group_by(sett_key) %>%
  summarise(
    n_static_ids=n_distinct(SG_id),
    SG_id=first(SG_id),
    .groups="drop"
  )

if(any(sett_lookup$n_static_ids>1L))
  stop("At least one sett key maps to more than one static SG_id.")

socg_static_counts <- live %>%
  filter(!is.na(socg_key),socg_key!="",sett_key!="") %>%
  left_join(sett_lookup %>% select(sett_key,SG_id),by="sett_key") %>%
  filter(!is.na(SG_id),SG_id!=999L) %>%
  count(socg_key,SG_id,name="n_records") %>%
  group_by(socg_key) %>%
  arrange(desc(n_records),SG_id,.by_group=TRUE) %>%
  mutate(
    total_core_records=sum(n_records),
    static_share=n_records/total_core_records,
    rank=row_number()
  ) %>%
  ungroup()

socg_static_map <- socg_static_counts %>%
  filter(rank==1L) %>%
  transmute(
    socg_key,
    static_SG_id=SG_id,
    mapping_records=total_core_records,
    static_mapping_share=static_share,
    static_mapping_confident=static_mapping_share>=0.80
  )

cat("\nB. RECORDED SOCG -> STATIC SG-ID MAPPING\n")
cat("Recorded SOCG labels with a core-sett mapping:",nrow(socg_static_map),"\n")
cat("Confident mappings (>=80% same static SG):",
    sum(socg_static_map$static_mapping_confident),"\n")
print(
  socg_static_map %>%
    arrange(static_mapping_confident,static_mapping_share),
  n=Inf,width=Inf
)

# =============================================================================
# C. POSTERIOR S -> STATIC SG RASTER (CONSISTENCY ONLY)
# =============================================================================

Sx <- as.matrix(archive$Sx_draws)
Sy <- as.matrix(archive$Sy_draws)
ac <- as_tibble(archive$ac_index) %>% mutate(ac_col=row_number())

if(!identical(dim(Sx),dim(Sy))) stop("Sx/Sy dimensions differ.")
if(ncol(Sx)!=nrow(ac)) stop("Activity-centre index does not match S columns.")

nr <- as.integer(sp$n_rows)
nc <- as.integer(sp$n_cols)
cs <- as.numeric(sp$cell_size)

cc <- floor((Sx-as.numeric(sp$xmin))/cs)+1L
rr <- floor((as.numeric(sp$ymax)-Sy)/cs)+1L

in_bounds <- cc>=1L & cc<=nc & rr>=1L & rr<=nr &
  is.finite(cc) & is.finite(rr)

cc_safe <- pmax(1L,pmin(nc,cc))
rr_safe <- pmax(1L,pmin(nr,rr))
lin <- rr_safe+(cc_safe-1L)*nr

sg_draws <- matrix(
  as.integer(sp$SG_mat[lin]),
  nrow=nrow(Sx),ncol=ncol(Sx)
)
sg_draws[!in_bounds] <- NA_integer_

post_sg_summary <- bind_rows(lapply(seq_len(ncol(sg_draws)),function(j){
  z <- sg_draws[,j]
  z <- z[!is.na(z)]
  if(!length(z))
    return(tibble(ac_col=j,posterior_modal_static_SG=NA_integer_,
                  posterior_modal_probability=NA_real_,
                  posterior_p_peripheral=NA_real_))
  tt <- sort(table(z),decreasing=TRUE)
  tibble(
    ac_col=j,
    posterior_modal_static_SG=as.integer(names(tt)[1]),
    posterior_modal_probability=as.numeric(tt[1])/length(z),
    posterior_p_peripheral=mean(z==999L)
  )
}))

comparison <- ac %>%
  select(ac_col,model_i,individual_id,tattoo,year,state_k) %>%
  left_join(
    annual_membership %>%
      select(tattoo,year,n_live_records,n_socg_records,n_distinct_socg,
             annual_socg,annual_socg_share,annual_socg_tied,
             membership_class,candidate_resident_socg),
    by=c("tattoo","year")
  ) %>%
  left_join(
    socg_static_map,
    by=c("candidate_resident_socg"="socg_key")
  ) %>%
  left_join(post_sg_summary,by="ac_col")

comparison$p_posterior_in_observed_static <- map2_dbl(
  comparison$ac_col,comparison$static_SG_id,
  function(j,g){
    if(is.na(g)) return(NA_real_)
    mean(sg_draws[,j]==g,na.rm=TRUE)
  }
)

comparison <- comparison %>%
  mutate(
    modal_static_agreement=case_when(
      !static_mapping_confident ~ NA,
      is.na(posterior_modal_static_SG) ~ NA,
      TRUE ~ posterior_modal_static_SG==static_SG_id
    )
  )

cat("\nC. POSTERIOR S -> STATIC SG CONSISTENCY\n")
cat("Archive-supported badger-years:",nrow(comparison),"\n")
cat("With candidate observed resident group:",
    sum(!is.na(comparison$candidate_resident_socg)),"\n")
cat("With confident observed SOCG -> static mapping:",
    sum(comparison$static_mapping_confident %in% TRUE),"\n")

cmp_supported <- comparison %>% filter(static_mapping_confident %in% TRUE)
if(nrow(cmp_supported)){
  cat("Modal posterior static-SG agreement:",
      sprintf("%.2f%%",100*mean(cmp_supported$modal_static_agreement,na.rm=TRUE)),"\n")
  cat("Median posterior probability in observed static SG:",
      sprintf("%.3f",median(cmp_supported$p_posterior_in_observed_static,na.rm=TRUE)),"\n")
  cat("Badger-years with <0.50 posterior probability in observed static SG:",
      sum(cmp_supported$p_posterior_in_observed_static<0.5,na.rm=TRUE),"\n")
}

# =============================================================================
# D. OBSERVED GROUP CHANGES VERSUS POSTERIOR SPATIAL MOVEMENT
# =============================================================================

D <- as.matrix(archive$movement_draws)
di <- as_tibble(archive$disp_index) %>%
  mutate(interval_col=row_number())

if(ncol(D)!=nrow(di)) stop("Movement draws do not match disp_index.")

# Locate each interval's two activity-centre columns.
ac_key <- ac %>% select(model_i,state_k,ac_col)
trans <- di %>%
  left_join(ac_key %>% rename(from_state_k=state_k,from_ac_col=ac_col),
            by=c("model_i","from_primary"="from_state_k")) %>%
  left_join(ac_key %>% rename(to_state_k=state_k,to_ac_col=ac_col),
            by=c("model_i","to_primary"="to_state_k")) %>%
  left_join(
    annual_membership %>%
      select(tattoo,year,from_socg=candidate_resident_socg,
             from_membership_class=membership_class),
    by=c("tattoo","from_year"="year")
  ) %>%
  left_join(
    annual_membership %>%
      select(tattoo,year,to_socg=candidate_resident_socg,
             to_membership_class=membership_class),
    by=c("tattoo","to_year"="year")
  ) %>%
  mutate(
    observed_group_change=case_when(
      is.na(from_socg)|is.na(to_socg) ~ NA,
      TRUE ~ from_socg!=to_socg
    ),
    p_high=colMeans(D)
  )

spatial_metrics <- bind_rows(lapply(seq_len(nrow(trans)),function(j){
  a <- trans$from_ac_col[j]
  b <- trans$to_ac_col[j]
  if(is.na(a)||is.na(b))
    return(tibble(interval_col=j,median_distance_m=NA_real_,
                  q025_distance_m=NA_real_,q975_distance_m=NA_real_))
  dd <- sqrt((Sx[,b]-Sx[,a])^2+(Sy[,b]-Sy[,a])^2)
  tibble(
    interval_col=j,
    median_distance_m=median(dd,na.rm=TRUE),
    q025_distance_m=quantile(dd,.025,na.rm=TRUE,names=FALSE),
    q975_distance_m=quantile(dd,.975,na.rm=TRUE,names=FALSE)
  )
}))

trans <- trans %>%
  mutate(interval_col=row_number()) %>%
  left_join(spatial_metrics,by="interval_col")

cat("\nD. RECORDED GROUP CHANGE VERSUS SPATIAL MOVEMENT\n")
trans_summary <- trans %>%
  filter(!is.na(observed_group_change)) %>%
  group_by(observed_group_change) %>%
  summarise(
    intervals=n(),
    median_p_high=median(p_high,na.rm=TRUE),
    pct_p_high_gt_05=100*mean(p_high>0.5,na.rm=TRUE),
    median_posterior_distance_m=median(median_distance_m,na.rm=TRUE),
    q25_distance_m=quantile(median_distance_m,.25,na.rm=TRUE),
    q75_distance_m=quantile(median_distance_m,.75,na.rm=TRUE),
    .groups="drop"
  )
print(trans_summary,n=Inf,width=Inf)

# A deliberately simple flag for later manual review; it is not a reclassification.
trans <- trans %>%
  mutate(
    group_change_low_spatial_support=
      observed_group_change %in% TRUE &
      p_high<0.20 &
      median_distance_m<250
  )

cat("Recorded group changes with low spatial-movement support:",
    sum(trans$group_change_low_spatial_support,na.rm=TRUE),"\n")

# =============================================================================
# SAVE
# =============================================================================

write_csv(
  annual_membership,
  "results/Phase3/P3_01_annual_recorded_membership.csv"
)
write_csv(
  socg_static_map,
  "results/Phase3/P3_01_socg_to_static_sg_mapping.csv"
)
write_csv(
  comparison,
  "results/Phase3/P3_01_archive_membership_comparison.csv"
)
write_csv(
  trans,
  "results/Phase3/P3_01_group_transition_spatial_audit.csv"
)

saveRDS(
  list(
    annual_membership=annual_membership,
    annual_group_counts=annual_counts,
    socg_static_mapping=socg_static_map,
    archive_comparison=comparison,
    transition_audit=trans,
    membership_summary=membership_summary,
    transition_summary=trans_summary,
    definition=list(
      primary_membership_source="recorded SOCG on live captures",
      candidate_resident_rule="published Woodchester hierarchy: Vicente et al. 2007 criteria 1-5, extending Rogers et al. 1998 annual modal-capture rule",
      multiple_or_tied="raw within-year SOCG counts retained; ties resolved with explicit published-style criterion and recorded in assignment_criterion",
      posterior_S_role="spatial consistency/connectivity only; does not overwrite recorded membership",
      static_SG_warning="V9 already used the static SG resistance surface, so S->SG agreement is not independent validation"
    )
  ),
  "data/phase3/P3_annual_recorded_membership.rds"
)

cat("\n============================================================\n")
cat("P3_01 COMPLETE\n")
cat("============================================================\n")
cat("Primary recommendation remains provisional until this audit is reviewed:\n")
cat("use recorded annual SOCG for epidemiological membership; use posterior S for spatial connectivity.\n")
