create or replace view analysis.grid_withheld_candidate_review_v1 with (security_invoker=false) as
select g.capture_id,e.tattoo,e.capture_date,e.is_pm,e.encounter_type,e.outcome,
g.original_grid_reference,c.capture_location_text as original_place_description,
g.source_easting,g.source_northing,g.corrected_easting as accepted_easting,
g.corrected_northing as accepted_northing,g.decision_status,g.map_review_status,
case
 when g.capture_id in (12072,17254) then 'INVESTIGATOR_REJECTED'
 when g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
 then 'TEST_100KM_NORTHING_SHIFT'
 when g.capture_id in (16861,17477) then 'LEG_OF_MUTTON_GRID_ANOMALY'
 else 'IRREGULAR_OR_REMOTE_GRID'
end as proposed_review_group,
case when g.decision_status='WITHHELD' and g.capture_id not in (12072,17254)
 and g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
then g.source_easting else null::numeric end as test_easting,
case when g.decision_status='WITHHELD' and g.capture_id not in (12072,17254)
 and g.source_northing between 290000 and 300000 and g.source_easting between 370000 and 390000
then g.source_northing - 100000 else null::numeric end as test_northing,
'REVIEW-ONLY: test coordinates NOT written to accepted encounter XY. Source map/grid-square identity and text must be checked before scientific acceptance.'::text as test_warning,
g.decision_note,g.map_review_note
from research.capture_grid_coordinate_decisions g
join analysis.encounters_clean_v1 e using(capture_id)
join research.captures c using(capture_id)
where g.decision_status='WITHHELD';
comment on view analysis.grid_withheld_candidate_review_v1 is
'ALL withheld historical grid sites, plus 30 test-only minus-100km northing candidates. No accepted locations assigned. Two researcher-rejected sites have no proposed replacement. Coordinates may be grid-square corners rather than actual observation positions.';
grant select on analysis.grid_withheld_candidate_review_v1 to badger_readonly,badger_research_readonly;
