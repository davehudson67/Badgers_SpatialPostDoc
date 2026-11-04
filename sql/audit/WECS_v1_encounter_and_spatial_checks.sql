-- WECS v1 — read-only quality-control checks, 4 November 2026
-- Supabase project: klpvihubzlyzubyyubtw
-- Scope: research-level capture/PM location audit; no changes to source records.

-- 1. Keep one analysis row per source capture/PM record.
select (select count(*) from research.captures) as research_records,
       count(*) as clean_records,
       count(distinct capture_id) as distinct_capture_ids
from analysis.encounters_clean_v1;

-- 2. Six standardised classification fields (identifiers excluded).
select encounter_type,outcome,count(*) records
from analysis.encounters_clean_v1
group by encounter_type,outcome
order by records desc,encounter_type,outcome;

-- 3. Spatial availability and quality.
select location_quality,count(*) records,
       count(*) filter(where location_easting is not null and location_northing is not null) with_xy,
       count(*) filter(where location_easting is null or location_northing is null) no_xy
from analysis.encounters_clean_v1
group by location_quality order by records desc;

-- 4. Individual (NOT necessarily distinct episode) source records without location.
select s.prior_location_class,count(*) records
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using(capture_id)
where e.location_quality='UNRESOLVED'
group by s.prior_location_class order by records desc;

-- 5. Sett IDs without Easting/Northing, and capture impact.
select s.sett_id,s.sett_name,count(c.capture_id) captures
from research.setts s
left join research.captures c on c.sett_id=s.sett_id
where s.easting is null or s.northing is null
group by s.sett_id,s.sett_name
order by captures desc,s.sett_name;

-- 6. Trace every manual classification correction and episode decision.
select * from research.encounter_classification_decisions order by capture_id;
select * from research.encounter_episode_decisions order by live_capture_id;
select * from research.encounter_pair_nonlinks order by first_capture_id,second_capture_id;

-- 7. Explicitly locate conflicting named sett and actual field/recovery context.
select e.capture_id,e.tattoo,e.capture_date,e.encounter_type,
       c.recorded_sett_name,c.capture_location_text,c.os_ref,
       e.location_quality
from analysis.encounters_clean_v1 e join research.captures c using(capture_id)
where e.location_quality='SETT_COORDINATE_CONFLICT'
order by e.capture_date,e.capture_id;

-- 8. Unresolved historical names: counts, not automatic alias decisions.
select c.recorded_sett_name,count(*) records
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using(capture_id)
join research.captures c using(capture_id)
where e.location_quality='UNRESOLVED'
  and s.prior_location_class='UNMATCHED_RECORDED_SETT_NAME'
group by c.recorded_sett_name
order by records desc,c.recorded_sett_name;
