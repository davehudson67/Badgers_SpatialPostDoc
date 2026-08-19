# =============================================================================
# WOODCHESTER SPATIAL CMR V3c DEVELOPMENT TEST
# 50 m habitat state space + NON-CENTRED HEAVY-TAILED movement
# Movement is an isotropic bivariate Student-t kernel with fixed df = 3.
# SG resistance remains out here; the next ecological model should add it only
# as a properly normalized movement component.
# =============================================================================
library(tidyverse); library(lubridate); library(nimble); library(coda); library(MCMCvis)

set.seed(123)

cat("\n============================================================\n")
cat("V3c HEAVY-TAILED MOVEMENT MODEL: BIVARIATE STUDENT-t3\n")
cat("400 badgers | non-centred | AF_slice | NO SG penalty yet\n")
cat("============================================================\n\n")

# ---- options ----------------------------------------------------------------
SAMPLE_N <- 400L
NITER <- 4000; NBURN <- 1000; NCHAINS <- 2

MOVE_DF <- 3
if(MOVE_DF <= 2) stop("MOVE_DF must be > 2.")
T_SCALE_FACTOR <- sqrt((MOVE_DF-2)/MOVE_DF)
MOVE_MEAN_FACTOR <- sqrt(MOVE_DF-2)*sqrt(pi)/2*gamma((MOVE_DF-1)/2)/gamma(MOVE_DF/2)
cat("Movement kernel: bivariate Student-t, df =",MOVE_DF,"; standardized t scale =",round(T_SCALE_FACTOR,4),"; mean radial factor =",round(MOVE_MEAN_FACTOR,4),"\n")

cmr_file <- "data/badger_final_CMRready_wDisease.rds"
sett_file <- "data/WoodchesterSettLocations.csv"
spatial_file <- "data/spatial/V3_spatial_inputs_50m_2km.rds"
dir.create("results",showWarnings=FALSE)

# ---- sett cleaning -----------------------------------------------------------
sett_aliases <- c("\\bCHESTNUT\\b"="CHESNUT","\\bJACKS\\b"="JACKSMIREY","\\bGRAVEL\\b"="GRAVELPIT",
"\\bBUCKHOLE\\b"="BUCKHOLT","\\bTOPSETT\\b"="TOP","\\bFOXCUB\\b"="FOX","\\bGULLEY\\b"="GULLY",
"\\bBLACKBERRY\\b"="BRAMBLE","\\bBOC\\b"="BOG","\\bCEDARBANK\\b"="CEDAR","\\bCLAYTRAP\\b"="CLAY",
"\\bCLIFF\\b"="CLIFFFACE","\\bDINGLEVALLEY\\b"="DINGLE")

clean_sett <- function(x) x %>% as.character() %>% toupper() %>%
  str_replace_all("[[:punct:]]"," ") %>% str_squish() %>%
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>% str_replace_all(sett_aliases) %>%
  str_replace_all("\\s+","")

# ---- V3 spatial inputs -------------------------------------------------------
sp <- readRDS(spatial_file)
SG_mat <- sp$SG_mat; habitat_mat <- sp$habitat_mat; zone_mat <- sp$zone_mat
grid_xmin <- sp$xmin; grid_xmax <- sp$xmax; grid_ymin <- sp$ymin; grid_ymax <- sp$ymax
cell_size <- sp$cell_size; n_rows <- sp$n_rows; n_cols <- sp$n_cols
stopifnot(!anyNA(SG_mat),!anyNA(habitat_mat),!anyNA(zone_mat))
cat("\nV3 grid:",n_rows,"x",n_cols,"@",cell_size,"m =",n_rows*n_cols,"cells\n")

# ---- exact sett coordinates --------------------------------------------------
sett_raw <- read_csv(sett_file,show_col_types=FALSE)
name_col <- intersect(c("Sett_Clean","Sett","sett","SettName","Sett_Upper","Name"),names(sett_raw))[1]
x_col <- intersect(c("SettX","sett_x","X","x","Easting","easting"),names(sett_raw))[1]
y_col <- intersect(c("SettY","sett_y","Y","y","Northing","northing"),names(sett_raw))[1]
if(any(is.na(c(name_col,x_col,y_col)))) stop("Could not identify sett name/X/Y columns.")

sett_xy <- sett_raw %>% transmute(Sett_Clean=clean_sett(.data[[name_col]]),
  x=as.numeric(.data[[x_col]]),y=as.numeric(.data[[y_col]])) %>%
  filter(!is.na(Sett_Clean),Sett_Clean!="",!is.na(x),!is.na(y)) %>% distinct(Sett_Clean,.keep_all=TRUE)

# ---- capture data ------------------------------------------------------------
cmr_raw <- readRDS(cmr_file)
cmr <- cmr_raw %>% mutate(Sett_Clean=clean_sett(sett),primary_year=as.integer(primary_year),
  trap_season=as.integer(trap_season)) %>% left_join(sett_xy,by="Sett_Clean")

cat("\nLive captures without XY:\n")
print(cmr %>% filter(has_live_capture,is.na(x)|is.na(y)) %>% count(Sett_Clean,sort=TRUE),n=Inf)
cmr <- cmr %>% filter(!has_live_capture | (!is.na(x)&!is.na(y)))

years <- min(cmr$primary_year,na.rm=TRUE):max(cmr$primary_year,na.rm=TRUE)
n_prim <- length(years); n_sec <- 4L
cmr <- cmr %>% mutate(primary=match(primary_year,years))
period_vec <- as.integer(match(floor(years/5)*5,sort(unique(floor(years/5)*5))))
n_periods <- max(period_vec)

# ---- entry group -------------------------------------------------------------
demog <- cmr_raw %>% arrange(tattoo,capture_date) %>% group_by(tattoo) %>%
  summarise(age_fc={a<-na.omit(age_fc); if(length(a)) as.character(a[1]) else NA_character_},.groups="drop") %>%
  mutate(entry_group=case_when(age_fc %in% c("Cub","Yearling")~1L,age_fc=="Adult"~2L,TRUE~NA_integer_))
cmr <- cmr %>% left_join(demog %>% select(tattoo,entry_group),by="tattoo")

# one live observation per badger x year x season
live <- cmr %>% filter(has_live_capture,!is.na(primary),!is.na(trap_season),!is.na(x),!is.na(y)) %>%
  arrange(tattoo,primary,trap_season,capture_date) %>% group_by(tattoo,primary,trap_season) %>%
  slice_tail(n=1) %>% ungroup()

eligible <- live %>% distinct(tattoo) %>% inner_join(demog,by="tattoo") %>%
  filter(entry_group %in% 1:2,!tattoo %in% "007V")
if(!is.na(SAMPLE_N) && SAMPLE_N<nrow(eligible)) eligible <- eligible %>% slice_sample(n=SAMPLE_N)

ids <- eligible$tattoo; nind <- length(ids)
live <- live %>% filter(tattoo %in% ids); cmr <- cmr %>% filter(tattoo %in% ids)
cat("\nBadgers:",nind,"\n"); print(count(eligible,entry_group))

# ---- exact-sett detectors ----------------------------------------------------
detectors <- live %>% distinct(Sett_Clean,x,y) %>% arrange(Sett_Clean) %>% mutate(detector=row_number())
X <- as.matrix(detectors %>% select(x,y)); R <- nrow(X)
live <- live %>% left_join(detectors %>% select(Sett_Clean,detector),by="Sett_Clean")

# Used-detector audit against new state space
det_audit <- detectors %>% mutate(
  col_R=floor((x-grid_xmin)/cell_size)+1L,row_R=floor((grid_ymax-y)/cell_size)+1L,
  in_bounds=col_R>=1 & col_R<=n_cols & row_R>=1 & row_R<=n_rows)
if(any(!det_audit$in_bounds)){print(det_audit %>% filter(!in_bounds),n=Inf); stop("Used detector outside V3 grid.")}

det_audit <- det_audit %>% mutate(
  SG=SG_mat[cbind(row_R,col_R)],habitat=habitat_mat[cbind(row_R,col_R)],zone=zone_mat[cbind(row_R,col_R)])
cat("\nDetector-grid audit:\n"); print(count(det_audit,zone,habitat,SG,sort=TRUE),n=Inf)
if(any(det_audit$habitat!=1L)) warning("At least one used detector falls in habitat=0; inspect det_audit.")

# ---- individual metadata -----------------------------------------------------
meta <- live %>% arrange(tattoo,primary,trap_season,capture_date) %>% group_by(tattoo) %>%
  summarise(first=first(primary),first_detector=first(detector),entry_group=first(entry_group),.groups="drop") %>%
  right_join(tibble(tattoo=ids),by="tattoo") %>% arrange(match(tattoo,ids))

first <- as.integer(meta$first); first_detector <- as.integer(meta$first_detector)
entry_group <- as.integer(meta$entry_group)
stopifnot(!anyNA(first),!anyNA(first_detector),!anyNA(entry_group))

# ---- death information -------------------------------------------------------
death <- cmr %>% filter(has_pm_record,!is.na(primary)) %>% group_by(tattoo) %>%
  summarise(death_primary=min(primary),death_season={
    q<-trap_season[primary==min(primary)]; q<-q[!is.na(q)]; if(length(q)) min(q) else NA_integer_},.groups="drop")

death_primary <- rep(n_prim+1L,nind); death_season <- rep(NA_integer_,nind)
m <- match(ids,death$tattoo); has_death <- !is.na(m)
death_primary[has_death] <- death$death_primary[m[has_death]]
death_season[has_death] <- death$death_season[m[has_death]]
known_death <- death_primary<=n_prim
K <- rep(n_prim,nind); K[known_death] <- pmin(n_prim,death_primary[known_death]+1L)

# ---- encounters --------------------------------------------------------------
H <- array(1L,c(nind,n_sec,n_prim))
for(r in seq_len(nrow(live))) H[match(live$tattoo[r],ids),live$trap_season[r],live$primary[r]] <- live$detector[r]+1L

J <- matrix(n_sec,nind,n_prim)
for(i in seq_len(nind)) if(known_death[i] && !is.na(death_season[i]) && death_primary[i]<=n_prim)
  J[i,death_primary[i]] <- max(1L,death_season[i])

z_data <- matrix(NA_integer_,nind,n_prim)
for(i in seq_len(nind)){
  z_data[i,unique(live$primary[live$tattoo==ids[i]])] <- 1L
  if(known_death[i]){
    z_data[i,death_primary[i]] <- 1L
    if(death_primary[i]<n_prim) z_data[i,(death_primary[i]+1L):n_prim] <- 0L
  }
}

# sort histories for compact model loops
ord <- order(K-first)
ids<-ids[ord]; H<-H[ord,,,drop=FALSE]; J<-J[ord,,drop=FALSE]; z_data<-z_data[ord,,drop=FALSE]
first<-first[ord]; K<-K[ord]; first_detector<-first_detector[ord]; entry_group<-entry_group[ord]; death_primary<-death_primary[ord]
N <- c(sum(K==first),nind)
if(any(K<first)) stop("ERROR: K < first.")
if(any(death_primary<first & death_primary<=n_prim)) stop("ERROR: known death before first spatial capture.")
if(N[1]==0L || N[1]==N[2]) stop("Current compact loops require both single- and multi-primary histories.")

# ---- initial values ----------------------------------------------------------
make_inits <- function(chain=1L){
  z_init <- matrix(0L,nind,n_prim)
  S_init <- array(NA_real_,c(nind,2,n_prim))
  eps_init <- array(NA_real_,c(nind,2,n_prim))

  alpha_logmove_init <- log(c(70,50))+rnorm(2,0,.03)
  sigma_move_init <- exp(alpha_logmove_init)

  for(i in seq_len(nind)){
    d <- live %>% filter(tattoo==ids[i]) %>% arrange(primary,trap_season,capture_date) %>%
      group_by(primary) %>% slice(1) %>% ungroup() %>% select(primary,x,y)

    xy <- matrix(NA_real_,n_prim,2)
    for(k in first[i]:K[i]){
      dk <- d %>% filter(primary==k)
      if(nrow(dk)) xy[k,] <- c(dk$x[1],dk$y[1]) else if(k>first[i]) xy[k,] <- xy[k-1,]
    }

    # Only the first annual AC is stochastic in the non-centred model.
    S_init[i,,first[i]] <- xy[first[i],]
    z_init[i,first[i]:K[i]] <- 1L

    # Innovations reconstruct exactly the same initial AC trajectory:
    # S[k] = S[k-1] + sigma_move[group] * eps[k].
    if(K[i]>first[i]) for(k in (first[i]+1L):K[i]){
      eps_init[i,1,k] <- (xy[k,1]-xy[k-1,1])/sigma_move_init[entry_group[i]]
      eps_init[i,2,k] <- (xy[k,2]-xy[k-1,2])/sigma_move_init[entry_group[i]]
    }
  }

  z_init[!is.na(z_data)] <- NA
  list(alpha_phi=c(qlogis(.70),qlogis(.68))+rnorm(2,0,.03),
       alpha_p=c(qlogis(.20),qlogis(.20))+rnorm(2,0,.03),
       alpha_logsigma=log(c(150,120))+rnorm(2,0,.03),
       alpha_logmove=alpha_logmove_init,
       beta_season_raw=rnorm(3,0,.03),beta_period_raw=rnorm(n_periods-1L,0,.03),
       S=S_init,eps=eps_init,z=z_init)
}
inits <- lapply(seq_len(NCHAINS),make_inits)

# ---- V3 initialization habitat audit -----------------------------------------
# Reconstruct the non-centred initial AC trajectories and verify that every
# living AC starts inside the grid and on habitat = 1.
bad_init <- list()
for(i in seq_len(nind)){
  g <- entry_group[i]
  sig0 <- exp(inits[[1]]$alpha_logmove[g])
  sx <- inits[[1]]$S[i,1,first[i]]
  sy <- inits[[1]]$S[i,2,first[i]]

  for(k in first[i]:K[i]){
    if(k>first[i]){
      sx <- sx + sig0*inits[[1]]$eps[i,1,k]
      sy <- sy + sig0*inits[[1]]$eps[i,2,k]
    }
    col <- floor((sx-grid_xmin)/cell_size)+1L
    row <- floor((grid_ymax-sy)/cell_size)+1L
    inb <- row>=1L && row<=n_rows && col>=1L && col<=n_cols
    hab <- if(inb) habitat_mat[row,col] else NA_integer_
    z0 <- if(is.na(z_data[i,k])) 1L else z_data[i,k]

    if(z0==1L && (!inb || is.na(hab) || hab!=1L))
      bad_init[[length(bad_init)+1L]] <- tibble(i=i,tattoo=ids[i],k=k,year=years[k],
        x=sx,y=sy,row=row,col=col,in_bounds=inb,habitat=hab)
  }
}
bad_init <- bind_rows(bad_init)
if(nrow(bad_init)){print(bad_init,n=Inf); stop("Invalid living AC initial values detected.")}
cat("\nInitial non-centred AC habitat audit: PASS\n")

# ---- V3 model ----------------------------------------------------------------
code_V3 <- nimbleCode({

  for(grp in 1:2){
    alpha_phi[grp] ~ dnorm(qlogis(.70),sd=1.5); phi_annual[grp] <- ilogit(alpha_phi[grp])
    alpha_p[grp] ~ dnorm(qlogis(.15),sd=1.5)
    alpha_logsigma[grp] ~ dnorm(log(250),sd=1); sigma[grp] <- exp(alpha_logsigma[grp])
    alpha_logmove[grp] ~ dnorm(log(100),sd=1); sigma_move[grp] <- exp(alpha_logmove[grp])
    mean_move[grp] <- sigma_move[grp]*MOVE_MEAN_FACTOR
  }


  for(s in 1:3){beta_season_raw[s] ~ dnorm(0,sd=1); beta_season[s] <- beta_season_raw[s]}
  beta_season[4] <- -sum(beta_season_raw[1:3])

  for(p in 1:(n_periods-1)){beta_period_raw[p] ~ dnorm(0,sd=1); beta_period[p] <- beta_period_raw[p]}
  beta_period[n_periods] <- -sum(beta_period_raw[1:(n_periods-1)])

  # Single-primary histories
  for(i in 1:N[1]){
    z[i,first[i]] ~ dbern(1)
    S[i,1,first[i]] ~ dunif(grid_xmin,grid_xmax)
    S[i,2,first[i]] ~ dunif(grid_ymin,grid_ymax)

    col_raw[i,first[i]] <- trunc((S[i,1,first[i]]-grid_xmin)/cell_size)+1
    row_raw[i,first[i]] <- trunc((grid_ymax-S[i,2,first[i]])/cell_size)+1
    col_S[i,first[i]] <- max(1,min(n_cols,col_raw[i,first[i]]))
    row_S[i,first[i]] <- max(1,min(n_rows,row_raw[i,first[i]]))
    in_bounds[i,first[i]] <- step(S[i,1,first[i]]-grid_xmin)*step(grid_xmax-S[i,1,first[i]])*
      step(S[i,2,first[i]]-grid_ymin)*step(grid_ymax-S[i,2,first[i]])
    habitat_here[i,first[i]] <- habitat_mat[row_S[i,first[i]],col_S[i,first[i]]]
    state_ok[i,first[i]] ~ dbern(in_bounds[i,first[i]]*habitat_here[i,first[i]])

    g[i,first[i],1] <- 0
    for(r in 1:R){
      D[i,r,first[i]] <- sqrt(pow(S[i,1,first[i]]-X[r,1],2)+pow(S[i,2,first[i]]-X[r,2],2))
      g[i,first[i],r+1] <- exp(-pow(D[i,r,first[i]],2)/(2*pow(sigma[entry_group[i]],2)))
    }
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])

    for(j in 1:J[i,first[i]]){
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]]+beta_season[j]+beta_period[period_vec[first[i]]]
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      captureProb[i,j,first[i]] <- step(H[i,j,first[i]]-2)*(g[i,first[i],H[i,j,first[i]]]/
        (G[i,first[i]]+1e-10))*P[i,j,first[i]]+(1-step(H[i,j,first[i]]-2))*(1-P[i,j,first[i]])
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }
  }

  # Multi-primary histories
  for(i in (N[1]+1):N[2]){
    z[i,first[i]] ~ dbern(1)
    S[i,1,first[i]] ~ dunif(grid_xmin,grid_xmax)
    S[i,2,first[i]] ~ dunif(grid_ymin,grid_ymax)

    col_raw[i,first[i]] <- trunc((S[i,1,first[i]]-grid_xmin)/cell_size)+1
    row_raw[i,first[i]] <- trunc((grid_ymax-S[i,2,first[i]])/cell_size)+1
    col_S[i,first[i]] <- max(1,min(n_cols,col_raw[i,first[i]]))
    row_S[i,first[i]] <- max(1,min(n_rows,row_raw[i,first[i]]))
    in_bounds[i,first[i]] <- step(S[i,1,first[i]]-grid_xmin)*step(grid_xmax-S[i,1,first[i]])*
      step(S[i,2,first[i]]-grid_ymin)*step(grid_ymax-S[i,2,first[i]])
    habitat_here[i,first[i]] <- habitat_mat[row_S[i,first[i]],col_S[i,first[i]]]
    state_ok[i,first[i]] ~ dbern(in_bounds[i,first[i]]*habitat_here[i,first[i]])

    g[i,first[i],1] <- 0
    for(r in 1:R){
      D[i,r,first[i]] <- sqrt(pow(S[i,1,first[i]]-X[r,1],2)+pow(S[i,2,first[i]]-X[r,2],2))
      g[i,first[i],r+1] <- exp(-pow(D[i,r,first[i]],2)/(2*pow(sigma[entry_group[i]],2)))
    }
    G[i,first[i]] <- sum(g[i,first[i],1:(R+1)])

    for(j in 1:J[i,first[i]]){
      lp0[i,j,first[i]] <- alpha_p[entry_group[i]]+beta_season[j]+beta_period[period_vec[first[i]]]
      p0[i,j,first[i]] <- ilogit(lp0[i,j,first[i]])
      lambda0[i,j,first[i]] <- -log(1-p0[i,j,first[i]])
      P[i,j,first[i]] <- 1-exp(-lambda0[i,j,first[i]]*G[i,first[i]])
      captureProb[i,j,first[i]] <- step(H[i,j,first[i]]-2)*(g[i,first[i],H[i,j,first[i]]]/
        (G[i,first[i]]+1e-10))*P[i,j,first[i]]+(1-step(H[i,j,first[i]]-2))*(1-P[i,j,first[i]])
      Ones[i,j,first[i]] ~ dbern(captureProb[i,j,first[i]])
    }

    for(k in (first[i]+1):K[i]){
      Palive[i,k-1] <- z[i,k-1]*phi_annual[entry_group[i]]
      z[i,k] ~ dbern(Palive[i,k-1]*step(death_primary[i]-k))

      # HEAVY-TAILED NON-CENTRED movement. The bivariate-t scale matrix is
      # chosen so each innovation coordinate has variance 1, retaining the
      # Gaussian model's interpretation of sigma_move as per-axis movement SD.
      eps[i,1:2,k] ~ dmvt(mu=eps_zero[1:2],scale=eps_scale[1:2,1:2],df=MOVE_DF)
      S[i,1,k] <- S[i,1,k-1]+sigma_move[entry_group[i]]*eps[i,1,k]
      S[i,2,k] <- S[i,2,k-1]+sigma_move[entry_group[i]]*eps[i,2,k]
      moveDist[i,k-1] <- sigma_move[entry_group[i]]*sqrt(pow(eps[i,1,k],2)+pow(eps[i,2,k],2))

      # metre coordinates -> 50 m landscape matrix
      col_raw[i,k] <- trunc((S[i,1,k]-grid_xmin)/cell_size)+1
      row_raw[i,k] <- trunc((grid_ymax-S[i,2,k])/cell_size)+1
      col_S[i,k] <- max(1,min(n_cols,col_raw[i,k]))
      row_S[i,k] <- max(1,min(n_rows,row_raw[i,k]))
      in_bounds[i,k] <- step(S[i,1,k]-grid_xmin)*step(grid_xmax-S[i,1,k])*
        step(S[i,2,k]-grid_ymin)*step(grid_ymax-S[i,2,k])

      habitat_here[i,k] <- habitat_mat[row_S[i,k],col_S[i,k]]

      # living AC must occupy valid land inside the state space
      valid_state[i,k] <- in_bounds[i,k]*habitat_here[i,k]
      state_prob[i,k] <- (1-z[i,k])+z[i,k]*valid_state[i,k]
      state_ok[i,k] ~ dbern(state_prob[i,k])

      g[i,k,1] <- 0
      for(r in 1:R){
        D[i,r,k] <- sqrt(pow(S[i,1,k]-X[r,1],2)+pow(S[i,2,k]-X[r,2],2))
        g[i,k,r+1] <- exp(-pow(D[i,r,k],2)/(2*pow(sigma[entry_group[i]],2)))
      }
      G[i,k] <- sum(g[i,k,1:(R+1)])

      for(j in 1:J[i,k]){
        lp0[i,j,k] <- alpha_p[entry_group[i]]+beta_season[j]+beta_period[period_vec[k]]
        p0[i,j,k] <- ilogit(lp0[i,j,k])
        lambda0[i,j,k] <- -log(1-p0[i,j,k])
        P[i,j,k] <- (1-exp(-lambda0[i,j,k]*G[i,k]))*z[i,k]
        captureProb[i,j,k] <- step(H[i,j,k]-2)*(g[i,k,H[i,j,k]]/(G[i,k]+1e-10))*P[i,j,k]+
          (1-step(H[i,j,k]-2))*(1-P[i,j,k])
        Ones[i,j,k] ~ dbern(captureProb[i,j,k])
      }
    }
  }
})


# ---- build -------------------------------------------------------------------
eps_zero <- c(0,0)
eps_scale <- diag(T_SCALE_FACTOR^2,2)

consts <- list(R=R,N=N,K=as.integer(K),J=J,first=as.integer(first),X=X,H=H,
  n_periods=n_periods,period_vec=period_vec,entry_group=entry_group,death_primary=death_primary,
  grid_xmin=grid_xmin,grid_xmax=grid_xmax,grid_ymin=grid_ymin,grid_ymax=grid_ymax,
  cell_size=cell_size,n_rows=n_rows,n_cols=n_cols,MOVE_DF=MOVE_DF,
  MOVE_MEAN_FACTOR=MOVE_MEAN_FACTOR,eps_zero=eps_zero,eps_scale=eps_scale)

data_list <- list(Ones=array(1L,dim(H)),z=z_data,state_ok=matrix(1L,nind,n_prim),
  habitat_mat=habitat_mat)

# ---- sanity check: make sure this is NOT the Gaussian epsX/epsY model -------
code_txt <- paste(deparse(code_V3),collapse=" ")
if(!grepl("dmvt",code_txt)) stop("STOP: code_V3 does not contain dmvt; wrong model loaded.")
if(grepl("epsX|epsY",code_txt)) stop("STOP: Gaussian epsX/epsY code detected; wrong model loaded.")
cat("\nHeavy-tail code check: PASS (dmvt present; epsX/epsY absent)\n")

message("\nBuilding V3c HEAVY-TAILED Student-t3 model...")
model_V3 <- nimbleModel(code_V3,constants=consts,data=data_list,inits=inits[[1]],
  dimensions=list(Ones=dim(H),z=dim(z_data),state_ok=c(nind,n_prim)),
  check=TRUE,calculate=FALSE)

print(model_V3$initializeInfo())
lp <- model_V3$calculate()
cat("\nInitial log probability:",lp,"\n")
if(!is.finite(lp)) stop("V3 initial log probability is not finite.")

message("\nCompiling model...")
cModel_V3 <- compileNimble(model_V3,resetFunctions=TRUE)

monitors <- c("phi_annual","sigma_move","mean_move","sigma","alpha_p","beta_season","beta_period")
config_V3 <- configureMCMC(model_V3,monitors=monitors,thin=1)

# Each subsequent annual movement innovation is one bivariate-t stochastic node.
for(i in (N[1]+1L):N[2]) for(k in (first[i]+1L):K[i]){
  node <- paste0("eps[",i,", 1:2, ",k,"]")
  config_V3$removeSamplers(node,print=FALSE)
  config_V3$addSampler(target=node,type="AF_slice")
}

Rmcmc_V3 <- buildMCMC(config_V3)
message("\nCompiling MCMC...")
cMCMC_V3 <- compileNimble(Rmcmc_V3,project=cModel_V3,resetFunctions=TRUE)

# ---- run ---------------------------------------------------------------------
message("\nRunning V3c NON-CENTRED Student-t development model...")
runtime_V3 <- system.time(samples_V3 <- runMCMC(cMCMC_V3,niter=NITER,nburnin=NBURN,nchains=NCHAINS,
  inits=inits,samplesAsCodaMCMC=TRUE,progressBar=TRUE,setSeed=3451:(3451+NCHAINS-1L)))
print(runtime_V3)

saveRDS(list(samples=samples_V3,runtime=runtime_V3,ids=ids,detectors=detectors,det_audit=det_audit,
  settings=list(sample_n=SAMPLE_N,niter=NITER,nburn=NBURN,nchains=NCHAINS,
                ac_sampler="AF_slice_bivariate_t",parameterisation="noncentred",movement_kernel="bivariate_Student_t",move_df=MOVE_DF,sg_model="removed_pending_normalized_kernel"),
  spatial_file=spatial_file),
  paste0("results/RD_SCR_V3c_t",MOVE_DF,"_SHORTTEST_habitat_noncentred_AF_",nind,"_badgers.rds"))

MCMCsummary(samples_V3)
gelman.diag(samples_V3,multivariate=FALSE)
effectiveSize(samples_V3)
