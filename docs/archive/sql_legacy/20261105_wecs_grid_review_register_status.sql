-- Applied via Supabase on 2026-11-05 after the two map-review migrations.
-- Investigator visual approval is geographic plausibility only, not precise location accuracy.
update research.wecs_review_flags
set current_interpretation='57 accepted by investigator as geographically plausible on interactive maps, while remaining provisionally precise. 40 withheld: two rejected and 38 pending, including 30 hypothetical minus-100km test locations that have NOT been applied.',
updated_at=now()
where flag_id='SPATIAL-GRID';
select flag_id,review_status,current_interpretation
from research.wecs_review_flags where flag_id='SPATIAL-GRID';
