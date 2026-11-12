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
