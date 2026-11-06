do $$
begin
 if (select count(*) from research.capture_grid_coordinate_decisions where decision_status='CORRECTED' and capture_id in (12072,17254))<>2 then
   raise exception 'Precondition failed: two corrections not found';
 end if;
end $$;
update research.capture_grid_coordinate_decisions
set corrected_easting=null,corrected_northing=null,decision_status='WITHHELD',
 decision_note='Investigator rejected provisional location on interactive map 2026-11-05. ST900022 was interpreted as SO E390000 N202200 but inconsistent with original Stanley Wood roadside verge opposite glider field gate. Neither grid-square interpretation accepted pending field/map evidence. Original RTA PM/death retained.',
 decision_source='Researcher map review 2026-11-05; original Access row 15375'
where capture_id=17254;
update research.capture_grid_coordinate_decisions
set corrected_easting=null,corrected_northing=null,decision_status='WITHHELD',
 decision_note='Investigator rejected distant grid point during interactive-map review 2026-11-05. Source SU062988-NOT TRUE MOVE is a historical annotation, not a confirmed death location or long-distance movement. Do not replace with earlier Beech/Mansion sett. Original PM death/cause KILLED retained; source Access row 8144.',
 decision_source='Researcher map review 2026-11-05; original Access row 8144'
where capture_id=12072;
insert into research.wecs_review_flags(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values
('SPATIAL-UN260-17254','GRID_LOCATION_REJECTED',array[17254]::bigint[],'UN260','Provisional position rejected for RTA recovery at Stanley Wood near glider field gate.','Source ST900022; original E390000 N102200, earlier SO reinterpretation E390000 N202200; both unverified against locality. Original Access PM RTA 2002-03-14.','XY withheld pending original source/map confirmation. Death outcome remains recorded.','NEEDS_SOURCE_CHECK'),
('SPATIAL-F030-12072','GRID_LOCATION_REJECTED',array[12072]::bigint[],'F030','Provisional SU reference rejected as verified death/movement coordinate.','Original SU062988-NOT TRUE MOVE, 1988-04-06 PM FOUND DEAD with cause KILLED; prior Beech/Mansion captures and Uley removal entry; original Access row 8144.','XY withheld. Literal SU grid should not be used to infer distant movement; preserve death pending historical map clarification.','NEEDS_SOURCE_CHECK')
on conflict(flag_id) do nothing;
update research.wecs_review_flags
set summary='Grid-reference audit: 57 corrected provisional, 40 withheld after map review.',
evidence='Original 59 corrected/38 withheld; researcher visually rejected 17254 UN260 and 12072 F030 on 2026-11-05. Both have retained original grid strings and PM deaths.',
current_interpretation='57 provisionally mapped grid points; 40 withheld. Review original field evidence before replacing either rejected point.',
updated_at=now()
where flag_id='SPATIAL-GRID';