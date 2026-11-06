-- Fix field/PM spatial provenance after seven newly discovered death-episode pairs.
-- A PM companion's own independent OS grid square is more informative than a nominal associated sett.
-- If PM has no independent grid, don't copy a sett centre or field point onto the PM row.
-- The primary field row retains its original/provisional point for event analyses; source PM text untouched.
create or replace view analysis.encounters_v1 with (security_invoker=true) as
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
comment on view analysis.encounters_v1 is 'WECS six-field encounter output: primary source death handling and PM companions preserved; PM companion own OS grid square retained with correct 100m square precision, but no synthetic inherited sett point when PM has no independent OS evidence. All grid correction decisions overlay original parsed points, mortality stays independent of XY.';
