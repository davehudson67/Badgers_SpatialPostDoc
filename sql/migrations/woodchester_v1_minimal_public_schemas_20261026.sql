-- V1 coauthor-facing schema simplification, 26 October 2026.
-- Non-destructive: preserve SQL view dependencies and provenance.
create schema if not exists internal_v1;
comment on schema internal_v1 is 'Internal supporting and legacy V1 analysis SQL, not coauthor primary views.';
grant usage on schema internal_v1 to badger_readonly,badger_research_readonly;
do $$
declare name text;
begin
foreach name in array array[
'capture_diagnostic_summary_standardised','capture_history','capture_traits_standardised',
'capture_traits_v1','individual_traits_standardised','capture_location_classified_v2',
'capture_location_classified_v3','capture_location_fields_v1','capture_pm_grid_reference_review',
'capture_sett_coordinate_inventory','culture_results_standardised','diagnostic_interpretation_standardised',
'infection_probabilities','infection_quarterly_probabilities','sett_coordinate_source_name_review',
'sett_coordinate_unmatched_v1','sett_coordinates_approved','sett_social_group_observed','stat_pak_results_standardised'
] loop
execute format('alter view analysis.%I set schema internal_v1',name);
end loop;
end $$;
grant select on all tables in schema internal_v1 to badger_readonly,badger_research_readonly;
alter table research.infection_probabilities_import set schema ingest;
alter table research.infection_quarterly_import set schema ingest;
alter table research.sett_coordinate_source_20261023 set schema ingest;
revoke all privileges on all tables in schema ingest from badger_readonly,badger_research_readonly;
