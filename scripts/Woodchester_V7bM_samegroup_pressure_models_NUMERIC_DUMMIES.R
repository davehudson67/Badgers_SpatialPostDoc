# =============================================================================
# SAME-GROUP PRESSURE MODEL — NUMERIC DUMMY FIX
#
# Purpose
#   The V2 smoke test still failed for M1_RAW, M1_SMOOTH and M2_INTERACTION
#   with:
#     contrasts can be applied only to factors with 2 or more levels
#
#   M0_FULL and M0_CC fitted, so the biological risk data were sound. The
#   remaining failure is in formula/factor handling when pressure terms are
#   added. This wrapper preserves the scientific model but replaces quarter and
#   5-year period factors with explicit numeric dummy variables before glm().
#   That removes all factor-contrast machinery from the pressure fits.
#
#   The underlying V2 model, risk-set construction and cluster-robust covariance
#   are unchanged.
# =============================================================================

src <- "scripts/Woodchester_V7bM_samegroup_pressure_models_V2.R"
if(!file.exists(src)) stop("Missing source script: ",src)

x <- readLines(src,warn=FALSE)
txt <- paste(x,collapse="\n")

old_start <- "fit_one <- function(formula,d,nkeep){"
old_end <- "\n\nmake_risk_data <- function(move_draw,inf_col,require_pressure=TRUE){"

if(!grepl(old_start,txt,fixed=TRUE)) stop("Could not find fit_one() in V2 script.")
if(!grepl(old_end,txt,fixed=TRUE)) stop("Could not find make_risk_data() boundary in V2 script.")

new_fit <- paste0(
"fit_one <- function(formula,d,nkeep){\n",
"  warns <- character(0)\n",
"\n",
"  # Replace categorical quarter/period terms with explicit numeric dummies.\n",
"  # This is algebraically equivalent to treatment-coded factors but avoids\n",
"  # R's contrasts machinery, which caused the pressure-model failures.\n",
"  d2 <- d\n",
"\n",
"  qlev <- sort(unique(as.integer(d2$outcome_quarter)))\n",
"  qnames <- character(0)\n",
"  if(length(qlev)>1L){\n",
"    for(q in qlev[-1L]){\n",
"      nm <- paste0('quarter_',q)\n",
"      d2[[nm]] <- as.integer(d2$outcome_quarter==q)\n",
"      qnames <- c(qnames,nm)\n",
"    }\n",
"  }\n",
"\n",
"  plev <- sort(unique(as.integer(d2$period_start)))\n",
"  pnames <- character(0)\n",
"  if(length(plev)>1L){\n",
"    for(p in plev[-1L]){\n",
"      nm <- paste0('period_',p)\n",
"      d2[[nm]] <- as.integer(d2$period_start==p)\n",
"      pnames <- c(pnames,nm)\n",
"    }\n",
"  }\n",
"\n",
"  ftxt <- paste(deparse(formula),collapse=' ')\n",
"  if(grepl('\\\\bquarter\\\\b',ftxt)){\n",
"    qrep <- if(length(qnames)) paste(qnames,collapse=' + ') else '0'\n",
"    ftxt <- gsub('\\\\bquarter\\\\b',qrep,ftxt)\n",
"  }\n",
"  if(grepl('\\\\bperiod\\\\b',ftxt)){\n",
"    prep <- if(length(pnames)) paste(pnames,collapse=' + ') else '0'\n",
"    ftxt <- gsub('\\\\bperiod\\\\b',prep,ftxt)\n",
"  }\n",
"  formula2 <- as.formula(ftxt,env=environment(formula))\n",
"\n",
"  fit <- tryCatch(\n",
"    withCallingHandlers(\n",
"      glm(\n",
"        formula2,\n",
"        family=binomial(link='logit'),\n",
"        data=d2,\n",
"        control=glm.control(maxit=100,epsilon=1e-8)\n",
"      ),\n",
"      warning=function(w){\n",
"        warns <<- c(warns,conditionMessage(w))\n",
"        invokeRestart('muffleWarning')\n",
"      }\n",
"    ),\n",
"    error=function(e)e\n",
"  )\n",
"\n",
"  if(inherits(fit,'error'))\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message=conditionMessage(fit)))\n",
"\n",
"  if(!isTRUE(fit$converged))\n",
"    return(list(ok=FALSE,draws=NULL,converged=FALSE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message='glm did not converge'))\n",
"\n",
"  rob <- tryCatch(cluster_vcov_glm(fit,d2$tattoo),error=function(e)e)\n",
"\n",
"  if(inherits(rob,'error'))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message=paste('cluster covariance failed:',conditionMessage(rob))))\n",
"\n",
"  if(any(!is.finite(rob$V)))\n",
"    return(list(ok=FALSE,draws=NULL,converged=TRUE,\n",
"                warning=paste(unique(warns),collapse=' | '),\n",
"                message='non-finite cluster covariance'))\n",
"\n",
"  dr <- rmvn_psd(nkeep,rob$beta,rob$V)\n",
"  colnames(dr) <- names(rob$beta)\n",
"\n",
"  list(ok=TRUE,draws=as_tibble(dr),converged=TRUE,\n",
"       warning=paste(unique(warns),collapse=' | '),message='')\n",
"}"
)

start_pos <- regexpr(old_start,txt,fixed=TRUE)[1]
end_pos <- regexpr(old_end,txt,fixed=TRUE)[1]

patched <- paste0(
  substr(txt,1,start_pos-1L),
  new_fit,
  substr(txt,end_pos,nchar(txt))
)

message("Applying numeric quarter/period dummy coding, then running same-group pressure model V2.")
eval(parse(text=patched),envir=.GlobalEnv)
