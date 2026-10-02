# =============================================================================
# SAME-GROUP PRESSURE MODEL — MATRIX-FIT IMPLEMENTATION
#
# Purpose
#   V3 removed factor contrasts from quarter/period handling but the pressure
#   models still failed inside formula-based glm() with:
#     "Argument mu must be a nonempty numeric vector"
#
#   M0_FULL and M0_CC continued to fit correctly, so the risk-set construction
#   and response data remained sound. This version therefore leaves the V2
#   scientific model and risk-set builder unchanged but replaces formula-based
#   fitting with an explicit numeric design matrix and stats::glm.fit().
#
#   This bypasses model.frame(), formula expansion and factor contrasts entirely.
#   The fitted scientific models remain:
#     M0_FULL        movement + sex + quarter + period
#     M0_CC          movement + sex + quarter + period
#     M1_RAW         M0_CC + raw same-group pressure
#     M1_SMOOTH      M0_CC + smoothed same-group pressure
#     M2_INTERACTION M1_RAW + movement x pressure
#
#   Cluster-robust covariance and posterior MVN draws are retained.
# =============================================================================

src <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V2.R"
if(!file.exists(src)) stop("Missing source script: ",src)

x <- readLines(src,warn=FALSE)
txt <- paste(x,collapse="\n")

old_start <- "fit_one <- function(formula,d,nkeep){"
old_end <- "\n\nmake_risk_data <- function"
if(!grepl(old_start,txt,fixed=TRUE)) stop("Could not find fit_one() in V2 script.")
if(!grepl(old_end,txt,fixed=TRUE)) stop("Could not find make_risk_data() boundary in V2 script.")

new_fit <- paste0(
"fit_one <- function(formula,d,nkeep){\n",
"  warns <- character(0)\n",
"  ftxt <- gsub('\\\\s+','',paste(deparse(formula),collapse=''))\n",
"\n",
"  y <- as.numeric(d$infection_event)\n",
"  cluster <- as.character(d$tattoo)\n",
"  if(!length(y) || !all(y %in% c(0,1)))\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,warning='',message='invalid or empty binary outcome'))\n",
"\n",
"  X <- matrix(1,nrow=nrow(d),ncol=1)\n",
"  colnames(X) <- '(Intercept)'\n",
"  add_col <- function(X,v,nm){\n",
"    z <- matrix(as.numeric(v),ncol=1); colnames(z) <- nm; cbind(X,z)\n",
"  }\n",
"\n",
"  X <- add_col(X,d$movement_state,'movement_state')\n",
"\n",
"  use_smooth <- grepl('pressure_smooth10',ftxt,fixed=TRUE)\n",
"  use_raw <- grepl('pressure10',ftxt,fixed=TRUE) && !use_smooth\n",
"  use_interaction <- grepl('movement_state*pressure10',ftxt,fixed=TRUE)\n",
"\n",
"  if(use_smooth) X <- add_col(X,d$pressure_smooth10,'pressure_smooth10')\n",
"  if(use_raw) X <- add_col(X,d$pressure10,'pressure10')\n",
"  if(use_interaction) X <- add_col(X,d$movement_state*d$pressure10,'movement_state:pressure10')\n",
"\n",
"  X <- add_col(X,d$sex,'sex')\n",
"\n",
"  qlev <- sort(unique(as.integer(d$outcome_quarter)))\n",
"  if(length(qlev)>1L){\n",
"    for(q in qlev[-1L]) X <- add_col(X,as.integer(d$outcome_quarter==q),paste0('quarter',q))\n",
"  }\n",
"\n",
"  plev <- sort(unique(as.integer(d$period_start)))\n",
"  if(length(plev)>1L){\n",
"    for(p in plev[-1L]) X <- add_col(X,as.integer(d$period_start==p),paste0('period',p))\n",
"  }\n",
"\n",
"  good <- is.finite(y) & nzchar(cluster) & apply(X,1,function(z) all(is.finite(z)))\n",
"  if(!all(good)){\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,warning='',\n",
"                message=paste0('non-finite model row(s): ',sum(!good))))\n",
"  }\n",
"\n",
"  fit <- tryCatch(\n",
"    withCallingHandlers(\n",
"      stats::glm.fit(x=X,y=y,family=stats::binomial(link='logit'),\n",
"                     control=stats::glm.control(maxit=100,epsilon=1e-8),intercept=TRUE),\n",
"      warning=function(w){warns <<- c(warns,conditionMessage(w)); invokeRestart('muffleWarning')}\n",
"    ),\n",
"    error=function(e)e\n",
"  )\n",
"\n",
"  if(inherits(fit,'error'))\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,\n",
"                warning=paste(unique(warns),collapse=' | '),message=conditionMessage(fit)))\n",
"  if(!isTRUE(fit$converged))\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,\n",
"                warning=paste(unique(warns),collapse=' | '),message='glm.fit did not converge'))\n",
"\n",
"  cf <- fit$coefficients\n",
"  active <- which(is.finite(cf))\n",
"  if(!length(active))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),message='no estimable coefficients'))\n",
"\n",
"  Xa <- X[,active,drop=FALSE]\n",
"  cf <- cf[active]\n",
"  mu <- as.numeric(fit$fitted.values)\n",
"  if(length(mu)!=length(y) || !length(mu) || any(!is.finite(mu)))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),message='invalid fitted probabilities'))\n",
"\n",
"  w <- pmax(mu*(1-mu),1e-12)\n",
"  XtWX <- crossprod(Xa,Xa*w)\n",
"\n",
"  inv_psd <- function(M){\n",
"    M <- (M+t(M))/2\n",
"    ee <- eigen(M,symmetric=TRUE)\n",
"    tol <- max(1e-12,max(abs(ee$values))*1e-10)\n",
"    keep <- ee$values>tol\n",
"    if(!any(keep)) stop('information matrix has no positive eigenvalues')\n",
"    V <- ee$vectors[,keep,drop=FALSE]\n",
"    V %*% diag(1/ee$values[keep],nrow=sum(keep)) %*% t(V)\n",
"  }\n",
"\n",
"  rob <- tryCatch({\n",
"    bread <- inv_psd(XtWX)\n",
"    score_rows <- Xa*as.numeric(y-mu)\n",
"    U <- rowsum(score_rows,group=cluster,reorder=FALSE)\n",
"    meat <- crossprod(U)\n",
"    G <- nrow(U); N <- nrow(Xa); K <- ncol(Xa)\n",
"    correction <- if(G>1L && N>K) (G/(G-1))*((N-1)/(N-K)) else 1\n",
"    VV <- bread %*% (correction*meat) %*% bread\n",
"    VV <- (VV+t(VV))/2\n",
"    rownames(VV) <- colnames(VV) <- names(cf)\n",
"    list(beta=cf,V=VV,G=G)\n",
"  },error=function(e)e)\n",
"\n",
"  if(inherits(rob,'error'))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message=paste('matrix robust covariance failed:',conditionMessage(rob))))\n",
"  if(any(!is.finite(rob$V)))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),message='non-finite matrix robust covariance'))\n",
"\n",
"  dr <- tryCatch(rmvn_psd(nkeep,rob$beta,rob$V),error=function(e)e)\n",
"  if(inherits(dr,'error'))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message=paste('MVN draw failed:',conditionMessage(dr))))\n",
"  colnames(dr) <- names(rob$beta)\n",
"\n",
"  list(ok=TRUE,draws=as_tibble(dr),converged=TRUE,\n",
"       warning=paste(unique(warns),collapse=' | '),message='')\n",
"}"
)

start_pos <- regexpr(old_start,txt,fixed=TRUE)[1]
end_pos <- regexpr(old_end,txt,fixed=TRUE)[1]
patched <- paste0(substr(txt,1,start_pos-1L),new_fit,substr(txt,end_pos,nchar(txt)))
patched <- sub("SENSITIVITY — V2","SENSITIVITY — V4 MATRIX FIT",patched,fixed=TRUE)

message("Using explicit numeric design matrices and glm.fit(); no formula/factor expansion in model fitting.")
eval(parse(text=patched),envir=.GlobalEnv)
