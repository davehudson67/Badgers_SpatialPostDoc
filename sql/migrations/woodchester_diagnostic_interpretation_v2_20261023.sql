-- Versioned diagnostic interpretation v2, 2026-10-23.
-- Source and research base rows preserved; NULL means indeterminate, not negative.
create or replace view analysis.diagnostic_interpretation_standardised as
with classified as (
select d.capture_id,'DPP'::text test_family,d.dpp_test_id source_record_id,
       concat_ws('/',d.visual_line_1,d.visual_line_2) recorded_result,
       case when upper(btrim(coalesce(d.visual_line_1,''))) in ('P','PX') or upper(btrim(coalesce(d.visual_line_2,''))) in ('P','PX') then 'POSITIVE'
            when upper(btrim(coalesce(d.visual_line_1,''))) in ('N','NX') and
                 (upper(btrim(coalesce(d.visual_line_2,''))) in ('N','NX') or nullif(btrim(coalesce(d.visual_line_2,'')),'') is null) then 'NEGATIVE'
            else 'INDETERMINATE' end interpreted_status
from research.dpp_tests d
union all
select x.capture_id,'IFN_GAMMA',x.ifn_test_id,x.test_result,
       case when nullif(btrim(coalesce(x.test_failed,'')),'') is not null then 'INVALID'
            when upper(btrim(coalesce(x.test_result,'')))='POSITIVE' then 'POSITIVE'
            when upper(btrim(coalesce(x.test_result,'')))='NEGATIVE' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.ifn_gamma_elisa x
union all
select e.capture_id,'ELISA',e.elisa_test_id,e.test_result,
       case when upper(btrim(coalesce(e.test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(e.test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.elisa_tests e
union all
select b.capture_id,'BROCK',b.brock_test_id,b.test_result,
       case when b.no_clotted is true then 'INVALID'
            when upper(btrim(coalesce(b.test_result,'')))='P' then 'POSITIVE'
            when upper(btrim(coalesce(b.test_result,'')))='N' then 'NEGATIVE'
            else 'INDETERMINATE' end
from research.brock_tests b
)
select i.tattoo,c.capture_id,c.capture_date,c.is_pm,
       x.test_family,x.source_record_id,x.recorded_result,x.interpreted_status,
       case when x.interpreted_status='POSITIVE' then true
            when x.interpreted_status='NEGATIVE' then false else null end as test_positive
from classified x join research.captures c on c.capture_id=x.capture_id
join research.individuals i on i.individual_id=c.individual_id;

create or replace view analysis.capture_diagnostic_summary_standardised as
select c.capture_id,i.tattoo,c.capture_date,c.is_pm,
       count(d.source_record_id) diagnostic_test_count,
       count(d.source_record_id) filter(where d.test_positive is true) positive_test_count,
       count(d.source_record_id) filter(where d.test_positive is false) negative_test_count,
       count(d.source_record_id) filter(where d.test_positive is null) uninterpretable_test_count,
       bool_or(d.test_positive is true) any_positive_test
from research.captures c join research.individuals i on i.individual_id=c.individual_id
left join analysis.diagnostic_interpretation_standardised d on c.capture_id=d.capture_id
group by c.capture_id,i.tattoo,c.capture_date,c.is_pm;
grant select on analysis.diagnostic_interpretation_standardised,analysis.capture_diagnostic_summary_standardised to badger_readonly,badger_research_readonly;
comment on view analysis.diagnostic_interpretation_standardised is 'v2 diagnostic interpretations, reversible derived values. DPP P/Px and N/Nx codes, explicit invalid IFN no-sample and Brock no-clot. Interpret with test-specific scientific constraints; INDETERMINATE is not negative.';
comment on view analysis.capture_diagnostic_summary_standardised is 'v2 convenience by capture, counts of interpretable and indeterminate tests; any_positive_test is descriptive evidence, not latent infection diagnosis.';
