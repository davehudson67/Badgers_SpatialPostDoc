-- WECS v1 mortality review output — exported from Supabase 2026-11-04.
-- Apply after analysis.encounters_clean_v1 and research.encounter_episode_decisions.
-- This view does NOT overwrite research source data; it is not a signed-off survival model extract.
create or replace view analysis.mortality_events_review_v1 with (security_invoker=true) as
WITH deaths AS (
         SELECT e.capture_id,
            e.tattoo,
            e.capture_date AS recorded_event_date,
            e.outcome AS mortality_outcome,
            e.encounter_type,
            e.is_pm,
            e.location_easting,
            e.location_northing,
            e.location_quality,
            e.episode_primary_capture_id,
            e.episode_record_role,
            c.individual_id,
            c.moc AS original_moc,
            c.pm_cause,
            ep.pm_capture_id AS linked_pm_capture_id,
            pm.capture_date AS linked_pm_date,
                CASE
                    WHEN e.location_easting IS NULL AND pm.location_easting IS NOT NULL THEN pm.location_easting
                    ELSE e.location_easting
                END AS best_available_easting,
                CASE
                    WHEN e.location_northing IS NULL AND pm.location_northing IS NOT NULL THEN pm.location_northing
                    ELSE e.location_northing
                END AS best_available_northing,
                CASE
                    WHEN e.location_easting IS NULL AND pm.location_easting IS NOT NULL THEN pm.location_quality
                    ELSE e.location_quality
                END AS best_available_location_quality
           FROM analysis.encounters_clean_v1 e
             JOIN research.captures c USING (capture_id)
             LEFT JOIN research.encounter_episode_decisions ep ON ep.live_capture_id = e.capture_id
             LEFT JOIN analysis.encounters_clean_v1 pm ON pm.capture_id = ep.pm_capture_id
          WHERE (e.outcome = ANY (ARRAY['FOUND_DEAD'::text, 'DIED'::text, 'KILLED'::text, 'EUTHANISED'::text])) AND e.episode_record_role <> 'PM_COMPANION'::text
        ), tested AS (
         SELECT d.capture_id,
            d.tattoo,
            d.recorded_event_date,
            d.mortality_outcome,
            d.encounter_type,
            d.is_pm,
            d.location_easting,
            d.location_northing,
            d.location_quality,
            d.episode_primary_capture_id,
            d.episode_record_role,
            d.individual_id,
            d.original_moc,
            d.pm_cause,
            d.linked_pm_capture_id,
            d.linked_pm_date,
            d.best_available_easting,
            d.best_available_northing,
            d.best_available_location_quality,
            ( SELECT min(x.capture_date) AS min
                   FROM research.captures x
                  WHERE x.individual_id = d.individual_id AND x.capture_date > d.recorded_event_date AND x.is_pm = false AND (x.moc = ANY (ARRAY['TRAP'::text, 'NET'::text, 'SNARE'::text, 'DART GUN'::text]))) AS next_live_capture_date,
            ( SELECT min(e2.capture_date) AS min
                   FROM analysis.encounters_clean_v1 e2
                     JOIN research.captures c2 USING (capture_id)
                  WHERE c2.individual_id = d.individual_id AND e2.capture_date < d.recorded_event_date AND (e2.outcome = ANY (ARRAY['FOUND_DEAD'::text, 'DIED'::text, 'KILLED'::text, 'EUTHANISED'::text])) AND e2.episode_record_role <> 'PM_COMPANION'::text) AS previous_death_record_date
           FROM deaths d
        )
 SELECT capture_id,
    tattoo,
    recorded_event_date,
    mortality_outcome,
    encounter_type,
    is_pm AS source_is_pm,
    original_moc,
    pm_cause,
    linked_pm_capture_id,
    linked_pm_date,
    best_available_easting AS location_easting,
    best_available_northing AS location_northing,
    best_available_location_quality AS location_quality,
    next_live_capture_date,
    previous_death_record_date,
        CASE
            WHEN next_live_capture_date IS NOT NULL THEN 'REVIEW_TATTOO_IDENTITY_AFTER_DEATH'::text
            WHEN previous_death_record_date IS NOT NULL THEN 'REVIEW_POSSIBLE_DUPLICATE_DEATH'::text
            WHEN is_pm OR linked_pm_capture_id IS NOT NULL THEN 'DEATH_RECORDED_PM_EVIDENCE'::text
            ELSE 'DEATH_RECORDED_NON_PM_OR_INFERRED'::text
        END AS mortality_review_status
   FROM tested;

-- Expected at export: 1311 event rows (10 linked PM companion source rows excluded); 401 event rows with no XY.
-- Documented identity conflicts and repeated death entries: docs/archive/spatial_audits/WECS_MORTALITY_SPATIAL_INDEPENDENCE_AUDIT_2026_11_04.md
