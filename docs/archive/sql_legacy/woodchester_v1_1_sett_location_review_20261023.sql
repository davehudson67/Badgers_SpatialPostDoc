-- Woodchester V1.1: auditable sett coordinates and unresolved recorded-location review.
create table if not exists research.sett_location_evidence (
 evidence_id bigint generated always as identity primary key,
 sett_id bigint not null references research.setts(sett_id),
 easting numeric,
 northing numeric,
 coordinate_system text not null default 'EPSG:27700',
 accuracy_m numeric,
 evidence_type text not null check(evidence_type in ('FIELD_TEAM','HISTORIC_MAP','GPS','OTHER')),
 source_reference text not null,
 observed_on date,
 recorded_by text,
 review_status text not null default 'PROPOSED' check(review_status in ('PROPOSED','APPROVED','REJECTED','SUPERSEDED')),
 reviewed_by text,
 reviewed_at timestamptz,
 notes text,
 created_at timestamptz not null default now(),
 check ((easting is null and northing is null) or (easting is not null and northing is not null)),
 check (accuracy_m is null or accuracy_m >= 0)
);
create unique index if not exists one_approved_coordinate_per_sett on research.sett_location_evidence(sett_id) where review_status='APPROVED';
create or replace view analysis.sett_coordinates_approved as
select s.sett_name,e.easting,e.northing,e.coordinate_system,e.accuracy_m,e.source_reference,e.observed_on
from research.setts s join research.sett_location_evidence e on e.sett_id=s.sett_id
where e.review_status='APPROVED';
create or replace view analysis.sett_field_team_review as
select s.sett_name,
       count(c.capture_id) as canonical_capture_count,
       max(c.capture_date) as last_capture_date,
       bool_or(e.review_status='APPROVED') as has_approved_coordinate
from research.setts s left join research.captures c on c.sett_id=s.sett_id
left join research.sett_location_evidence e on e.sett_id=s.sett_id
group by s.sett_id,s.sett_name;
create or replace view analysis.unresolved_recorded_sett_names as
select recorded_sett_name,count(*) as n_captures,min(capture_date) first_recorded,max(capture_date) last_recorded
from research.captures where sett_id is null and nullif(btrim(recorded_sett_name),'') is not null
group by recorded_sett_name;
grant select on research.sett_location_evidence to badger_research_readonly;
grant select on analysis.sett_coordinates_approved,analysis.sett_field_team_review,analysis.unresolved_recorded_sett_names to badger_readonly,badger_research_readonly;
