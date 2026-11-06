-- Woodchester V1.2: source-supported reversal of inferred sett assignment
-- Scientific decision: Dave Hudson, 2026-10-23.
-- Source records: tblCaptures PM=Yes, original sett NULL; group text preserved.
-- Capture IDs verified against canonical tattoo,date,PM flag.
begin;
do $$
declare n integer;
begin
select count(*) into n from research.captures c
join research.individuals i on i.individual_id=c.individual_id
where (c.capture_id=17583 and i.tattoo='015S' and c.capture_date='2021-09-02' and c.is_pm)
or (c.capture_id=17584 and i.tattoo='053M' and c.capture_date='2021-09-02' and c.is_pm)
or (c.capture_id=17548 and i.tattoo='026H' and c.capture_date='2021-09-29' and c.is_pm);
if n<>3 then raise exception 'Expected exactly 3 checked PM records; got %',n; end if;
end $$;
update research.captures
set sett_id=null,
location_cleaning_note='V1.2 Dave Hudson: reverted inferred physical sett on PM BCP record. Original Access sett blank; CHESTNUT/HOLLOW TREE present only in recorded socg. Do not infer PM site or resident group.'
where capture_id in (17583,17584,17548)
and is_pm is true and recorded_sett_name is null
and location_cleaning_note='Original sett blank; value recorded in socg was not a valid social group but matched a known sett and was used as cleaned sett';
do $$
declare n integer;
begin
select count(*) into n from research.captures where capture_id in (17583,17584,17548) and sett_id is null and location_cleaning_note like 'V1.2 Dave Hudson:%';
if n<>3 then raise exception 'V1.2 migration did not update all three records; got %',n;end if;
end $$;
commit;