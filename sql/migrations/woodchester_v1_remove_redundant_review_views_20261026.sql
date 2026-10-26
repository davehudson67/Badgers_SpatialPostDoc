-- Non-destructive V1 coauthor cleanup: remove redundant stand-alone diagnostic/review views.
-- Source data, stable V1 interfaces and their dependency views are retained.
drop view if exists analysis.location_review_767_v1;
drop view if exists analysis.historical_sett_candidates;
drop view if exists analysis.sett_field_team_review;
drop view if exists analysis.unmatched_capture_sett_review;
drop view if exists analysis.unmatched_coordinate_sett_candidates;
drop view if exists analysis.unresolved_recorded_sett_names;
drop view if exists analysis.capture_location_classified;
comment on schema analysis is 'Woodchester analysis layer: V1 researcher-facing views and core diagnostic analysis; no temporary 767-record location review tables are retained.';
