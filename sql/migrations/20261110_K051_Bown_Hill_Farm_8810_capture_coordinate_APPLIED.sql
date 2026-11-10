-- APPLIED DIRECTLY to Supabase 2026-11-10; guarded one-row data transaction.
-- NOT a Supabase-registered schema migration; DO NOT rerun in production.
-- K051 capture 8810: researcher supplied Bown Hill Farm garage location
-- SO 82442 01956 -> BNG E382442 N201956, nominal 1m grid cell,
-- NOT surveyed precision nor known actual microposition.
-- Original original_os_ref is NULL, stored as NULL (not backfilled).
-- Source LISTERS is associated sett (ID 546), not garage location.
BEGIN;
DO $guard$
BEGIN
 IF (SELECT count(*) FROM research.captures c
     JOIN research.individuals i USING(individual_id)
     JOIN analysis.encounters_clean_v1 e USING(capture_id)
     WHERE c.capture_id=8810 AND upper(trim(i.tattoo))='K051'
       AND c.capture_date=DATE '1999-10-27'
       AND c.recorded_sett_name='LISTERS'
       AND c.capture_location_text='BUILDING'
       AND c.os_ref IS NULL AND e.encounter_type='FOUND_ALIVE'
       AND e.location_type='BUILDING' AND e.sett_id=546
       AND e.location_easting=383444 AND e.location_northing=201738)=0
 THEN RAISE EXCEPTION 'K051 8810 source state unexpectedly differs; refusing coordinate decision';
 END IF;
 IF EXISTS(SELECT 1 FROM research.capture_grid_coordinate_decisions WHERE capture_id=8810)
 THEN RAISE EXCEPTION 'Existing coordinate decision for 8810; refusing duplicate';
 END IF;
END $guard$;
INSERT INTO research.capture_grid_coordinate_decisions
 (capture_id,original_grid_reference,source_easting,source_northing,
 corrected_easting,corrected_northing,decision_status,decision_note,decision_source,
 map_review_status,map_review_note)
VALUES
 (8810,NULL,383444,201738,382442,201956,'CORRECTED',
 'Investigator supplied SO 82442 01956 for Bown Hill Farm garage where K051 was found alive on 1999-10-27. Five-figure easting/northing UK OS grid denotes nominal 1 m grid square, not surveyed indoor position or proven animal position precision. Source Access capture has no original OS grid reference; do not misattribute investigator-supplied grid to original source. Original LISTERS label is social-group/sett association and its reference E383444 N201738 is NOT the garage encounter position. Preserve encounter_type FOUND_ALIVE and location_type BUILDING; classify spatial use as independently supplied non-sett live encounter, never as active fixed-sett trap detector.',
 'Investigator-supplied locality grid SO 82442 01956, 2026-11-10; K051 capture 8810',
 'PENDING_REVIEW',
 'Investigator provided OS grid for Bown Hill Farm; accepted supplied locality point, no independent survey or within-building coordinate verification.');
COMMIT;
