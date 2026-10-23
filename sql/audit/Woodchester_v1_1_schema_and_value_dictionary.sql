-- V1.1 complete schema/column inventory and observed possible entries.
-- Output 1 lists every column and type; output 2 lists *observed* values for
-- short textual/boolean categorical fields (not an authoritative allowed-value set).
select c.table_schema,c.table_name,c.ordinal_position,c.column_name,
       c.data_type,c.is_nullable,c.column_default,
       pgd.description as database_comment
from information_schema.columns c
left join pg_catalog.pg_namespace ns on ns.nspname=c.table_schema
left join pg_catalog.pg_class cls on cls.relnamespace=ns.oid and cls.relname=c.table_name
left join pg_catalog.pg_attribute att on att.attrelid=cls.oid and att.attname=c.column_name
left join pg_catalog.pg_description pgd on pgd.objoid=cls.oid and pgd.objsubid=att.attnum
where c.table_schema in ('research','analysis','access_raw','ingest')
order by c.table_schema,c.table_name,c.ordinal_position;

-- To find valid options for an individual field, consult constraints/lookups,
-- not just values seen in existing rows. Example:
select coalesce(culture_result,'<SQL NULL>') as value,count(*) n
from research.cultures group by culture_result order by n desc;
select coalesce(age_first_capture,'<SQL NULL>') as value,count(*) n
from research.individuals group by age_first_capture order by n desc;
select coalesce(sex,'<SQL NULL>') as value,count(*) n
from research.individuals group by sex order by n desc;
select result_code,result_label from research.stat_pak_results order by display_order;
