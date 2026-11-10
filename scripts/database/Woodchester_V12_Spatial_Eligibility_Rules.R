# WECS V12 frozen evidence: approved model-specific fixed-sett eligibility.
# Source classifications in analysis.encounters_clean_v1 remain unchanged.
# Investigator-approved 2026-11-10: named-sett TRAP observations whose
# ancillary capture_location_text was blank can use the accepted sett point.
# The source evidence for this exact category was audited in Supabase:
# 159 records, 110 original MOC=TRAP and 49 curated TRAP (source MOC NULL)
# across 37 setts and 133 tattoos, with valid canonical sett IDs and XY.
# Future snapshots MUST be re-audited against source recorded names/comments
# if counts or quality categories differ. This is not permission to convert
# ALL SETT_ASSOCIATION records into trap locations.
v12_spatial_eligibility <- function(d, enforce_20261106_snapshot=TRUE) {
 needed <- c("capture_id","tattoo","capture_date","is_pm","encounter_type",
             "location_type","location_quality","sett_id",
             "location_easting","location_northing")
 if(!all(needed %in% names(d)))
  stop("Spatial eligibility missing columns: ",
       paste(setdiff(needed,names(d)),collapse=", "))
 if(!nrow(d))stop("Empty qualifying live capture snapshot")
 yr <- as.integer(format(as.Date(d$capture_date),"%Y"))
 if(anyNA(yr))stop("Missing/invalid capture date")
 eligible_period <- yr>=1977 & yr<=2025
 valid_sett <- !is.na(d$sett_id) & nzchar(as.character(d$sett_id))
 valid_xy <- is.finite(suppressWarnings(as.numeric(d$location_easting))) &
             is.finite(suppressWarnings(as.numeric(d$location_northing)))
 live <- !is.na(d$is_pm) & !d$is_pm
 explicit <- eligible_period & live & valid_xy & valid_sett &
   !is.na(d$location_type) & d$location_type=="SETT" &
   !is.na(d$location_quality) & d$location_quality=="SETT_POINT_PROVISIONAL"
 named_blank <- eligible_period & live & valid_xy & valid_sett &
   !is.na(d$encounter_type) & d$encounter_type=="TRAP" &
   !is.na(d$location_type) & d$location_type=="SETT_ASSOCIATION" &
   !is.na(d$location_quality) &
   d$location_quality=="SETT_ASSOCIATION_PROVISIONAL"
 if(any(explicit & named_blank))stop("Spatial categories overlap")
 # In the 2026-11-06 frozen input, this class was independently checked
 # against original recorded sett name, blank ancillary location text,
 # context comments, sett registry and method. No source MOC was extracted,
 # so that method-provenance subdivision cannot be reconstructed here.
 if(enforce_20261106_snapshot) {
  if(sum(eligible_period)!=16218L ||
     sum(explicit)!=15521L || sum(named_blank)!=159L)
    stop("Frozen source counts differ: re-audit original capture text and method ",
         "before applying the named blank-location rule to a new snapshot. ",
         "Observed 1977–2025 rows=",sum(eligible_period),
         ", explicit=",sum(explicit),", named blank=",sum(named_blank))
 }
 cls <- rep("NOT_FIXED_SETT_SPATIAL",nrow(d))
 cls[explicit] <- "EXPLICIT_SETT_POINT_PROVISIONAL"
 cls[named_blank] <- "APPROVED_NAMED_SETT_BLANK_LOCATION"
 d$v12_spatial_evidence <- cls
 d$v12_fixed_sett_spatial <- explicit | named_blank
 d$v12_original_method_evidence <- ifelse(named_blank,
    "MOC_MIXED_NOT_IN_FROZEN_SNAPSHOT", "NOT_SEPARATELY_AUDITED_HERE")
 d
}
