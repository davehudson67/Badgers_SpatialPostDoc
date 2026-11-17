# Woodchester Badger Modelling: Plain-Language Overview

**Updated: 17 November 2026**

This is a short orientation guide for the modelling programme. It is deliberately **not** a second evidence record: the [Modelling Development Roadmap](WOODCHESTER_MODEL_DEVELOPMENT_ROADMAP.md) remains the authoritative source for dated decisions, model specifications, data rules, commands, checks and numerical results. When a detail matters, use the roadmap and the versioned run outputs.

## What are we trying to learn?

A badger may be caught, missed, alive but outside the monitored area, dead, or no longer present. The monitored footprint has shrunk over time. Detailed trap-by-trap effort records are unavailable; the field assumption is that trapping was saturated **within the area monitored**. Saturation does not mean every badger there was caught.

The joint model aims to estimate annual locations and movement while accounting for imperfect capture, survival, entry and disappearance. It uses a badger’s distance from the assumed detector network to inform the chance of capture. A non-capture therefore contributes evidence only under the stated coverage and detection assumptions.

The central aim is to avoid treating “not seen” as automatically “dead” or “emigrated.” A later capture, a recovery, the animal’s likely location and the changing monitored footprint all help distinguish possible histories. Some distinctions—especially death versus permanent departure—may remain weakly identified.

## How the model work fits together

| Stage | What it does | Current standing |
|---|---|---|
| **V7–V10** | Earlier movement, infection and spatial-capture model development. | Historical; some spatial formulations were superseded. Their evidence and lessons remain in the roadmap. |
| **V11 / V11R2** | Estimates geographic movement centres from capture histories; V11R2 is the current fitted movement reference and includes spatial-resolution sensitivity analyses. | Fitted reference, but its legacy inputs still need reconciliation with curated data. |
| **V12J** | Combines continuous annual movement centres with spatial capture, entry, survival/apparent disappearance and mortality evidence in one likelihood. Hidden alive/dead and movement states are integrated over rather than assigned as known. | Real-data developmental model; full chains did not yield a completed fit. |
| **V12K** | Extends V12J with age and sex effects and a persistent individual movement tendency. It also represents uncertain birth cohorts and age at entry. | Computational development and speed testing; no validated full-data posterior yet. |
| **V13** | Planned disease introduction, infectiousness, transmission and persistence work. | Future programme, dependent on suitable V12 and disease-data validation. |

V12 is therefore an extension of the movement-centre work: it still estimates where individuals are likely to be through time, while using the capture, survival, entry and recovery information to learn those locations and histories jointly. It does not simply take V11 locations as fixed truth.

Core, periphery and outside are summaries placed over the continuous locations. They help describe movement among areas, but do not force badgers to occupy discrete zones. The fixed geographic reference must also be kept separate from the shrinking monitoring footprint: losing coverage is not itself evidence of physical emigration. Predictions beyond monitored areas depend on assumptions about space, movement and entry; they are not direct observations of an external population.

## What data are in the current V12K development run?

The frozen input is based on snapshot `data/model_snapshots/v12_20261110T105256Z_2681271`. The full-cohort development run uses **3,156 observed trapping-cohort badgers plus 200 augmented candidates**, over **49 years**, with **138 detectors**, including **17 detector locations with uncertain XY**. The earlier V12J input audit reported 15,915 trap-capture records, one located non-sett live encounter, 558 candidate recoveries and 157 forced removals. Candidate recoveries remain provisional under the documented mortality screen.

The 200 augmented candidates are a modelling device for animals never observed in the trapping cohort; they are not a known population count. The current likelihood represents the eligible trapping cohort, not every animal known only from opportunistic encounters or mortality records. Those separate ascertainment streams remain held out until their observation processes are represented appropriately. See the roadmap for the exact inclusion rules and mortality treatment.

## What has been checked, and what has not?

The custom likelihood has passed small exact-enumeration and compiled checks. The age/sex/individual extension has also passed computational tests on small fixtures. Sparse capture storage, batched sampler construction and detector-year dependency checks have allowed short runs on the full cohort. Reusing detector-distance calculations reduced sampling time by about 40% in one short timing comparison. A later annual-detector check passed its compiled comparisons and dependency checks.

These are checks that the code runs and that tested calculations agree with their reference calculations. They are **not** evidence of convergence or biological validity. Earlier full-data attempts stalled during setup or compilation, and one early annual-detector implementation stopped at a failed dependency check.

At the last reported check on 17 November, the corrected annual-detector full-cohort run had passed its checks and entered model setup. No later completion, adequate multi-chain fit, convergence result or biological estimate had been reported.

## The next steps

1. Check the annual-detector run’s latest log, exit code, saved output and stage timings.
2. If it completes, compare its cost with the earlier full-cohort timing runs.
3. Use the best verified implementation for an adequately long multi-chain fit.
4. Assess convergence of both shared parameters and individual movement histories, then test posterior predictions and sensitivity to coverage, augmentation, mortality/recovery and birth/entry-age assumptions.
5. Only then decide which survival, entry, movement and core/periphery conclusions the data support.

**In one sentence:** V12K’s full-cohort joint likelihood has passed important computational checks, but its runtime and inferential performance still need to be demonstrated before drawing biological conclusions.
