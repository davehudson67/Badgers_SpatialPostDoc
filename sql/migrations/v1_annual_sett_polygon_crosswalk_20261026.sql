-- Generated V1 annual fixed-sett point x historical annual polygon crosswalk.
-- Geometry calculation occurs in scripts/Spatial/10_build_V1_annual_sett_polygon_membership.R
-- Polygon matches are spatial evidence, not definitive SG residency.
create table if not exists research.sett_annual_territory_matches(
 match_id bigint generated always as identity primary key,
 year integer not null check(year between 1977 and 2025),
 sett_id bigint not null references research.setts(sett_id),
 polygon_id text,
 territory_name text,
 match_status text not null check(match_status in ('ONE_POLYGON','MULTIPLE_POLYGONS','OUTSIDE_ALL','NO_COORDINATE','ON_BOUNDARY')),
 polygon_source text not null,
 coordinate_source text,
 created_at timestamptz not null default now(),
 constraint status_polygon_consistency check (
  (polygon_id is null and match_status in ('OUTSIDE_ALL','NO_COORDINATE')) or
  (polygon_id is not null and match_status in ('ONE_POLYGON','MULTIPLE_POLYGONS','ON_BOUNDARY'))
 )
);
create unique index if not exists sett_annual_territory_matches_year_sett_polygon_uq
 on research.sett_annual_territory_matches(year,sett_id,polygon_id) nulls not distinct;
comment on table research.sett_annual_territory_matches is 'Spatial sett-point x annual territory polygons for 1977–2025, not verified social-group residence. One row per polygon intersection including overlaps and boundary cases; null polygon for unmatched or unmapped sett-years.';
