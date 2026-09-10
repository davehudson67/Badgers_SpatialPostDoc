# =============================================================================
# V7MC-MHMM v6 PAIR-AC COMBINE + EXACT POSTERIOR STATE AGREEMENT
# =============================================================================
library(tidyverse)
library(coda)

CHAIN_FILES <- sprintf(
  "results/RD_SCR_V7MCMHMMv6_PAIR_AC_1285_CHAIN_%d_TUNED_15K.rds",1:3
)
missing <- CHAIN_FILES[!file.exists(CHAIN_FILES)]
if(length(missing)) stop("Missing chain file(s):\n",paste(missing,collapse="\n"))

ilogit <- function(x) 1/(1+exp(-x))
logsum2 <- function(a,b){m<-max(a,b);m+log(exp(a-m)+exp(b-m))}
classic_rhat <- function(xs){
  n<-min(vapply(xs,length,integer(1)))
  xs<-lapply(xs,function(x)as.numeric(x[seq_len(n)]))
  W<-mean(vapply(xs,var,numeric(1))); B<-n*var(vapply(xs,mean,numeric(1)))
  if(!is.finite(W)||W<=0)return(NA_real_)
  sqrt((((n-1)/n)*W+B/n)/W)
}
smooth_high <- function(lr,p_init,p_RD,p_DD){
  Tn<-length(lr); if(!Tn)return(numeric())
  e<-1e-12
  p_init<-min(1-e,max(e,p_init));p_RD<-min(1-e,max(e,p_RD));p_DD<-min(1-e,max(e,p_DD))
  a0<-a1<-numeric(Tn)
  x0<-log1p(-p_init);x1<-log(p_init)+lr[1];z<-logsum2(x0,x1)
  a0[1]<-x0-z;a1[1]<-x1-z
  if(Tn>1)for(t in 2:Tn){
    q0<-logsum2(a0[t-1]+log1p(-p_RD),a1[t-1]+log1p(-p_DD))
    q1<-logsum2(a0[t-1]+log(p_RD),a1[t-1]+log(p_DD))
    z<-logsum2(q0,q1+lr[t]);a0[t]<-q0-z;a1[t]<-q1+lr[t]-z
  }
  b0<-b1<-numeric(Tn)
  if(Tn>1)for(t in (Tn-1):1){
    q0<-logsum2(log1p(-p_RD)+b0[t+1],log(p_RD)+lr[t+1]+b1[t+1])
    q1<-logsum2(log1p(-p_DD)+b0[t+1],log(p_DD)+lr[t+1]+b1[t+1])
    z<-logsum2(q0,q1);b0[t]<-q0-z;b1[t]<-q1-z
  }
  out<-numeric(Tn)
  for(t in seq_len(Tn)){
    g0<-a0[t]+b0[t];g1<-a1[t]+b1[t];z<-logsum2(g0,g1);out[t]<-exp(g1-z)
  }
  out
}
canon <- function(x)gsub("\\s+","",x)

global_chains<-vector("list",3);p_by_chain<-NULL;runtimes<-vector("list",3)

for(cc in 1:3){
  cat("\n============================================================\nREADING V6 CHAIN",cc,"\n============================================================\n")
  obj<-readRDS(CHAIN_FILES[cc]);sm<-as.matrix(obj$samples);cn<-colnames(sm);ccn<-canon(cn)

  if(cc==1){
    ids<-obj$ids;individual_ids<-obj$individual_ids
    sex_data<-as.integer(obj$sex_data);adult_entry<-as.integer(obj$adult_entry)
    first<-as.integer(obj$first);K<-as.integer(obj$K);years<-obj$years
    disp_index<-obj$disp_index;nind<-length(ids);n_interval<-nrow(disp_index)
    base<-sub("\\[.*$","",ccn)
    global_pos<-which(base%in%obj$core_monitors);global_names<-cn[global_pos]
    emit_names<-paste0("log_emit_ratio_save[",seq_len(n_interval),"]")
    emit_pos<-match(canon(emit_names),ccn)
    if(anyNA(emit_pos))stop("Could not match emission-ratio columns.")
    rows_by_i<-split(seq_len(n_interval),disp_index$model_i)
    p_by_chain<-matrix(NA_real_,n_interval,3,dimnames=list(NULL,paste0("chain",1:3)))
    cat("Retained draws:",nrow(sm),"\n")
  }else{
    global_pos<-match(canon(global_names),ccn);emit_pos<-match(canon(emit_names),ccn)
    if(anyNA(global_pos)||anyNA(emit_pos))stop("Column mismatch in chain ",cc)
  }

  G<-sm[,global_pos,drop=FALSE];E<-sm[,emit_pos,drop=FALSE];global_chains[[cc]]<-G
  gp<-function(x){z<-match(x,colnames(G));if(is.na(z))stop("Missing ",x);z}
  ja<-gp("alpha_disp_init");jba<-gp("beta_disp_adult");jbs<-gp("beta_disp_init_sex")
  jr<-gp("alpha_RD");jbr<-gp("beta_RD_sex");jd<-gp("alpha_DD");jbd<-gp("beta_DD_sex")
  psum<-numeric(n_interval)

  cat("Exact smoothing across",nrow(sm),"draws...\n")
  for(d in seq_len(nrow(sm))){
    gd<-G[d,]
    for(i in seq_len(nind)){
      rr<-rows_by_i[[as.character(i)]];if(is.null(rr)||!length(rr))next
      p0<-ilogit(gd[ja]+gd[jba]*adult_entry[i]+gd[jbs]*sex_data[i])
      pr<-ilogit(gd[jr]+gd[jbr]*sex_data[i]);pd<-ilogit(gd[jd]+gd[jbd]*sex_data[i])
      psum[rr]<-psum[rr]+smooth_high(E[d,rr],p0,pr,pd)
    }
    if(d%%250==0)cat("  draw",d,"/",nrow(sm),"\n")
  }
  p_by_chain[,cc]<-psum/nrow(sm);runtimes[[cc]]<-obj$runtime
  rm(obj,sm,E,G,psum);gc()
}

diag_rows<-lapply(seq_along(global_names),function(j){
  xs<-lapply(global_chains,function(m)m[,j]);par<-global_names[j]
  one<-coda::mcmc.list(lapply(xs,function(x)coda::as.mcmc(matrix(x,ncol=1,dimnames=list(NULL,par)))))
  tibble(parameter=par,Rhat=classic_rhat(xs),
         ESS=tryCatch(as.numeric(coda::effectiveSize(one)[1]),error=function(e)NA_real_),
         chain1_mean=mean(xs[[1]]),chain2_mean=mean(xs[[2]]),chain3_mean=mean(xs[[3]]))
})
global_diag<-bind_rows(diag_rows)%>%arrange(desc(Rhat))

per_chain<-bind_rows(lapply(1:3,function(j){
  p<-p_by_chain[,j]
  tibble(chain=j,mean_p_high=mean(p),median_p_high=median(p),
         n_p50=sum(p>=.5),n_p80=sum(p>=.8),n_p95=sum(p>=.95))
}))
pairwise<-bind_rows(lapply(combn(1:3,2,simplify=FALSE),function(z){
  a<-p_by_chain[,z[1]];b<-p_by_chain[,z[2]]
  tibble(chain_a=z[1],chain_b=z[2],correlation=cor(a,b),
         mean_abs_diff=mean(abs(a-b)),median_abs_diff=median(abs(a-b)),
         q95_abs_diff=as.numeric(quantile(abs(a-b),.95)),
         n_abs_diff_gt_0_20=sum(abs(a-b)>.2),n_abs_diff_gt_0_50=sum(abs(a-b)>.5))
}))
rng<-apply(p_by_chain,1,function(z)max(z)-min(z));m50<-rowSums(p_by_chain>=.5);m80<-rowSums(p_by_chain>=.8)
overall<-tibble(n_intervals=nrow(p_by_chain),mean_chain_range=mean(rng),median_chain_range=median(rng),
                q95_chain_range=as.numeric(quantile(rng,.95)),n_range_gt_0_20=sum(rng>.2),n_range_gt_0_50=sum(rng>.5),
                n_p50_all_3=sum(m50==3),n_p50_2_of_3=sum(m50==2),n_p50_1_of_3=sum(m50==1),
                n_p80_all_3=sum(m80==3),n_p80_2_of_3=sum(m80==2),n_p80_1_of_3=sum(m80==1))
intervals<-disp_index%>%bind_cols(as_tibble(p_by_chain))%>%
  mutate(p_chain_min=apply(p_by_chain,1,min),p_chain_max=apply(p_by_chain,1,max),
         p_chain_range=p_chain_max-p_chain_min)%>%arrange(desc(p_chain_range))

cat("\n============================================================\nGLOBAL PARAMETER DIAGNOSTICS\n============================================================\n")
print(global_diag,n=Inf,width=Inf)
cat("\nConvergence summary:\n")
print(global_diag%>%summarise(n_parameters=n(),max_Rhat=max(Rhat,na.rm=TRUE),
  n_Rhat_gt_1_01=sum(Rhat>1.01,na.rm=TRUE),n_Rhat_gt_1_05=sum(Rhat>1.05,na.rm=TRUE),
  min_ESS=min(ESS,na.rm=TRUE),median_ESS=median(ESS,na.rm=TRUE)))
cat("\nEXACT SMOOTHED MOVEMENT-STATE OCCUPANCY\n");print(per_chain,width=Inf)
cat("\nPAIRWISE CHAIN AGREEMENT: EXACT P(HIGH)\n");print(pairwise,width=Inf)
cat("\nOVERALL LATENT-STATE AGREEMENT\n");print(overall,width=Inf)
cat("\n20 MOST CHAIN-SENSITIVE INTERVALS\n")
print(intervals%>%select(tattoo,from_year,to_year,starts_with("chain"),p_chain_min,p_chain_max,p_chain_range)%>%slice_head(n=20),n=20,width=Inf)

saveRDS(list(global_diagnostics=global_diag,per_chain=per_chain,pairwise=pairwise,
             overall=overall,interval_chain_probabilities=intervals,runtimes=runtimes,
             chain_files=CHAIN_FILES,
             settings=list(model="V7MCMHMMv6_pair_AC",
                           latent_diagnostic="exact_forward_backward_smoothed_P_high")),
        "results/V7MCMHMMv6_PAIR_AC_TUNED_15K_diagnostics.rds")
cat("\nSaved: results/V7MCMHMMv6_PAIR_AC_TUNED_15K_diagnostics.rds\n")
