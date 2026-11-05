insert into research.wecs_review_flags
(flag_id,category,capture_ids,tattoo,summary,evidence,current_interpretation,review_status)
values
('SPATIAL-LEG-OF-MUTTON','HISTORICAL_FIELD_LOCATION',
array[8784,8783,16861,17012,17477,17495,17487,17334,16868,17319]::bigint[],null,
'Leg of Mutton is a named field/trapping locality, not a verified canonical sett.',
'1983 historical captures 8784 NET/FIELD LEG OF MUTTON MID and 8783 SNARE/HEDGE LEG OF MUTTON 35; 2019 SHOT (GP) PM records use Leg of Mutton, sometimes "above Peglars". No canonical matching research.setts name. Two PMs 16861 and 17477 both use SO820500 (N250000; inconsistent); other 2019 Leg of Mutton records use SO834020 and SO836003 and are not demonstrably the same exact location.',
'No new sett ID or sett coordinates assigned. Retain the historical field locality, two withheld SHOT PM XY and original death outcomes. If a map names the field or shot locations can be corroborated, correct individual capture XY, not automatically all Leg of Mutton records.',
'NEEDS_SOURCE_CHECK'),
('SPATIAL-COCKADILLY','NAMED_RECOVERY_LOCALITY',
array[18,12,3382]::bigint[],null,
'Cockadilly is a hamlet/RTA recovery locality rather than a confirmed badger sett.',
'No canonical sett named COCKADILLY; many source RTA records describe Cockadilly roads. Original capture 18 grid string 801791 COCKADILLY conflicts with named locality; another source capture 12 has 799002 COCKADILLY. Do not transfer coordinate between different RTA episodes.',
'Preserve capture 18 PM/RTA mortality and recorded Cockadilly place name but withhold XY until original grid can be corroborated. Do not add Cockadilly as canonical sett solely on these records.',
'NEEDS_SOURCE_CHECK')
on conflict (flag_id) do nothing;
