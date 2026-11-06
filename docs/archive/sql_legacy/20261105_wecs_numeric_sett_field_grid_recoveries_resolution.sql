-- The six numeric strings appearing in the original SETT name field
-- are 6-digit British National Grid references, not named setts.
-- This migration is an audit classification only. Existing analysis XY,
-- source records, death fates and canonical sett IDs must NOT change.
DO $$
DECLARE n int;
BEGIN
 SELECT COUNT(*) INTO n
 FROM research.captures c
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 WHERE c.capture_id IN (30,32,57,62,73,77)
   AND c.capture_location_text='SETT'
   AND c.recorded_sett_name ~ '^[0-9]{6}$'
   AND c.sett_id IS NULL
   AND c.is_pm = TRUE
   AND e.location_easting IS NOT NULL AND e.location_northing IS NOT NULL
   AND e.location_type IN ('RECOVERY_SITE','ROAD');
 IF n<>6 THEN
   RAISE EXCEPTION 'Unexpected source/current analysis state for numeric SETT-field recoveries: %/6',n;
 END IF;
END $$;

UPDATE research.wecs_review_flags
SET category='NUMERIC_GRID_STORED_IN_SETT_NAME',
capture_ids=ARRAY[30,32,57,62,73,77]::bigint[],
summary='Six historical PM records have six-digit grid references in the SETT-name source field, not named setts.',
evidence='Source capture IDs 30=808011, 32=810997, 57=825008, 62=830028, 73=836008, 77=837009; all PM, no canonical sett_id, already decoded to 100m BNG squares in analysis.encounters_clean_v1. 810997 was already independently accepted as corrected provisional N199700. Mapped sett CHESTNUT lies inside the 808011 square, and PARK MILL inside the 837009 square; coincident square is not proof of capture at that sett. Nearest-sett comparisons for other records do not establish sett identity.',
current_interpretation='All six are grid-referenced PM recovery/road locations already represented by accepted approximate XY in analysis, not missing sett locations. Five retain GRID_CELL_100M_PREFIX_UNVERIFIED, one GRID_REFERENCE_CORRECTED_PROVISIONAL. No original source field rewrite, no new sett ID, no UN resident SG assignment.',
review_status='RESOLVED',
final_decision='Keep six 100m grid-square positions (capture 30 E380800/N201100; 32 E381000/N199700; 57 E382500/N200800; 62 E383000/N202800; 73 E383600/N200800; 77 E383700/N200900) as currently represented in cleaned analysis. Treat original numeric recorded_sett_name as misfiled grid reference, not a sett alias. Exact recovery sites and identity of nearby setts unproven. Original Access/research rows unchanged; death outcomes retained.',
final_decision_at=now(),
updated_at=now()
WHERE flag_id='SPATIAL-UNNAMED-SETT';

DO $$
BEGIN
IF (SELECT review_status FROM research.wecs_review_flags WHERE flag_id='SPATIAL-UNNAMED-SETT')<>'RESOLVED'
THEN RAISE EXCEPTION 'Expected existing numeric-SETT issue flag not found; aborted'; END IF;
END $$;