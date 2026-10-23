-- Woodchester badger database cleaning/provenance audit
-- Read-only audit queries. Safe to run as a maintainer.
-- Updated 2026-10-16.

-- 1. Row counts across raw and canonical research tables
select table_schema, table_name
from information_schema.tables
where table_schema in ('access_raw','research')
order by table_schema, table_name;

-- Core explicit count comparison
select 'access_raw.tbl_badger' object, count(*) n from access_raw.tbl_badger
union all select 'research.individuals', count(*) from research.individuals
union all select 'access_raw.tbl_captures', count(*) from access_raw.tbl_captures
union all select 'research.captures', count(*) from research.captures
union all select 'access_raw.tbl_culture', count(*) from access_raw.tbl_culture
union all select 'research.cultures', count(*) from research.cultures
union all select 'access_raw.tbl_dpp_test', count(*) from access_raw.tbl_dpp_test
union all select 'research.dpp_tests', count(*) from research.dpp_tests
union all select 'access_raw.tbl_elisa', count(*) from access_raw.tbl_elisa
union all select 'research.elisa_tests', count(*) from research.elisa_tests
union all select 'access_raw.tbl_ifn_gamma_elisa', count(*) from access_raw.tbl_ifn_gamma_elisa
union all select 'research.ifn_gamma_elisa', count(*) from research.ifn_gamma_elisa
union all select 'access_raw.tbl_stat_pak', count(*) from access_raw.tbl_stat_pak
union all select 'research.stat_pak_tests', count(*) from research.stat_pak_tests
union all select 'access_raw.tbl_brock_test', count(*) from access_raw.tbl_brock_test
union all select 'research.brock_tests', count(*) from research.brock_tests
union all select 'access_raw.tbl_wounds', count(*) from access_raw.tbl_wounds
union all select 'research.wounds', count(*) from research.wounds
order by object;

-- 2. Capture location/social-group assignment coverage
select
  count(*) as captures,
  count(*) filter (where sett_id is not null) as with_sett_id,
  count(*) filter (
    where recorded_sett_name is not null and sett_id is null
  ) as recorded_sett_unresolved,
  count(*) filter (
    where recorded_social_group_name is not null
  ) as with_recorded_sg,
  count(*) filter (
    where recorded_social_group_id is not null
  ) as with_recorded_sg_id,
  count(*) filter (
    where recorded_social_group_name is not null
      and recorded_social_group_id is null
  ) as recorded_sg_unresolved
from research.captures;

-- 3. Every non-trivial location cleaning note
select
  capture_id,
  individual_id,
  capture_date,
  recorded_sett_name,
  sett_id,
  recorded_social_group_name,
  recorded_social_group_id,
  location_cleaning_note
from research.captures
where location_cleaning_note is not null
order by capture_date,capture_id;

-- 4. Recorded sett values that have no canonical sett assignment
select recorded_sett_name, count(*) n
from research.captures
where recorded_sett_name is not null
  and sett_id is null
group by recorded_sett_name
order by n desc, recorded_sett_name;

-- 5. Recorded social-group values that have no canonical SG assignment
select recorded_social_group_name, count(*) n
from research.captures
where recorded_social_group_name is not null
  and recorded_social_group_id is null
group by recorded_social_group_name
order by n desc, recorded_social_group_name;

-- 6. Canonical lookup entries carrying provenance notes
select 'sett' object_type, sett_id id, sett_name name, notes
from research.setts
where notes is not null and btrim(notes)<>''
union all
select 'social_group', social_group_id, social_group_name, notes
from research.social_groups
where notes is not null and btrim(notes)<>''
union all
select 'supergroup', supergroup_id, supergroup_name, notes
from research.supergroups
where notes is not null and btrim(notes)<>''
order by object_type,name;

-- 7. Sett/social-group history
select
  h.sett_social_group_id,
  s.sett_name,
  sg.social_group_name,
  h.valid_from,
  h.valid_to,
  h.notes
from research.sett_social_group_history h
join research.setts s using (sett_id)
join research.social_groups sg using (social_group_id)
order by s.sett_name,h.valid_from nulls first,sg.social_group_name;

-- 8. SG/supergroup history
select
  h.social_group_supergroup_id,
  sg.social_group_name,
  sp.supergroup_name,
  h.valid_from,
  h.valid_to,
  h.notes
from research.social_group_supergroup_history h
join research.social_groups sg using (social_group_id)
join research.supergroups sp using (supergroup_id)
order by sg.social_group_name,h.valid_from nulls first,sp.supergroup_name;

-- 9. Analysis capture view definition: proves where normalised fields come from
select pg_get_viewdef('analysis.capture_history'::regclass,true);

-- 10. Research-role effective privileges
select
  c.relname as object_name,
  has_table_privilege(
    'badger_research_readonly',c.oid,'select'
  ) as can_select,
  has_table_privilege(
    'badger_research_readonly',c.oid,'insert'
  ) as can_insert,
  has_table_privilege(
    'badger_research_readonly',c.oid,'update'
  ) as can_update,
  has_table_privilege(
    'badger_research_readonly',c.oid,'delete'
  ) as can_delete
from pg_class c
join pg_namespace n on n.oid=c.relnamespace
where n.nspname='research'
  and c.relkind='r'
order by c.relname;

-- 11. Live data dictionary skeleton
select
  table_schema,
  table_name,
  ordinal_position,
  column_name,
  data_type,
  is_nullable,
  column_default
from information_schema.columns
where table_schema in ('access_raw','research','analysis')
order by table_schema,table_name,ordinal_position;

-- 12. Duplicate-key audits
select tattoo,count(*) n
from research.individuals
group by tattoo
having count(*)>1
order by n desc,tattoo;

select capture_id,count(*) n
from research.captures
group by capture_id
having count(*)>1;

-- 13. Orphan checks
select count(*) as captures_without_individual
from research.captures c
left join research.individuals i using (individual_id)
where i.individual_id is null;

select count(*) as cultures_without_capture
from research.cultures x
left join research.captures c using (capture_id)
where c.capture_id is null;

select count(*) as dpp_without_capture
from research.dpp_tests x
left join research.captures c using (capture_id)
where c.capture_id is null;

select count(*) as wounds_without_capture
from research.wounds x
left join research.captures c using (capture_id)
where c.capture_id is null;
