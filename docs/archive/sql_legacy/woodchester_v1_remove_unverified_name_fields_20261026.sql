-- V1 removal of unsupported individual name data from cleaned research.
-- Keep the original Access archive unchanged. Two legacy compatibility view fields
-- remain NULL to preserve dependent view signatures until further refactoring.
do $$ declare v text; begin
v:=pg_get_viewdef('internal_v1.capture_history'::regclass,true);
v:=replace(v,'individuals.historical_names','NULL::text AS historical_names');
v:=replace(v,'individuals.n_historical_names','NULL::bigint AS n_historical_names');
execute 'create or replace view internal_v1.capture_history as '||v;
end $$;
alter table research.individuals drop column historical_names;
alter table research.individuals drop column n_historical_names;
