-- Five original Access PM references manually reviewed against nearby Woodchester-area recovery descriptions.
-- Provisional SO-square readings; never exact GIS points; original strings remain unchanged.
do $$
declare actual int;
begin
select count(*) into actual from research.captures c join analysis.encounters_clean_v1 e using(capture_id)
join (values
(16859,'83188,00086'),
(16967,'S0826024'),
(16997,'OS822024'),
(17043,'82774 00203'),
(17500,'81500050')
) v(capture_id,os_ref) on c.capture_id=v.capture_id and c.os_ref=v.os_ref
where c.is_pm and e.location_easting is null and e.location_northing is null;
if actual <> 5 then raise exception 'Expected five exact source PM records with missing XY, got %',actual;end if;
end $$;
insert into research.capture_grid_coordinate_decisions
(capture_id,original_grid_reference,source_easting,source_northing,corrected_easting,corrected_northing,decision_status,decision_note,decision_source)
values
(16859,'83188,00086',null,null,383188,200086,'CORRECTED',
'Numeric 5+5 OS reference 83188 00086; assumed SO square because original recovery says RTA WOOD FARM. Six-figure precision NOT assumed: 10 digits give nominal 1m grid cell but source accuracy unverified. Original comma retained. Provisional until map confirmation.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(16967,'S0826024',null,null,382600,202400,'CORRECTED',
'Source S0 prefix contains digit zero where SO has letter O. Provisional SO826024 (100m grid square) supported by Selsley Common / Boundary Court Farm roadside description. Original source string retained.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(16997,'OS822024',null,null,382200,202400,'CORRECTED',
'Source OS822024 appears to use OS shorthand instead of explicit SO prefix. Infer SO822024 (100m grid square) from original Pen Wood / B4066 before cattle grid description. Prefix inference NOT independently verified.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(17043,'82774 00203',null,null,382774,200203,'CORRECTED',
'Original five+five digit numeric grid reference, no letter prefix. Provisional SO82774 00203 from Tinkley Lane (original source spells Line), Nailsworth–Nympsfield area; nominal 1m grid-square width does NOT mean observed metre accuracy.',
'WECS 2026-11-04 Access malformed-grid salvage'),
(17500,'81500050',null,null,381500,200500,'CORRECTED',
'Eight numeric digits interpreted as 8150 0050 (10m square) with assumed SO prefix from Tinkley Lane recovery text. Source numeric splitting/prefix still provisional; neither 10m positioning accuracy nor exact death site verified.',
'WECS 2026-11-04 Access malformed-grid salvage')
on conflict(capture_id) do nothing;

update research.wecs_review_flags set
summary='OS grid QA: 59 provisional corrections, 38 withheld points; malformed source strings are separately audited.',
evidence='Original SO/ST and implicit prefix issues: 54 earlier verified provisional corrections plus 5 new manually reconstructed original Access PM refs (16859,16967,16997,17043,17500). Original source strings retained; 38 geographically ambiguous grid points remain withheld. 100m grid-square logic verified for six-digit references.',
current_interpretation='59 provisional corrected grid positions are usable with strong quality caveats and original provenance; five new source strings require map/source confirmation before precision-sensitive use. 38 withheld points remain without clean XY. No recorded fatal event was excluded.',
updated_at=now()
where flag_id='SPATIAL-GRID';

-- A narrow review view for outstanding missing-coordinate categories, preserving mortality and note context.
create or replace view analysis.spatial_missing_review_v1 with (security_invoker=false) as
select e.capture_id,e.tattoo,e.capture_date,e.is_pm,e.encounter_type,e.outcome,
e.sett_id,ss.sett_name as canonical_sett_name,c.recorded_sett_name,
c.capture_location_text,c.os_ref,c.moc as original_moc,c.comment,c.pm_cause,
e.episode_record_role,e.location_type,e.location_quality,
case
when e.episode_record_role='PM_COMPANION' then 'PM_COMPANION_NO_INDEPENDENT_POINT'
when e.location_quality='SETT_COORDINATE_CONFLICT' then 'ASSOCIATED_SETT_NOT_ACTUAL_SITE'
when e.location_quality='GRID_REFERENCE_AMBIGUOUS_WITHHELD' then 'ORIGINAL_GRID_VERIFY'
when e.sett_id is not null and ss.easting is null then 'SETT_XY_FIELD_TEAM'
when e.is_pm then 'MORTALITY_RECOVERY_LOCATION'
when nullif(btrim(coalesce(c.recorded_sett_name,'')),'') is not null then 'NAMED_NON_SETT_SITE'
else 'SOURCE_LOCATION_UNSPECIFIED'
end as spatial_review_priority
from analysis.encounters_clean_v1 e
join research.captures c using(capture_id)
left join research.setts ss on ss.sett_id=e.sett_id
where e.location_easting is null or e.location_northing is null;
comment on view analysis.spatial_missing_review_v1 is 'Current WECS missing XY audit queue by explanatory cause, not all missing points are errors. Outcomes including death are preserved. Sett association is not physical encounter location; no automatic imputation.';
grant select on analysis.spatial_missing_review_v1 to badger_readonly,badger_research_readonly;
