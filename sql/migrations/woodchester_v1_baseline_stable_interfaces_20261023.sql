-- Working Version 1 (2026-10-23): stable researcher-facing location interface.
-- Earlier v2/v3 audit views retained for technical provenance; no source records overwritten.
create or replace view analysis.capture_location_v1 with (security_invoker = true) as
select v.capture_id,v.tattoo,v.capture_date,v.is_pm,
       v.sett_id, v.original_recorded_sett_name,
       case when v.sett_id is not null then s.sett_name end as canonical_sett_name,
       v.location_class, v.location_display_category, v.capture_location_text,v.os_ref,
       v.reference_source,v.so_grid_six_digits,v.newly_parsed_grid_reference,
       v.grid_sw_easting,v.grid_sw_northing,v.newly_parsed_cell_width_m,
       v.accompanying_location_description,v.positional_precision_note,
       case when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PROVISIONAL_GRID_CELL_NOT_SETT'
            when v.location_class='KNOWN_SETT' then 'CANONICAL_SETT'
            else 'REVIEW_OR_MISSING' end as spatial_interpretation
from analysis.capture_location_classified_v3 v
left join research.setts s on s.sett_id=v.sett_id;

create or replace view analysis.sett_inventory_v1 with (security_invoker = true) as
select s.sett_id,s.sett_name as canonical_sett_name,
       coalesce(i.n_captures,0)::bigint as capture_count,
       i.n_pm_records,i.first_capture_date,i.last_capture_date,
       i.easting,i.northing,i.coordinate_system,i.accuracy_m,
       i.coordinate_source,i.coordinate_status
from research.setts s join analysis.capture_sett_coordinate_inventory i on i.sett_name=s.sett_name;

create or replace view analysis.sett_coordinate_unmatched_v1 with (security_invoker = true) as
select source_name,source_display_name,easting,northing,match_status
from analysis.sett_coordinate_source_name_review where match_status='REVIEW_NAME';

grant select on analysis.capture_location_v1,analysis.sett_inventory_v1,analysis.sett_coordinate_unmatched_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_v1 is 'Woodchester working V1 stable capture-location interface. Historical field unmodified. Grid references are provisional locations and never sett points.';
comment on view analysis.sett_inventory_v1 is 'Woodchester working V1 stable canonical sett inventory with linked coordinate evidence and capture counts.';
comment on view analysis.sett_coordinate_unmatched_v1 is 'Woodchester working V1 coordinate source names not yet matched to canonical sett identities.';
create table if not exists ingest.woodchester_data_baseline_versions (
version_label text primary key,
baseline_date date not null,
status text not null,
scope text not null,
scientific_rules text not null,
outstanding_work text not null,
recorded_by text not null,
recorded_at timestamptz not null default now()
);
insert into ingest.woodchester_data_baseline_versions
(version_label,baseline_date,status,scope,scientific_rules,outstanding_work,recorded_by)
values ('v1',date '2026-10-23','WORKING_BASELINE',
'Woodchester Access-derived research and analysis layers, sett coordinate source and PM recovery-location interpretation',
'Raw recorded names preserved. TOP SETT = TOP; GULLY coordinate alias = GULLEY. Canonical sett coordinates linked only where unambiguous or previously approved. SO/ST recovery grid squares not reclassified as setts; map coordinates provisional and original text retained.',
'Validate source CRS; spatial extent and historical ST/SO conventions; reconcile unmatched coordinate source names, historical unmatched names, descriptive PM recoveries and non-PM location names; complete source-table and field parity review.',
'Dave Hudson')
on conflict(version_label) do nothing;
revoke all on ingest.woodchester_data_baseline_versions from public,anon,authenticated;
