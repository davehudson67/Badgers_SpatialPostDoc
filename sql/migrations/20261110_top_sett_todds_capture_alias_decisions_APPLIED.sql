-- 2026-11-10: capture-level fixed-sett alias decisions, applied to live Supabase
-- using a guarded, transactional SQL data update (not registered in
-- supabase_migrations.schema_migrations). This file records executed logic
-- for audit/reproduction on a separately established historic baseline.
-- DO NOT replay without reviewing existing decisions and source counts.
--
-- Original research.captures recorded names, sett_id, location text, source
-- coordinates and all research.setts XY were preserved.
BEGIN;
DO $$
DECLARE n integer;
BEGIN
 SELECT count(*) INTO n
 FROM research.captures c
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 JOIN research.setts s ON s.sett_id=e.sett_id
 WHERE ((c.recorded_sett_name='TOP SETT' AND s.sett_name='TOP')
    OR (c.recorded_sett_name='TODDS' AND s.sett_name='TODD''S'))
   AND c.capture_location_text='SETT'
   AND e.location_type='SETT'
   AND e.location_quality='SETT_POINT_PROVISIONAL'
   AND c.sett_id=e.sett_id
   AND e.location_easting=s.easting
   AND e.location_northing=s.northing;
 IF n<>357 THEN RAISE EXCEPTION 'Expected 357 fixed-sett alias events; found %',n; END IF;
 IF EXISTS (
   SELECT 1 FROM research.capture_sett_alias_decisions a
   JOIN research.captures c USING(capture_id)
   WHERE c.recorded_sett_name IN ('TOP SETT','TODDS')
 ) THEN RAISE EXCEPTION 'Existing decisions found; do not reapply'; END IF;
END $$;
INSERT INTO research.capture_sett_alias_decisions
(capture_id,original_recorded_name,canonical_sett_id,decision_note,decision_source)
SELECT c.capture_id,c.recorded_sett_name,e.sett_id,
 CASE WHEN c.recorded_sett_name='TOP SETT'
 THEN 'Approved historical sett-name harmonisation TOP SETT -> TOP. Capture recorded at SETT with canonical TOP coordinate; preserve recorded text and original coordinates/provenance.'
 ELSE 'Approved historical sett-name harmonisation TODDS -> TODD''S. Capture recorded at SETT with canonical TODD''S coordinate; preserve recorded text and original coordinates/provenance.' END,
 'Researcher-approved global fixed-sett alias rule; 2026-11-10'
FROM research.captures c
JOIN analysis.encounters_clean_v1 e USING(capture_id)
JOIN research.setts s ON s.sett_id=e.sett_id
WHERE ((c.recorded_sett_name='TOP SETT' AND s.sett_name='TOP')
    OR (c.recorded_sett_name='TODDS' AND s.sett_name='TODD''S'))
 AND c.capture_location_text='SETT'
 AND e.location_type='SETT'
 AND e.location_quality='SETT_POINT_PROVISIONAL'
 AND c.sett_id=e.sett_id AND e.location_easting=s.easting
 AND e.location_northing=s.northing;
DO $$
BEGIN
 IF (SELECT count(*) FROM research.capture_sett_alias_decisions a
 JOIN research.captures c USING(capture_id)
 WHERE c.recorded_sett_name IN ('TOP SETT','TODDS'))<>357
 THEN RAISE EXCEPTION 'Alias decision count check failed'; END IF;
END $$;
COMMIT;
