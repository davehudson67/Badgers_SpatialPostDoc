create or replace view analysis.capture_location_classified_v2 as
with pm as (
 select c.capture_id,c.tattoo,c.capture_date,c.is_pm,c.sett_id,c.recorded_sett_name,c.os_ref,c.capture_location_text,
 g.so_six_digits as existing_grid,
 upper(substring(coalesce(c.recorded_sett_name,'') from '(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)')) as grid_text_raw,
 (regexp_match(coalesce(c.recorded_sett_name,''),'(^|[^0-9])([0-9]{3}[[:space:]]?[0-9]{3})([^0-9]|$)'))[2] as grid_text,
 g.grid_reference_source as existing_grid_source
 from analysis.capture_history c left join analysis.capture_pm_grid_reference_review g on g.capture_id=c.capture_id
), parsed as (
 select *,coalesce(existing_grid,regexp_replace(grid_text,'[[:space:]]','','g')) as six_digits,
 case when existing_grid is not null then existing_grid_source when is_pm and sett_id is null and grid_text is not null then 'recorded_sett_name_embedded' end as reference_source
 from pm
)
select capture_id,tattoo,capture_date,is_pm,sett_id,recorded_sett_name as original_recorded_sett_name,os_ref,capture_location_text,
 case when sett_id is not null then 'KNOWN_SETT'
 when is_pm and six_digits is not null and six_digits ~ '^[0-9]{6}$' then 'GRID_REFERENCED_PM_LOCATION'
 when is_pm then 'PM_LOCATION_UNRESOLVED'
 when nullif(btrim(recorded_sett_name),'') is not null then 'UNMATCHED_RECORDED_SETT_NAME'
 else 'LOCATION_NOT_RECORDED' end as location_class,
 case when is_pm and sett_id is null and six_digits ~ '^[0-9]{6}$' then 'GRID REFERENCE (NOT A SETT)' else null end as location_display_category,
 reference_source,six_digits as so_grid_six_digits,
 case when six_digits ~ '^[0-9]{6}$' then 300000+substring(six_digits,1,3)::int*100 end as grid_sw_easting,
 case when six_digits ~ '^[0-9]{6}$' then 200000+substring(six_digits,4,3)::int*100 end as grid_sw_northing,
 case when is_pm and sett_id is null and reference_source='recorded_sett_name_embedded'
 then nullif(btrim(regexp_replace(recorded_sett_name,'(^|[^0-9])[0-9]{3}[[:space:]]?[0-9]{3}([^0-9]|$)',' ')),'') end as accompanying_location_description,
 case when is_pm and sett_id is null and six_digits ~ '^[0-9]{6}$' then 'PROVISIONAL_SO_100M_GRID_SQUARE' end as positional_precision_note
from parsed;
grant select on analysis.capture_location_classified_v2 to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified_v2 is 'Classifies PM grid references embedded in sett-name text with optional descriptive place names as non-sett recovery locations, without changing canonical records. SO 100m grid squares are provisional. Source text kept intact.';
