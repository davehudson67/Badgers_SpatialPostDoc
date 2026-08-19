library(readr)
library(tidyverse)
library(stringr)
library(lubridate)

# Load cleaned CMR data
cmr_data <- readRDS("data/badger_final_CMRready_wDisease.rds")

# Join the numeric Sett_ID onto the CMR data
cmr_data <- cmr_data %>%
  left_join(settGrid %>% select(Sett_Clean, Sett_ID), by = c("sett" = "Sett_Clean"))

# Define Dimensions
unique_badgers <- unique(cmr_data$tattoo)
unique_years <- sort(unique(cmr_data$primary_year))

nind <- length(unique_badgers)       # Number of badgers
n_prim <- length(unique_years)       # Number of years
n_sec <- 4                           # Number of trapping seasons per year
R <- nrow(X_matrix)                  # Number of setts

# Initialize Empty Matrices
H <- array(1, dim = c(nind, n_sec, n_prim)) # 1 = Not Caught. 2:(R+1) = Caught at Sett r
z_data <- matrix(NA, nrow = nind, ncol = n_prim)
sex_id <- rep(NA, nind)
first_caught <- rep(NA, nind)
death_occasion <- rep(n_prim + 1, nind) # Default to 'survived past the study'

# Fill the Matrices
for (i in seq_len(nind)) {
  badger_id <- unique_badgers[i]
  b_data <- cmr_data %>% filter(tattoo == badger_id)
  
  # A. Sex (1 = Female, 2 = Male, NA = Unknown)
  sex_val <- as.character(b_data$sex[1])
  sex_id[i] <- ifelse(sex_val == "Female", 1, ifelse(sex_val == "Male", 2, NA))
  
  # B. First capture year
  first_caught[i] <- which(unique_years == min(b_data$primary_year))
  
  # C. Fill Capture History (H) & Determine Death
  for (r in 1:nrow(b_data)) {
    k <- which(unique_years == b_data$primary_year[r])
    j <- b_data$trap_season[r]
    
    # If caught alive at a known sett, record the Sett ID + 1 (because 1 means not caught)
    if (b_data$has_live_capture[r] && !is.na(b_data$Sett_ID[r])) {
      H[i, j, k] <- b_data$Sett_ID[r] + 1
    }
    
    # If found dead, record the year of death
    if (b_data$has_pm_record[r]) {
      death_occasion[i] <- min(death_occasion[i], k)
    }
    
    # Fill z_data (1 = alive in years they were caught)
    z_data[i, k] <- 1 
  }
  
  # D. Right-censor the dead badgers (z = 0 for all years AFTER they died)
  if (death_occasion[i] <= n_prim) {
    # If they died before the end of the study, set subsequent years to 0
    if (death_occasion[i] < n_prim) {
      z_data[i, (death_occasion[i] + 1):n_prim] <- 0
    }
  }
}

cat("Matrices built successfully!\n")
cat("Dimensions of H array:", dim(H), "\n")
