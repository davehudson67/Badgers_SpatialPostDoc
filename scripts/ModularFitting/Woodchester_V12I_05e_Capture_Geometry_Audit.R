#!/usr/bin/env Rscript
# V12I-05e: read-only diagnostic of synthetic geometry for problematic animals.
# Uses truth ONLY for validation; does not alter fitting likelihood/outputs.
base <- Sys.getenv("V12I_VALIDATION_OUT","")
replicate <- as.integer(Sys.getenv("V12I_REPLICATE","3"))
id <- as.integer(Sys.getenv("V12I_BADGER","11"))
chains <- as.integer(Sys.getenv("V12I_CHAINS","3"))
if(!nzchar(base)||!dir.exists(base)||anyNA(c(replicate,id,chains))||
   replicate<1||id<1||chains<2) stop("Invalid parameters")
paths <- file.path(base,sprintf("rep%02d_chain%02d",replicate,seq_len(chains)),
                  "smoke_fit.rds")
if(!all(file.exists(paths))) stop("One or more model fits are missing")
fits <- lapply(paths,readRDS)
ref <- fits[[1]]
stopifnot(all(vapply(fits[-1],function(f)
  identical(f$encounters,ref$encounters) &&
  identical(f$true_positions,ref$true_positions),logical(1))))
mats <- lapply(fits,function(f) as.matrix(f$posterior_samples))
names_norm <- function(m) gsub("[[:space:]]","",colnames(m))
nm <- names_norm(mats[[1]])
if(!all(vapply(mats,function(m) identical(names_norm(m),nm),logical(1))))
  stop("Nonmatching posterior monitor names")
draws <- do.call(rbind,mats)
colnames(draws) <- nm
y <- ref$encounters
T <- dim(y)[2]; Q <- dim(y)[3]; J <- dim(y)[4]
if(id>dim(y)[1]) stop("Requested individual outside simulated cohort")
d <- as.data.frame(ref$detectors)
if(!all(c("x","y","Sett_Clean")%in%names(d))) stop("Missing detector columns")
DX <- d$x-mean(d$x); DY <- d$y-mean(d$y)
sigma_det <- 170; season <- c(.35,.85,1,.70)
if(Q!=length(season)) stop("Unexpected quarters")
p0 <- draws[,"p0"]
rows <- list()
cat("=== TARGET INDIVIDUAL ===\nReplicate:",replicate,
    "ID:",id,"years:",T,"detectors:",J,"\n")
for(t in seq_len(T)) {
  keys <- paste0("S[",id,",",1:2,",",t,"]")
  cols <- match(keys,nm)
  if(anyNA(cols)) stop("Missing S monitors: ",paste(keys,collapse=","))
  xy <- draws[,cols,drop=FALSE]
  truth <- as.numeric(ref$true_positions[id,,t])
  estimate <- colMeans(xy)
  cat(sprintf("Year %d | alive truth %d | captures %d | true centre (%.1f, %.1f) | posterior centre (%.1f, %.1f)\n",
    t,ref$latent_survival[id,t],sum(y[id,t,,,drop=FALSE]),
    truth[1],truth[2],estimate[1],estimate[2]))
  for(j in seq_len(J)) {
    yy <- as.numeric(y[id,t,,j])
    dt <- sqrt((truth[1]-DX[j])^2+(truth[2]-DY[j])^2)
    dm <- sqrt((estimate[1]-DX[j])^2+(estimate[2]-DY[j])^2)
    # Expected count per detector conditional on being alive.
    pred_truth <- sum(.42*season*exp(-dt^2/(2*sigma_det^2)))
    pred_est <- mean(vapply(seq_len(nrow(draws)),function(k)
       sum(p0[k]*season*exp(
        -((xy[k,1]-DX[j])^2+(xy[k,2]-DY[j])^2)/(2*sigma_det^2))),
       numeric(1)))
    rows[[length(rows)+1L]] <- data.frame(replicate=replicate,
       badger=id,year=t,detector=j,sett=d$Sett_Clean[j],
       captures=sum(yy),captured_quarters=paste(which(yy>0),collapse=","),
       detector_x=DX[j],detector_y=DY[j],
       true_distance_m=round(dt,1),posterior_mean_distance_m=round(dm,1),
       expected_captures_true=round(pred_truth,3),
       expected_captures_posterior=round(pred_est,3))
  }
}
out <- do.call(rbind,rows)
print(out[,c("year","sett","captures","captured_quarters",
             "true_distance_m","posterior_mean_distance_m",
             "expected_captures_true","expected_captures_posterior")],
      row.names=FALSE)
output <- file.path(base,sprintf("rep%02d_badger%02d_capture_geometry.csv",replicate,id))
write.csv(out,output,row.names=FALSE)
cat("\nSaved:",output,"\n")
cat("Expected captures use the illustrative fitted distance kernel and season;\n")
cat("posterior prediction is conditional on alive, not a full survival-integrated PPC.\n")
