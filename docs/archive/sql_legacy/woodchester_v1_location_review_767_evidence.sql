create or replace view analysis.location_review_767_v1 with (security_invoker=true) as
with base as (
select c.capture_id,r.individual_id,i.tattoo,c.capture_date,c.is_pm,c.recorded_sett_name,c.capture_location_text,c.os_ref,c.comment,c.location_cleaning_note,c.recorded_social_group_name,c.recorded_supergroup_name,c.sett_id,s.sett_name canonical_sett_name,s.notes sett_notes,c.location_type,c.location_coordinate_basis,c.location_easting,c.location_northing,
case when c.sett_id is not null then '01_KNOWN_SETT_MISSING_COORDINATES' when c.is_pm then '03_PM_NO_MATCHED_SETT' else '02_ALIVE_UNMATCHED_CAPTURE' end review_group
from analysis.capture_history_v1 c
join research.captures r on r.capture_id=c.capture_id
join research.individuals i on i.individual_id=r.individual_id
left join research.setts s on s.sett_id=c.sett_id
left join analysis.sett_inventory_v1 si on si.sett_id=c.sett_id
where nullif(btrim(c.recorded_sett_name),'') is not null
and (c.sett_id is null or si.easting is null or si.northing is null)
), enriched as (
select b.*, lateral_prev.capture_date previous_capture_date,lateral_prev.sett_name previous_sett_name,lateral_prev.recorded_sett_name previous_recorded_sett_name,
lateral_next.capture_date next_capture_date,lateral_next.sett_name next_sett_name,lateral_next.recorded_sett_name next_recorded_sett_name
from base b
left join lateral(select h.capture_date,h.sett_name,h.recorded_sett_name from analysis.capture_history_v1 h where h.tattoo=b.tattoo and (h.capture_date,h.capture_id)<(b.capture_date,b.capture_id) order by h.capture_date desc,h.capture_id desc limit 1) lateral_prev on true
left join lateral(select h.capture_date,h.sett_name,h.recorded_sett_name from analysis.capture_history_v1 h where h.tattoo=b.tattoo and (h.capture_date,h.capture_id)>(b.capture_date,b.capture_id) order by h.capture_date,h.capture_id limit 1) lateral_next on true
)
select recorded_sett_name,capture_location_text,case when is_pm then 'PM' else 'ALIVE' end record_type,review_group,capture_id,tattoo,capture_date,canonical_sett_name,recorded_social_group_name,recorded_supergroup_name,os_ref,location_type,location_easting,location_northing,location_coordinate_basis,comment,location_cleaning_note,sett_notes,previous_capture_date,previous_sett_name,previous_recorded_sett_name,next_capture_date,next_sett_name,next_recorded_sett_name
from enriched;
grant select on analysis.location_review_767_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.location_review_767_v1 is 'Working V1 review of 767 capture records with recorded location text but no coordinate-linked canonical sett. Adjacent captures are clues, not proof of residency. Do not substitute SG centroid for sett coordinates.';
