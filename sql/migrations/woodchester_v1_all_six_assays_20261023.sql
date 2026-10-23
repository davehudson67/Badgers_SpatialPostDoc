-- Include existing v1 culture interpretation in the unified test-level view
create or replace view analysis.diagnostic_interpretation_standardised as
with x as (
select capture_id,'DPP'::text test_family,dpp_test_id source_record_id,
       concat_ws('/',visual_line_1,visual_line_2) recorded_result,
       case when upper(btrim(coalesce(visual_line_1,''))) in ('P','PX') or upper(btrim(coalesce(visual_line_2,''))) in ('P','PX') then 'POSITIVE'
            when upper(btrim(coalesce(visual_line_1,''))) in ('N','NX') and
                 (upper(btrim(coalesce(visual_line_2,''))) in ('N','NX') or nullif(btrim(coalesce(visual_line_2,'')),'') is null) then 'NEGATIVE'
            else 'INDETERMINATE' end interpreted_status
from research.dpp_tests
union all
select capture_id,'IFN_GAMMA',ifn_test_id,test_result,
       case when nullif(btrim(coalesce(test_failed,'')),'') is not null then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='POSITIVE' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='NEGATIVE' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.ifn_gamma_elisa
union all
select capture_id,'ELISA',elisa_test_id,test_result,
       case when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.elisa_tests
union all
select capture_id,'BROCK',brock_test_id,test_result,
       case when no_clotted is true then 'INVALID'
            when upper(btrim(coalesce(test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.brock_tests
union all
select capture_id,'STAT_PAK',stat_pak_test_id,original_result_text,result_status
from analysis.stat_pak_results_standardised
union all
select capture_id,'CULTURE',culture_id,culture_result_recorded,
       case culture_result_status
         when 'M_BOVIS_DETECTED' then 'POSITIVE'
         when 'NEGATIVE' then 'NEGATIVE'
         when 'INVALID' then 'INVALID'
         else 'INDETERMINATE' end
from analysis.culture_results_standardised
)
select i.tattoo,c.capture_id,c.capture_date,c.is_pm,
       x.test_family,x.source_record_id,x.recorded_result,x.interpreted_status,
       case when x.interpreted_status='POSITIVE' then true
            when x.interpreted_status='NEGATIVE' then false else null end as test_positive
from x join research.captures c on c.capture_id=x.capture_id
join research.individuals i on i.individual_id=c.individual_id;
comment on view analysis.diagnostic_interpretation_standardised is 'Version 1 baseline: six assay families including culture; original results preserved and nullable positivity excludes missing/invalid/pending and other organisms.';
