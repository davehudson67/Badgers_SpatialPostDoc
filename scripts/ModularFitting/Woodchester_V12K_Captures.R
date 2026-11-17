# Read both the original dense V12K inputs and newly prepared sparse inputs.
v12k_capture_events <- function(input) {
 if (!is.null(input$capture_events)) return(input$capture_events)
 counts <- input$counts
 if (!identical(as.integer(dim(counts)), as.integer(c(input$N,input$T,input$J,4L))) ||
     anyNA(counts)) stop("Invalid dense V12K capture counts")
 cells <- which(counts != 0)
 count <- counts[cells]
 if (any(!is.finite(count) | count < 0 | count != floor(count)))
  stop("Invalid capture count")
 events <- cbind(arrayInd(cells, dim(counts)), count)
 colnames(events) <- c("badger","year","detector","quarter","count")
 events
}

v12k_pack_captures <- function(input, selected, NN) {
 events <- v12k_capture_events(input)
 fit_index <- integer(input$N)
 fit_index[selected] <- seq_along(selected)
 events[,"badger"] <- fit_index[events[,"badger"]]
 events <- events[events[,"badger"] > 0,,drop=FALSE]

 # One row per occupied detector-quarter, padded only to the largest
 # number of such rows in any selected badger-year. Zero detector = padding.
 cells <- events[,"badger"] + (events[,"year"] - 1L)*NN
 sizes <- tabulate(cells, NN*input$T)
 packed <- array(0, c(NN,input$T,max(1L,sizes),3L))
 if (nrow(events)) {
  events <- events[order(cells,events[,"quarter"],events[,"detector"],method="radix"),,drop=FALSE]
  slot <- sequence(sizes[sizes > 0L])
  for (column in seq_len(3L))
   packed[cbind(events[,"badger"],events[,"year"],slot,column)] <- events[,column+2L]
 }
 list(events=events, packed=packed)
}

# Exact annual detector subsets. Omit only rows whose coverage is zero in all
# quarters and which have no capture marks. No distance cutoff is used.
# Global detector order is retained to preserve floating-point summation order.
v12k_annual_detectors <- function(availability, packed) {
 dd <- dim(availability)
 pp <- dim(packed)
 if(length(dd)!=3L || dd[2]!=4L || length(pp)!=4L ||
    pp[2]!=dd[3] || pp[4]!=3L || any(!is.finite(availability)) ||
    any(availability<0)) stop("Invalid annual detector inputs")
 JJ <- dd[1]; TT <- dd[3]
 active <- vector("list",TT)
 # Two rows keep NIMBLE's model-side slices matrix-valued, even when
 # there is only one capture slot. Additional rows are zero padding.
 if(pp[3]<2L) {
  expanded <- array(0,c(pp[1],pp[2],2L,3L))
  expanded[,,1,] <- packed[,,1,]
  packed <- expanded
 }
 remapped <- packed
 for(t in seq_len(TT)) {
  ids <- as.vector(packed[,t,,1])
  if(any(!is.finite(ids) | ids<0 | ids>JJ | ids!=floor(ids)))
   stop("Invalid packed detector index")
  marks <- sort(unique(as.integer(ids[ids>0])))
  av <- matrix(availability[,,t],JJ,4L)
  active[[t]] <- sort(unique(c(which(rowSums(av)>0),marks)))
  map <- integer(JJ)
  map[active[[t]]] <- seq_along(active[[t]])
  positive <- ids>0
  ids[positive] <- map[ids[positive]]
  remapped[,t,,1] <- ids
 }
 n_active <- lengths(active)
 n_local <- pmax(2L,n_active)
 indices <- matrix(0L,max(n_local),TT)
 local_availability <- array(0,c(max(n_local),4L,TT))
 for(t in seq_len(TT))if(n_active[t]>0L) {
  rows <- seq_len(n_active[t])
  indices[rows,t] <- active[[t]]
  local_availability[rows,,t] <- availability[active[[t]],,t]
 }
 list(indices=indices,n_active=n_active,n_local=n_local,
      availability=local_availability,packed=remapped,active=active)
}
