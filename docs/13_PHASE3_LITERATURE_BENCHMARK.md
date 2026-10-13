# Phase 3 literature benchmark and social-group definition

## Purpose

Use the three Woodchester papers supplied by the project owner as explicit
benchmarks, rather than treating Phase 3 as a literature-free new analysis:

- Rogers et al. (1998), *Movement of badgers in a high-density population*.
- Vicente et al. (2007), *Social organization and movement influence the
  incidence of bovine tuberculosis...*.
- Furber et al. (2025), *Data-driven analysis of fine-scale badger movement in
  the UK*.

The immediate purpose is to define social-group membership in a way that is
consistent with historical Woodchester analyses. The later purpose is to
reproduce/audit the older findings under their original definitions, then ask
what changes when we use the richer V9 movement and infection posterior
histories.

## Social-group assignment

### Territory delineation

Historical Woodchester social-group territories were established annually by
field methods, especially spring bait-marking. Vicente et al. describe
different marked bait at main setts and assignment of boundary latrines from
pellet mixtures, with annual territories digitised in GIS. Furber et al. also
treat bait-marking as the Woodchester field reference for social groups.

Therefore:

1. Annual field-defined SOCG is the preferred epidemiological grouping.
2. If annual bait-marking polygons/layers can be recovered, preserve them as a
   separate dynamic territory product.
3. The static V9 SG raster is not a substitute for annual territory
   delineation. It was already used as a movement-resistance surface.
4. Posterior activity centres S are used for connectivity, spatial uncertainty,
   and consistency checking, not to overwrite field SOCG membership.

### Annual individual membership

Rogers et al. assigned annual group membership to the group in which the
badger appeared most often across captures that year, with a first-capture
rule for the simple two-capture/two-group tie.

Vicente et al. formalised the annual assignment hierarchy:

1. group in which the badger was most frequently caught in that year;
2. use allocation(s) in adjacent years;
3. use capture frequency across current and both adjacent years;
4. use the nearest relevant capture immediately before/after the year;
5. use the first relevant capture if still indeterminate.

They report that more than 96% were assigned by criterion 1.

Phase-3 code should retain:
- the final annual resident group;
- the criterion used;
- all raw within-year group captures;
- whether multiple groups were observed in the year.

This preserves temporary excursions rather than converting every observed
group visit into a change of residence.

## Published findings to reproduce/audit

### Rogers et al. 1998 — 1978–1995

Benchmark:
- males moved between groups more often than females;
- previous movement strongly predicted subsequent movement;
- movement probability varied with age, body weight, group size and group;
- most inter-group movements were short and between neighbouring groups;
- permanent group changes were uncommon relative to temporary/occasional
  movements;
- individual infection status did not predict movement;
- years with more inter-group movement were followed by higher TB incidence.

Important comparison with V9:
- V9 strongly supports greater male initiation of high mobility;
- V7a similarly finds little evidence that infection triggers high mobility;
- V9 chronological-age sensitivity suggests declining initiation of high
  mobility with age, unlike the older capture-to-capture inter-group movement
  result. These are not equivalent movement definitions and should be
  investigated explicitly.
- V7b does not show a clear positive effect of latent high mobility on the
  mover's own later infection. This differs from the older population-level
  movement/TB association and motivates separating source mobility from
  recipient mobility.

### Vicente et al. 2007 — 1990–2004

Benchmark:
- existing group TB prevalence was a major predictor of individual/group
  incidence;
- declining group size was associated with greater incidence;
- individual movement within the core and previous group movement were
  associated with later individual incidence;
- movements into groups from other core groups predicted group incidence more
  clearly than movements from outside;
- group size itself was not a strong predictor;
- sex ratio modified some movement/incidence relationships.

Important comparison with current Phase 2:
- our same-group infection-pressure effect agrees strongly with the published
  local-prevalence result;
- our annual turnover and group-size decline effects are weak, unlike the
  published decline result;
- our latent high-mobility effect on acquisition is weak, unlike their
  observed inter-group movement association.

These differences are scientifically useful, but they must first be checked
under matched definitions.

## Required replication bridge before the new Phase-3 model

Do not compare coefficients from unlike constructs.

Build one historical benchmark panel that reproduces, as closely as possible:

1. published annual resident-group allocation;
2. observed inter-group movement from recorded group changes;
3. Rogers-style annual movement rate;
4. Vicente-style group movement index and core-immigrant counts;
5. MNA group size and annual group-size trend;
6. culture-positive/excretor incidence, because Vicente's endpoint was
   culture-detected excretion rather than the current all-tests latent infection
   trajectory.

Run the benchmark on the original paper windows first (1978–1995 and
1990–2004), then extend the same definitions through 2025. This separates:
- true temporal change;
- different disease definitions;
- different movement definitions;
- different social-group assignment rules.

## 2018 temporal question

Furber et al. identify 2018 as the start of badger culling on farmland
surrounding the National Trust core of Woodchester and explicitly note that
social structure could change from 2018 onwards.

Use 2018 as a prespecified descriptive/era breakpoint, not automatically as a
causal intervention effect.

First describe annual changes in:
- number and size of social groups;
- annual membership ambiguity and group switching;
- observed inter-group movement;
- V9 spatial/high-mobility connectivity;
- TB incidence/prevalence.

Then test whether the relationship between:
- within-group infection pressure, and
- external infected-source connectivity

differs before versus from 2018 onward.

## Novel Phase-3 question after benchmark replication

The central new model remains:

future group infection
  ~ within-group infection pressure
  + external infected-source connectivity
  + group structure
  + time/era.

This distinguishes local amplification from movement-mediated importation.

Only if external infected-source connectivity is supported should source
strength be refined to culture excretor / revised super-excretor status.
