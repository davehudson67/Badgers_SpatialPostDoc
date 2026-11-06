create or replace view analysis.capture_location_classified as
select h.capture_id,h.tattoo,h.capture_date,h.is_pm,
       h.recorded_sett_name as original_recorded_sett_name,
       h.sett_id,h.normalized_sett_name as canonical_sett_name,
       h.os_ref,h.capture_location_text,
       case
         when h.sett_id is not null then 'KNOWN_SETT'
         when g.so_six_digits is not null then 'GRID_REFERENCED_PM_LOCATION'
         when h.is_pm then 'PM_LOCATION_UNRESOLVED'
         when nullif(btrim(h.recorded_sett_name),'') is not null then 'UNMATCHED_RECORDED_SETT_NAME'
         else 'LOCATION_NOT_RECORDED'
       end as location_class,
       case when h.sett_id is not null then h.normalized_sett_name
            when g.so_six_digits is not null then 'GRID REFERENCE (NOT A SETT)'
            else null end as display_location_name,
       g.grid_reference_source,g.so_six_digits,
       g.grid_cell_easting,g.grid_cell_northing,g.grid_cell_width_m,
       g.inferred_crs,g.review_status as grid_reference_review_status
from analysis.capture_history h
left join analysis.capture_pm_grid_reference_review g on g.capture_id=h.capture_id;
grant select on analysis.capture_location_classified to badger_readonly,badger_research_readonly;
comment on view analysis.capture_location_classified is 'Researcher-facing location classification distinguishing known setts, grid-referenced PM locations (not setts), other unreviewed PM locations and unmatched capture sett text. Source values never overwritten; six-digit SO grid cells are provisional.';
