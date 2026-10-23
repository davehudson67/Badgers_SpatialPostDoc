# Woodchester V10a: annual-primary robust-design SCR with multiple locations

## Design retained

The field design is represented as:

- primary period: calendar year;
- secondary occasions: four quarterly trapping campaigns (Q1-Q4);
- a quarterly campaign may contain more than one capture of the same badger;
- individual trapping nights within a quarterly campaign are not reconstructed,
  because the historical detector-by-night effort matrix is incomplete.

This preserves the established robust-design hierarchy rather than redefining
quarters as primary periods.

## Why V10a differs from V8/V9

V8/V9 use one annual activity centre and collapse each badger/year/quarter to one
selected spatial capture location.

Audits showed that, in the 1,932-badger maximal movement population:

- 14,049 spatially usable live capture events occur;
- 12,907 badger-quarters contain at least one usable live capture;
- 1,076 badger-quarters contain >1 live capture;
- 443 contain >1 recognised sett;
- a badger has at most 3 usable captures in a quarter.

V10a retains all genuine spatial capture locations.

## Hierarchical spatial states

For badger i in year y, let

    A[i,y] = annual activity centre / annual spatial anchor.

This is the primary-period spatial state and is the state that undergoes the
between-year movement process.

For secondary quarter q in year y, let

    S[i,y,q] = quarter-specific centre of spatial use.

The quarterly centre is modelled around the annual centre:

    S[i,y,q] | A[i,y], omega
      ~ Normal_2(A[i,y], omega^2 I).

omega is the within-year / among-quarter spatial-use scale.

This does not assert that the badger "moves to a new territory" every quarter.
If omega is small, quarterly centres remain tightly clustered around the annual
centre. The posterior distribution of distances

    ||S[i,y,q] - S[i,y,q-1]||

quantifies how much secondary-period spatial use shifts within years.

This is an extension of strict spatial closure within the annual primary period:
demographic robust-design structure is retained, while spatial use is allowed to
vary among secondary trapping campaigns.

## Multiple-location observation likelihood

Let C[i,y,q] indicate whether the badger was captured at least once during the
quarterly trapping campaign.

Let n[i,y,q] be the observed number of usable spatial captures (0-3 in the current
snapshot), and let h[i,y,q,m] be the detector/sett for observed capture m.

For the quarter-specific centre S[i,y,q], define the usual SCR kernel

    g[i,y,q,r] =
      exp(-d(S[i,y,q], X[r])^2 / (2*sigma_i^2)),

and

    G[i,y,q] = sum_r g[i,y,q,r].

The quarterly probability of at least one capture follows the existing hazard
formulation

    Pcap[i,y,q] =
      1 - exp(-lambda0[i,y,q] * G[i,y,q]).

For a non-capture quarter:

    L_obs = 1 - Pcap.

For a captured quarter with n observed capture locations, V10a conditions on the
observed number of within-campaign captures and retains every location:

    L_obs =
      Pcap
      * product_{m=1}^{n}
          g[h_m] / G.

Thus a quarter A,A,B contributes

    Pcap * pi_A * pi_A * pi_B,

not just A or B.

The model does NOT treat A,A,B as three complete surveys of the study area.
There is one quarterly capture/non-capture term (Pcap) and multiple conditional
spatial-location terms.

This is deliberate because full detector-by-night effort is unavailable.

## Detection parameters

Initial V10a retains the established structure:

    logit-scale baseline detection:
      alpha_p + beta_p_sex * sex
      + seasonal effect
      + five-year period effect;

    individual detection-space scale:
      log sigma_i =
        alpha_logsigma + beta_sigma_sex * sex_i.

sigma_i controls how capture probability declines with distance from the
quarter-specific centre S, not from the annual anchor A.

## Annual movement process

Annual activity centres retain the established two-state movement process.

For y > first observed live year:

    A[i,y] = A[i,y-1] + epsilon[i,y],

    epsilon[i,y]
      ~ Normal_2(0, sigma_move[i,y]^2 I).

Movement state:

    z[i,y] = 0 : local/stable annual movement;
    z[i,y] = 1 : high-mobility/relocation annual movement.

Movement scale:

    log sigma_move[i,y] =
        alpha_logmove
      + beta_move_sex * sex_i
      + beta_move_high * z[i,y],

with beta_move_high > 0.

The state process retains the V8 structure:

    P(z_y=1 | z_{y-1}=0) = p_RD,
    P(z_y=1 | z_{y-1}=1) = p_DD,

with sex effects and an adult-entry effect on the initial interval.

## What is now separately estimable

V10a has three spatial scales with different biological/statistical roles:

1. sigma_i:
   detector/capture-location decay around a quarter-specific centre;

2. omega:
   variation in quarter-specific centres around the annual activity centre;

3. sigma_move:
   movement of the annual activity centre between years.

The repeated within-quarter capture histories are particularly important for
separating sigma_i from omega.

## Missing quarters and years

Within a year, all four quarter-specific centres S[i,y,q] exist while that animal
is inside its first-to-last observed annual history, even if a particular quarter
has no capture.

An uncaptured quarter contributes its quarterly non-capture likelihood and its
S[i,y,q] remains latent around A[i,y].

Internal years with no capture retain a latent annual A[i,y] through the annual
movement process. Their four S states are also latent.

No states are inferred before the first observed live year or after the last
observed live year in V10a; survival/emigration remains conditioned out.

## Model-building sequence

V10a-0 (smoke / identifiability model):
- annual A;
- quarterly S around A;
- all multiple spatial capture locations;
- two-state annual movement;
- sex effects;
- habitat constraints;
- no social-group/peripheral resistance.

Only after V10a-0 is stable:

V10a-1:
- add the established landscape/peripheral component if still supported;

V10a-2:
- replace static social-group resistance with time-varying historical territory
  information derived from bait-marking maps;

Disease modules:
- use posterior annual movement states and, separately, derived within-year
  quarterly shifts.

## Primary model diagnostics

Before production fitting, verify:

- posterior separation of sigma_detection, omega_within_year and sigma_move;
- within-quarter/multiple-location posterior predictive fit;
- distribution of quarter-to-quarter centre shifts;
- annual movement-state convergence and occupancy;
- sensitivity to counting repeat same-sett captures once vs multiple times;
- comparison with V8/V9 annual-AC results;
- sensitivity to years with long internal gaps.

## Interpretation

V10a should be described as:

"an open robust-design spatial capture-recapture movement model with annual primary
periods, four quarterly secondary trapping campaigns, and quarter-specific spatial
random effects around annual activity centres."

It is not a strict spatial-closure RD-SCR because spatial use is allowed to vary
among secondary occasions, but the primary/secondary field-design hierarchy is
retained.
