library(readr)
library(tidyverse)
library(stringr)
library(lubridate)

# ==============================================================================
# 1. Import Data
# ==============================================================================
raw_dir <- "data/rawBadgers"

badger_raw <- read_csv(
  file.path(raw_dir, "tblBadger.csv"), 
  locale = locale(encoding = "Windows-1252"),
  show_col_types = FALSE
)

captures_raw <- read_csv(
  file.path(raw_dir, "tblCaptures.csv"), 
  locale = locale(encoding = "Windows-1252"),
  show_col_types = FALSE
)

# Load official list of valid setts
official_setts_df <- read_csv("data/WoodchesterSettLocations.csv", show_col_types = FALSE)

# ==============================================================================
# 2. Clean Individual Traits
# ==============================================================================
individuals <- badger_raw %>%
  transmute(
    tattoo = toupper(trimws(tattoo)),
    sex = str_to_title(trimws(sex)),
    age_fc = str_to_title(trimws(age_fc)),
    # A year_fc of "0" means unknown, so convert it to NA
    year_fc = if_else(trimws(year_fc) == "0", NA_integer_, as.integer(year_fc))
  ) %>%
  # Drop empty rows and ensure we only have exactly 1 row per badger
  filter(!is.na(tattoo), tattoo != "") %>%
  distinct(tattoo, .keep_all = TRUE)

# ==============================================================================
# 3. Clean and Fuse Captures (Fixing Same-Day Records)
# ==============================================================================
encounters <- captures_raw %>%
  transmute(tattoo = toupper(trimws(tattoo)),
            capture_date = dmy(date),
            pm_flag = (toupper(trimws(pm)) == "YES"),
            sett = trimws(iconv(sett, to = "UTF-8", sub = "")),
            socg = trimws(iconv(socg, to = "UTF-8", sub = "")),
            where = trimws(iconv(where, to = "UTF-8", sub = "")),
            comment_raw = trimws(iconv(comment, to = "UTF-8", sub = "")),
            pm_cause_raw = trimws(iconv(pm_cause, to = "UTF-8", sub = ""))) %>%
  filter(!is.na(tattoo), tattoo != "", !is.na(capture_date)) %>%
  mutate(primary_year = year(capture_date),
         # Automatically breaks the year into 4 seasons (Jan-Mar = 1, etc.)
         trap_season = quarter(capture_date)) %>%
  # SORT: Live captures float above PM records on the same day
  arrange(tattoo, capture_date, pm_flag) %>%
  # FUSE: Compress same-day records into a single row
  group_by(tattoo, capture_date) %>%
  summarise(primary_year = first(primary_year),
            trap_season = first(trap_season),
            has_live_capture = any(!pm_flag),
            has_pm_record = any(pm_flag),
            # Take the best available location (Live setts naturally get picked first)
            sett = first(na.omit(sett)),
            socg = first(na.omit(socg)),
            where = first(na.omit(where)),
            # Merge all comments together so we don't lose PM/death notes
            comment = paste(unique(na.omit(c(comment_raw, pm_cause_raw))), collapse = " | "),
            .groups = "drop")

# ==============================================================================
# 4. Join Traits & Standardize Text Formatting
# ==============================================================================
encounters_all <- encounters %>%
  left_join(individuals, by = "tattoo") %>%
  mutate(across(c(sett, socg, where, comment), ~ str_remove_all(., "Û")),
         sett = toupper(sett),
         socg = toupper(socg),
         sett = str_replace_all(sett, "\\|", " "),
         socg = str_replace_all(socg, "\\|", " "),
         # PROTECT EXCEPTIONS:
         #sett = str_replace_all(sett, "\\bTOP SETT\\b", "TOPSETT"),
         #socg = str_replace_all(socg, "\\bTOP SETT\\b", "TOPSETT"),
         # Remove the standalone words "SETT", "MAIN", and "OUTLIER" everywhere else
         sett = str_remove_all(sett, "\\b(SETT|MAIN|OUTLIER)\\b"),
         socg = str_remove_all(socg, "\\b(SETT|MAIN|OUTLIER)\\b"),
         # remove spaces
         sett = str_replace_all(sett, "\\s+", ""),
         socg = str_replace_all(socg, "\\s+", ""),
         sex = case_when(sex %in% c("Male", "Female") ~ sex, TRUE ~ "Unknown"),
         sex = factor(sex, levels = c("Female", "Male", "Unknown"))) %>%
  arrange(tattoo, capture_date)

# ==============================================================================
# 5. Official Sett Matching
# ==============================================================================

# Create a Dictionary of known typos and aliases
sett_aliases <- c(
  "\\bCHESTNUT\\b" = "CHESNUT",
  "\\bJACKS\\b"    = "JACKSMIREY",
  "\\bGRAVEL\\b"   = "GRAVELPIT",
  "\\bBUCKHOLT\\b"   = "BUCKHOLE",
  "\\bTOPSETT\\b"   = "TOP",
  "\\bFOXCUB\\b"   = "FOX",
  "\\bGULLEY\\b"   = "GULLY",
  "\\bBLACKBERRY\\b"   = "BRAMBLE",
  "\\bBOC\\b"   = "BOG",
  "\\bCEDARBANK\\b"   = "CEDAR",
  "\\bCLAYTRAP\\b"   = "CLAY",
  "\\bCLIFF\\b"   = "CLIFFFACE",
  "\\bDINGLEVALLEY\\b"   = "DINGLE"
)

# Clean the official list (Applying the standardisation rules)
true_setts <- official_setts_df %>%
  pull(SETT) %>%
  toupper() %>%
  str_replace_all("[[:punct:]]", " ") %>%  # Converts dots/pipes to spaces
  str_squish() %>%                         
  str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>% 
  str_replace_all("\\s+", "")              

encounters_all <- encounters_all %>%
  mutate(sett_clean_temp = toupper(sett) %>%
           str_replace_all("[[:punct:]]", " ") %>%
           str_squish() %>%
           str_remove_all("\\b(SETT|MAIN|OUTLIER)\\b") %>%
           str_replace_all(sett_aliases) %>%
           str_replace_all("\\s+", ""),
         is_official = sett_clean_temp %in% true_setts,
         # If the sett is NOT official, append the original raw text to 'where'
         where = case_when(!is.na(sett) & !is_official & !is.na(where) ~ paste(sett, where, sep = " | "),
                           !is.na(sett) & !is_official & is.na(where) ~ sett,
                           TRUE ~ where),
         # Overwrite the final sett column with the PERFECT official name (or NA if unofficial/junk)
         sett = if_else(!is_official, NA_character_, sett_clean_temp)) %>%
  # Clean up our temporary working column
  select(-is_official, -sett_clean_temp)

# ==============================================================================
# 6. Filter Uninformative Badgers & Calculate Modal Sett
# ==============================================================================

# Identify and drop "PM-Only" badgers (never caught alive in a trap)
live_check <- encounters_all %>%
  group_by(tattoo) %>%
  summarise(ever_live = any(has_live_capture), .groups = "drop")

badgers_to_drop <- live_check %>% filter(!ever_live) %>% pull(tattoo)

encounters_useful <- encounters_all %>%
  filter(!(tattoo %in% badgers_to_drop))

cat("Dropped PM-only (unmarked) badgers:", length(badgers_to_drop), "\n")

# Calculate the Lifetime Modal Sett for each badger
modal_setts <- encounters_useful %>%
  filter(!is.na(sett)) %>%
  count(tattoo, sett) %>%
  # Sort so the most frequent sett is at the top
  arrange(tattoo, desc(n)) %>%
  group_by(tattoo) %>%
  slice(1) %>% # Take the top one
  select(tattoo, modal_sett = sett) %>%
  ungroup()

# ==============================================================================
# 7. Collapse to One-Per-Season
# ==============================================================================
encounters_cmr_ready <- encounters_useful %>%
  left_join(modal_setts, by = "tattoo") %>%
  mutate(differs_from_modal = !is.na(sett) & !is.na(modal_sett) & (sett != modal_sett)) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  # 1. PM records (DEATHS) must always float to the top and be kept!
  # 2. Setts that differ from the modal sett (Movement)
  # 3. Latest date
  arrange(desc(has_pm_record), desc(differs_from_modal), desc(capture_date), .by_group = TRUE) %>%
  slice(1) %>%
  ungroup()

# ==============================================================================
# 8. Extract and View the Dropped Observations
# ==============================================================================

dropped_observations <- encounters_useful %>%
  anti_join(encounters_cmr_ready, by = c("tattoo", "capture_date")) %>%
  arrange(tattoo, capture_date)

cat("Original records:", nrow(encounters_useful), "\n")
cat("Collapsed CMR records:", nrow(encounters_cmr_ready), "\n")
cat("Observations safely compressed away:", nrow(dropped_observations), "\n")

# ==============================================================================
# 9. Import and Clean Diagnostic Data
# ==============================================================================

# Culture Tests
culture_clean <- read_csv(file.path(raw_dir, "tblCulture.csv"), show_col_types = FALSE) %>%
  transmute(tattoo = toupper(trimws(tattoo)),
            date = dmy(date),
            primary_year = year(date),
            trap_season = quarter(date),    
            sample_type = toupper(trimws(sample)),
            is_pos = str_detect(toupper(result), "POS|M\\.BOVIS|M BOVIS")) %>%
  filter(!is.na(tattoo), !is.na(date)) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    culture_tested = TRUE,
    culture_positive = any(is_pos, na.rm = TRUE),
    culture_samples = paste(unique(na.omit(sample_type)), collapse = " | "),
    .groups = "drop")

# IFN Gamma Tests
ifn_clean <- read_csv(file.path(raw_dir, "tblIFN_Gamma_ELISA.csv"), show_col_types = FALSE) %>%
  transmute(tattoo = toupper(trimws(BadgerId)),
            date = dmy(str_replace(CaptureDate, "2919", "2019")), # Fix typo
            primary_year = year(date),
            trap_season = quarter(date),
            is_pos = str_detect(toupper(Result), "POSITIVE")) %>% 
  filter(!is.na(tattoo), !is.na(date)) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(ifn_tested = TRUE,
            ifn_positive = any(is_pos, na.rm = TRUE),    
            .groups = "drop")

# DPP Tests
dpp_clean <- read_csv(file.path(raw_dir, "tblDPPTest.csv"), show_col_types = FALSE) %>%
  transmute(tattoo = toupper(trimws(BadgerID)),
            date = dmy(CaptureDate),
            primary_year = year(date),
            trap_season = quarter(date),
            is_pos = toupper(trimws(VisualLine1)) %in% c("P", "PX") | toupper(trimws(VisualLine2)) %in% c("P", "PX")) %>% 
  filter(!is.na(tattoo), !is.na(date)) %>%
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(
    dpp_tested = TRUE,
    dpp_positive = any(is_pos, na.rm = TRUE),
    .groups = "drop"
  )

# Historical all.diag.results
hist_diag_clean <- read_csv(file.path(raw_dir, "all.diag.results.csv"), show_col_types = FALSE) %>%
  transmute(tattoo = toupper(trimws(tattoo)),   
            date = dmy(date),
            primary_year = year(date),
            trap_season = quarter(date),
            actually_tested = !is.na(statpak) | !is.na(brock),
            is_pos = (statpak == 1) | (brock == 1)) %>% 
  
  # NEW: Only keep rows where they actually performed the test!
  filter(!is.na(tattoo), !is.na(date), actually_tested == TRUE) %>% 
  
  group_by(tattoo, primary_year, trap_season) %>%
  summarise(hist_tested = TRUE,
            hist_positive = any(is_pos, na.rm = TRUE),
            .groups = "drop")

# Take a peek at all the columns inside all.diag
raw_all_diag <- read_csv("data/rawBadgers/all.diag.results.csv", show_col_types = FALSE)
cat("Columns in all.diag:\n")
print(names(raw_all_diag))

# Check for "Ghost Badgers" (Tested, but not in our CMR capture data)
ghost_badgers <- raw_all_diag %>%
  mutate(tattoo = toupper(trimws(tattoo))) %>%
  anti_join(encounters_cmr_ready, by = "tattoo")

cat("\nBadgers in all.diag but completely missing from our CMR data:", n_distinct(ghost_badgers$tattoo), "\n")
print(head(ghost_badgers))

# ==============================================================================
# ---- 10. Combine Diagnostics and Join to CMR ----
# ==============================================================================

encounters_final_with_disease <- encounters_cmr_ready %>%
  left_join(culture_clean, by = c("tattoo", "primary_year", "trap_season")) %>%
  left_join(ifn_clean, by = c("tattoo", "primary_year", "trap_season")) %>%
  left_join(dpp_clean, by = c("tattoo", "primary_year", "trap_season")) %>%
  left_join(hist_diag_clean, by = c("tattoo", "primary_year", "trap_season")) %>%
  
  # Clean up the NAs for badgers that weren't tested in a given season
  mutate(
    across(ends_with("_tested"), ~ replace_na(., FALSE)),
    across(ends_with("_positive"), ~ replace_na(., FALSE)),
    
    # Create Master Flags
    tested_this_season = culture_tested | ifn_tested | dpp_tested | hist_tested,
    any_positive_test = culture_positive | ifn_positive | dpp_positive | hist_positive
  )

cat("=== FINAL DISEASE AUDIT ===\n")
cat("Total CMR Records:", nrow(encounters_final_with_disease), "\n")
cat("Records with ANY disease test:", sum(encounters_final_with_disease$tested_this_season), "\n")
cat("Records with a POSITIVE test:", sum(encounters_final_with_disease$any_positive_test), "\n\n")

# Breakdown of positivity by test type
encounters_final_with_disease %>%
  filter(tested_this_season) %>%
  summarise(
    Culture_Pos = sum(culture_positive),
    IFN_Pos = sum(ifn_positive),
    DPP_Pos = sum(dpp_positive),
    Hist_Pos = sum(hist_positive)
  ) %>%
  print()

saveRDS(encounters_final_with_disease, "data/processed/badger_final_CMRready_wDisease.rds")
