alter table research.individuals add column if not exists historical_names text;
alter table research.individuals add column if not exists n_historical_names bigint not null default 0;
with names as (
 select individual_id,string_agg(distinct btrim(name),' | ' order by btrim(name)) as names,count(distinct btrim(name))::bigint n
 from research.individual_names where nullif(btrim(name),'') is not null group by individual_id
)
update research.individuals i set historical_names=n.names,n_historical_names=n.n from names n where n.individual_id=i.individual_id;
do $$
declare v text; a integer; b integer;
begin
v:=pg_get_viewdef('internal_v1.capture_history'::regclass,true);
a:=strpos(v,'WITH individual_name_summary AS (');
b:=strpos(v,'SELECT c.capture_id');
if a=0 or b<=a then raise exception 'Unexpected view SQL'; end if;
v:=left(v,a-1) || 'WITH individual_name_summary AS (SELECT individual_id,historical_names,n_historical_names FROM research.individuals) ' || substr(v,b);
execute 'create or replace view internal_v1.capture_history as '||v;
end $$;
drop table research.individual_names;
comment on column research.individuals.historical_names is 'Original names from Access tblCaptures; distinct names separated by |; TR retained.';
comment on column research.individuals.n_historical_names is 'Count distinct recorded names from tblCaptures.';
