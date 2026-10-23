-- Versioned, non-destructive canonical interpretation v1.
-- Maintains raw Access records and typed canonical research records unchanged.
create or replace view analysis.individual_traits_standardised as
select i.tattoo, i.elect_tag,
       i.age_first_capture as age_first_capture_recorded,
       case when upper(btrim(coalesce(i.age_first_capture,''))) in ('CUB','YEARLING','ADULT')
            then upper(btrim(i.age_first_capture)) else 'UNKNOWN' end as age_first_capture_standardised,
       (i.age_first_capture is null) as age_first_capture_missing,
       i.year_first_capture,
       i.sex as sex_recorded,
       case when upper(btrim(coalesce(i.sex,''))) in ('MALE','FEMALE')
            then upper(btrim(i.sex)) else 'UNKNOWN' end as sex_standardised,
       (i.sex is null) as sex_missing
from research.individuals i;

create or replace view analysis.culture_results_standardised as
select i.tattoo, c.capture_id, cu.culture_id,
       c.capture_date, c.is_pm, cu.sample_type as sample_type_recorded,
       case when upper(btrim(coalesce(cu.sample_type,''))) in ('OA','TA','URINE','FAECES')
            then upper(btrim(cu.sample_type)) else 'OTHER' end as sample_group,
       cu.culture_result as culture_result_recorded,
       case
         when upper(btrim(coalesce(cu.culture_result,''))) = 'M.BOVIS' then 'M_BOVIS_DETECTED'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'NEGATIVE' then 'NEGATIVE'
         when upper(btrim(coalesce(cu.culture_result,''))) in ('M.AVIUM','M.OTHER') then 'OTHER_ORGANISM'
         when upper(btrim(coalesce(cu.culture_result,''))) in ('FAILED','CONTAMINATED') then 'INVALID'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'PENDING' then 'PENDING'
         when upper(btrim(coalesce(cu.culture_result,''))) = 'NOT TESTED' then 'NOT_TESTED'
         when nullif(btrim(coalesce(cu.culture_result,'')),'') is null then 'MISSING'
         else 'UNRECOGNISED'
       end as culture_result_status,
       case when upper(btrim(coalesce(cu.culture_result,'')))='M.BOVIS' then true
            when upper(btrim(coalesce(cu.culture_result,'')))='NEGATIVE' then false
            else null end as is_m_bovis_detected,
       cu.afno,cu.spoligo,cu.spolprime,cu.wgs_clade
from research.cultures cu
join research.captures c on c.capture_id=cu.capture_id
join research.individuals i on i.individual_id=c.individual_id;

grant select on analysis.individual_traits_standardised,analysis.culture_results_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.individual_traits_standardised is 'Version 1: non-destructive age/sex standardisation. UNKNOWN includes canonical NULL and nonstandard codes; explicit missing flags distinguish NULL. Not an age correction.';
comment on view analysis.culture_results_standardised is 'Version 1: culture result categories. Only M.BOVIS and NEGATIVE yield non-null binary evidence; other organism/invalid/pending/missing results are not treated as negative.';