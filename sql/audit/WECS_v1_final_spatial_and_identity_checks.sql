-- Woodchester WECS: repeatable read-only QA after 2026-11-04 spatial and identity audit.
-- Important: these are baseline ASSERTION QUERIES, not mutating migrations.
-- No source data edits permitted; death status independent of XY.

-- Source-row preservation and episode roles: expect 17,586 total and distinct IDs; 17 PM_COMPANION.
select count(*) source_rows,count(distinct capture_id) unique_capture_ids,
count(*) filter(where episode_record_role='PM_COMPANION') linked_pm_companions
from analysis.encounters_clean_v1;

-- Original outcomes independent of missing XY.
select outcome,count(*) rows,
count(*) filter(where location_easting is null or location_northing is null) missing_xy
from analysis.encounters_clean_v1 group by outcome order by rows desc;

-- Spatial quality: reviewed grid cells distinct from actual sett proxies / unknown.
select location_quality,count(*) rows,
count(*) filter(where location_easting is not null and location_northing is not null) with_xy
from analysis.encounters_clean_v1 group by location_quality order by rows desc;

-- 54 CORRECTED and 38 WITHHELD, all original grid and source parsed values retained.
select decision_status,count(*) rows from research.capture_grid_coordinate_decisions group by decision_status;
select capture_id,original_grid_reference,source_easting,source_northing,
corrected_easting,corrected_northing,decision_status,decision_note
from analysis.grid_reference_audit_v1 order by decision_status,capture_id;

-- All 107 non-sett-sett conflict rows should have null physical encounter XY and no independent original OS reference.
select count(*) conflicts,
count(*) filter(where e.location_easting is not null or e.location_northing is not null) conflicts_with_inferred_xy,
count(*) filter(where c.os_ref is not null) with_independent_os_ref
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where e.location_quality='SETT_COORDINATE_CONFLICT';

-- One primary recorded death per confirmed capture/PM pair.
select count(*) linked_pairs from research.encounter_episode_decisions;
select tattoo,count(*) death_events,min(recorded_event_date) first_death,max(recorded_event_date) last_death
from analysis.mortality_events_review_v1
group by tattoo having count(*)>1 order by tattoo;

-- Mortality candidate includes disputed events with HOLD flags, never deletes them for lack of grid XY.
select terminal_model_status,count(*) rows,
count(*) filter(where location_easting is null or location_northing is null) no_accepted_xy
from analysis.mortality_model_candidate_v1 group by terminal_model_status order by terminal_model_status;
select capture_id,tattoo,recorded_event_date,mortality_outcome,terminal_model_status,terminal_model_note
from analysis.mortality_model_candidate_v1
where terminal_model_status<>'CANDIDATE_TERMINAL_DEATH'
order by tattoo,capture_id;

-- 020D original Access cub-year contradiction; U005 PM and later live source evidence.
select tattoo,year_fc,age_fc from access_raw.tbl_badger where tattoo in ('020D','U005');
select raw_row_id,tattoo,capture_date,pm,moc,sett,where_text,comment,pm_cause
from access_raw.tbl_captures
where (tattoo='020D' and (capture_date like '2020%' or capture_date like '2022%'))
or (tattoo='U005' and capture_date like '2003%')
order by tattoo,capture_date;

-- Check the editable flag status and decisions: 12 current flags, 5 resolved.
select flag_id,tattoo,review_status,current_interpretation,final_decision
from analysis.wecs_review_flags_v1
order by review_status,flag_id;
