-- READ-ONLY regression audit: capture 8810 K051, investigator location supplied 2026-11-10.
-- Expected: zero rows (each returned row is a violation).
WITH check_row AS (
 SELECT c.capture_id,c.capture_date,c.recorded_sett_name,
 c.capture_location_text,c.os_ref,e.encounter_type,e.location_type,
 e.location_quality,e.sett_id,e.location_easting,e.location_northing,
 g.original_grid_reference,g.corrected_easting,g.corrected_northing,
 g.decision_status,g.decision_source,i.tattoo
 FROM research.captures c
 JOIN research.individuals i USING(individual_id)
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 LEFT JOIN research.capture_grid_coordinate_decisions g USING(capture_id)
 WHERE c.capture_id=8810
)
SELECT * FROM check_row
WHERE upper(trim(tattoo)) IS DISTINCT FROM 'K051'
 OR capture_date IS DISTINCT FROM DATE '1999-10-27'
 OR recorded_sett_name IS DISTINCT FROM 'LISTERS'
 OR capture_location_text IS DISTINCT FROM 'BUILDING'
 OR os_ref IS NOT NULL OR original_grid_reference IS NOT NULL
 OR encounter_type IS DISTINCT FROM 'FOUND_ALIVE'
 OR location_type IS DISTINCT FROM 'BUILDING'
 OR location_quality IS DISTINCT FROM 'GRID_REFERENCE_CORRECTED_PROVISIONAL'
 OR sett_id IS DISTINCT FROM 546
 OR location_easting IS DISTINCT FROM 382442
 OR location_northing IS DISTINCT FROM 201956
 OR corrected_easting IS DISTINCT FROM 382442
 OR corrected_northing IS DISTINCT FROM 201956
 OR decision_status IS DISTINCT FROM 'CORRECTED'
 OR decision_source NOT LIKE 'Investigator-supplied locality grid SO 82442 01956%';
