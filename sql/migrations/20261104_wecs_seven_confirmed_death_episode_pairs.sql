-- Seven additional same-death primary/PM pairs confirmed against both canonical and original Access evidence.
-- Both source rows remain; one death event per linked episode.
do $$
declare n int;
begin
 select count(*) into n
 from (values (16891,17441,'EUTHANISED'),(8377,17427,'EUTHANISED'),(11061,17510,'EUTHANISED'),
 (3966,16832,'DIED_AFTER_CAPTURE'),(16884,16883,'EUTHANISED'),(16816,16815,'EUTHANISED'),
 (17183,17058,'EUTHANISED')) pairs(live_id,pm_id,fate)
 join research.captures a on a.capture_id=pairs.live_id
 join research.captures b on b.capture_id=pairs.pm_id
 where a.individual_id=b.individual_id and a.is_pm=false and b.is_pm=true
 and a.weight=b.weight and b.capture_date between a.capture_date and (a.capture_date+1);
 if n<>7 then raise exception 'Seven-pair same-event source check failed; got %',n;end if;
 if exists (select 1 from research.encounter_pair_nonlinks n
 join (values (16891,17441),(8377,17427),(11061,17510),(3966,16832),
              (16884,16883),(16816,16815),(17183,17058)) p(a,b)
  on (n.first_capture_id=p.a and n.second_capture_id=p.b)
  or (n.first_capture_id=p.b and n.second_capture_id=p.a))
 then raise exception 'Explicit nonlink prohibits proposed join';end if;
end $$;
insert into research.encounter_episode_decisions
(live_capture_id,pm_capture_id,episode_outcome,decision_status,field_location_basis,decision_note,review_flags,decision_source)
values
(16891,17441,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'001R: same tattoo 2004-03-15 FOUND EXT live euthanised at B4066 Buckholt Lodge gate; same-day PM says EUTHANASIA, both weigh 8.9kg. One death. PM independent SO795015 grid reference remains accessible in source; live event coordinates unresolved.',
array['PM_HAS_INDEPENDENT_GRID','FIELD_POINT_UNRESOLVED']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(8377,17427,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'017R: 2009-11-04 TRAP at LARCH and euthanised on welfare grounds, PM dated 2009-11-05 confirms euthanasia and same 5.9kg weight; one death. PM grid SO800285 is separately withheld as spatially inconsistent; retain supported LARCH sett-proxy for live trapping.',
array['NEXT_DAY_PM_DATE','PM_OS_GRID_WITHHELD']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(11061,17510,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'045W: 2005-07-29 FOUND EXT at PEGLARS, severe maggot-infested bite wound, animal euthanised; same-day PM repeats exact narrative and 2.3kg; one death.',
array[]::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(3966,16832,'DIED_AFTER_CAPTURE','CONFIRMED','LIVE_RECORD',
'D007: 1999-08-02 FOUND EXT by farmer at Coaley Peak, died under anaesthetic. The original primary comment explicitly says PM was same day but was entered as 1999-08-03 because historic Access could not store capture and PM on same date. Same tattoo and 3.9kg; one death. PM grid 715015 without prefix remains separately provisional.',
array['PM_DATE_ARTIFICIALLY_PLUS_ONE_DAY','CAUSE_DIED_UNDER_ANAESTHETIC','PM_GRID_PREFIX_UNVERIFIED']::text[],
'WECS original primary comment explicitly links PM; 2026-11-04'),
(16884,16883,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'I022: 2004-05-12 found in extremis below Wych Elm, euthanised using Dolethal. Same-day PM repeats case with identical 3.8kg; one death. Original PM ST grid has separate audited provisional interpretation.',
array['PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(16816,16815,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'M012: 2001-04-01 field note explicitly EUTHANASED SEE PM FORM; same-day PM documents convulsions/euthanasia, identical 6.9kg. One event. PM ST grid handled by separate spatial audit.',
array['PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04'),
(17183,17058,'EUTHANISED','CONFIRMED','LIVE_RECORD',
'Q070: 2001-10-24 found alive at Tinkley Lane opposite Wood Farm, euthanised after sampling. Same-day RTA PM says still alive when found, euthanased, same 10.1kg. One euthanasia; RTA is suspected injury mechanism not another separate death.',
array['RTA_ASSOCIATED','PM_GRID_PREFIX_CORRECTED_PROVISIONAL']::text[],
'WECS original Access + canonical capture/PM audit 2026-11-04')
on conflict(live_capture_id) do nothing;

update research.encounter_classification_decisions set
outcome='DIED',
decision_note='D007 PM companion to primary 3966 (same encounter; historical PM date shifted one day as explicitly documented). Original primary record says died under anaesthetic. Single DIED episode; PM method originally blank and remains UNKNOWN. PM grid point distinct from last sett.',
decision_source='WECS confirmed source-described D007 pair 2026-11-04',
decided_at=now()
where capture_id=16832;

insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status,final_decision,final_decision_at)
values(
'DEATH-SEVEN-FURTHER-PAIRS','DUPLICATE_EPISODE',
array[16891,17441,8377,17427,11061,17510,3966,16832,16884,16883,16816,16815,17183,17058]::bigint[],
null,'Seven additional duplicate death-row pairs are one field-handling/PM episode each.',
'Pairs independently checked via same tattoo, date (or 1 day), same weight, and matching explicit euthanasia/died narratives. D007 primary expressly explains historical PM one-day date shift.',
'Seven more confirmed pairs, adding to previous 10; one death per episode and both historical source rows retained.',
'RESOLVED',
'Link seven exact pairs in research.encounter_episode_decisions. Six EUTHANISED and D007 DIED_AFTER_CAPTURE; PM companion not an independent mortality event. Date and spatial provenance preserved.',now())
on conflict(flag_id) do nothing;
