alter table research.capture_grid_coordinate_decisions
add column if not exists map_review_status text not null default 'PENDING_REVIEW';
alter table research.capture_grid_coordinate_decisions
add column if not exists map_review_note text;
alter table research.capture_grid_coordinate_decisions
add column if not exists map_reviewed_at timestamptz;
do $$
begin
 if not exists (select 1 from pg_constraint where conname='wecs_grid_map_review_status_check') then
 alter table research.capture_grid_coordinate_decisions
 add constraint wecs_grid_map_review_status_check
 check (map_review_status in ('PENDING_REVIEW','VISUALLY_VERIFIED','REJECTED_BY_INVESTIGATOR'));
 end if;
 if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED')<>57
 then raise exception 'Expected exactly 57 corrected grid points; inspect before recording review'; end if;
end $$;
update research.capture_grid_coordinate_decisions
set map_review_status='VISUALLY_VERIFIED',
map_review_note='Investigator reviewed interactive Woodchester and overview maps 2026-11-05; accepted geographical plausibility of plotted corrected positions. NOT independent verification of the source grid prefix, cell precision or exact physical carcass position. Preserve source original grid and provisional spatial flag.',
map_reviewed_at=now()
where decision_status='CORRECTED' and map_review_status='PENDING_REVIEW';
update research.capture_grid_coordinate_decisions
set map_review_status='REJECTED_BY_INVESTIGATOR',
map_review_note='Investigator explicitly rejected outlier on interactive overview map 2026-11-05; recovery XY remains withheld and mortality unchanged.',
map_reviewed_at=now()
where capture_id in (17254,12072) and decision_status='WITHHELD';
comment on column research.capture_grid_coordinate_decisions.map_review_status is
'Visual map acceptance only, not independently surveyed location accuracy. VISUALLY_VERIFIED retains provisional grid precision/uncertain prefix. Rejected sites keep NULL analysis coordinates.';
comment on column research.capture_grid_coordinate_decisions.map_review_note is
'Investigator visual map sign-off with scope and limitations, separate from provenance and original source.';
