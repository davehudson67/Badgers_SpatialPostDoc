-- WOODCHESTER: read-only audit of named-sett live captures with blank
-- supplementary location text. Intended before V12 spatial observation input.
-- Does NOT promote any case automatically or modify research/analysis data.
-- Live database counts as at 2026-11-10:
-- 1977–2025 live qualifying records 16218; 15521 SETT_POINT_PROVISIONAL
-- mapped candidates; 159 blank location-text / TRAP / canonical sett XY
-- records at 37 setts involving 133 tattoos, split into:
-- 110 original MOC TRAP; 49 MOC NULL but curated TRAP with weight+blood.
-- 304 explicit SETT records have noneligible quality/no accepted XY;
-- 52 nonsett geographic conflict records are deliberately withheld.
-- The 1976 records are intentionally outside the model scope.
WITH eligible_live AS MATERIALIZED (
 SELECT c.capture_id,c.capture_date,c.recorded_sett_name,
 c.capture_location_text,c.moc,c.comment,c.weight,c.blood_sample_taken,
 e.tattoo,e.encounter_type,e.location_type,e.location_quality,
 e.sett_id AS canonical_sett_id,e.location_easting,e.location_northing,
 s.sett_name,s.easting AS sett_x,s.northing AS sett_y
 FROM research.captures c
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 LEFT JOIN research.setts s ON s.sett_id=e.sett_id
 WHERE NOT e.is_pm
   AND e.episode_record_role IS NOT NULL
   AND e.episode_record_role <> 'PM_COMPANION'
   AND e.encounter_type IN ('TRAP','NET','SNARE','DART','FOUND_ALIVE')
   AND c.capture_date >= DATE '1977-01-01'
   AND c.capture_date < DATE '2026-01-01'
),
flags AS (
 SELECT *,
  (location_type='SETT' AND location_quality='SETT_POINT_PROVISIONAL'
   AND canonical_sett_id IS NOT NULL
   AND location_easting IS NOT NULL AND location_northing IS NOT NULL)
     AS old_fixed_sett,
  (location_type='SETT_ASSOCIATION'
   AND location_quality='SETT_ASSOCIATION_PROVISIONAL'
   AND encounter_type='TRAP'
   AND (capture_location_text IS NULL OR btrim(capture_location_text)='')
   AND canonical_sett_id IS NOT NULL
   AND sett_x IS NOT NULL AND sett_y IS NOT NULL
   AND recorded_sett_name IS NOT NULL
   AND btrim(recorded_sett_name)<>'') AS blank_named_sett_trap
 FROM eligible_live
)
SELECT count(*) AS n_live_1977_2025,
 count(*) FILTER(WHERE old_fixed_sett) AS n_old_fixed_sett,
 count(*) FILTER(WHERE blank_named_sett_trap) AS n_blank_named_sett_trap,
 count(*) FILTER(WHERE blank_named_sett_trap AND moc='TRAP')
   AS n_blank_original_trap,
 count(*) FILTER(WHERE blank_named_sett_trap AND moc IS NULL
  AND weight IS NOT NULL AND blood_sample_taken IS TRUE)
   AS n_blank_curated_trap_with_sampling,
 count(DISTINCT canonical_sett_id) FILTER(WHERE blank_named_sett_trap)
   AS distinct_blank_setts,
 count(DISTINCT tattoo) FILTER(WHERE blank_named_sett_trap)
   AS distinct_blank_tattoos,
 count(*) FILTER(WHERE location_type='SETT'
   AND (location_quality<>'SETT_POINT_PROVISIONAL'
        OR location_quality IS NULL)) AS n_explicit_sett_without_fixed_xy,
 count(*) FILTER(WHERE location_quality='SETT_COORDINATE_CONFLICT')
   AS n_explicit_nonsett_context_conflicts
FROM flags;

-- SECOND QUERY: exact source events to review, with both possible meanings
-- clearly separated. Do not treat these as approved until checked against
-- recorded trap context, spelling decisions and relevant source notes.
WITH eligible_live AS MATERIALIZED (
 SELECT c.capture_id,c.capture_date,c.recorded_sett_name,
 c.capture_location_text,c.moc,c.comment,c.weight,c.blood_sample_taken,
 e.tattoo,e.encounter_type,e.location_type,e.location_quality,
 e.sett_id AS canonical_sett_id,s.sett_name,
 s.easting AS proposed_sett_x,s.northing AS proposed_sett_y
 FROM research.captures c
 JOIN analysis.encounters_clean_v1 e USING(capture_id)
 JOIN research.setts s ON s.sett_id=e.sett_id
 WHERE NOT e.is_pm
   AND e.episode_record_role IS NOT NULL
   AND e.episode_record_role <> 'PM_COMPANION'
   AND e.encounter_type='TRAP'
   AND c.capture_date>=DATE '1977-01-01'
   AND c.capture_date<DATE '2026-01-01'
   AND e.location_type='SETT_ASSOCIATION'
   AND e.location_quality='SETT_ASSOCIATION_PROVISIONAL'
   AND (c.capture_location_text IS NULL OR btrim(c.capture_location_text)='')
   AND s.easting IS NOT NULL AND s.northing IS NOT NULL
)
SELECT capture_id::text AS capture_id,tattoo,capture_date,
 recorded_sett_name,sett_name,canonical_sett_id::text AS canonical_sett_id,
 moc AS source_method,encounter_type AS curated_method,
 proposed_sett_x,proposed_sett_y,
 weight IS NOT NULL AS measured_weight,
 blood_sample_taken IS TRUE AS blood_sampled,
 comment
FROM eligible_live ORDER BY capture_date,capture_id;
