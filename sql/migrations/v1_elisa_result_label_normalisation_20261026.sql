alter table research.elisa_tests add column test_result_clean text generated always as (case when test_result in ('NO SERA','NO SERUM') then 'NO SERUM' else test_result end) stored;
