-- Working Version 1: link the definitive source coordinates to unambiguous canonical setts.
-- Matching: punctuation-insensitive exact canonical name, plus four previously recorded coordinate aliases.
-- All unmatched coordinate-source rows are retained in research.sett_coordinate_source_20261023.
with matches as (
 select src.*,s.sett_id
 from research.sett_coordinate_source_20261023 src
 join research.setts s on regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g') = regexp_replace(upper(s.sett_name),'[^A-Z0-9]','','g')
 union all
 select src.*,s.sett_id
 from research.sett_coordinate_source_20261023 src
 join research.setts s on
     (src.source_name='CLIFF.FACE' and s.sett_name='CLIFF')
  or (src.source_name='GULLY' and s.sett_name='GULLEY')
  or (src.source_name='STONEY.TRACK' and s.sett_name='STONY TRACK')
  or (src.source_name='ELEVEN.ROW' and s.sett_name='ELEVENTH ROW')
),
unique_matches as (
 select m.* from matches m
 where (select count(*) from matches d where d.source_name=m.source_name)=1
   and (select count(*) from matches d where d.sett_id=m.sett_id)=1
)
insert into research.sett_location_evidence
(sett_id,easting,northing,coordinate_system,evidence_type,source_reference,review_status,reviewed_by,reviewed_at,notes)
select m.sett_id,m.easting,m.northing,'EPSG:27700','OTHER',
       'WoodchesterSettLocations (1).csv; source Sett_Upper='||m.source_name,
       'APPROVED','Dave Hudson',now(),
       'Coordinate from supplied definitive sett source; display SETT='||m.source_display_name
from unique_matches m
where not exists(select 1 from research.sett_location_evidence e where e.sett_id=m.sett_id and e.review_status='APPROVED');

create or replace view analysis.sett_coordinate_source_name_review as
with matches as (
select src.source_name,s.sett_id from research.sett_coordinate_source_20261023 src
join research.setts s on regexp_replace(upper(src.source_name),'[^A-Z0-9]','','g')=regexp_replace(upper(s.sett_name),'[^A-Z0-9]','','g')
union all
select src.source_name,s.sett_id from research.sett_coordinate_source_20261023 src join research.setts s on
(src.source_name='CLIFF.FACE' and s.sett_name='CLIFF') or
(src.source_name='GULLY' and s.sett_name='GULLEY') or
(src.source_name='STONEY.TRACK' and s.sett_name='STONY TRACK') or
(src.source_name='ELEVEN.ROW' and s.sett_name='ELEVENTH ROW')
)
select src.source_name,src.source_display_name,src.easting,src.northing,
s.sett_name as matched_canonical_sett,
case when s.sett_id is null then 'REVIEW_NAME' else 'LINKED' end as match_status
from research.sett_coordinate_source_20261023 src
left join matches m on m.source_name=src.source_name
left join research.setts s on s.sett_id=m.sett_id;
grant select on analysis.sett_coordinate_source_name_review to badger_readonly,badger_research_readonly;
comment on view analysis.sett_coordinate_source_name_review is 'Definitive uploaded coordinate file compared against canonical sett names; unresolved source names remain visible with original easting/northing.';
