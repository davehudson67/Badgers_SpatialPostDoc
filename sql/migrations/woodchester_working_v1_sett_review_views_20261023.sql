-- Woodchester working Version 1: live sett inventories for field team review.
-- No changes to original recorded sett names or existing canonical assignments.
create or replace view analysis.capture_sett_coordinate_inventory as
select s.sett_name,
       count(c.capture_id)::bigint as n_captures,
       count(c.capture_id) filter(where c.is_pm)::bigint as n_pm_records,
       min(c.capture_date) as first_capture_date,
       max(c.capture_date) as last_capture_date,
       e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference as coordinate_source,
       case when e.evidence_id is not null then 'COORDINATES_APPROVED'
            else 'COORDINATES_MISSING' end as coordinate_status
from research.setts s
left join research.captures c on c.sett_id=s.sett_id
left join research.sett_location_evidence e on e.sett_id=s.sett_id and e.review_status='APPROVED'
group by s.sett_id,s.sett_name,e.evidence_id,e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference;

create or replace view analysis.unmatched_capture_sett_review as
select btrim(c.recorded_sett_name) as recorded_sett_name,
       count(*)::bigint n_captures,
       count(*) filter(where c.is_pm)::bigint n_pm_records,
       min(c.capture_date) first_capture_date,
       max(c.capture_date) last_capture_date,
       'UNREVIEWED'::text as name_review_status
from research.captures c
where c.sett_id is null and nullif(btrim(c.recorded_sett_name),'') is not null
group by btrim(c.recorded_sett_name);

grant select on analysis.capture_sett_coordinate_inventory,analysis.unmatched_capture_sett_review to badger_readonly,badger_research_readonly;
comment on view analysis.capture_sett_coordinate_inventory is 'Live working V1 inventory of every canonical sett, capture count and approved coordinates; includes setts with no assigned captures.';
comment on view analysis.unmatched_capture_sett_review is 'Live working V1 list of original capture sett labels not matched to canonical IDs; labels may be lanes, field locations, aliases, or setts and are not automatically cleaned.';
