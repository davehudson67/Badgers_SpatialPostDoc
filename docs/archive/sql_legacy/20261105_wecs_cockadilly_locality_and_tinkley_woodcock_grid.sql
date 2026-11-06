-- Targeted final spatial pass 2026-11-05.
-- Two independently corroborated reversed references, plus two approved Cockadilly centre proxies.
-- Only four capture IDs, preserving original Access and PM outcomes.
DO $$
DECLARE n int;
BEGIN
 SELECT COUNT(*) INTO n FROM research.capture_grid_coordinate_decisions g
 JOIN research.captures c USING(capture_id)
 WHERE g.decision_status='WITHHELD'
 AND ((g.capture_id=16869 AND c.os_ref='008802' AND c.moc='RTA')
 OR (g.capture_id=17117 AND c.os_ref='SO988808' AND c.moc='RTA')
 OR (g.capture_id=18 AND c.recorded_sett_name LIKE '%COCKADILLY%' AND c.moc='RTA'));
 IF n<>3 THEN RAISE EXCEPTION 'Expected exactly 3 withheld source records, got %',n; END IF;
 IF EXISTS (SELECT 1 FROM research.capture_grid_coordinate_decisions WHERE capture_id=3382)
 THEN RAISE EXCEPTION 'Cockadilly source 3382 already has a grid decision'; END IF;
END $$;

UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=380200,corrected_northing=200800,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Original 008802 is a transposition of 802008, corroborated by two separate source RTAs at Tinkley Lane Nympsfield signpost/playing field: captures 16856 and 17002 have exact source 802008 E380200,N200800. Use 100m grid-square approximate locality, not exact layby/RTA point. Source original and formerly parsed E300800,N280200 retained.',
decision_source='WECS cross-record source grid and Tinkley Lane descriptions 2026-11-05',
map_review_note='Strong independent historic cross-record source corroboration; not individually surveyed. Accept as approximate location only.',
map_reviewed_at=now()
WHERE capture_id=16869;
UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=380800,corrected_northing=198800,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Source SO988808 is an apparent transposition of 808988 AND mistaken SO square: corrected ST808988, E380800,N198800. Other independent Woodcock entrance original refs ST808989 (17077), ST807991 (16948/17146), SO807992 (17071). All point to this small roadside locality; this is a 100m grid square NOT exact carcass position. Original E398800,N280800 and SO988808 preserved. UN animal gets NO social-group assignment.',
decision_source='WECS cross-record original Woodcock OS reference audit 2026-11-05',
map_review_note='Corroborated by four original nearby Woodcock entrance records, retain grid-square approximation only; UN badger does not get SG.',
map_reviewed_at=now()
WHERE capture_id=17117;

UPDATE research.capture_grid_coordinate_decisions
SET corrected_easting=379800,corrected_northing=200200,
decision_status='CORRECTED',map_review_status='PENDING_REVIEW',
decision_note='Investigator explicitly approved assigning Cockadilly village-centre approximation instead of a spurious old 801791 grid. OSM node 412786736 Cockadilly hamlet centre 51.7004528,-2.2933255 converts to approx E379825,N200231. Rounded proxy E379800,N200200 (100m neighbourhood); this is locality CENTROID not exact RTA recovery grid or sett. Preserve original 801791 COCKADILLY and original misparsed E380100,N279100.',
decision_source='WECS_LOCALITY_CENTROID Cockadilly OSM hamlet node + user locality acceptance 2026-11-05',
map_review_note='APPROXIMATE hamlet centre only; not a site-specific accident coordinate and no sett/SG assignment.',
map_reviewed_at=now()
WHERE capture_id=18;

INSERT INTO research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,
decision_status,decision_note,decision_source,map_review_status,map_review_note,map_reviewed_at)
VALUES
(3382,'COCKADILLY',null,null,379800,200200,'CORRECTED',
'Original RTA locality is only Cockadilly (no source OS grid). Researcher accepted settlement centre as general location. OSM hamlet node 412786736 51.7004528,-2.2933255, rounded to E379800,N200200. Distinct from exact animal recovery location and not a canonical sett.',
'WECS_LOCALITY_CENTROID Cockadilly OSM hamlet node + user locality acceptance 2026-11-05',
'PENDING_REVIEW','Approximate village centre, not a surveyed capture/road-recovery point.',now());

CREATE OR REPLACE VIEW analysis.encounters_v1 WITH (security_invoker=true) AS
 WITH source AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date,
            e.is_pm,
            e.sett_id,
            e.original_moc,
            e.original_location_name,
            e.original_location_text,
            e.original_os_ref,
            e.prior_location_class,
            e.prior_reference_source,
            e.sett_name,
            e.location_easting AS prior_easting,
            e.location_northing AS prior_northing,
            e.coordinate_representation AS prior_coordinate_representation,
            e.newly_parsed_cell_width_m,
            e.episode_primary_capture_id,
            e.episode_record_role,
            e.resolved_episode_outcome,
            e.episode_field_easting,
            e.episode_field_northing,
            e.episode_field_coordinate_representation,
            c.individual_id,
            c.release_assessment,
            c.comment,
            c.pm_cause,
            (((COALESCE(c.comment, ''::text) || ' '::text) || COALESCE(c.pm_cause, ''::text)) || ' '::text) || COALESCE(c.capture_location_text, ''::text) AS narrative,
                CASE
                    WHEN (upper(COALESCE(TRIM(BOTH FROM c.capture_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text, 'OTHER'::text, 'OUTSIDE WP'::text, 'NOT WP'::text])) AND e.sett_id IS NOT NULL AND (COALESCE(c.moc, ''::text) = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'FOUND EXT'::text, 'RTA'::text])) THEN true
                    ELSE false
                END AS sett_point_context_conflict,
                CASE
                    WHEN c.moc IS NULL AND c.is_pm = false AND (EXISTS ( SELECT 1
                       FROM research.captures later
                      WHERE later.individual_id = c.individual_id AND later.capture_date > c.capture_date AND later.is_pm = false AND ((later.moc = ANY (ARRAY['TRAP'::text, 'SNARE'::text, 'NET'::text, 'DART GUN'::text])) OR later.moc IS NULL AND later.weight IS NOT NULL AND later.blood_sample_taken = true))) THEN true
                    ELSE false
                END AS subsequent_live_sampling
           FROM analysis.encounters_with_episodes_v1 e
             JOIN research.captures c USING (capture_id)
        ), standardised AS (
         SELECT source.capture_id,
            source.tattoo,
            source.capture_date,
            source.is_pm,
            source.sett_id,
            source.original_moc,
            source.original_location_name,
            source.original_location_text,
            source.original_os_ref,
            source.prior_location_class,
            source.prior_reference_source,
            source.sett_name,
            source.prior_easting,
            source.prior_northing,
            source.prior_coordinate_representation,
            source.newly_parsed_cell_width_m,
            source.episode_primary_capture_id,
            source.episode_record_role,
            source.resolved_episode_outcome,
            source.episode_field_easting,
            source.episode_field_northing,
            source.episode_field_coordinate_representation,
            source.individual_id,
            source.release_assessment,
            source.comment,
            source.pm_cause,
            source.narrative,
            source.sett_point_context_conflict,
            source.subsequent_live_sampling,
                CASE
                    WHEN source.original_moc = 'TRAP'::text THEN 'TRAP'::text
                    WHEN source.original_moc = 'NET'::text THEN 'NET'::text
                    WHEN source.original_moc = 'SNARE'::text THEN 'SNARE'::text
                    WHEN source.original_moc = 'DART GUN'::text THEN 'DART'::text
                    WHEN source.original_moc = 'FOUND EXT'::text THEN 'FOUND_IN_EXTREMIS'::text
                    WHEN source.original_moc = 'FOUND DEAD'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc = 'RTA'::text THEN 'RTA'::text
                    WHEN source.original_moc = ANY (ARRAY['SHOT (GP)'::text, 'SHOT'::text]) THEN 'SHOT'::text
                    WHEN source.original_moc = 'REMOVAL'::text THEN 'REMOVAL'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'PUT_DOWN'::text
                    WHEN source.original_moc = 'DEAD SN/TR'::text THEN 'DEAD_SNARE_TRAP'::text
                    WHEN source.original_moc = 'ON ROAD'::text THEN 'ON_ROAD'::text
                    WHEN source.original_moc = 'REPORTED BY MEMBER OF THE PUBLIC'::text THEN 'PUBLIC_REPORT'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'found in a lean-to|found in garage|found under wood pile'::text THEN 'FOUND_ALIVE'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'SHOT'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'RTA'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'FOUND DEAD|DEAD BADGER|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'TRAP'::text
                    WHEN source.original_moc IS NULL AND source.subsequent_live_sampling THEN 'TRAP'::text
                    ELSE 'UNKNOWN'::text
                END AS encounter_type_clean,
                CASE
                    WHEN source.episode_primary_capture_id IS NOT NULL THEN
                    CASE
                        WHEN source.resolved_episode_outcome = 'DIED_AFTER_CAPTURE'::text THEN 'DIED'::text
                        ELSE source.resolved_episode_outcome
                    END
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.narrative ~* 'sampled and released at night|sampled and released'::text THEN 'RELEASED'::text
                    WHEN source.original_moc = 'PUT DOWN'::text THEN 'EUTHANISED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.narrative ~* 'euthan|put down|put to sleep|humanely destroy'::text OR upper(COALESCE(source.pm_cause, ''::text)) = 'EUTH'::text) THEN 'EUTHANISED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND upper(COALESCE(source.pm_cause, ''::text)) = 'KILLED'::text THEN 'KILLED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text, 'FOUND EXT'::text])) AND (source.release_assessment = 'Death'::text OR source.narrative ~* 'died under anaesth|died in holding|died overnight|dead on arrival|did not recover from anaesth'::text) THEN 'DIED'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) AND source.is_pm THEN 'FOUND_DEAD'::text
                    WHEN (source.original_moc = ANY (ARRAY['SHOT'::text, 'SHOT (GP)'::text])) AND source.is_pm THEN 'KILLED'::text
                    WHEN source.original_moc = 'REMOVAL'::text AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'KILLED|SHOT'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'SHOT|CULL'::text THEN 'KILLED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DEAD BADGER|FOUND DEAD|CARCASE|CARCASS|TOO ROTTEN|FLY BLOWN'::text THEN 'FOUND_DEAD'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'DIED IN HOLDING|DIED OVERNIGHT'::text THEN 'DIED'::text
                    WHEN source.original_moc IS NULL AND source.is_pm AND NULLIF(TRIM(BOTH FROM COALESCE(source.pm_cause, ''::text)), ''::text) IS NOT NULL THEN 'DIED'::text
                    WHEN source.original_moc = 'FOUND EXT'::text AND source.is_pm THEN 'DIED'::text
                    WHEN (source.original_moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text])) AND NOT source.is_pm THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.sett_id IS NOT NULL AND source.narrative !~* 'found in garage|found in a lean-to|found under wood pile'::text AND source.capture_date >= '1998-01-01'::date AND source.capture_date < '2000-01-01'::date AND (EXISTS ( SELECT 1
                       FROM research.captures rc
                      WHERE rc.capture_id = source.capture_id AND rc.blood_sample_taken = true AND rc.weight IS NOT NULL)) AND NOT (EXISTS ( SELECT 1
                       FROM research.captures pm
                      WHERE pm.individual_id = source.individual_id AND pm.is_pm = true AND pm.capture_date >= source.capture_date AND pm.capture_date <= (source.capture_date + 7))) THEN 'PRESUMED_RELEASED'::text
                    WHEN source.original_moc IS NULL AND NOT source.is_pm AND source.subsequent_live_sampling THEN 'PRESUMED_RELEASED'::text
                    ELSE 'UNKNOWN'::text
                END AS outcome_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'RECOVERY_SITE'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'LINKED_FIELD_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text AND source.sett_id IS NOT NULL THEN 'SETT'::text
                    WHEN (source.original_moc = ANY (ARRAY['RTA'::text, 'ON ROAD'::text])) OR source.original_moc IS NULL AND source.is_pm AND COALESCE(source.pm_cause, ''::text) ~* 'RTA|VEHICLE'::text THEN 'ROAD'::text
                    WHEN source.original_moc = ANY (ARRAY['FOUND DEAD'::text, 'DEAD SN/TR'::text]) THEN 'RECOVERY_SITE'::text
                    WHEN upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = ANY (ARRAY['FIELD'::text, 'WOOD'::text, 'HEDGE'::text, 'BOUNDARY'::text, 'BUILDING'::text, 'GARDEN'::text]) THEN upper(TRIM(BOTH FROM source.original_location_text))
                    WHEN source.original_moc = ANY (ARRAY['NET'::text, 'SNARE'::text]) THEN 'OTHER_CAPTURE_SITE'::text
                    WHEN source.sett_id IS NOT NULL THEN 'SETT_ASSOCIATION'::text
                    WHEN source.prior_location_class = 'GRID_REFERENCED_PM_LOCATION'::text THEN 'RECOVERY_SITE'::text
                    ELSE 'UNKNOWN'::text
                END AS location_type_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN source.prior_easting
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_easting
                END AS x_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_northing IS NOT NULL THEN source.prior_northing
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN NULL::numeric
                    WHEN source.sett_point_context_conflict THEN NULL::numeric
                    ELSE source.prior_northing
                END AS y_clean,
                CASE
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text AND source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.prior_easting IS NOT NULL THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.episode_record_role = 'PM_COMPANION'::text THEN 'UNRESOLVED'::text
                    WHEN source.sett_point_context_conflict THEN 'SETT_COORDINATE_CONFLICT'::text
                    WHEN source.prior_easting IS NULL OR source.prior_northing IS NULL THEN 'UNRESOLVED'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text AND source.newly_parsed_cell_width_m IS NOT NULL THEN 'GRID_CELL'::text
                    WHEN source.prior_coordinate_representation = 'GRID_CELL_SW_CORNER'::text THEN 'GRID_CELL_PRECISION_UNCONFIRMED'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text AND upper(COALESCE(TRIM(BOTH FROM source.original_location_text), ''::text)) = 'SETT'::text THEN 'SETT_POINT_PROVISIONAL'::text
                    WHEN source.prior_coordinate_representation = 'SETT_POINT'::text THEN 'SETT_ASSOCIATION_PROVISIONAL'::text
                    ELSE 'PROVISIONAL'::text
                END AS quality_clean
           FROM source
        )
 SELECT standardised.capture_id,
    standardised.tattoo,
    standardised.capture_date,
    standardised.is_pm,
    COALESCE(alias.canonical_sett_id, standardised.sett_id) AS sett_id,
    standardised.episode_primary_capture_id,
    standardised.episode_record_role,
    COALESCE("dec".encounter_type, standardised.encounter_type_clean) AS encounter_type,
    COALESCE("dec".outcome, standardised.outcome_clean) AS outcome,
        CASE
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN 'SETT'::text
            ELSE standardised.location_type_clean
        END AS location_type,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_easting
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.easting
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.x_clean
        END AS location_easting,
        CASE
            WHEN grid.capture_id IS NOT NULL THEN grid.corrected_northing
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text THEN mapped_sett.northing
            WHEN alias.capture_id IS NOT NULL THEN NULL::numeric
            ELSE standardised.y_clean
        END AS location_northing,
        CASE
            WHEN grid.decision_status = 'WITHHELD'::text THEN 'GRID_REFERENCE_AMBIGUOUS_WITHHELD'::text
            WHEN grid.decision_status = 'CORRECTED'::text AND grid.decision_source LIKE 'WECS_LOCALITY_CENTROID%'::text THEN 'LOCALITY_CENTROID_APPROXIMATE'::text
            WHEN grid.decision_status = 'CORRECTED'::text THEN 'GRID_REFERENCE_CORRECTED_PROVISIONAL'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text AND regexp_replace(upper(COALESCE(standardised.original_os_ref, ''::text)), '[[:space:],.-]'::text, ''::text, 'g'::text) ~ '^SO[0-9]{6}$'::text THEN 'GRID_CELL_100M_RECORDED_SO'::text
            WHEN standardised.quality_clean = 'GRID_CELL_PRECISION_UNCONFIRMED'::text THEN 'GRID_CELL_100M_PREFIX_UNVERIFIED'::text
            WHEN alias.capture_id IS NOT NULL AND upper(COALESCE(standardised.original_location_text, ''::text)) = 'SETT'::text AND mapped_sett.easting IS NOT NULL AND mapped_sett.northing IS NOT NULL THEN 'SETT_POINT_PROVISIONAL'::text
            WHEN alias.capture_id IS NOT NULL THEN 'SETT_ASSOCIATION_ONLY'::text
            ELSE standardised.quality_clean
        END AS location_quality
   FROM standardised
     LEFT JOIN research.encounter_classification_decisions "dec" USING (capture_id)
     LEFT JOIN research.capture_sett_alias_decisions alias ON alias.capture_id = standardised.capture_id
     LEFT JOIN research.setts mapped_sett ON mapped_sett.sett_id = alias.canonical_sett_id
     LEFT JOIN research.capture_grid_coordinate_decisions grid ON grid.capture_id = standardised.capture_id;

UPDATE research.wecs_review_flags
SET review_status='RESOLVED',final_decision='Cockadilly is an RTA recovery locality, not a sett. For capture IDs 18 and 3382 use an approved rounded hamlet-centre approximation E379800,N200200 with quality LOCALITY_CENTROID_APPROXIMATE; source text and original values unchanged. Do not use these centroids as exact capture/recovery coordinates.',final_decision_at=now(),
current_interpretation='Both unlocated Cockadilly PM RTAs now have a coarse locality-centre proxy, explicitly distinguished from grid-cell and exact field point.',updated_at=now()
WHERE flag_id='SPATIAL-COCKADILLY';

UPDATE research.wecs_review_flags
SET summary='Grid location audit: 92 interpreted points accepted, 6 withheld.',
current_interpretation='87 investigator-verified map points plus UN221 west-gate, two corroborated C016/UN492 road grids, and 2 Cockadilly hamlet-centre proxies. Of 92 CORRECTED decisions, 90 are grid/cell interpretations and 2 are LOCALITY_CENTROID_APPROXIMATE. Six WITHHELD points remain (2 investigator-rejected); no mortality events removed. Grid accuracy not overclaimed.',
updated_at=now() WHERE flag_id='SPATIAL-GRID';

DO $$
BEGIN
IF (SELECT COUNT(*) FROM research.capture_grid_coordinate_decisions WHERE decision_status='CORRECTED')<>92
OR (SELECT COUNT(*) FROM research.capture_grid_coordinate_decisions WHERE decision_status='WITHHELD')<>6
OR (SELECT COUNT(*) FROM analysis.encounters_clean_v1 WHERE location_quality='LOCALITY_CENTROID_APPROXIMATE')<>2
THEN RAISE EXCEPTION 'Spatial post-audit counts invalid; transaction rolled back'; END IF;
END $$;
