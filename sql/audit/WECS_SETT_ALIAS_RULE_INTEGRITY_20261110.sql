-- Read-only validation of fixed-sett original-name to canonical-name mappings.
-- Execute after subsequent import/cleaning migrations and before model freezes.
-- Expected as at 2026-11-10: TOP SETT -> TOP = 349 fixed-sett TRAP rows;
-- TODDS -> TODD'S = 8; both fully documented in capture_sett_alias_decisions.
-- TOP SETT appears in 9 additional non-qualifying/non-sett records; no
-- automatic trapping-location assumption is made for them.
--
-- This lists every exception, including *new* records not yet in the
-- decision register. Review rather than silently inserting a new mapping.
WITH target AS (
 SELECT c.capture_id,c.recorded_sett_name,c.capture_location_text,
 e.location_type,e.location_quality,e.sett_id AS cleaned_sett_id,
 e.location_easting,e.location_northing,
 s.sett_name,s.easting AS canonical_x,s.northing AS canonical_y,
 a.canonical_sett_id AS approved_sett_id,
 a.original_recorded_name AS approved_original
 FROM research.captures c
 LEFT JOIN analysis.encounters_clean_v1 e USING(capture_id)
 LEFT JOIN research.setts s ON s.sett_id=e.sett_id
 LEFT JOIN research.capture_sett_alias_decisions a USING(capture_id)
 WHERE c.recorded_sett_name IN ('TOP SETT','TODDS')
),
expected AS (
 SELECT *,
 CASE WHEN recorded_sett_name='TOP SETT' THEN 'TOP'
 ELSE 'TODD''S' END AS expected_name
 FROM target
),
violations AS (
 SELECT capture_id::text,recorded_sett_name,sett_name,
   capture_location_text,location_type,location_quality,
   CASE
    WHEN cleaned_sett_id IS NULL OR sett_name IS DISTINCT FROM expected_name
      THEN 'INCORRECT_OR_MISSING_CANONICAL_SETT'
    WHEN location_type='SETT' AND location_quality='SETT_POINT_PROVISIONAL'
      AND (canonical_x IS DISTINCT FROM location_easting OR
           canonical_y IS DISTINCT FROM location_northing)
      THEN 'CANONICAL_SETT_XY_MISMATCH'
    WHEN capture_location_text='SETT' AND location_type='SETT'
      AND location_quality='SETT_POINT_PROVISIONAL' AND
         (approved_sett_id IS DISTINCT FROM cleaned_sett_id OR
          approved_original IS DISTINCT FROM recorded_sett_name)
      THEN 'MISSING_OR_CONTRADICTORY_ALIAS_DECISION'
    ELSE NULL
   END AS review_reason
 FROM expected
)
SELECT * FROM violations WHERE review_reason IS NOT NULL
ORDER BY capture_id::bigint;
