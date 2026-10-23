-- Stable working V1 researcher-facing capture tables; non-destructive.
create or replace view analysis.capture_location_fields_v1 with (security_invoker=true) as
select v.capture_id,v.canonical_sett_name as sett_name,
case when v.location_class='KNOWN_SETT' then 'SETT'
when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PM_GRID_REFERENCE'
when v.location_class='PM_LOCATION_UNRESOLVED' then 'PM_LOCATION_UNRESOLVED'
when v.location_class='UNMATCHED_RECORDED_SETT_NAME' then 'UNMATCHED_CAPTURE_LOCATION'
else 'NOT_RECORDED' end as location_type,
case when v.location_class='KNOWN_SETT' then i.easting when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_easting::numeric end as location_easting,
case when v.location_class='KNOWN_SETT' then i.northing when v.location_class='GRID_REFERENCED_PM_LOCATION' then v.grid_sw_northing::numeric end as location_northing,
case when v.location_class='KNOWN_SETT' then i.coordinate_system when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'EPSG:27700' end as location_crs,
case when v.location_class='KNOWN_SETT' then 'SETT_SOURCE_COORDINATE'
when v.location_class='GRID_REFERENCED_PM_LOCATION' then 'PROVISIONAL_GRID_SQUARE_SOUTHWEST_CORNER'
else 'NO_VALIDATED_COORDINATE' end as location_coordinate_basis,v.location_class
from analysis.capture_location_v1 v left join analysis.sett_inventory_v1 i on i.sett_id=v.sett_id;
create or replace view analysis.capture_history_v1 with (security_invoker=true) as
select h.*,l.sett_name,l.location_type,l.location_easting,l.location_northing,l.location_crs,l.location_coordinate_basis,l.location_class
from analysis.capture_history h left join analysis.capture_location_fields_v1 l using(capture_id);
create or replace view analysis.capture_traits_v1 with (security_invoker=true) as
select t.*,l.sett_name,l.location_type,l.location_easting,l.location_northing,l.location_crs,l.location_coordinate_basis,l.location_class
from analysis.capture_traits_standardised t left join analysis.capture_location_fields_v1 l using(capture_id);
grant select on analysis.capture_location_fields_v1,analysis.capture_history_v1,analysis.capture_traits_v1 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_history_v1 is 'V1 standard capture-history table with sett_name NULL unless confirmed canonical sett. PM recovery grid locations are separate.';
comment on view analysis.capture_traits_v1 is 'V1 standardised capture traits with consistent sett_name and location fields.';
comment on view analysis.capture_location_fields_v1 is 'Reusable V1 capture location semantic fields; interpreted grid corner never implies sett.';
