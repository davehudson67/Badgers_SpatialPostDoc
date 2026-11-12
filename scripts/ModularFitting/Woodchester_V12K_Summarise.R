#!/usr/bin/env Rscript
for(pkg in c("nimble","posterior","sf","digest"))if(!requireNamespace(pkg,quietly=TRUE))stop("Install ",pkg)
suppressPackageStartupMessages(library(nimble))
source("scripts/ModularFitting/Woodchester_V12K_Likelihood.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Covariates.R",local=.GlobalEnv)
source("scripts/ModularFitting/Woodchester_V12K_Captures.R",local=.GlobalEnv)
run<-Sys.getenv("V12K_RUN","")
b<-readRDS(file.path(run,"joint_covariate_inputs.rds"))
b$capture_events<-v12k_capture_events(b)
b$counts<-NULL
fits<-lapply(1:3,function(ch)readRDS(file.path(run,sprintf("chain%02d",ch),"joint_fit.rds")))
stopifnot(length(unique(vapply(fits,`[[`,character(1),"input_sha256")))==1L,
 identical(fits[[1]]$input_sha256,digest::digest(file.path(run,"joint_covariate_inputs.rds"),file=TRUE,algo="sha256")),
 all(vapply(fits,function(f)identical(f$selected,fits[[1]]$selected),logical(1))))
if(any(vapply(fits,function(f)f$Nobs!=b$N,logical(1))))
 warning("Subset smoke outputs: population totals are NOT full-data estimates")
vars<-colnames(fits[[1]]$samples)
stopifnot(all(vapply(fits,function(f)identical(colnames(f$samples),vars),logical(1))))
nr<-min(vapply(fits,function(f)nrow(f$samples),integer(1)))
a<-array(NA_real_,c(nr,3,length(vars)),dimnames=list(NULL,NULL,vars))
for(ch in 1:3)a[,ch,]<-fits[[ch]]$samples[seq_len(nr),,drop=FALSE]
diagnostics<-as.data.frame(posterior::summarise_draws(posterior::as_draws_array(a),
 "mean","sd",~quantile(.x,probs=c(.025,.975)),"rhat","ess_bulk","ess_tail"))
diagnostics$diagnostics_pass<-is.finite(diagnostics$rhat)&diagnostics$rhat<1.01 &
 diagnostics$ess_bulk>=400 & diagnostics$ess_tail>=400
write.csv(diagnostics,file.path(run,"multichain_summary.csv"),row.names=FALSE)
print(diagnostics)

# FFBS recovers states jointly with the sampled continuous locations. No
# thresholding posterior mean tracks or treating old V11 tracks as observations.
nd<-as.integer(Sys.getenv("V12K_SUMMARY_DRAWS","20"))
if(is.na(nd)||nd<1)stop("Invalid summary draws")
set.seed(20261110)
annual_rows<-list();flow_rows<-list();counter<-0L
for(ch in 1:3) {
 f<-fits[[ch]];SS<-f$spatial;colnames(SS)<-gsub("[[:space:]]","",colnames(SS))
 draws<-unique(round(seq(1,nrow(SS),length.out=min(nd,nrow(SS)))))
 NN<-length(f$ids);TT<-b$T
 captures<-v12k_pack_captures(b,f$selected,NN)$packed
 for(row in draws) {
  grow<-as.integer(row*f$thin2/f$thin)
  if(grow<1||grow>nrow(f$samples))stop("Monitor streams cannot be aligned")
  g<-f$samples[grow,]; names(g)<-gsub("[[:space:]]","",names(g))
  X<-as.matrix(b$detectors[,c("x","y")])
  for(j in which(!b$detectors$known))for(d in 1:2) {
   key<-sprintf("X[%d,%d]",j,d)
   if(!key %in% colnames(SS))stop("Missing latent detector monitor: ",key)
   X[j,d]<-SS[row,key]
  }
  nz<-matrix(0,TT,3);flow<-array(0,c(TT-1,3,3));entry<-numeric(TT)
  Nsuper<-0L;avail<-numeric(TT)
  for(i in seq_len(NN)) {
   S<-matrix(NA_real_,TT,2)
   for(d in 1:2) {
    keys<-sprintf("S[%d,%d,%d]",i,seq_len(TT),d)
    if(any(!keys %in% colnames(SS)))stop("Missing annual coordinate monitors")
    S[,d]<-SS[row,keys]
   }
   sx<-SS[row,sprintf("sex[%d]",i)]
   bi<-as.integer(SS[row,sprintf("birth_index[%d]",i)])
   uu<-SS[row,sprintf("u_move[%d]",i)]
   p<-v12k_individual_parameters(g,sx,b$birth_years[bi],uu,b$years,f$sigma_res,
                                  b$birth_padding,length(b$birth_years))
   ell<-matrix(0,TT,4);pos<-rec<-risk<-forced<-matrix(0,TT,4)
   if(i<=f$Nobs) {
    ii<-f$selected[i];pos<-b$positive[ii,,];rec<-b$recovery[ii,,];risk<-b$at_risk[ii,,];forced<-b$forced[ii,,]
   }
   for(t in seq_len(TT)) {
    pp<-plogis(g["alpha_p"]+p$detection_sex+c(0,g[paste0("season[",2:4,"]")])+
      if(b$period[t]==1)0 else g[paste0("era[",b$period[t],"]")])
    marks<-matrix(captures[i,t,,,drop=FALSE],ncol=3L);au<-matrix(0,4,4)
    survey<-as.numeric(apply(b$availability[,,t,drop=FALSE],2,function(z)any(z>0)))
    if(i<=f$Nobs) {au<-b$aux[ii,t,,];survey<-b$survey[ii,t,]}
    ell[t,]<-v12k_emission(S[t,1],S[t,2],X,b$availability[,,t],marks,pp,
                         survey,p$sigma_det,au,f$aux_sd)
   }
   F<-v12k_factors_R(S,ell,pos,rec,risk,forced,p,b$bounds,f$reference_sd)
   path<-v12k_sample_path_R(F,p$psi,i<=f$Nobs)
   if(all(path==0))next
   Nsuper<-Nsuper+1L
   st<-path[2L+5L*(seq_len(TT)-1L)] # after annual entry/movement, before Q1
   alive<-st %in% 2:3
   pts<-sf::st_as_sf(data.frame(x=S[,1]*1000+b$origin[1],y=S[,2]*1000+b$origin[2]),
      coords=c("x","y"),crs=27700)
   incore<-lengths(sf::st_intersects(pts,b$zones[1,]))>0
   inouter<-lengths(sf::st_intersects(pts,b$zones[2,]))>0
   zone<-ifelse(incore,1L,ifelse(inouter,2L,3L))
   for(t in which(alive))nz[t,zone[t]]<-nz[t,zone[t]]+1
   for(t in seq_len(TT-1L))if(alive[t]&&alive[t+1L])
     flow[t,zone[t],zone[t+1L]]<-flow[t,zone[t],zone[t+1L]]+1
   for(t in seq_len(TT)) {
    previous<-path[1L+5L*(t-1L)]
    if(previous==1L && alive[t])entry[t]<-entry[t]+1
   }
  }
  counter<-counter+1L
  annual_rows[[counter]]<-data.frame(chain=ch,draw=row,year=b$years,
   core=nz[,1],periphery=nz[,2],outside=nz[,3],alive=rowSums(nz),
   annual_entry=entry,Nsuper=Nsuper,observed_cohort=f$Nobs,candidate_cap=NN)
  z<-expand.grid(interval=seq_len(TT-1L),origin=1:3,destination=1:3)
  z$count<-as.vector(flow);z$from_year<-b$years[z$interval]
  z$to_year<-b$years[z$interval+1L];z$chain<-ch;z$draw<-row
  z$origin<-c("core","periphery","outside")[z$origin]
  z$destination<-c("core","periphery","outside")[z$destination]
  flow_rows[[counter]]<-z
 }
}
annual<-do.call(rbind,annual_rows);flows<-do.call(rbind,flow_rows)
write.csv(annual,file.path(run,"annual_population_draws_SCENARIO.csv"),row.names=FALSE)
write.csv(flows,file.path(run,"zone_exchange_draws_SCENARIO.csv"),row.names=FALSE)
summ<-function(d,by,cols) {
 groups<-split(seq_len(nrow(d)),interaction(d[by],drop=TRUE))
 do.call(rbind,lapply(groups,function(ii) {
  r<-d[ii[1],by,drop=FALSE]
  for(nm in cols) {
   r[[paste0(nm,"_mean")]]<-mean(d[[nm]][ii])
   r[[paste0(nm,"_q025")]]<-unname(quantile(d[[nm]][ii],.025))
   r[[paste0(nm,"_q975")]]<-unname(quantile(d[[nm]][ii],.975))
  };r
 }))
}
write.csv(summ(annual,"year",c("core","periphery","outside","alive","annual_entry")),
 file.path(run,"annual_population_summary_SCENARIO.csv"),row.names=FALSE)
write.csv(summ(flows,c("from_year","to_year","origin","destination"),"count"),
 file.path(run,"zone_exchange_summary_SCENARIO.csv"),row.names=FALSE)
cap<-mean((annual$Nsuper-annual$observed_cohort)>=
           (annual$candidate_cap-annual$observed_cohort)*.95)
writeLines(c(paste0("global_diagnostics_all_pass=",all(diagnostics$diagnostics_pass)),
 paste0("state_paths_per_chain=",nd),paste0("fraction_draws_near_candidate_cap=",cap),
 "Population and outside exchange are assumption-dependent developmental outputs.",
 "First entry is not automatically immigration; outside is not permanent emigration.",
 "Counts are annual activity-centre endpoint transitions, not all excursions.",
 "Compare coverage, entry buffer, augmentation cap and recovery scenarios.",
 "Outside movement is extrapolated from a shared movement/survival process.",
 "Global diagnostics do not establish mixing of individual locations, birth cohorts, sex, random effects or abundance.",
 "Spatial/state summaries use a limited number of retained draws; inspect before interpretation."),
 file.path(run,"VALIDATION_STATUS.txt"))
cat(readLines(file.path(run,"VALIDATION_STATUS.txt")),sep="\n")
