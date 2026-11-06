do $$
begin
 if not exists (
 select 1 from research.capture_grid_coordinate_decisions g
 join research.captures c using(capture_id)
 where g.capture_id=17285 and g.original_grid_reference='014795'
 and g.decision_status='WITHHELD'
 and c.moc='RTA'
 and c.capture_location_text ilike '%west gate%'
 ) then raise exception 'UN221 original source not as expected: abort'; end if;
end $$;
update research.capture_grid_coordinate_decisions
set corrected_easting=379500,
corrected_northing=201400,
decision_status='CORRECTED',
map_review_status='PENDING_REVIEW',
map_review_note='Source cross-check with user-provided Woodchester Park west-gate latitude 51.711125 longitude -2.298038, transforms to BNG approximately E379504 N201419; independent listed historic gateway SO795014 (E379539 N201433). This establishes likely transposition of original six-digit reference 014795 to 795014. Geographically corroborated but exact RTA site within road corner not surveyed.',
decision_note='Original PM RTA source OS 014795 had three-digit easting/northing halves reversed. Location text explicitly corner of Woodchester Park west gate on Uley-Stroud road. Reconstructed SO795014, BNG E379500,N201400, representing a 100m OS grid square, with independent historic listed gateway at SO795014 and investigator WGS84 position within same grid cell. Original 014795 and prior parser E301400,N279500 preserved. Do not claim exact carcass point.',
decision_source='WECS original Access text + investigator map position 2026-11-05 + historic west gateway independently listed SO795014'
where capture_id=17285;

insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at)
values('SPATIAL-UN221-WEST-GATE','OS_GRID_HALVES_TRANSPOSED',array[17285]::bigint[],'UN221',
'West gate RTA original six-figure grid reference had reversed digit halves.',
'Capture 17285 2000-02-18 RTA, source 014795, recorded Woodchester Park west gate on Uley-Stroud road. Investigator location 51.711125,-2.298038 is BNG E379504,N201419; independently listed west gateway SO795014 E379539,N201433.',
'Reconstructed six-digit OS reference 795014. BNG grid-square SW corner E379500,N201400 is accepted as historically supported approximate recovery locality; not an exact carcass measurement.',
'RESOLVED',
'Original 014795 preserved; accepted corrected 100 m grid square SO795014 E379500,N201400 for spatial use with provisional quality. Mortality event unchanged.',now())
on conflict(flag_id) do nothing;

update research.wecs_review_flags
set summary='Grid QA: 88 corrected grid points, nine withheld, including two user-rejected.',
current_interpretation='87 earlier visually approved provisional grids plus UN221 west-gate six-figure transposition corroborated independently with user and listed gateway; now 88 corrected and 9 withheld. UN260 and F030 remain rejected. No mortality changes.',
updated_at=now()
where flag_id='SPATIAL-GRID';
