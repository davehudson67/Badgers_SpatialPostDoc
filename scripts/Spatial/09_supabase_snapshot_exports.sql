-- Run each SELECT separately in the Supabase SQL Editor; download each result as CSV.
-- Save under data/local_supabase_snapshots/ on Exeter; do NOT commit snapshots.

-- setts.csv
select sett_id, sett_name, notes
from research.setts order by sett_id;

-- groups.csv
select social_group_id, social_group_name
from research.social_groups order by social_group_id;

-- history.csv
select sett_id, social_group_id, valid_from, valid_to, notes
from research.sett_social_group_history order by sett_id, social_group_id;

-- captures_annual_aggregate.csv
select extract(year from capture_date)::integer as year,
       sett_id, recorded_social_group_id, count(*)::integer as n_captures
from research.captures
where capture_date >= date '1977-01-01'
  and capture_date < date '2026-01-01'
  and coalesce(is_pm,false) = false
  and sett_id is not null
group by 1,2,3 order by 1,2,3;
