-- WOODCHESTER V12 READ-ONLY INPUT ELIGIBILITY AUDIT | 2026-11-05
-- Run against live Supabase AFTER the 2026-11-05 encounter/PM spatial + ID cleanup.
-- Never filter an observed live animal merely because its capture or PM location has no accepted XY.
-- Original data unchanged. One source encounter row is not always one biological episode.
--
-- Scope: descriptive pre-fit audit. The frozen V11R2 movement cohort (1932)
-- was assembled in local RDS objects; matching that cohort requires those files
-- on the RStudio server, so this SQL does NOT assert individual membership.
-- "Qualifying live" here means an encounter explicitly classified
-- TRAP/NET/SNARE/DART/FOUND_ALIVE, not PM, excluding PM companion records.
-- FOUND_IN_EXTREMIS, non-PM REMOVAL and ambiguous outcomes are separately audited;
-- they cannot automatically be treated as routine capture/release occasions.
--
-- 1) Integrity of source rows and historic identities.
select
  count(*) as source_rows,
  count(distinct c.capture_id) as distinct_capture_ids,
  count(distinct c.individual_id) as individual_ids,
  count(*) filter(where c.capture_date is null) as missing_dates,
  count(*) filter(where c.individual_id is null) as missing_individual_ids,
  count(*) filter(where e.location_easting is null or e.location_northing is null) as missing_xy_rows,
  count(*) filter(where e.episode_record_role='PM_COMPANION') as linked_pm_companions
from research.captures c
join analysis.encounters_clean_v1 e using(capture_id);

-- 2) The observed live study cohort and mutually exclusive dead-only cohort.
with live as (
  select c.individual_id,
         count(*) as n_live,
         count(distinct extract(year from c.capture_date)) as n_live_years,
         count(*) filter(where e.location_easting is null or e.location_northing is null) as n_live_missing_xy
  from research.captures c
  join analysis.encounters_clean_v1 e using(capture_id)
  where e.is_pm=false and e.episode_record_role<>'PM_COMPANION'
    and e.encounter_type in ('TRAP','NET','SNARE','DART','FOUND_ALIVE')
  group by c.individual_id
), deaths as (
  select i.individual_id,
         count(*) filter(where m.terminal_model_status='CANDIDATE_TERMINAL_DEATH') as n_candidate_death
  from analysis.mortality_model_candidate_v1 m
  join research.individuals i on i.tattoo=m.tattoo
  group by i.individual_id
), a as (
 select i.individual_id,i.tattoo,i.sex_clean,i.age_first_capture_clean,
        i.year_first_capture,coalesce(l.n_live,0) as n_live,
        coalesce(l.n_live_years,0) as n_live_years,
        coalesce(l.n_live_missing_xy,0) as n_live_missing_xy,
        coalesce(d.n_candidate_death,0) as n_candidate_death
 from research.individuals i
 left join live l using(individual_id)
 left join deaths d using(individual_id)
)
select
 count(*) as all_individuals,
 count(*) filter(where n_live>0) as qualifying_live_observed,
 count(*) filter(where n_live=0 and n_candidate_death>0) as death_only,
 count(*) filter(where n_live=0 and tattoo like 'UN%') as dead_only_un,
 count(*) filter(where n_live=0 and tattoo not like 'UN%') as dead_only_other,
 count(*) filter(where n_live=1) as exactly_one_live_encounter,
 count(*) filter(where n_live>0 and n_live_years=1) as one_calendar_year,
 count(*) filter(where n_live_years>=2) as two_or_more_live_years,
 count(*) filter(where n_live>0 and n_live_missing_xy=n_live) as all_live_xy_missing,
 count(*) filter(where n_live_missing_xy>0 and n_live_missing_xy<n_live) as partly_xy_missing,
 count(*) filter(where n_live>0 and sex_clean='UNKNOWN') as live_sex_unknown,
 count(*) filter(where n_live>0 and age_first_capture_clean='UNKNOWN') as live_age_first_unknown,
 count(*) filter(where n_live>0 and year_first_capture is null) as live_year_first_unknown,
 count(*) filter(where n_live>0 and n_candidate_death>0) as live_with_candidate_recorded_death
from a;

-- 3) Spatial data effects. Missing location does not itself remove live captures from V12.
select
 count(*) as qualifying_live_encounters,
 count(*) filter(where e.location_easting is null or e.location_northing is null) as live_encounters_unmapped,
 count(distinct c.individual_id) filter(where e.location_easting is null or e.location_northing is null) as affected_individuals,
 count(distinct e.sett_id) filter(where e.location_easting is null or e.location_northing is null) as missing_sett_ids
from research.captures c
join analysis.encounters_clean_v1 e using(capture_id)
where e.is_pm=false and e.episode_record_role<>'PM_COMPANION'
and e.encounter_type in ('TRAP','NET','SNARE','DART','FOUND_ALIVE');

-- 4) Different missing-coordinate reasons and live-observed consequences.
select
 spatial_review_priority,count(*) as source_rows,
 count(*) filter(where is_pm=false and encounter_type in ('TRAP','NET','SNARE','DART','FOUND_ALIVE')) as potentially_usable_live_rows,
 count(distinct tattoo) filter(where is_pm=false and encounter_type in ('TRAP','NET','SNARE','DART','FOUND_ALIVE')) as affected_live_tattoos
from analysis.spatial_missing_review_v1
group by 1 order by source_rows desc;

-- 5) One biological death episode rather than duplicating matched field and PM rows.
select terminal_model_status,
 count(*) as primary_death_events,
 count(*) filter(where tattoo like 'UN%') as unidentified_tattoos,
 count(*) filter(where location_easting is null or location_northing is null) as without_xy
from analysis.mortality_model_candidate_v1
group by terminal_model_status order by terminal_model_status;

-- 6) Check the known anomalies, and do not override the four disputed terminal flags.
select capture_id,tattoo,recorded_event_date,mortality_outcome,
terminal_model_status,terminal_model_note
from analysis.mortality_model_candidate_v1
where terminal_model_status<>'CANDIDATE_TERMINAL_DEATH'
order by tattoo,capture_id;

-- 7) Year-boundary / historical age metadata audit. Not automatic exclusions.
select c.capture_id,i.tattoo,c.capture_date,
       i.year_first_capture,i.age_first_capture_clean,e.encounter_type,e.outcome
from research.captures c
join research.individuals i using(individual_id)
join analysis.encounters_clean_v1 e using(capture_id)
where i.year_first_capture is not null
and extract(year from c.capture_date)::int<i.year_first_capture
order by i.tattoo,c.capture_date;

-- 8) Model-specific handling of non-standard live/terminal encounter contexts.
select e.encounter_type,e.is_pm,e.episode_record_role,e.outcome,count(*) as n
from analysis.encounters_clean_v1 e
where e.encounter_type in ('REMOVAL','FOUND_IN_EXTREMIS','UNKNOWN','PUT_DOWN','ON_ROAD')
or e.outcome in ('UNKNOWN','DIED','EUTHANISED')
group by 1,2,3,4 order by n desc;

-- 9) Source date ranges. Historic V11R2 fitting-period restrictions may differ.
select
 min(capture_date) as earliest_source_date,
 max(capture_date) as latest_source_date,
 count(*) filter(where capture_date<'1977-01-01') as before_1977,
 count(*) filter(where capture_date>'2025-12-31') as during_2026
from research.captures;

-- 10) V11R2 compatibility is NOT decidable without original local inputs.
-- Required file-level comparison on the RStudio server:
-- data/badger_encounters_useful.rds
-- results/V7_population_inclusion_audit.rds
-- data/WoodchesterSettLocations.csv
-- results/V11R2_RES50_RD_ANNUALAC_DECOUPLED_MULTILOC_AGE_BADGERRE_1932_CHAIN*.rds
-- and corresponding *_STATES.rds.
-- Use capture_id / tattoo / date / original sett + canonical sett_id / XY
-- to compare old and new observations. Review permissive legacy aliases
-- (e.g., FOXCUB->FOX, DINGLEVALLEY->DINGLE, BLACKBERRY->BRAMBLE)
-- before considering a V11R2 rerun or propagating states to V12.
