-- V1 coauthor read-only roles share access to curated research and analysis.
-- Access staging/raw remains restricted.
grant usage on schema research,analysis to badger_readonly,badger_research_readonly;
do $$
declare t record;
begin
for t in select table_name from information_schema.tables where table_schema='research' and table_type='BASE TABLE' and table_name not in ('infection_probabilities_import','infection_quarterly_import','sett_coordinate_source_20261023') loop
execute format('grant select on research.%I to badger_readonly,badger_research_readonly',t.table_name);
end loop;
end $$;
grant select on all tables in schema analysis to badger_readonly,badger_research_readonly;
revoke insert,update,delete,truncate,references,trigger on all tables in schema research from badger_readonly,badger_research_readonly;
revoke insert,update,delete,truncate,references,trigger on all tables in schema analysis from badger_readonly,badger_research_readonly;
