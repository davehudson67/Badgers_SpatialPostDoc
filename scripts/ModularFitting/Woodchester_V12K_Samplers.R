# Configure the default non-coordinate samplers and install the same ordered
# x/y blocks in one list update. NIMBLE 1.3's per-pair removeSamplers scans
# the entire sampler list and addSampler extends its execution order each time.
v12k_configure_samplers <- function(model, monitors, NN, TT, unknown_detectors) {
 all_nodes <- model$getNodeNames(stochOnly=TRUE,includeData=FALSE)
 coordinate_nodes <- grep("^[SX]\\[",all_nodes,value=TRUE)
 conf <- configureMCMC(model,nodes=setdiff(all_nodes,coordinate_nodes),
                      monitors=monitors,enableWAIC=FALSE,print=FALSE)
 defaults <- conf$getSamplers()
 cat("Default non-coordinate samplers:",length(defaults),"\n")

 i <- rep(seq_len(NN),each=TT)
 t <- rep(seq_len(TT),times=NN)
 x <- c(sprintf("S[%d,%d,1]",i,t),sprintf("X[%d,1]",unknown_detectors))
 y <- c(sprintf("S[%d,%d,2]",i,t),sprintf("X[%d,2]",unknown_detectors))
 block_nodes <- c(x,y)
 # NIMBLE may print spaces inside indices. Match using canonical names.
 node_keys <- gsub(" ","",coordinate_nodes,fixed=TRUE)
 position <- match(block_nodes,node_keys)
 stopifnot(length(block_nodes)==length(coordinate_nodes),
           !anyNA(position),!anyDuplicated(position))
 npairs <- length(x)

 # Let addSampler resolve the sampler and its control defaults once per scale.
 # Both targets in every pair are already checked as latent scalar nodes.
 template_conf <- configureMCMC(model,nodes=NULL,monitors=character(),
                               enableWAIC=FALSE,print=FALSE)
 conf_class <- methods::getRefClass("samplerConf",where=asNamespace("nimble"))
 blocks <- vector("list",npairs)
 for (start in c(1L, NN*TT+1L)) {
  end <- if(start==1L) NN*TT else npairs
  if(start>end) next
  template_conf$addSampler(target=c(x[start],y[start]),type="RW_block",silent=TRUE,
     control=list(scale=if(start==1L) .05 else .1,propCov=diag(2),adaptive=TRUE))
  templates <- template_conf$getSamplers()
  template <- templates[[length(templates)]]
  for (k in seq.int(start,end)) {
   blocks[[k]] <- conf_class$new(name=template$name,
       samplerFunction=template$samplerFunction,target=c(x[k],y[k]),
       control=template$control,model=model)
   if(k %% 10000L==0L || k==end)
    cat("Configured coordinate blocks:",k,"/",npairs,"\n")
  }
 }
 conf$setSamplers(ind=c(defaults,blocks))
 conf$setSamplerExecutionOrder()
 conf
}
