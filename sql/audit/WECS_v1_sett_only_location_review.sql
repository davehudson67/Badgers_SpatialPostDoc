-- WECS sett-only audit (2026-11-04).
-- Exactly match original capture_location_text='SETT'; no spatial updates.
-- Focus unresolved alias names; exclude already-canonical setts awaiting XY.

-- Original location=SETT audit grouped by spatial issue.
select e.location_quality,s.prior_location_class,count(*) records,
       count(distinct c.recorded_sett_name) recorded_names
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using(capture_id)
join research.captures c using(capture_id)
where upper(trim(coalesce(c.capture_location_text,'')))='SETT'
group by 1,2 order by records desc;

-- 67 unresolved records / 37 names (as of 2026-11-04).
select c.recorded_sett_name,count(*) n,
       min(c.capture_date) first_capture,max(c.capture_date) last_capture,
       string_agg(distinct coalesce(c.moc,'[blank]'),', ') original_methods
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using(capture_id)
join research.captures c using(capture_id)
where upper(trim(coalesce(c.capture_location_text,'')))='SETT'
  and e.location_quality='UNRESOLVED'
  and s.prior_location_class='UNMATCHED_RECORDED_SETT_NAME'
group by c.recorded_sett_name
order by n desc,c.recorded_sett_name;

-- Record-level evidence for human review.
select e.capture_id,e.tattoo,e.capture_date,c.recorded_sett_name,
       c.moc,e.encounter_type,c.capture_location_text,c.os_ref,
       c.comment,e.location_quality
from analysis.encounters_clean_v1 e
join analysis.encounters_standardised_v1 s using(capture_id)
join research.captures c using(capture_id)
where upper(trim(coalesce(c.capture_location_text,'')))='SETT'
  and e.location_quality='UNRESOLVED'
  and s.prior_location_class='UNMATCHED_RECORDED_SETT_NAME'
order by c.recorded_sett_name,e.capture_date,e.capture_id;

-- Specifically name-less SETT records, including the non-PM historical captures
-- and 2014 found-in-extremis event, separate from the 67 named unmatched.
select e.capture_id,e.tattoo,e.capture_date,c.moc,c.is_pm,c.comment
from analysis.encounters_clean_v1 e
join research.captures c using(capture_id)
where upper(trim(coalesce(c.capture_location_text,'')))='SETT'
  and e.location_quality='UNRESOLVED'
  and c.recorded_sett_name is null
order by e.capture_date,e.capture_id;
