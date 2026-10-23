-- Woodchester Version 1: read-only Access → research capture/identity checks.
-- Baseline audit by Dave Hudson, 2026-10-23.
select count(*) as original_badgers,
       count(*) filter(where i.individual_id is null) as not_in_research
from access_raw.tbl_badger r
left join research.individuals i on upper(btrim(r.tattoo))=upper(btrim(i.tattoo));

with matches as (
select r.raw_row_id,c.capture_id
from access_raw.tbl_captures r
left join research.individuals i on upper(btrim(r.tattoo))=upper(btrim(i.tattoo))
left join research.captures c on c.individual_id=i.individual_id
 and c.capture_date=r.capture_date::date
 and c.is_pm=(upper(btrim(coalesce(r.pm,''))) in ('YES','Y','TRUE'))
)
select count(*) original_capture_rows,
       count(*) filter(where capture_id is null) unmatched_rows,
       count(distinct capture_id) distinct_matched_captures
from matches;

select count(*) duplicate_tattoo_date_pm_keys from (
 select i.tattoo,c.capture_date,c.is_pm
 from research.captures c join research.individuals i using(individual_id)
 group by 1,2,3 having count(*)>1
) duplicate_keys;

select count(*) dpp_rows,
       count(*) filter(where raw.raw_row_id is null) unmatched_source_rows
from research.dpp_tests d
left join access_raw.tbl_dpp_test raw on raw.raw_row_id=d.source_raw_row_id;

select count(*) filter(where is_pm) post_mortem_rows,
       count(*) filter(where capture_date is null) missing_dates
from research.captures;
