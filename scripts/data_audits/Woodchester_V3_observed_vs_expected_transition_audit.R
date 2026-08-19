# ============================================================
# WOODCHESTER V3 EMPIRICAL TRANSITION vs SPATIAL-AVAILABILITY AUDIT
#
# Purpose
# -------
# Compare the social/spatial category of OBSERVED consecutive-year movements
# with the category expected from distance + the actual irregular SG geometry
# alone, before fitting any SG-resistance parameter.
#
# For each observed annual origin:
#   1. choose an actual observed sett as the annual representative location;
#   2. classify the next consecutive-year observed destination as:
#        same_SG / neighbour_SG / nonneighbour_SG / peripheral;
#   3. from that origin location, sum a Gaussian movement kernel over ALL
#      available land-grid cells;
#   4. calculate the baseline probability mass available in each category;
#   5. compare the observed category with that baseline expectation.
#
# This does NOT fit a model and does NOT estimate beta_SG. It is a diagnostic
# for whether there appears to be excess same-SG fidelity beyond that expected
# from Euclidean distance and territory geometry alone.
#
# Run after the normal V3 data-preparation section AND after the spatial-audit
# adjacency objects have been created, or let this script rebuild adjacency.
#
# Required objects:
#   live, ids, grid, habitat_mat, SG_mat, zone_mat,
#   cell_size, grid_xmin, grid_ymax
#
# Useful if already present:
#   entry_group, adj_counts
# ============================================================

library(tidyverse)
library(sf)

# ---------------- USER OPTIONS ---------------------------------
# These are sensitivity values, not fitted estimates.
SIGMA_TEST <- c(60, 100, 150)

# Optional group-specific values close to the current non-centred development
# estimates. Change these later as the model stabilises.
SIGMA_BY_GROUP <- c(`1`=100, `2`=66)

# Gaussian search radius. At 4 sigma, residual mass is negligible for this audit.
N_SIGMA <- 4

OUT_DIR <- "results/V3_spatial_audit/observed_vs_expected"
dir.create(OUT_DIR, recursive=TRUE, showWarnings=FALSE)

# ---------------- CHECK REQUIRED OBJECTS ------------------------
req <- c("live","ids","grid","habitat_mat","SG_mat","zone_mat",
         "cell_size","grid_xmin","grid_ymax")
miss <- req[!vapply(req, exists, logical(1), inherits=TRUE)]
if(length(miss)) stop("Missing required objects: ", paste(miss, collapse=", "))

if(!all(c("tattoo","primary","x","y") %in% names(live)))
  stop("`live` must contain tattoo, primary, x and y.")

# Use primary_year if present; otherwise derive a label from primary.
if(!"primary_year" %in% names(live)) live$primary_year <- live$primary

# Attach entry group by tattoo if possible.
if(exists("entry_group") && length(entry_group)==length(ids)){
  entry_lookup <- tibble(tattoo=ids, entry_group=as.integer(entry_group))
} else {
  entry_lookup <- tibble(tattoo=ids, entry_group=NA_integer_)
}

# ---------------- GRID SETUP ------------------------------------
grid_sf <- st_as_sf(grid)
grid_xy <- st_coordinates(grid_sf)
land_idx <- which(grid$habitat==1)
core_ids <- sort(unique(grid$SG_id[grid$zone==1 & grid$SG_id!=999]))

# ---------------- REBUILD 4-NEIGHBOUR SG ADJACENCY IF NEEDED ----
if(!exists("adj_counts")){
  nr <- nrow(SG_mat); nc <- ncol(SG_mat)
  adj_counts <- matrix(0L,length(core_ids),length(core_ids),
                       dimnames=list(core_ids,core_ids))

  for(r in seq_len(nr)) for(c in seq_len(nc)){
    s0 <- SG_mat[r,c]; z0 <- zone_mat[r,c]
    if(z0!=1 || s0==999) next

    for(off in list(c(0L,1L),c(1L,0L))){
      rr <- r+off[1]; cc <- c+off[2]
      if(rr>nr || cc>nc) next
      s1 <- SG_mat[rr,cc]; z1 <- zone_mat[rr,cc]

      if(z1==1 && s1!=999 && s1!=s0){
        a <- match(as.character(s0),rownames(adj_counts))
        b <- match(as.character(s1),colnames(adj_counts))
        adj_counts[a,b] <- adj_counts[a,b]+1L
        adj_counts[b,a] <- adj_counts[b,a]+1L
      }
    }
  }
}

is_neighbour <- function(s0,s1){
  if(is.na(s0) || is.na(s1) || s0==999 || s1==999 || s0==s1) return(FALSE)
  if(!as.character(s0) %in% rownames(adj_counts) ||
     !as.character(s1) %in% colnames(adj_counts)) return(FALSE)
  adj_counts[as.character(s0),as.character(s1)] > 0
}

# ---------------- COORDINATE -> GRID LOOKUP ----------------------
lookup_xy <- function(x,y){
  col <- floor((x-grid_xmin)/cell_size)+1L
  row <- floor((grid_ymax-y)/cell_size)+1L
  inb <- row>=1L & row<=nrow(habitat_mat) & col>=1L & col<=ncol(habitat_mat)

  SG <- habitat <- zone <- rep(NA_integer_,length(x))
  ok <- which(inb)
  SG[ok] <- SG_mat[cbind(row[ok],col[ok])]
  habitat[ok] <- habitat_mat[cbind(row[ok],col[ok])]
  zone[ok] <- zone_mat[cbind(row[ok],col[ok])]

  tibble(row_R=row,col_R=col,in_bounds=inb,SG_id=SG,habitat=habitat,zone=zone)
}

# ================================================================
# 1. BUILD ANNUAL OBSERVED REPRESENTATIVE LOCATIONS
# ================================================================
# We deliberately DO NOT average x/y coordinates.
#
# For each badger-year:
#   - determine the modal observed SG;
#   - within that SG, determine the most frequently observed exact sett location;
#   - use an actual observed x/y from that sett/location as the representative.
#
# This avoids creating artificial midpoint locations that can fall in lakes
# or across SG boundaries.

live_model <- live %>%
  filter(tattoo %in% ids, !is.na(x), !is.na(y)) %>%
  bind_cols(lookup_xy(.$x,.$y)) %>%
  filter(in_bounds, habitat==1)

# If Sett_Clean is absent, define location by exact x/y.
if(!"Sett_Clean" %in% names(live_model))
  live_model <- live_model %>% mutate(Sett_Clean=paste(x,y,sep="_"))

# Modal SG per individual-year.
annual_sg <- live_model %>%
  count(tattoo,primary,primary_year,SG_id,zone,name="n_sg_obs") %>%
  group_by(tattoo,primary) %>%
  arrange(desc(n_sg_obs), zone, SG_id, .by_group=TRUE) %>%
  slice(1) %>%
  ungroup()

# Most frequently used actual sett/location within the selected annual SG.
annual_loc <- live_model %>%
  inner_join(annual_sg %>% select(tattoo,primary,SG_id,zone),
             by=c("tattoo","primary","SG_id","zone")) %>%
  count(tattoo,primary,primary_year,SG_id,zone,Sett_Clean,x,y,name="n_loc_obs") %>%
  group_by(tattoo,primary) %>%
  arrange(desc(n_loc_obs),Sett_Clean,.by_group=TRUE) %>%
  slice(1) %>%
  ungroup() %>%
  left_join(entry_lookup,by="tattoo")

cat("\n========================================\n")
cat("ANNUAL REPRESENTATIVE LOCATIONS\n")
cat("========================================\n")
cat("Annual badger-years:",nrow(annual_loc),"\n")
cat("Badgers represented:",n_distinct(annual_loc$tattoo),"\n")
cat("Peripheral annual representatives:",sum(annual_loc$zone==2),"\n")

# ================================================================
# 2. OBSERVED CONSECUTIVE-YEAR TRANSITIONS
# ================================================================

transitions <- annual_loc %>%
  arrange(tattoo,primary) %>%
  group_by(tattoo) %>%
  mutate(next_primary=lead(primary),
         next_year=lead(primary_year),
         dest_x=lead(x),dest_y=lead(y),
         dest_SG=lead(SG_id),dest_zone=lead(zone),
         dest_sett=lead(Sett_Clean)) %>%
  ungroup() %>%
  filter(!is.na(next_primary), next_primary==primary+1L) %>%
  rename(origin_year=primary_year,origin_x=x,origin_y=y,
         origin_SG=SG_id,origin_zone=zone,origin_sett=Sett_Clean)

# Classification of observed endpoint transition.
transitions <- transitions %>%
  rowwise() %>%
  mutate(
    observed_category = case_when(
      origin_zone==1 && dest_zone==1 && origin_SG==dest_SG ~ "same_SG",
      origin_zone==1 && dest_zone==1 && is_neighbour(origin_SG,dest_SG) ~ "neighbour_SG",
      origin_zone==1 && dest_zone==1 ~ "nonneighbour_SG",
      dest_zone==2 ~ "peripheral",
      TRUE ~ "other"
    ),
    observed_distance_m=sqrt((dest_x-origin_x)^2+(dest_y-origin_y)^2)
  ) %>%
  ungroup()

# The key normalized-SG audit is most interpretable for origins in mapped core SGs.
trans_core <- transitions %>%
  filter(origin_zone==1,origin_SG!=999,observed_category!="other") %>%
  mutate(observed_category=factor(observed_category,
    levels=c("same_SG","neighbour_SG","nonneighbour_SG","peripheral")))

cat("\n========================================\n")
cat("OBSERVED CONSECUTIVE-YEAR TRANSITIONS\n")
cat("========================================\n")
cat("All consecutive transitions:",nrow(transitions),"\n")
cat("Core-origin transitions used:",nrow(trans_core),"\n\n")

observed_summary <- trans_core %>%
  count(observed_category,name="n") %>%
  complete(observed_category=factor(c("same_SG","neighbour_SG","nonneighbour_SG","peripheral"),
                                    levels=levels(trans_core$observed_category)),
           fill=list(n=0)) %>%
  mutate(prop_observed=n/sum(n))

print(observed_summary,n=Inf)

cat("\nObserved annual endpoint distance (m):\n")
print(summary(trans_core$observed_distance_m))

# ================================================================
# 3. EXPECTED CATEGORY AVAILABILITY FOR EACH OBSERVED ORIGIN
# ================================================================

category_weights <- function(origin_x,origin_y,origin_SG,sigma){
  max_d <- N_SIGMA*sigma

  # Fast rectangular prefilter, then exact Euclidean radius.
  dx <- grid_xy[land_idx,1]-origin_x
  dy <- grid_xy[land_idx,2]-origin_y
  keep <- abs(dx)<=max_d & abs(dy)<=max_d
  idx <- land_idx[keep]
  d <- sqrt(dx[keep]^2+dy[keep]^2)
  take <- d<=max_d

  idx <- idx[take]
  d <- d[take]

  if(!length(idx))
    return(c(same_SG=NA,neighbour_SG=NA,nonneighbour_SG=NA,peripheral=NA))

  z1 <- grid$zone[idx]
  s1 <- grid$SG_id[idx]

  catg <- ifelse(z1==2,"peripheral",
           ifelse(s1==origin_SG,"same_SG",
             ifelse(vapply(s1,function(s)is_neighbour(origin_SG,s),logical(1)),
                    "neighbour_SG","nonneighbour_SG")))

  w <- exp(-d^2/(2*sigma^2))
  ws <- tapply(w,factor(catg,
    levels=c("same_SG","neighbour_SG","nonneighbour_SG","peripheral")),sum)
  ws[is.na(ws)] <- 0
  ws/sum(ws)
}

audit_rows <- vector("list",nrow(trans_core)*length(SIGMA_TEST))
ii <- 0L

for(j in seq_len(nrow(trans_core))){
  if(j %% 250==0) cat("Processed",j,"of",nrow(trans_core),"core-origin transitions\n")

  for(sig in SIGMA_TEST){
    p <- category_weights(trans_core$origin_x[j],trans_core$origin_y[j],
                          trans_core$origin_SG[j],sig)
    ii <- ii+1L
    audit_rows[[ii]] <- tibble(
      transition_id=j,tattoo=trans_core$tattoo[j],
      entry_group=trans_core$entry_group[j],
      origin_year=trans_core$origin_year[j],
      next_year=trans_core$next_year[j],
      origin_SG=trans_core$origin_SG[j],
      dest_SG=trans_core$dest_SG[j],
      observed_category=as.character(trans_core$observed_category[j]),
      observed_distance_m=trans_core$observed_distance_m[j],
      sigma_test=sig,
      exp_same_SG=unname(p["same_SG"]),
      exp_neighbour_SG=unname(p["neighbour_SG"]),
      exp_nonneighbour_SG=unname(p["nonneighbour_SG"]),
      exp_peripheral=unname(p["peripheral"])
    )
  }
}

transition_audit <- bind_rows(audit_rows) %>%
  rowwise() %>%
  mutate(expected_prob_observed = case_when(
    observed_category=="same_SG" ~ exp_same_SG,
    observed_category=="neighbour_SG" ~ exp_neighbour_SG,
    observed_category=="nonneighbour_SG" ~ exp_nonneighbour_SG,
    observed_category=="peripheral" ~ exp_peripheral,
    TRUE ~ NA_real_
  )) %>%
  ungroup()

# ================================================================
# 4. OBSERVED vs EXPECTED: OVERALL
# ================================================================

expected_overall <- transition_audit %>%
  group_by(sigma_test) %>%
  summarise(
    n=n(),
    expected_same_SG=mean(exp_same_SG),
    expected_neighbour_SG=mean(exp_neighbour_SG),
    expected_nonneighbour_SG=mean(exp_nonneighbour_SG),
    expected_peripheral=mean(exp_peripheral),
    mean_prob_of_observed_category=mean(expected_prob_observed),
    .groups="drop"
  )

observed_wide <- observed_summary %>%
  select(observed_category,prop_observed) %>%
  pivot_wider(names_from=observed_category,values_from=prop_observed,
              names_prefix="observed_")

comparison_overall <- expected_overall %>%
  crossing(observed_wide) %>%
  mutate(
    excess_same_SG=observed_same_SG-expected_same_SG,
    ratio_same_SG=observed_same_SG/expected_same_SG,
    excess_neighbour_SG=observed_neighbour_SG-expected_neighbour_SG,
    ratio_neighbour_SG=observed_neighbour_SG/expected_neighbour_SG,
    excess_nonneighbour_SG=observed_nonneighbour_SG-expected_nonneighbour_SG,
    ratio_nonneighbour_SG=observed_nonneighbour_SG/expected_nonneighbour_SG,
    excess_peripheral=observed_peripheral-expected_peripheral,
    ratio_peripheral=observed_peripheral/expected_peripheral
  )

cat("\n========================================\n")
cat("OBSERVED vs EXPECTED: OVERALL\n")
cat("========================================\n")
print(comparison_overall,n=Inf)

# ================================================================
# 5. OBSERVED vs EXPECTED BY ENTRY GROUP
# ================================================================

obs_group <- trans_core %>% filter(!is.na(entry_group)) %>%
  count(entry_group,observed_category,name="n") %>%
  group_by(entry_group) %>%
  mutate(prop_observed=n/sum(n)) %>%
  ungroup() %>%
  select(entry_group,observed_category,prop_observed) %>%
  pivot_wider(names_from=observed_category,values_from=prop_observed,
              names_prefix="observed_",values_fill=0)

exp_group <- transition_audit %>% filter(!is.na(entry_group)) %>%
  group_by(entry_group,sigma_test) %>%
  summarise(n=n(),expected_same_SG=mean(exp_same_SG),
            expected_neighbour_SG=mean(exp_neighbour_SG),
            expected_nonneighbour_SG=mean(exp_nonneighbour_SG),
            expected_peripheral=mean(exp_peripheral),.groups="drop")

comparison_group <- exp_group %>% left_join(obs_group,by="entry_group") %>%
  mutate(excess_same_SG=observed_same_SG-expected_same_SG,
         ratio_same_SG=observed_same_SG/expected_same_SG,
         excess_peripheral=observed_peripheral-expected_peripheral,
         ratio_peripheral=observed_peripheral/expected_peripheral)

cat("\n========================================\n")
cat("OBSERVED vs EXPECTED: ENTRY GROUP\n")
cat("========================================\n")
print(comparison_group,n=Inf)

# ================================================================
# 6. OBSERVED vs EXPECTED BY ORIGIN SOCIAL GROUP
# ================================================================

obs_sg <- trans_core %>%
  count(origin_SG,observed_category,name="n") %>%
  group_by(origin_SG) %>% mutate(prop_observed=n/sum(n),n_transitions=sum(n)) %>%
  ungroup() %>%
  select(origin_SG,n_transitions,observed_category,prop_observed) %>%
  distinct() %>%
  pivot_wider(names_from=observed_category,values_from=prop_observed,
              names_prefix="observed_",values_fill=0)

exp_sg <- transition_audit %>%
  group_by(origin_SG,sigma_test) %>%
  summarise(expected_same_SG=mean(exp_same_SG),
            expected_neighbour_SG=mean(exp_neighbour_SG),
            expected_nonneighbour_SG=mean(exp_nonneighbour_SG),
            expected_peripheral=mean(exp_peripheral),.groups="drop")

comparison_sg <- exp_sg %>% left_join(obs_sg,by="origin_SG") %>%
  mutate(excess_same_SG=observed_same_SG-expected_same_SG,
         ratio_same_SG=observed_same_SG/expected_same_SG,
         excess_peripheral=observed_peripheral-expected_peripheral,
         ratio_peripheral=observed_peripheral/expected_peripheral)

cat("\n========================================\n")
cat("OBSERVED vs EXPECTED: ORIGIN SG\n")
cat("========================================\n")
print(comparison_sg,n=Inf)

# ================================================================
# 7. GROUP-SPECIFIC SIGMA AUDIT
# ================================================================
# Uses one sigma value for each entry group, approximating the current
# development-model movement scales. This is descriptive only.

group_sigma_rows <- list(); kk <- 0L
for(j in seq_len(nrow(trans_core))){
  g <- as.character(trans_core$entry_group[j])
  if(is.na(g) || !g %in% names(SIGMA_BY_GROUP)) next

  sig <- unname(SIGMA_BY_GROUP[g])
  p <- category_weights(trans_core$origin_x[j],trans_core$origin_y[j],
                        trans_core$origin_SG[j],sig)

  kk <- kk+1L
  group_sigma_rows[[kk]] <- tibble(
    transition_id=j,tattoo=trans_core$tattoo[j],entry_group=as.integer(g),
    sigma_used=sig,observed_category=as.character(trans_core$observed_category[j]),
    exp_same_SG=unname(p["same_SG"]),
    exp_neighbour_SG=unname(p["neighbour_SG"]),
    exp_nonneighbour_SG=unname(p["nonneighbour_SG"]),
    exp_peripheral=unname(p["peripheral"])
  )
}
group_sigma_audit <- bind_rows(group_sigma_rows)

group_sigma_summary <- group_sigma_audit %>%
  group_by(entry_group,sigma_used) %>%
  summarise(
    n=n(),
    expected_same_SG=mean(exp_same_SG),
    expected_neighbour_SG=mean(exp_neighbour_SG),
    expected_nonneighbour_SG=mean(exp_nonneighbour_SG),
    expected_peripheral=mean(exp_peripheral),
    .groups="drop"
  ) %>%
  left_join(obs_group,by="entry_group") %>%
  mutate(excess_same_SG=observed_same_SG-expected_same_SG,
         ratio_same_SG=observed_same_SG/expected_same_SG,
         excess_peripheral=observed_peripheral-expected_peripheral,
         ratio_peripheral=observed_peripheral/expected_peripheral)

cat("\n========================================\n")
cat("GROUP-SPECIFIC SIGMA: OBSERVED vs EXPECTED\n")
cat("========================================\n")
print(group_sigma_summary,n=Inf)

# ================================================================
# 8. SIMPLE DIAGNOSTIC PLOTS
# ================================================================

plot_overall <- comparison_overall %>%
  select(sigma_test,starts_with("observed_"),starts_with("expected_")) %>%
  #select(-mean_prob_of_observed_category) %>%
  pivot_longer(-sigma_test,names_to="type_category",values_to="proportion") %>%
  separate(type_category,c("type","category"),sep="_",extra="merge") %>%
  ggplot(aes(x=category,y=proportion,fill=type)) +
  geom_col(position="dodge") +
  facet_wrap(~sigma_test,labeller=label_both) +
  labs(x=NULL,y="Proportion",fill=NULL,
       title="Observed annual transitions vs geometry-only expectation")

ggsave(file.path(OUT_DIR,"observed_vs_expected_overall.png"),
       plot_overall,width=10,height=6,dpi=200)

plot_sg <- comparison_sg %>%
  filter(sigma_test==100,n_transitions>=10) %>%
  ggplot(aes(x=reorder(factor(origin_SG),excess_same_SG),
             y=excess_same_SG)) +
  geom_col() +
  geom_hline(yintercept=0,lty=2) +
  coord_flip() +
  labs(x="Origin SG",y="Observed - expected same-SG proportion",
       title="Excess same-SG fidelity by origin SG (sigma = 100 m)",
       subtitle="Positive values indicate more same-SG transitions than geometry alone predicts")

ggsave(file.path(OUT_DIR,"excess_same_SG_by_origin_SG_sigma100.png"),
       plot_sg,width=8,height=7,dpi=200)

# ================================================================
# 9. SAVE OUTPUTS
# ================================================================

write_csv(annual_loc,file.path(OUT_DIR,"annual_observed_representative_locations.csv"))
write_csv(trans_core,file.path(OUT_DIR,"observed_consecutive_transitions.csv"))
write_csv(transition_audit,file.path(OUT_DIR,"transition_expected_availability.csv"))
write_csv(observed_summary,file.path(OUT_DIR,"observed_transition_summary.csv"))
write_csv(comparison_overall,file.path(OUT_DIR,"observed_vs_expected_overall.csv"))
write_csv(comparison_group,file.path(OUT_DIR,"observed_vs_expected_by_entry_group.csv"))
write_csv(comparison_sg,file.path(OUT_DIR,"observed_vs_expected_by_origin_SG.csv"))
write_csv(group_sigma_summary,file.path(OUT_DIR,"group_specific_sigma_summary.csv"))

saveRDS(
  list(annual_loc=annual_loc,transitions=trans_core,
       transition_audit=transition_audit,
       observed_summary=observed_summary,
       comparison_overall=comparison_overall,
       comparison_group=comparison_group,
       comparison_sg=comparison_sg,
       group_sigma_summary=group_sigma_summary,
       settings=list(SIGMA_TEST=SIGMA_TEST,SIGMA_BY_GROUP=SIGMA_BY_GROUP,N_SIGMA=N_SIGMA)),
  file.path(OUT_DIR,"V3_observed_vs_expected_transition_audit.rds")
)

cat("\n========================================\n")
cat("AUDIT COMPLETE\n")
cat("========================================\n")
cat("Outputs written to:",OUT_DIR,"\n\n")
cat("PLEASE SEND BACK THESE OBJECTS FIRST:\n")
cat("  observed_summary\n")
cat("  comparison_overall\n")
cat("  comparison_group\n")
cat("  group_sigma_summary\n")
cat("\nThen, if manageable:\n")
cat("  comparison_sg\n")
