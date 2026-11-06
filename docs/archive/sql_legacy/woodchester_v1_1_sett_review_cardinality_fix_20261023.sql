create or replace view analysis.sett_field_team_review as
select s.sett_name,
       (select count(*) from research.captures c where c.sett_id=s.sett_id) as canonical_capture_count,
       (select max(c.capture_date) from research.captures c where c.sett_id=s.sett_id) as last_capture_date,
       exists (select 1 from research.sett_location_evidence e where e.sett_id=s.sett_id and e.review_status='APPROVED') as has_approved_coordinate
from research.setts s;