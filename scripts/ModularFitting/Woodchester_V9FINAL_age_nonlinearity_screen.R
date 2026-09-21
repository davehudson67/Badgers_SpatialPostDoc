# =============================================================================
# WOODCHESTER V9 FINAL — NON-LINEAR AGE SCREEN
#
# Purpose
#   Cheap posterior-history screen before considering another integrated NIMBLE
#   age model. Uses accepted V9 latent movement-state histories directly.
#
# Questions
#   1) Is age non-linear for the INITIAL high-mobility interval?
#   2) Is age non-linear for later LOCAL -> HIGH transitions?
#
# For each coherent V9 state history, compare:
#   linear: state ~ sex + age
#   spline: state ~ sex + natural spline(age, df=3)
#
# This is a screening analysis, NOT another movement MCMC. Positive
# delta_AIC = AIC(linear) - AIC(spline) favours the spline.
# =============================================================================

library(tidyverse)
library(splines)

MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V9_FINAL.rds"
IND_FILE <- "data/badger_individuals.rds"
for(f in c(MOVE_FILE,IND_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

mov <- readRDS(MOVE_FILE)
ind <- as_tibble(readRDS(IND_FILE))

MAX_DRAWS <- as.integer(Sys.getenv("MAX_DRAWS","1500"))
SEED <- as.integer(Sys.getenv("SEED","7092071"))
DF_SPLINE <- as.integer(Sys.getenv("DF_SPLINE","3"))
set.seed(SEED)

idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number(), model_i=as.integer(model_i),
         tattoo=trimws(as.character(tattoo)),
         from_year=as.integer(from_year), to_year=as.integer(to_year))

birth <- ind %>%
  transmute(tattoo=trimws(as.character(tattoo)),
            age_fc=toupper(str_squish(as.character(age_fc))),
            year_fc=as.integer(year_fc)) %>%
  mutate(birth_year=case_when(
    age_fc=="CUB" & !is.na(year_fc) ~ year_fc,
    age_fc=="YEARLING" & !is.na(year_fc) ~ year_fc-1L,
    TRUE ~ NA_integer_
  )) %>%
  distinct(tattoo,.keep_all=TRUE)

idx <- idx %>%
  left_join(birth %>% select(tattoo,birth_year),by="tattoo") %>%
  mutate(age_years=from_year-birth_year, known_age=!is.na(birth_year))

if(any(idx$known_age & (!is.finite(idx$age_years) | idx$age_years<0))) stop("Invalid reconstructed ages.")
if(ncol(mov$state_draws)!=nrow(idx)) stop("Movement state matrix does not match interval index.")
if(any(!mov$state_draws%in%c(0L,1L))) stop("Movement states must be 0/1.")

sex_interval <- as.integer(mov$sex[idx$model_i])
if(any(!sex_interval%in%c(0L,1L))) stop("Sex must be 0/1.")

# Previous movement interval within animal.
prev_col <- rep(NA_integer_,nrow(idx))
for(rr in split(seq_len(nrow(idx)),idx$model_i)){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}

# Initial interval is explicitly recorded in current index; fall back to first row.
if("is_initial_interval"%in%names(idx)){
  initial_row <- as.logical(idx$is_initial_interval)
}else{
  initial_row <- ave(seq_len(nrow(idx)),idx$model_i,FUN=seq_along)==1L
}

draw_ids <- unique(round(seq(1,nrow(mov$state_draws),length.out=min(MAX_DRAWS,nrow(mov$state_draws)))))
ages <- sort(unique(idx$age_years[idx$known_age]))
pred_grid <- expand_grid(age_years=ages,male=0:1)

safe_glm <- function(d,spline=FALSE){
  if(spline){
    glm(cbind(y,n-y) ~ male + ns(age_years,df=DF_SPLINE),data=d,family=binomial())
  }else{
    glm(cbind(y,n-y) ~ male + age_years,data=d,family=binomial())
  }
}

one_component <- function(st,component){
  if(component=="INITIAL"){
    rr <- which(idx$known_age & initial_row)
  }else{
    rr <- which(idx$known_age & !is.na(prev_col) & !initial_row & st[prev_col]==0L)
  }
  d <- tibble(age_years=idx$age_years[rr],male=sex_interval[rr],y=st[rr]) %>%
    group_by(age_years,male) %>%
    summarise(n=n(),y=sum(y),.groups="drop")
  if(nrow(d)<6L || sum(d$y)==0L || sum(d$n-d$y)==0L) return(NULL)
  lin <- safe_glm(d,FALSE); spl <- safe_glm(d,TRUE)
  list(
    compare=tibble(component=component,n=sum(d$n),high=sum(d$y),
                   AIC_linear=AIC(lin),AIC_spline=AIC(spl),
                   delta_AIC=AIC(lin)-AIC(spl)),
    pred=tibble(
      component=component,
      age_years=rep(pred_grid$age_years,2L),
      male=rep(pred_grid$male,2L),
      model=rep(c("LINEAR","SPLINE"),each=nrow(pred_grid)),
      p=c(predict(lin,newdata=pred_grid,type="response"),
          predict(spl,newdata=pred_grid,type="response"))
    )
  )
}

comp_list <- list(); pred_list <- list(); k <- 0L
for(dd in seq_along(draw_ids)){
  st <- as.integer(mov$state_draws[draw_ids[dd],])
  for(component in c("INITIAL","LOCAL_TO_HIGH")){
    z <- one_component(st,component)
    if(is.null(z)) next
    k <- k+1L
    comp_list[[k]] <- z$compare %>% mutate(draw=draw_ids[dd],.before=1)
    pred_list[[k]] <- z$pred %>% mutate(draw=draw_ids[dd],.before=1)
  }
  if(dd%%100L==0L) cat("Processed movement history",dd,"/",length(draw_ids),"\n")
}

comparison <- bind_rows(comp_list)
predictions <- bind_rows(pred_list)

summary <- comparison %>%
  group_by(component) %>%
  summarise(draws=n(),
            median_n=median(n),median_high=median(high),
            delta_AIC_median=median(delta_AIC),
            delta_AIC_q025=quantile(delta_AIC,.025),
            delta_AIC_q975=quantile(delta_AIC,.975),
            P_spline_AIC_better=mean(delta_AIC>0),
            P_delta_AIC_gt2=mean(delta_AIC>2),
            P_delta_AIC_gt6=mean(delta_AIC>6),.groups="drop")

pred_summary <- predictions %>%
  group_by(component,model,male,age_years) %>%
  summarise(p_median=median(p),p_q025=quantile(p,.025),p_q975=quantile(p,.975),.groups="drop")

cat("\n============================================================\n")
cat("V9 FINAL NON-LINEAR AGE SCREEN\n")
cat("============================================================\n")
print(summary,n=Inf,width=Inf)
cat("\nSpline predicted probabilities by age/sex:\n")
print(pred_summary %>% filter(model=="SPLINE"),n=Inf,width=Inf)

dir.create("results",showWarnings=FALSE,recursive=TRUE)
saveRDS(list(comparison=comparison,predictions=predictions,summary=summary,
             prediction_summary=pred_summary,
             settings=list(method="posterior-history logistic screen; natural spline vs linear age",
                           spline_df=DF_SPLINE,n_state_histories=length(draw_ids),
                           interpretation="screen only; consider integrated NIMBLE spline only if curvature is clear")),
        "results/V9FINAL_age_nonlinearity_screen.rds")
write_csv(summary,"results/V9FINAL_age_nonlinearity_screen_summary.csv")
write_csv(pred_summary,"results/V9FINAL_age_nonlinearity_screen_predictions.csv")
cat("\nSaved age non-linearity screen outputs.\n")
