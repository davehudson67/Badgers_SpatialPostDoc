-- 5 Nov 2026: investigator has visually accepted all thirty plotted hypothetical N-100km alternatives.
-- Preserve historical OS text and original parser positions, and keep 100m grid-cell/assumed prefix uncertainty.
do $$
declare n integer;
begin
 select count(*) into n
 from research.capture_grid_coordinate_decisions g
 join analysis.grid_withheld_candidate_review_v1 v using(capture_id)
 where g.decision_status='WITHHELD'
 and g.map_review_status='PENDING_REVIEW'
 and v.proposed_review_group='TEST_100KM_NORTHING_SHIFT'
 and v.test_easting=g.source_easting and v.test_northing=g.source_northing-100000
 and v.test_easting is not null and v.test_northing is not null;
 if n<>30 then
 raise exception 'Preflight expected 30 eligible, found %; no changes made.', n;
 end if;
end $$;

update research.capture_grid_coordinate_decisions g
set corrected_easting=v.test_easting,
corrected_northing=v.test_northing,
decision_status='CORRECTED',
map_review_status='VISUALLY_VERIFIED',
map_reviewed_at=now(),
map_review_note='Investigator inspected test-only -100km-northing map and approved all 30 alternatives 2026-11-05 as geographically plausible. Visual signoff is NOT a proof of exact original grid prefix, carcass recovery location or sub-cell accuracy.',
decision_note=g.decision_note || ' [2026-11-05 investigator map decision: accept test -100000m northing as PROVISIONAL grid-square proxy. Historical original ref and original parser XY remain unchanged. Never interpret as independent metre-accuracy survey.]',
decision_source='Original grid source + investigator interactive-map sign-off 2026-11-05'
from analysis.grid_withheld_candidate_review_v1 v
where v.capture_id=g.capture_id and g.decision_status='WITHHELD'
and g.map_review_status='PENDING_REVIEW'
and v.proposed_review_group='TEST_100KM_NORTHING_SHIFT'
and v.test_easting=g.source_easting and v.test_northing=g.source_northing-100000
and v.test_easting is not null and v.test_northing is not null;

update research.wecs_review_flags
set summary='87 corrected grid references visually approved; 10 remain withheld.',
evidence='5 Nov 2026: 57 previously corrected points plus 30 additional 100km northing-shift alternatives approved from interactive map. Original source refs unchanged, map acceptance only confirms plausible geography; source prefix and grid-square precision remain provisional. Two explicitly rejected grid points remain withheld.',
current_interpretation='87 corrected grid references carry VISUALLY_VERIFIED map-review status but remain provisional grid-square representations; 10 withheld await source evidence (including rejected UN260 and F030). Never discard mortality because XY is absent.',
updated_at=now()
where flag_id='SPATIAL-GRID';

do $$
begin
if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED')<>87 or
   (select count(*) from research.capture_grid_coordinate_decisions where decision_status='WITHHELD')<>10 or
   (select count(*) from research.capture_grid_coordinate_decisions where map_review_status='VISUALLY_VERIFIED')<>87 or
   (select count(*) from research.capture_grid_coordinate_decisions where map_review_status='REJECTED_BY_INVESTIGATOR')<>2
then raise exception 'Post-update grid state failed, transaction rolled back'; end if;
end $$;
