-- Working Version 1: independent, non-destructive reconciliation of names and coordinate proximity.
create or replace view analysis.unmatched_coordinate_sett_candidates as
select src.source_name, src.source_display_name, src.easting,src.northing,
       near.sett_name as nearest_named_sett,
       round(sqrt(power(src.easting-near.easting,2)+power(src.northing-near.northing,2)))::integer nearest_distance_m,
       (select count(*) from research.captures c where regexp_replace(upper(coalesce(c.recorded_sett_name,'')),'[^A-Z0-9]','','g')=regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g'))::bigint exact_normalised_capture_mentions,
       case when src.source_name='VILLIERS.UPPER' then 'MATCH_RECORDED_CAPTURE_NAME_REVIEW_IDENTITY'
            when src.source_name like '%NEEDS%' then 'SOURCE_RENAME_REQUIRED'
            else 'UNMATCHED_COORDINATE_NAME' end as review_category
from analysis.sett_coordinate_source_name_review src
cross join lateral (
 select s.sett_name,e.easting,e.northing from research.sett_location_evidence e
 join research.setts s using(sett_id)
 where e.review_status='APPROVED'
 order by power(src.easting-e.easting,2)+power(src.northing-e.northing,2)
 limit 1
) near
where src.match_status='REVIEW_NAME';
grant select on analysis.unmatched_coordinate_sett_candidates to badger_readonly,badger_research_readonly;
comment on view analysis.unmatched_coordinate_sett_candidates is 'Name/nearest-point review only; geographic distance is not evidence that points represent the same sett.';
