-- WOODCHESTER DATABASE v1 baseline extension, idempotent presentation-layer migration.
-- Existing prior migrations v1/v2/v3 retained as historical history.
create or replace view analysis.stat_pak_results_standardised as
select i.tattoo,s.capture_id,s.stat_pak_test_id,c.capture_date,
s.stat_pak_id as original_result_code,s.test_result as original_result_text,
case when upper(btrim(s.stat_pak_id))='P' then 'POSITIVE'
when upper(btrim(s.stat_pak_id))='N' then 'NEGATIVE'
when upper(btrim(s.stat_pak_id))='C' then 'INVALID'
else 'INDETERMINATE' end result_status,
case when upper(btrim(s.stat_pak_id))='P' then true
when upper(btrim(s.stat_pak_id))='N' then false else null end test_positive
from research.stat_pak_tests s join research.captures c using(capture_id)
join research.individuals i using(individual_id);

create or replace view analysis.capture_traits_standardised as
select c.capture_id,i.tattoo,c.capture_date,
extract(year from c.capture_date)::integer capture_year,
extract(quarter from c.capture_date)::integer capture_quarter,
c.is_pm,c.sett_id,c.recorded_sett_name,c.recorded_social_group_id,
c.recorded_social_group_name,
t.sex_recorded,t.sex_standardised,t.sex_missing,
t.age_first_capture_recorded,t.age_first_capture_standardised,
t.year_first_capture,
case when t.year_first_capture is not null and c.capture_date is not null
then extract(year from c.capture_date)::integer-t.year_first_capture else null end
as years_since_first_capture,
case when t.age_first_capture_standardised='CUB' and t.year_first_capture is not null
then extract(year from c.capture_date)::integer-t.year_first_capture
else null end as approximate_age_if_first_captured_as_cub
from research.captures c join research.individuals i using(individual_id)
join analysis.individual_traits_standardised t on t.tattoo=i.tattoo;

grant select on analysis.stat_pak_results_standardised,analysis.capture_traits_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.capture_traits_standardised is 'V1: year/quarter and years since first capture; approximate age only for recorded CUB first captures, not validated exact age.';
