-- Woodchester canonicalisation candidates: read-only audit
-- 2026-10-23. No source records altered.
-- Run separately in SQL editor; inspect individual rows before any corrections.
-- 1: source evidence for historical individual correction
select i.tattoo, r.age_fc original_age, i.age_first_capture canonical_age
from research.individuals i
left join access_raw.tbl_badger r on upper(btrim(r.tattoo))=upper(btrim(i.tattoo))
where i.tattoo='067B';

-- 2: unlinked *recorded* sett values, not missing location data
select recorded_sett_name, count(*) captures
from research.captures
where nullif(btrim(recorded_sett_name),'') is not null and sett_id is null
group by recorded_sett_name order by captures desc,recorded_sett_name;

-- 3: unlinked *recorded* social-group values
select recorded_social_group_name,count(*) captures
from research.captures
where nullif(btrim(recorded_social_group_name),'') is not null
and recorded_social_group_id is null
group by recorded_social_group_name order by captures desc;

-- 4: nontrivial location cleaning provenance, grouped before investigating
select location_cleaning_note,count(*) captures
from research.captures where location_cleaning_note is not null
group by location_cleaning_note order by captures desc;

-- 5: candidate date-typo rows in *preserved* IFN import
select raw_row_id,tattoo,capture_date from (
select raw_row_id,badger_id as tattoo,capture_date from access_raw.tbl_ifn_gamma_elisa
) src where capture_date like '%2919%';

-- 6: canonical sex missingness; NULL deliberately distinct from UNKNOWN
select coalesce(sex,'<SQL NULL>') as sex_value,count(*) individuals
from research.individuals group by sex order by individuals desc;

-- 7: source/research culture-result frequency equivalence
with a as (select result,count(*) n from access_raw.tbl_culture group by result),
b as (select culture_result result,count(*) n from research.cultures group by culture_result)
select coalesce(a.result,b.result,'<SQL NULL>') category,
coalesce(a.n,0) raw_n,coalesce(b.n,0) canonical_n,
coalesce(a.n,0)-coalesce(b.n,0) difference
from a full join b on a.result is not distinct from b.result
order by category;

-- 8: uniqueness of canonical tattoo under case/whitespace normalisation
select upper(btrim(tattoo)) canonical_key,count(*) rows,
array_agg(tattoo order by tattoo) recorded_forms
from research.individuals
group by upper(btrim(tattoo)) having count(*)>1;

-- 9: null vs unresolved coordinates and groups
select count(*) total,
count(*) filter(where sett_id is null) no_sett_id,
count(*) filter(where sett_id is null and nullif(btrim(recorded_sett_name),'') is not null) named_unlinked_sett,
count(*) filter(where recorded_social_group_id is null) no_sg_id,
count(*) filter(where recorded_social_group_id is null and nullif(btrim(recorded_social_group_name),'') is not null) named_unlinked_sg
from research.captures;
