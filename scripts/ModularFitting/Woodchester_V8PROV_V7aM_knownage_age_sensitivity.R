# =============================================================================
# V8 PROVISIONAL V7a-M KNOWN-AGE SENSITIVITY
#
# DEVELOPMENT ONLY: uses the existing V8 provisional movement histories while
# the final V9 movement fit is being resolved.
#
# Fits, on IDENTICAL known-age local-origin transitions:
#   B0: logit P(high_t | local_{t-1}) = alpha + beta_inf*infection + beta_sex*sex
#   B1: same + beta_age*(chronological age at movement origin - 3 years)
#
# B0 vs the existing full-sample V8PROV V7a result diagnoses known-age sample
# restriction. B0 vs B1 diagnoses age adjustment on exactly the same rows.
# =============================================================================

library(tidyverse)

PAIR_FILE <- "data/badger_phase2_paired_latent_inputs_V8_PROVISIONAL.rds"
MOVE_FILE <- "data/badger_movement_posterior_histories_1932_V8_PROVISIONAL.rds"
INF_FILE <- "data/badger_infection_trajectories_all_tests_inferred.rds"
IND_FILE <- "data/badger_individuals.rds"
for(f in c(PAIR_FILE,MOVE_FILE,INF_FILE,IND_FILE)) if(!file.exists(f)) stop("Missing required file: ",f)

paired <- readRDS(PAIR_FILE); mov <- readRDS(MOVE_FILE); inf <- readRDS(INF_FILE); individuals <- as_tibble(readRDS(IND_FILE))

MAX_PAIRS <- as.integer(Sys.getenv("MAX_PAIRS","100"))
N_PROP <- as.integer(Sys.getenv("N_PROP","3000"))
N_KEEP <- as.integer(Sys.getenv("N_KEEP","50"))
SEED <- as.integer(Sys.getenv("SEED","7092061"))
RESULT_TAG <- Sys.getenv("RESULT_TAG","SMOKE_100")
AGE_CENTER <- 3
set.seed(SEED)

START_YEAR <- as.integer(inf$start_year)
inf_ids <- trimws(as.character(inf$tattoo))

birth <- individuals %>%
  transmute(tattoo=trimws(as.character(tattoo)),age_fc=toupper(str_squish(as.character(age_fc))),year_fc=as.integer(year_fc)) %>%
  mutate(birth_year=case_when(age_fc=="CUB" & !is.na(year_fc) ~ year_fc,
                              age_fc=="YEARLING" & !is.na(year_fc) ~ year_fc-1L,
                              TRUE ~ NA_integer_)) %>%
  distinct(tattoo,.keep_all=TRUE)

idx <- as_tibble(mov$interval_index) %>%
  mutate(interval_col=row_number(),model_i=as.integer(model_i),tattoo=trimws(as.character(tattoo)),
         from_year=as.integer(from_year),to_year=as.integer(to_year)) %>%
  left_join(birth %>% select(tattoo,birth_year),by="tattoo") %>%
  mutate(age_years=from_year-birth_year,age_c=age_years-AGE_CENTER,known_age=!is.na(birth_year))

if(ncol(mov$state_draws)!=nrow(idx)) stop("Movement state matrix does not match interval index.")
if(any(!mov$state_draws%in%c(0L,1L))) stop("Movement states must be 0/1.")
if(any(!as.integer(mov$sex)%in%c(0L,1L))) stop("Sex must be 0/1.")
if(any(idx$known_age & (!is.finite(idx$age_years) | idx$age_years<0))) stop("Invalid reconstructed ages.")
if(any(!unique(idx$tattoo)%in%inf_ids)) stop("Some movement badgers absent from infection trajectories.")

prev_col <- rep(NA_integer_,nrow(idx))
for(rr in split(seq_len(nrow(idx)),idx$model_i)){
  rr <- rr[order(idx$from_year[rr],idx$to_year[rr])]
  if(length(rr)>1L) prev_col[rr[-1L]] <- rr[-length(rr)]
}
sex_interval <- as.integer(mov$sex[idx$model_i])
inf_row_interval <- match(idx$tattoo,inf_ids)
q4_time <- 4L*(idx$from_year-START_YEAR)+4L

known_ids <- unique(idx$tattoo[idx$known_age])
cat("Known-age badgers represented in V8 provisional movement histories:",length(known_ids),"\n")
cat("Known-age interval origin ages:",min(idx$age_years[idx$known_age]),"to",max(idx$age_years[idx$known_age]),"years\n")

age_levels <- sort(unique(idx$age_years[idx$known_age & !is.na(prev_col)]))
cells <- expand_grid(sex=0:1,infected=0:1,age_years=age_levels) %>% arrange(age_years,infected,sex) %>% mutate(cell=row_number(),age_c=age_years-AGE_CENTER)
cell_key <- with(cells,paste(sex,infected,age_years,sep="|"))

pair_index <- paired$pair_index %>% arrange(pair_draw)
MAX_PAIRS <- min(MAX_PAIRS,nrow(pair_index))
if(MAX_PAIRS<nrow(pair_index)){
  pick <- unique(round(seq(1,nrow(pair_index),length.out=MAX_PAIRS)))
  if(length(pick)!=MAX_PAIRS) pick <- sort(sample(seq_len(nrow(pair_index)),MAX_PAIRS))
  pair_index <- pair_index[pick,,drop=FALSE]
}

n_mat <- matrix(0L,nrow(pair_index),nrow(cells)); y_mat <- matrix(0L,nrow(pair_index),nrow(cells))
for(pp in seq_len(nrow(pair_index))){
  st <- as.integer(mov$state_draws[pair_index$movement_draw[pp],])
  ic <- pair_index$infection_col[pp]
  it <- as.integer(inf$infection_time[,ic])
  infected <- it[inf_row_interval]>0L & it[inf_row_interval]<=q4_time
  eligible <- idx$known_age & !is.na(prev_col) & st[prev_col]==0L
  rr <- which(eligible)
  key <- paste(sex_interval[rr],as.integer(infected[rr]),idx$age_years[rr],sep="|")
  cc <- match(key,cell_key)
  if(anyNA(cc)) stop("Could not map a known-age V7a cell.")
  n_mat[pp,] <- tabulate(cc,nbins=nrow(cells))
  y_mat[pp,] <- tabulate(cc[st[rr]==1L],nbins=nrow(cells))
  if(pp%%25L==0L) cat("Built known-age V7a counts",pp,"/",nrow(pair_index),"\n")
}

make_spec <- function(with_age=FALSE){
  X <- cbind(alpha=1,beta_inf=cells$infected,beta_sex=cells$sex)
  pm <- c(alpha=qlogis(.05),beta_inf=0,beta_sex=0); ps <- c(alpha=1.5,beta_inf=1.5,beta_sex=1.5)
  if(with_age){X <- cbind(X,beta_age=cells$age_c); pm <- c(pm,beta_age=0); ps <- c(ps,beta_age=.5)}
  list(X=X,mean=pm,sd=ps,name=if(with_age) "KNOWNAGE_PLUS_AGE" else "KNOWNAGE_BASELINE")
}

log1pexp <- function(x) ifelse(x>0,x+log1p(exp(-x)),log1p(exp(x)))
draw_mvn <- function(n,mu,Sigma){R<-chol(Sigma); sweep(matrix(rnorm(n*length(mu)),n,length(mu))%*%R,2,mu,"+")}
logdmvn_many <- function(x,mu,Sigma){d<-length(mu); md<-mahalanobis(x,mu,Sigma); ld<-as.numeric(determinant(Sigma,logarithm=TRUE)$modulus); -.5*(d*log(2*pi)+ld+md)}

fit_pair <- function(n,y,spec){
  X<-spec$X; pm<-spec$mean; ps<-spec$sd; P<-ncol(X)
  logpost <- function(th){eta<-as.vector(X%*%th); sum(y*eta-n*log1pexp(eta))-.5*sum(((th-pm)/ps)^2)}
  nlp <- function(th) -logpost(th)
  grad <- function(th){eta<-as.vector(X%*%th); p<-plogis(eta); -as.vector(crossprod(X,y-n*p)+( -(th-pm)/(ps^2) ))}
  opt <- optim(pm,nlp,grad,method="BFGS",control=list(maxit=600,reltol=1e-10))
  eta<-as.vector(X%*%opt$par); p<-plogis(eta); w<-n*p*(1-p)
  H<-crossprod(X,X*w)+diag(1/(ps^2),P); ee<-eigen(H,symmetric=TRUE); ee$values[ee$values<1e-8]<-1e-8
  V<-ee$vectors%*%diag(1/ee$values,P)%*%t(ee$vectors); QV<-V*(1.5^2)
  prop<-draw_mvn(N_PROP,opt$par,QV)
  etaP<-prop%*%t(X); ll<-rowSums(sweep(etaP,2,y,"*")-sweep(log1pexp(etaP),2,n,"*")); z<-sweep(prop,2,pm,"-"); lp<--.5*rowSums(sweep(z^2,2,ps^2,"/"))
  lw<-ll+lp-logdmvn_many(prop,opt$par,QV); lw<-lw-max(lw); ww<-exp(lw); ww<-ww/sum(ww)
  keep<-sample.int(N_PROP,N_KEEP,replace=TRUE,prob=ww); dr<-prop[keep,,drop=FALSE]; colnames(dr)<-colnames(X)
  list(draws=dr,ESS=1/sum(ww^2),maxw=max(ww),optim=opt$convergence)
}

specs <- list(make_spec(FALSE),make_spec(TRUE)); pooled <- list(); diags <- list(); k<-0L; d<-0L
for(sp in specs){
  for(pp in seq_len(nrow(pair_index))){
    fit<-fit_pair(as.numeric(n_mat[pp,]),as.numeric(y_mat[pp,]),sp)
    z<-as_tibble(fit$draws) %>% mutate(pair_draw=pair_index$pair_draw[pp],model=sp$name,.before=1)
    k<-k+1L; pooled[[k]]<-z
    d<-d+1L; diags[[d]]<-tibble(model=sp$name,pair_draw=pair_index$pair_draw[pp],transitions=sum(n_mat[pp,]),high=sum(y_mat[pp,]),IS_ESS=fit$ESS,max_weight=fit$maxw,optim_code=fit$optim)
    if(pp%%25L==0L) cat("Fitted",sp$name,pp,"/",nrow(pair_index),"\n")
  }
}
draws <- bind_rows(pooled); diagnostics <- bind_rows(diags)

summ_one <- function(z,param){x<-z[[param]]; tibble(parameter=param,mean=mean(x),sd=sd(x),median=median(x),q025=unname(quantile(x,.025)),q975=unname(quantile(x,.975)),P_gt_0=mean(x>0),OR_median=median(exp(x)),OR_q025=unname(quantile(exp(x),.025)),OR_q975=unname(quantile(exp(x),.975)))}
summary <- bind_rows(lapply(unique(draws$model),function(mm){z<-filter(draws,model==mm); pars<-intersect(c("beta_inf","beta_sex","beta_age"),names(z)); bind_rows(lapply(pars,function(p) summ_one(z,p))) %>% mutate(model=mm,.before=1)}))

cat("\n============================================================\nV8PROV V7a KNOWN-AGE AGE SENSITIVITY\n============================================================\n")
print(summary,n=Inf,width=Inf)
cat("\nDiagnostics:\n"); print(diagnostics %>% group_by(model) %>% summarise(pairs=n(),min_ESS=min(IS_ESS),median_ESS=median(IS_ESS),max_weight=max(max_weight),optim_fail=sum(optim_code!=0),.groups="drop"),n=Inf,width=Inf)

out <- paste0("results/V8PROV_V7aM_knownage_age_",RESULT_TAG,".rds"); csv<-paste0("results/V8PROV_V7aM_knownage_age_",RESULT_TAG,"_summary.csv")
saveRDS(list(model="V8PROV V7a known-age baseline vs chronological-age adjustment",draws=draws,summary=summary,diagnostics=diagnostics,cells=cells,pair_index=pair_index,settings=list(age_center=AGE_CENTER,n_pairs=nrow(pair_index),N_PROP=N_PROP,N_KEEP=N_KEEP,development_only=TRUE)),out)
write_csv(summary,csv)
cat("Saved:",out,"\nSaved:",csv,"\n")
