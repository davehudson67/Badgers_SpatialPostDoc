-- Source-backed identity QA and conservative spatial conflict disposition, 2026-11-04.
update research.wecs_review_flags
set evidence='Access source access_raw.tbl_badger: tattoo 020D sex FEMALE, age_fc CUB, year_fc 2022. Yet access_raw.tbl_captures raw_row_id 1798 assigns 2020-05-18 RTA PM death to 020D. 2022-2024 repeated live trapping is separately recorded. Death cannot be assigned to the 2022 cub if source age/year correct; actual dead individual unverified.',
current_interpretation='Preserve original 2020 RTA PM as genuine evidence, but exclude from terminal death assignment for the 2022-onwards 020D history. Possible tattoo reuse or incorrect historical PM identity; exact correction requires original PM/field record.',
updated_at=now()
where flag_id='DEATH-020D';
update research.wecs_review_flags
set evidence='Original Access rows 14749-14751 all explicitly use U005: live 2003-01-22; PM FOUND DEAD 2003-02-06 at Wood Farm (weight recorded 0); live TRAP 2003-09-02 with body length 82.5cm. No additional tag or PM identification fields confirm identity.',
current_interpretation='Preserve original PM death as recorded; do not treat it as terminal death of the subsequently trapped U005 until original carcass/tattoo evidence clarifies identity. No supported alternative tattoo yet.',
updated_at=now()
where flag_id='DEATH-U005';
update research.wecs_review_flags
set evidence='Source evidence: 107 records have original location context FIELD, WOOD, HEDGE, BOUNDARY, BUILDING, OTHER, OUTSIDE WP or NOT WP with a separate associated sett. Zero have independent os_ref and all 107 have null analysis XY. Includes 54 PM and 53 non-PM records.',
current_interpretation='Spatial absence is an accepted final state. Retain canonical sett ASSOCIATION when documented, but do not turn it into an exact field/road/recovery site coordinate. Keep SETT_COORDINATE_CONFLICT QA label for model selection.',
review_status='RESOLVED',
final_decision='Leave encounter XY null for all 107 records; preserve the associated sett separately. Exact field/recovery positions require independent evidence, not sett-centre imputation. Encounter fate and mortality unchanged.',
final_decision_at=now(),updated_at=now()
where flag_id='SPATIAL-CONFLICT';
update research.wecs_review_flags
set summary='OS grid conversions: 54 provisional corrections, 38 suspect coordinates withheld; six-digit 100m precision now explicit.',
evidence='Original grid parser defaulted to SO; many ST-labeled local Woodchester sites fell 100km south, and unprefixed refs ending 99x fell 100km north. 50 ST local-site interpretations + 4 original embedded ST/SU refs corrected. 38 ambiguous locations withheld. Remaining refs classified by 100m cell precision and recorded/assumed prefix. Original OS strings preserved.',
current_interpretation='Only corrected named-site grid-square proxies and explicitly supported original 100m cells may contribute spatial evidence; quality flags distinguish inferred prefix and source prefix. 38 withheld entries require original map/source confirmation; do not interpret southwest corner as exact death position.',
updated_at=now()
where flag_id='SPATIAL-GRID';
update research.wecs_review_flags
set evidence='Original Access: PM 2000-05-15 at Jacks carcase decomposed, then 2000-05-17 FOUND DEAD and text TOO DECOMPOSED - NOT SENT FOR POST MORTEM. Two records use same tattoo/site but PM flag and wording conflict.',
current_interpretation='Likely one dead badger with two records; first death is candidate event, later entry provisionally withheld as possible duplicate. Original PM flag disagreement requires source clarification.',
updated_at=now()
where flag_id='DEATH-Q082';
insert into research.wecs_review_flags(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values ('SPATIAL-UNNAMED-SETT','MISSING_LOCATION',array[17560,17573,17557,17542,17561,16882]::bigint[],null,
'Six original SETT records with no recorded canonical sett name.',
'Four ordinary live trap records, one RTA PM, and one FOUND EXT euthanasia (024Y field source). Capture histories examined: no defensible same-episode exact sett for most. 024Y PM companion carries a 100m grid reference to a reported discovery site.',
'Leave physical encounter XY unknown absent original field evidence. Preserve separate fate/mortality; 024Y two source rows already confirmed one euthanasia.',
'OPEN')
on conflict(flag_id) do nothing;

create or replace view analysis.mortality_model_candidate_v1 with (security_invoker=false) as
select m.*,
case when m.capture_id in (16968,17328) then 'HOLD_IDENTITY_CONTRADICTION'
when m.capture_id in (4987,7311) then 'HOLD_POSSIBLE_REPEAT_DEATH'
else 'CANDIDATE_TERMINAL_DEATH' end as terminal_model_status,
case when m.capture_id in (16968,17328)
then 'Original Access death entry conflicts with later definite live tattoo history; PM remains in review table pending identification.'
when m.capture_id in (4987,7311)
then 'Additional dead entry at same place after previous death; not treated as independent terminal death pending record review.'
else 'Candidate recorded death event; identity and episode evidence still subject to global survival-history checks.'
end as terminal_model_note
from analysis.mortality_events_review_v1 m;
comment on view analysis.mortality_model_candidate_v1 is 'Candidate survival-model event review with explicit HOLD statuses for two identity-contradictory PM records and two repeat-death candidates. Does not discard records, nor certify all other deaths independently verified. Source mortality retained even when XY null. Not yet final signed-off survival extract.';
grant select on analysis.mortality_model_candidate_v1 to badger_readonly,badger_research_readonly;
