create or replace view analysis.capture_location_classified_v3 as
with src as (
select v.*,upper(regexp_replace(coalesce(v.os_ref,''),'[[:space:],.-]','','g')) as cleaned_os_ref
from analysis.capture_location_classified_v2 v
), parsed as (
select src.*,
case when cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$' then substring(cleaned_os_ref,1,2) end as grid_prefix,
case when cleaned_os_ref ~ '^(SO|ST)([0-9]{6}|[0-9]{8}|[0-9]{10})$' then substring(cleaned_os_ref,3) end as grid_digits
from src
), converted as (
select parsed.*,
case when grid_digits is not null then power(10,5-length(grid_digits)/2)::integer end as additional_cell_width_m,
case when grid_digits is not null then 300000 + substring(grid_digits,1,length(grid_digits)/2)::integer * power(10,5-length(grid_digits)/2)::integer end as additional_easting,
case when grid_digits is not null then (case grid_prefix when 'SO' then 200000 when 'ST' then 100000 end) + substring(grid_digits,length(grid_digits)/2+1)::integer * power(10,5-length(grid_digits)/2)::integer end as additional_northing
from parsed
)
select capture_id,tattoo,capture_date,is_pm,sett_id,original_recorded_sett_name,os_ref,capture_location_text,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'GRID_REFERENCED_PM_LOCATION' else location_class end as location_class,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'GRID REFERENCE (NOT A SETT)' else location_display_category end as location_display_category,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'os_ref_explicit_prefix' else reference_source end as reference_source,
so_grid_six_digits,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_easting else grid_sw_easting end as grid_sw_easting,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_northing else grid_sw_northing end as grid_sw_northing,
accompanying_location_description,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then 'PARSED_'||grid_prefix||'_'||additional_cell_width_m||'M_GRID_SQUARE' else positional_precision_note end as positional_precision_note,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then grid_prefix||grid_digits end as newly_parsed_grid_reference,
case when location_class='PM_LOCATION_UNRESOLVED' and grid_digits is not null then additional_cell_width_m end as newly_parsed_cell_width_m
from converted;
grant select on analysis.capture_location_classified_v3 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified_v3 is 'Adds only explicitly prefixed ST/SO OS grid references at 100m, 10m and 1m nominal grid precision to PM recovery classification. No sett identity changes, no unsupported prefixes or typo correction. ST is 300km E / 100km N, SO 300km E / 200km N; coordinates designate SW grid-square corner rather than exact point.';
