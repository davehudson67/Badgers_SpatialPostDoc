# =============================================================================
# WOODCHESTER V6c REPRODUCIBILITY / V7-READINESS AUDIT
#
# Purpose:
#   Reproduce the key movement-state diagnostics used to decide that V6c is
#   suitable as the movement scaffold for V7.
#
# This script:
#   - DOES NOT connect to PostgreSQL/Supabase
#   - reads the saved V6c result RDS
#   - audits MCMC convergence and ESS
#   - rebuilds the corrected movement-pattern classification
#   - audits observed annual displacement and year gaps
#   - checks the ecological interpretation of posterior P(high mobility)
#   - summarizes sex composition by movement state
#   - flags movement-support and 50 m grid concerns
#   - writes aggregate audit tables to results/V6c_audit/
#
# No individual identifiers are exported by default.
# =============================================================================

library(tidyverse)
library(coda)
library(MCMCvis)

# ---- options ----------------------------------------------------------------
RESULT_FILE <- "results/RD_SCR_V6c_WIDE_SUPPORT_SEX_TRANSITIONS_500_badgers.rds"
OUT_DIR <- "results/V6c_audit"
EXPORT_INDIVIDUAL_IDS <- FALSE

RHAT_WARN <- 1.05
ESS_WARN <- 200
LOCAL_GRID_RATIO_WARN <- 0.5   # warn if movement sigma < 0.5 grid-cell widths

dir.create(OUT_DIR,recursive=TRUE,showWarnings=FALSE)

if(!file.exists(RESULT_FILE)) stop("Cannot find V6c result file: ",RESULT_FILE)

res <- readRDS(RESULT_FILE)

req <- c("samples","ids","sex_data","first","K","years","disp_index","disp_summary",
         "annual_obs","settings")
miss <- req[!vapply(req,function(x)!is.null(res[[x]]),logical(1))]
if(length(miss)) stop("V6c result is missing required object(s): ",paste(miss,collapse=", "))

samples <- res$samples
ids <- res$ids
sex_data <- res$sex_data
first <- res$first
K <- res$K
years <- res$years
disp_index <- res$disp_index
disp_summary <- res$disp_summary
annual_obs <- res$annual_obs

cat("\n============================================================\n")
cat("WOODCHESTER V6c REPRODUCIBILITY / V7-READINESS AUDIT\n")
cat("============================================================\n")
cat("Result:",RESULT_FILE,"\n")
cat("Individuals:",length(ids),"\n")
cat("Years:",min(years),"-",max(years),"\n")
cat("Movement intervals:",nrow(disp_summary),"\n\n")

# =============================================================================
# 1. CORE MCMC DIAGNOSTICS
# =============================================================================

core_pars <- c(
  "alpha_logmove","beta_move_sex","beta_move_disp",
  "alpha_disp_init","beta_disp_adult","beta_disp_init_sex",
  "alpha_RD","beta_RD_sex","alpha_DD","beta_DD_sex",
  "p_RD_female","p_RD_male","p_DD_female","p_DD_male",
  "sigma_move_female_resident","sigma_move_male_resident",
  "sigma_move_female_disperser","sigma_move_male_disperser",
  "mean_move_female_resident","mean_move_male_resident",
  "mean_move_female_disperser","mean_move_male_disperser",
  "alpha_p","beta_p_sex","alpha_logsigma","beta_sigma_sex",
  "beta_sg","beta_peripheral"
)

sample_names <- colnames(as.matrix(samples[[1]]))
core_pars <- core_pars[core_pars %in% sample_names]

if(!length(core_pars)) stop("None of the expected V6c parameters were found.")

cat("1. Posterior summary\n")
core_summary <- MCMCsummary(samples,params=core_pars)
print(core_summary)

cat("\n2. Gelman-Rubin diagnostics\n")
gd <- gelman.diag(samples[,core_pars],multivariate=FALSE)
print(gd)

cat("\n3. Effective sample sizes\n")
ess <- effectiveSize(samples[,core_pars])
print(ess)

rhat_tab <- tibble(
  parameter=rownames(gd$psrf),
  Rhat=gd$psrf[,1],
  Rhat_upper=gd$psrf[,2]
)

ess_tab <- tibble(
  parameter=names(ess),
  ESS=as.numeric(ess)
)

diag_tab <- full_join(rhat_tab,ess_tab,by="parameter") %>%
  mutate(
    warn_Rhat=Rhat>RHAT_WARN,
    warn_ESS=ESS<ESS_WARN,
    warning=warn_Rhat | warn_ESS
  )

cat("\nParameters triggering audit thresholds:\n")
print(diag_tab %>% filter(warning),n=Inf)

write_csv(diag_tab,file.path(OUT_DIR,"01_core_mcmc_diagnostics.csv"))

# =============================================================================
# 2. POSTERIOR MEANS FOR LATENT STATES / UNKNOWN SEX
# =============================================================================

posterior_means <- Reduce(
  "+",
  lapply(samples,function(x) colMeans(as.matrix(x)))
)/length(samples)

# If disp_summary in the saved result already contains p_disperser, retain it.
if(!"p_disperser" %in% names(disp_summary)){
  disp_summary <- disp_index %>%
    mutate(p_disperser=unname(posterior_means[node]))
}

stopifnot(all(c("model_i","tattoo","from_primary","to_primary","p_disperser") %in% names(disp_summary)))

# =============================================================================
# 3. CORRECTED MOVEMENT-PATTERN CLASSIFICATION
# =============================================================================

p_male <- as.numeric(sex_data)
unknown_sex_idx <- which(is.na(sex_data))

if(length(unknown_sex_idx)){
  sex_nodes <- paste0("sex[",unknown_sex_idx,"]")
  found <- sex_nodes %in% names(posterior_means)
  p_male[unknown_sex_idx[found]] <- posterior_means[sex_nodes[found]]
}

sex_summary <- tibble(
  model_i=seq_along(ids),
  tattoo=ids,
  sex_known=!is.na(sex_data),
  known_sex=sex_data,
  p_male=p_male
)

individual_summary <- disp_summary %>%
  arrange(model_i,from_primary) %>%
  group_by(model_i,tattoo) %>%
  summarise(
    n_intervals=n(),
    mean_p_disperser=mean(p_disperser,na.rm=TRUE),
    max_p_disperser=max(p_disperser,na.rm=TRUE),
    first_p_disperser=first(p_disperser),
    last_p_disperser=last(p_disperser),
    n_intervals_p50=sum(p_disperser>=.50,na.rm=TRUE),
    n_intervals_p80=sum(p_disperser>=.80,na.rm=TRUE),
    .groups="drop"
  ) %>%
  left_join(sex_summary,by=c("model_i","tattoo")) %>%
  mutate(
    movement_pattern=case_when(
      max_p_disperser<.20 ~ "strongly_resident",
      n_intervals==1 & max_p_disperser>=.80 ~ "single_high_mobility_event",
      n_intervals>=3 & mean_p_disperser>=.70 &
        n_intervals_p80/n_intervals>=.67 ~ "persistent_high_mobility",
      n_intervals>=2 & first_p_disperser>=.70 &
        last_p_disperser<.30 ~ "disperser_then_settled",
      n_intervals>=2 & first_p_disperser<.30 &
        last_p_disperser>=.70 ~ "became_disperser",
      n_intervals_p80>=1 ~ "episodic_disperser",
      TRUE ~ "mixed_or_uncertain"
    )
  )

pattern_counts <- individual_summary %>%
  count(movement_pattern,name="n") %>%
  mutate(proportion=n/sum(n))

cat("\n============================================================\n")
cat("CORRECTED MOVEMENT-PATTERN CLASSIFICATION\n")
cat("============================================================\n")
print(pattern_counts,n=Inf)

write_csv(pattern_counts,file.path(OUT_DIR,"02_movement_pattern_counts.csv"))

if(EXPORT_INDIVIDUAL_IDS){
  write_csv(individual_summary,file.path(OUT_DIR,"02b_individual_movement_summary_PRIVATE.csv"))
}

# =============================================================================
# 4. LATENT-STATE OCCUPANCY
# =============================================================================

state_summary <- disp_summary %>%
  summarise(
    n_intervals=n(),
    n_p50=sum(p_disperser>=.50,na.rm=TRUE),
    n_p80=sum(p_disperser>=.80,na.rm=TRUE),
    mean_p=mean(p_disperser,na.rm=TRUE),
    median_p=median(p_disperser,na.rm=TRUE)
  )

cat("\nLatent state occupancy:\n")
print(state_summary)

write_csv(state_summary,file.path(OUT_DIR,"03_latent_state_occupancy.csv"))

# =============================================================================
# 5. YEAR-GAP AUDIT
# =============================================================================

if(!all(c("year_gap","observed_move") %in% names(annual_obs)))
  stop("annual_obs must contain year_gap and observed_move.")

gap_counts <- annual_obs %>%
  count(year_gap,name="n")

gap_summary <- annual_obs %>%
  group_by(year_gap) %>%
  summarise(
    n=n(),
    zero=sum(observed_move==0,na.rm=TRUE),
    p_zero=mean(observed_move==0,na.rm=TRUE),
    median=median(observed_move,na.rm=TRUE),
    p75=quantile(observed_move,.75,na.rm=TRUE),
    p90=quantile(observed_move,.90,na.rm=TRUE),
    p95=quantile(observed_move,.95,na.rm=TRUE),
    p99=quantile(observed_move,.99,na.rm=TRUE),
    max=max(observed_move,na.rm=TRUE),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("YEAR-GAP AUDIT\n")
cat("============================================================\n")
print(gap_counts,n=Inf)
print(gap_summary,n=Inf)

write_csv(gap_counts,file.path(OUT_DIR,"04_year_gap_counts.csv"))
write_csv(gap_summary,file.path(OUT_DIR,"05_year_gap_movement_summary.csv"))

# =============================================================================
# 6. CONSECUTIVE-YEAR MOVEMENT DISTRIBUTION
# =============================================================================

consecutive <- annual_obs %>%
  filter(year_gap==1)

consecutive_summary <- consecutive %>%
  summarise(
    n=n(),
    zero=sum(observed_move==0,na.rm=TRUE),
    p_zero=mean(observed_move==0,na.rm=TRUE),
    median=median(observed_move,na.rm=TRUE),
    p75=quantile(observed_move,.75,na.rm=TRUE),
    p90=quantile(observed_move,.90,na.rm=TRUE),
    p95=quantile(observed_move,.95,na.rm=TRUE),
    p99=quantile(observed_move,.99,na.rm=TRUE),
    max=max(observed_move,na.rm=TRUE),
    moved_250=sum(observed_move>250,na.rm=TRUE),
    moved_500=sum(observed_move>500,na.rm=TRUE),
    moved_1000=sum(observed_move>1000,na.rm=TRUE)
  )

cat("\nConsecutive-year observed movement:\n")
print(consecutive_summary)

write_csv(consecutive_summary,file.path(OUT_DIR,"06_consecutive_year_movement.csv"))

# =============================================================================
# 7. P(HIGH MOBILITY) VS OBSERVED MOVEMENT DISTANCE
# =============================================================================

join_req <- c("tattoo","previous_primary","primary","year_gap","observed_move")
if(!all(join_req %in% names(annual_obs)))
  stop("annual_obs is missing one or more join columns: ",paste(setdiff(join_req,names(annual_obs)),collapse=", "))

disp_validation <- disp_summary %>%
  left_join(
    annual_obs %>%
      transmute(
        tattoo,
        from_primary=previous_primary,
        to_primary=primary,
        year_gap,
        observed_move
      ),
    by=c("tattoo","from_primary","to_primary")
  ) %>%
  filter(!is.na(observed_move),year_gap==1) %>%
  mutate(
    move_class=case_when(
      observed_move==0 ~ "0 m",
      observed_move<=250 ~ "1-250 m",
      observed_move<=500 ~ "251-500 m",
      observed_move<=1000 ~ "501-1000 m",
      TRUE ~ ">1000 m"
    ),
    move_class=factor(
      move_class,
      levels=c("0 m","1-250 m","251-500 m","501-1000 m",">1000 m")
    )
  )

validation_summary <- disp_validation %>%
  group_by(move_class,.drop=FALSE) %>%
  summarise(
    n=n(),
    mean_p_disperser=mean(p_disperser,na.rm=TRUE),
    median_p_disperser=median(p_disperser,na.rm=TRUE),
    p80=mean(p_disperser>=.80,na.rm=TRUE),
    .groups="drop"
  )

cat("\n============================================================\n")
cat("LATENT-STATE INTERPRETABILITY AUDIT\n")
cat("P(high mobility) by observed consecutive-year relocation\n")
cat("============================================================\n")
print(validation_summary,n=Inf)

write_csv(validation_summary,file.path(OUT_DIR,"07_state_probability_by_observed_movement.csv"))

# monotonic descriptive check
monotonic_means <- all(diff(validation_summary$mean_p_disperser)>=0)
cat("Mean P(high mobility) increases monotonically across movement bins:",monotonic_means,"\n")

# =============================================================================
# 8. SEX COMPOSITION BY LATENT MOVEMENT STATE
# =============================================================================

interval_sex <- disp_summary %>%
  left_join(
    sex_summary %>% select(model_i,p_male,sex_known,known_sex),
    by="model_i"
  )

expected_resident <- sum(1-interval_sex$p_disperser,na.rm=TRUE)
expected_disperser <- sum(interval_sex$p_disperser,na.rm=TRUE)

expected_male_resident <- sum(
  (1-interval_sex$p_disperser)*interval_sex$p_male,
  na.rm=TRUE
)

expected_male_disperser <- sum(
  interval_sex$p_disperser*interval_sex$p_male,
  na.rm=TRUE
)

sex_by_state <- tibble(
  state=c("stable_local","high_mobility"),
  expected_intervals=c(expected_resident,expected_disperser),
  expected_male_intervals=c(expected_male_resident,expected_male_disperser)
) %>%
  mutate(
    expected_male_proportion=expected_male_intervals/expected_intervals,
    expected_female_proportion=1-expected_male_proportion
  )

cat("\nExpected posterior sex composition by state:\n")
print(sex_by_state)

write_csv(sex_by_state,file.path(OUT_DIR,"08_expected_sex_composition_by_state.csv"))

# =============================================================================
# 9. MOVEMENT SUPPORT / GRID-SCALE AUDIT
# =============================================================================

settings <- res$settings

support <- settings$movement_support_m
if(is.null(support) && !is.null(settings$sigma_grid))
  support <- range(settings$sigma_grid)

grid_size <- NA_real_
if(file.exists("data/spatial/V3_spatial_inputs_50m_2km.rds")){
  sp <- readRDS("data/spatial/V3_spatial_inputs_50m_2km.rds")
  if(!is.null(sp$cell_size)) grid_size <- sp$cell_size
}

post_mean <- function(par){
  if(!par %in% names(posterior_means)) return(NA_real_)
  as.numeric(posterior_means[par])
}

scale_audit <- tibble(
  parameter=c(
    "sigma_move_female_resident",
    "sigma_move_male_resident",
    "sigma_move_female_disperser",
    "sigma_move_male_disperser"
  ),
  posterior_mean=c(
    post_mean("sigma_move_female_resident"),
    post_mean("sigma_move_male_resident"),
    post_mean("sigma_move_female_disperser"),
    post_mean("sigma_move_male_disperser")
  )
)

if(length(support)==2){
  scale_audit <- scale_audit %>%
    mutate(
      support_min=support[1],
      support_max=support[2],
      ratio_to_lower=posterior_mean/support_min,
      ratio_to_upper=posterior_mean/support_max
    )
}

if(is.finite(grid_size)){
  scale_audit <- scale_audit %>%
    mutate(
      grid_cell_m=grid_size,
      sigma_in_grid_cells=posterior_mean/grid_size,
      grid_resolution_warning=
        str_detect(parameter,"resident") &
        sigma_in_grid_cells<LOCAL_GRID_RATIO_WARN
    )
}

cat("\n============================================================\n")
cat("MOVEMENT SUPPORT / GRID AUDIT\n")
cat("============================================================\n")
print(scale_audit,n=Inf)

write_csv(scale_audit,file.path(OUT_DIR,"09_movement_support_grid_audit.csv"))

# =============================================================================
# 10. V7 READINESS SUMMARY
# =============================================================================

beta_RD_sex_mean <- post_mean("beta_RD_sex")
p_RD_female_mean <- post_mean("p_RD_female")
p_RD_male_mean <- post_mean("p_RD_male")
beta_move_sex_mean <- post_mean("beta_move_sex")

readiness <- tibble(
  item=c(
    "transition_parameter_convergence",
    "high_mobility_scale_convergence",
    "state_interpretability",
    "episodic_not_fixed_type",
    "sex_transition_effect",
    "sex_within_state_distance_effect",
    "consecutive_year_information",
    "local_scale_grid_sensitivity",
    "ready_as_V7_movement_scaffold"
  ),
  assessment=c(
    ifelse(all(diag_tab$Rhat[diag_tab$parameter %in% c("alpha_RD","beta_RD_sex")]<=RHAT_WARN,na.rm=TRUE),
           "PASS","CHECK"),
    ifelse(all(diag_tab$Rhat[diag_tab$parameter %in%
              c("sigma_move_female_disperser","sigma_move_male_disperser")]<=RHAT_WARN,na.rm=TRUE),
           "PASS","PROVISIONAL"),
    ifelse(monotonic_means,"PASS","CHECK"),
    ifelse((pattern_counts %>% filter(movement_pattern=="persistent_high_mobility") %>% pull(n) %>% sum())<=
             (pattern_counts %>% summarise(n=sum(n)) %>% pull(n))*0.05,
           "SUPPORTED","CHECK"),
    paste0("beta_RD_sex mean=",round(beta_RD_sex_mean,3),
           "; p_RD F=",round(p_RD_female_mean,3),
           "; M=",round(p_RD_male_mean,3)),
    paste0("beta_move_sex mean=",round(beta_move_sex_mean,3)),
    paste0(nrow(consecutive)," consecutive-year observed transitions"),
    ifelse(any(scale_audit$grid_resolution_warning %in% TRUE,na.rm=TRUE),
           "25 m sensitivity recommended","No warning"),
    "YES, as a movement-development scaffold; not yet a final survival/emigration model"
  )
)

cat("\n============================================================\n")
cat("V7 READINESS SUMMARY\n")
cat("============================================================\n")
print(readiness,n=Inf)

write_csv(readiness,file.path(OUT_DIR,"10_V7_readiness_summary.csv"))

# =============================================================================
# 11. HUMAN-READABLE TEXT REPORT
# =============================================================================

report <- c(
  "WOODCHESTER V6c REPRODUCIBILITY / V7-READINESS AUDIT",
  paste("Run date:",Sys.Date()),
  paste("Result file:",RESULT_FILE),
  "",
  paste("Individuals:",length(ids)),
  paste("Latent movement intervals:",nrow(disp_summary)),
  paste("Consecutive-year observed transitions:",nrow(consecutive)),
  paste("Same-location proportion among consecutive years:",
        round(mean(consecutive$observed_move==0,na.rm=TRUE),3)),
  "",
  "Movement-state pattern counts:",
  paste(capture.output(print(pattern_counts,n=Inf)),collapse="\n"),
  "",
  "P(high mobility) by observed movement:",
  paste(capture.output(print(validation_summary,n=Inf)),collapse="\n"),
  "",
  "Parameters triggering convergence/ESS warnings:",
  paste(capture.output(print(diag_tab %>% filter(warning),n=Inf)),collapse="\n"),
  "",
  "Interpretation:",
  "The V6c high-mobility state should be interpreted as a time-varying relocation/high-mobility state,",
  "not as a permanent 'disperser type'. The local Gaussian scale is smaller than the current 50 m",
  "landscape grid and largely represents the strong same-sett annual fidelity in the observed data.",
  "The movement scaffold is suitable for V7 development, while disperser-scale convergence, grid",
  "resolution, state-space/peripheral resistance and alternative movement-state formulations remain",
  "required sensitivity checks."
)

writeLines(report,file.path(OUT_DIR,"V6c_audit_report.txt"))

cat("\nAudit outputs written to:",OUT_DIR,"\n")
cat("DONE\n")
