create or replace view analysis.capture_pm_grid_reference_review as
with base as (
 select c.capture_id,c.capture_date,c.is_pm,c.sett_id,c.recorded_sett_name,c.capture_location_text,c.os_ref,
 upper(regexp_replace(coalesce(c.os_ref,''),'[[:space:].-]','','g')) as os_clean,
 upper(regexp_replace(coalesce(c.recorded_sett_name,''),'[[:space:].-]','','g')) as recorded_clean
 from research.captures c where c.is_pm
), codes as (
 select *,case when os_clean ~ '^(SO)?[0-9]{6}$' then regexp_replace(os_clean,'^SO','')
               when recorded_clean ~ '^(SO)?[0-9]{6}$' then regexp_replace(recorded_clean,'^SO','')
               else null end as so_six_digits,
 case when os_clean ~ '^(SO)?[0-9]{6}$' then 'os_ref'
      when recorded_clean ~ '^(SO)?[0-9]{6}$' then 'recorded_sett_name'
      else null end as grid_reference_source
 from base
)
select capture_id,capture_date,is_pm,sett_id,recorded_sett_name,capture_location_text,os_ref,
 so_six_digits,grid_reference_source,
 case when so_six_digits is not null then 300000+(substring(so_six_digits,1,3)::int*100) end as grid_cell_easting,
 case when so_six_digits is not null then 200000+(substring(so_six_digits,4,3)::int*100) end as grid_cell_northing,
 case when so_six_digits is not null then 100 end as grid_cell_width_m,
 case when so_six_digits is not null then 'EPSG:27700' end as inferred_crs,
 case when so_six_digits is not null then 'PARSED_SO_6_DIGIT_GRID_CELL_NEEDS_SOURCE_CONFIRMATION'
 else 'UNPARSED_OR_ABSENT' end as review_status
from codes;
grant select on analysis.capture_pm_grid_reference_review to badger_readonly,badger_research_readonly;
comment on view analysis.capture_pm_grid_reference_review is 'PM capture-location grid reference review. Only pure SO+six digit or six-digit fields are interpreted as 100-m SO grid squares. Coordinates mark cell SW corner, NOT a sett point or exact badger location. Original evidence and uncertainty retained. No change to sett_id.';
