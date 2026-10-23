# Formal modelling overview, results, inference and model checks

As a brief summary... I started by looking at whether variation in badger movement behaviour helps explain patterns of M. bovis infection and then moved into a broader attempt to understand how movement, social structure and infection interact through time and space. Below details a staged approach: first developing and checking a latent spatial movement model, then testing the two directional hypotheses of infection influencing subsequent movement and movement influencing subsequent infection, before exploring age, within-group infection pressure and social-group instability as potential explanations for those relationships.

The aim throughout has been to propagate uncertainty in both movement state and infection timing, avoid over-interpreting any single reconstructed history and only complicate analyses where there is a clear biological question. The emerging results suggest that individual high mobility may be less important for infection risk than the wider social and epidemiological context, which naturally leads to the next stage of considering infection dynamics at the social-group, temporal and spatial-network levels.


## 1. Latent spatial movement model: (V9)

### Scientific question

For every badger and annual interval, infer whether the animal was undergoing local/stable movement or high mobility, while simultaneously estimating its latent annual spatial position and accounting for imperfect detection and the social/landscape structure.

This is a Bayesian latent-state spatial model fitted using MCMC in NIMBLE.

The final maximal-data model contains 1,932 badgers and 6,316 annual movement intervals.

### Latent spatial state

For badger \(i\) in year \(t\):

\[
S_{it}=(x_{it},y_{it})
\]

is the latent annual activity centre.

The movement-state variable is:

\[
D_{it} =
\begin{cases}
0 & \text{local}\\
1 & \text{high mobility}.
\end{cases}
\]

So \(D\) is the movement history we subsequently exported, whereas \(S\) is the underlying spatial location being estimated inside the model.

The actual NIMBLE code implements the activity-centre transition as:

```r
eps[i,1:2,k] ~ dmnorm(mean=eps_zero[1:2],
                      prec=eps_prec[1:2,1:2])

S[i,1,k] <- S[i,1,k-1] +
            sigma_move[i,k]*eps[i,1,k]

S[i,2,k] <- S[i,2,k-1] +
            sigma_move[i,k]*eps[i,2,k]
```

Thus:

\[
S_{it}-S_{i,t-1}
\sim N_2(0,\sigma^2_{it}I).
\]

### Movement magnitude

The movement scale is:

\[
\log(\sigma_{it})
=
\alpha_{\rm move}
+
\beta_{\rm move,sex}Male_i
+
\beta_{\rm move,state}D_{it}.
\]

In the original code:

```r
log_sigma_move[i,k] <-
    alpha_logmove +
    beta_move_sex*sex[i] +
    beta_move_disp*disp[i,k]
```

`beta_move_disp` has an exponential prior, forcing the high state to have greater movement variance than the local state:

```r
beta_move_disp ~ dexp(1)
```

So the two states cannot simply swap labels during MCMC. State 1 is explicitly the higher-movement state.

### State transitions

For later intervals, the binary Markov process estimates the probability of entering the high-mobility state from local movement (\(R\rightarrow D\)) and the probability of remaining in the high-mobility state (\(D\rightarrow D\)). The complementary probabilities define persistence in the local state (\(R\rightarrow R=1-p_{RD}\)) and return from high mobility to local movement (\(D\rightarrow R=1-p_{DD}\)).

Local→high:

\[
\text{logit}(P[D_{it}=1\mid D_{i,t-1}=0])
=
\alpha_{RD}+\beta_{RD,sex}Male_i.
\]

High→high:

\[
\text{logit}(P[D_{it}=1\mid D_{i,t-1}=1])
=
\alpha_{DD}+\beta_{DD,sex}Male_i.
\]

The code is:

```r
p_RD_i[i,k] <- ilogit(
    alpha_RD +
    beta_RD_sex*sex[i]
)

p_DD_i[i,k] <-
    ilogit(alpha_DD +
           beta_DD_sex*sex[i])

p_disp_markov[i,k] <-
    (1-disp[i,k-1])*p_RD_i[i,k] +
    disp[i,k-1]*p_DD_i[i,k]

disp[i,k] ~ dbern(p_disp_state[i,k])
```

The first movement interval has a separate state probability:

\[
\text{logit}(P[D_{i1}=1])
=
\alpha_{\rm init}
+\beta_{\rm adult}AdultEntry_i
+\beta_{\rm init,sex}Male_i.
\]

### Landscape/social-group resistance

Movement is not treated as unrestricted Gaussian movement. Candidate activity-centre positions are weighted according to whether they lie in the same social-group core, another group's core, or peripheral habitat.

The relevant code is:

```r
beta_sg ~ dexp(1)
beta_peripheral ~ dexp(1)

sg_multiplier <- exp(-beta_sg)
peripheral_multiplier <- exp(-beta_peripheral)
```

and:

```r
log_R_dest[i,k] <-
    -beta_sg*dest_other_core[i,k] -
    beta_peripheral*dest_peripheral[i,k]
```

The long V9 fit estimates `beta_sg` at only about 0.017, whereas `beta_peripheral` is about 3.3. Conditional on movement distance and the dynamically normalised availability of destination habitat, this suggests little additional resistance to entering another social-group core, but a much stronger penalty associated with movement into peripheral habitat. This should be interpreted cautiously. The observation model incorporates the spatial distribution of detector locations and therefore accounts to some extent for spatial differences in detectability, but trapping locations are considerably sparser in the peripheral zone and detailed temporal variation in trapping effort is not explicitly modelled. Consequently, the strength of the inferred peripheral resistance may partly reflect the poorer observational support for activity centres in these areas.

### Detection model

Observed captures are conditional on the latent activity centre.

Detection varies by sex, season and 5-year calendar period, and declines spatially away from the activity centre. Conceptually:

\[
p_{ijkt}=f(d_{ijkt},
\sigma_{\rm det,i},
sex_i,
season_j,
period_t).
\]

This matters because the movement model is not treating “not caught at another sett” as proof that the badger did not move there.

### V9 reparameterisation

The original scale parameters were:

\[
\alpha_{\rm move},\quad
\beta_{\rm move,sex},\quad
\beta_{\rm move,state}.
\]

These original parameters were strongly correlated and mixed poorly so I instead sampled:

\[
\log\sigma_{\rm male,local},
\qquad
\log\sigma_{\rm female,high},
\qquad
\beta_{\rm move,state}.
\]

```r
alpha_logmove <-
    logmove_female_high-beta_move_disp

beta_move_sex <-
    logmove_male_local-alpha_logmove
```

### Main inference

The behavioural-state result is much stronger than the exact movement-scale result.

Approximate transition probabilities from V9 run are:

| Result | Approximate estimate |
|---|---:|
| Female local → high | ~3–4% per interval |
| Male local → high | ~15% |
| Male vs female local→high OR | ~5 |
| Female high → high | ~31% |
| Male high → high | ~20% |
| Hard movement-state agreement between chains | ~99% |

The exact high-state movement scales are less stable but approximate posterior means suggest ~1.1 km for female high-state and ~0.7 km for male high-state annual radial movement.

## 2. Chronological-age movement model

This was the same spatial movement model on the 1,756 animals whose age could be reconstructed from being first caught as a cub or yearling.

Birth year is defined in the code as:

```r
birth_year=case_when(
  age_fc=="CUB" ~ year_fc,
  age_fc=="YEARLING" ~ year_fc-1
)
```

Age acts only on initiation of high mobility, not the magnitude of movement once high and not high-state persistence.

For later local→high transitions:

\[
\text{logit}(p_{RD,it})
=
\alpha_{RD}
+\beta_{RD,sex}Male_i
+\beta_{age}(Age_{it}-3).
\]

The code:

```r
p_RD_i[i,k] <- ilogit(
    alpha_RD +
    beta_RD_sex*sex[i] +
    beta_age*age_c[i,k]
)
```

with:

```r
beta_age ~ dnorm(0,sd=.35)
OR_age_per_year <- exp(beta_age)
```

The final V9 age estimate was approximately:

\[
\beta_{age}\approx-0.236
\]

and therefore:

\[
OR_{age}\approx0.79 \text{ per year}.
\]

So each additional year of age is associated with roughly 21% lower odds of initiating high mobility, conditional on sex and the rest of the movement model.

# 3. Non-linear age sensitivity

I then tested whether the linear age coefficient was too restrictive.

This was not another NIMBLE fit... It used each of the 1,500 accepted V9 state histories.

The code compares:

```r
glm(cbind(y,n-y) ~ male + age_years,
    family=binomial())
```

with:

```r
glm(cbind(y,n-y) ~
      male + ns(age_years,df=3),
    family=binomial())
```

separately for initial intervals and later local→high transitions.

For later local→high transitions, the spline performed worse overall: median \(\Delta AIC=AIC_{linear}-AIC_{spline}\) was −3.09, and the spline was preferred in only 2.5% of histories.

So the evidence supports keeping the simpler approximately logit-linear decline with age.


## 4. Infection → subsequent high mobility: (V7a)

This asks whether being infected before movement increases the probability of subsequently switching from local to high mobility.

The population consists only of local-origin transitions.

The model is:

\[
Y_{it}\sim Bernoulli(p_{it}),
\]

where \(Y_{it}=1\) means the current interval is high mobility, conditional on the previous interval being local.

\[
\text{logit}(p_{it})
=
\alpha
+\beta_{\rm inf}InfectedOrigin_{it}
+\beta_{\rm sex}Male_i.
\]

The actual code describes it as:

```text
logit P(high_t = 1 | state_{t-1}=local)
    = alpha +
      beta_inf * infected_origin +
      beta_sex * sex
```

`infected_origin` means infected by Q4 of the origin year.

The model is reduced to four grouped-binomial strata:

```r
strata <- tibble(
  sex      = c(0,1,0,1),
  infected = c(0,0,1,1)
)
```

with design:

```r
X <- cbind(
  alpha=1,
  beta_inf=strata$infected,
  beta_sex=strata$sex
)
```

## Priors

```r
PRIOR_MEAN <- c(
    alpha=qlogis(.05),
    beta_inf=0,
    beta_sex=0
)

PRIOR_SD <- c(
    alpha=1.5,
    beta_inf=1.5,
    beta_sex=1.5
)
```

### Fitting

Rather than running 1,500 separate MCMC models, we fit the disease model separately to each of the 1,500 plausible movement–infection histories using importance sampling. For each history, the algorithm first identifies the region of parameter space that best fits the data, draws a large number of candidate parameter values around that region and then weights those candidates according to their exact posterior probability. This provides a computationally efficient approximation to the Bayesian posterior without having to run a separate MCMC for every history.

We retain the same number of posterior draws from every movement–infection history, so each plausible reconstruction contributes equally to the final result. The final posterior therefore incorporates uncertainty in both movement state and infection timing rather than treating any one reconstructed history as known.

### Final result

\[
OR_{\rm infection}=1.13
\]

95% CrI approximately:

\[
0.72-1.69.
\]

So there is no clear evidence that prior infection causes a subsequent high-mobility transition.

By contrast:

\[
OR_{\rm male}\approx5.07
\]

with CrI roughly 3.72–7.01.

The median support per paired history was about 4,083 local-origin transitions, including ~513 infected origins and ~304 high-mobility outcomes.

## 5. High mobility → subsequent infection: V7b

This reverses the direction.

Movement ending in year \(t\) predicts infection during quarters 1–4 of year \(t+1\), provided the animal was susceptible at Q4 of \(t\).

The code explicitly checks:

```r
susceptible_q4 <-
    infection_time==0L ||
    infection_time>move_end_q4
```

Then it constructs the following year's quarterly risk set.

The discrete-time hazard model is:

\[
Y_{iq}\sim Bernoulli(h_{iq}),
\]

\[
\text{logit}(h_{iq})
=
\alpha
+\beta_{\rm move}D_{it}
+\beta_{\rm sex}Male_i
+\gamma_q
+\delta_{period}.
\]

Quarter and period effects use sum-to-zero contrasts.

The design matrix is built as:

```r
X[r,1] <- 1
X[r,2] <- cells$movement_state[r]
X[r,3] <- cells$sex[r]
X[r,4:6] <- quarter_contrast(...)
X[r,7:P] <- period_contrast(...)
```

### Priors

The baseline quarterly acquisition prior is centred around 1.25%:

```r
PRIOR_MEAN <- c(
  alpha=qlogis(.0125),
  beta_move=0,
  beta_sex=0,
  ...
)
```

with weakly informative SDs of 1.5 on the main effects and 1 on temporal effects.

### Fitting

Again this uses exact grouped-binomial likelihoods for each paired history.

Because V7b contains more parameters than V7a, candidate parameter values were generated using a mixture of a moderately broad distribution around the best-fitting region and a smaller, much broader component. This reduces the risk that importance sampling misses plausible values in the tails of the posterior.

### Final result

\[
OR_{\rm movement}=0.78
\]

with 95% CrI approximately:

\[
0.27-1.66.
\]

Therefore there is no evidence that high mobility increases subsequent acquisition risk.

The male effect is clearer:

\[
OR_{\rm male}\approx1.53
\]

with CrI roughly 1.07–2.17.

Median support was about 13,746 quarterly risk observations, 171 infection events and 1,145 animals per paired history.

## 6. Known-age disease sensitivities

These were designed specifically as confounding checks.

For V7a we compare:

\[
B0:
\quad
\text{logit}(p)
=
\alpha+\beta_{\rm inf}I+\beta_{\rm sex}Male
\]

with:

\[
B1:
\quad
\text{logit}(p)
=
\alpha+\beta_{\rm inf}I+\beta_{\rm sex}Male
+\beta_{\rm age}(Age-3).
\]

For V7b:

\[
B0:
\quad
\text{logit}(h)
=
\alpha+\beta_{\rm move}D+\beta_{\rm sex}Male
+\gamma_q+\delta_p
\]

versus:

\[
B1:
\quad
B0+\beta_{\rm age}(Age-3).
\]

This architecture is quite important because:

- full model vs known-age baseline tests sample-selection effects;
- known-age baseline vs known-age+age tests age confounding.

### Results

For infection→movement, the infection OR was about 1.01 on the known-age subset and 1.08 after age adjustment. Age itself had OR ~0.858/year.

For movement→infection, the movement OR was ~0.79 before age and ~0.80 after age. Age itself was weak, OR ~0.955.

Thus age is a strong determinant of movement but not the explanation for the weak movement–disease effects.

## 7. Same-group infection-pressure model

This extends V7b.

For focal badger \(i\) in social group \(g\):

\[
P_{gt}
=
\frac{
\text{number of other group members infected by Q4}(t)
}{
\text{number of other supported group members}
}.
\]

The focal animal is explicitly excluded.

The main model is:

\[
\text{logit}(h_{iq})
=
\alpha
+\beta_DD_{it}
+\beta_P(10P_{gt})
+\beta_{\rm sex}Male_i
+\gamma_q+\delta_p.
\]

(`10P` means the coefficient is per 10 percentage-point increase).

The code constructs models roughly as:

```r
movement_state
pressure10
sex
quarter
period
```

and uses logistic regression with badger-cluster robust covariance.

Rather than treating each regression coefficient as known exactly, we generate many plausible versions of the fitted coefficients based on their estimated uncertainty. We do this for every plausible movement–infection history and combine the resulting draws so the final uncertainty reflects both uncertainty in the regression itself and uncertainty in the underlying movement and infection histories.

Same-group infection pressure was calculated as the proportion of other observed group members already infected. We analysed both the raw proportion and a Jeffreys-smoothed version, which reduces the influence of extreme proportions arising from very small group samples. Similar results from the two definitions provide a robustness check on the infection-pressure effect.

\[
\tilde P=
\frac{infected+0.5}{n+1}.
\]

We also fitted:

\[
D\times P
\]

to test whether mobility becomes more important at high infection pressure.

### Results

Raw pressure:

\[
OR\approx1.16
\]

per +10 percentage points with all supported groups and approximately 1.18 with the ≥3-other-animal restriction.

Smoothed pressure gives approximately 1.19–1.21.

There was no convincing movement × pressure interaction.

So the strong result is local infection pressure, not focal high mobility.

## 8. Group turnover / social instability model

For group \(g\):

\[
T_{gt}
=
\frac{
Arrivals_{gt}+Departures_{gt}
}{
Stayers_{gt}+Arrivals_{gt}+Departures_{gt}
}.
\]

We tested whether social-group instability was associated with future infection risk. Group turnover was defined as the proportion of supported group members involved in arrivals or departures between consecutive years, with the focal badger excluded from the calculation. The fullest model included focal movement state, same-group infection pressure, group turnover, group-size decline, current group size, sex, quarter and calendar period.

Because individual badgers contribute repeated observations and multiple badgers can belong to the same social group in the same year, uncertainty was adjusted for clustering at both the badger and group-year levels. This avoids treating all observations as independent and gives more realistic uncertainty around the estimated effects.

Turnover and infection pressure were scaled so that their effects are interpreted per 10 percentage-point increase.

The fullest model is:

\[
\begin{aligned}
\text{logit}(h_{iq}) =\;&
\alpha
+\beta_DD_{it}
+\beta_P(10P_{gt})\\
&+\beta_T(10T_{gt})
+\beta_{\Delta N}\Delta N_{gt}\\
&+\beta_N(N_{gt}/5)
+\beta_{\rm sex}Male_i
+\gamma_q+\delta_p .
\end{aligned}
\]

### Results

Results were:

\[
OR_{\rm pressure}\approx1.21,
\]

\[
OR_{\rm turnover}\approx1.06
\]

per +10pp in the fullest model,

\[
OR_{\rm decline}\approx1.00
\]

and

\[
OR_{\rm size}\approx1.31
\]

per five other animals, although the latter remained uncertain.

## 9. Destination-group composition model

This is exploratory rather than part of the core disease analysis.

After an observed social-group switch, it models either:

\[
P(\text{observed again at }t+1)
\]

or, conditional on follow-up,

\[
P(\text{still in destination group at }t+1).
\]

The actual R formula is:

```r
outcome ~
    male*female10 +
    dest_size5 +
    period5
```

where:

- `female10` is destination female proportion centred at 50% and scaled per 10pp;
- `dest_size5` is destination group size centred and scaled per five animals;
- repeated events are clustered by badger.

The settlement analysis had 264 followed-up entries, 162 persistence events and 213 individual clusters.

There was no strong evidence that male settlement increases with destination female bias. Male persistence was relatively flat; female settlement showed a tendency to decline as destinations became more female-biased.

## 10. Within-individual movement→infection sensitivity

This asks a different question from V7b:

> For the same badger, is infection risk greater during/after its high-mobility periods than during/after its local periods?

This is effectively a conditional logistic / case-crossover sensitivity, so all time-invariant differences between badgers are conditioned out.

But there is limited statistical support... there are 171 event animals overall but only around 24 event animals actually change movement state over informative periods.

Therefore the within-animal movement coefficient is poorly estimated. Earlier fits tended to lean positive but with very wide uncertainty.


### Checking

### 1. Data-construction and population audits

- 1,932 movement animals;
- all 1,932 matched to the infection snapshot;
- 6,316 retained movement intervals;
- 1,500 movement histories;
- 1,500 paired movement/infection histories.

### 2. Computational/inference diagnostics

For the NIMBLE movement model we have inspected:

- trace/chain behaviour;
- \(\hat R\);
- effective sample size;
- long-chain versus short-chain results;
- first-half versus second-half drift;
- agreement in latent movement states between independent chains;
- state occupancy;

The movement-state transition process is good but the exact high-mobility movement scale, especially female-high, remains poorly mixed.

Independently fitted chains classify the latent states with roughly 99% hard-state agreement.

For V7a/V7b because we use importance sampling we check different things:

- optimization convergence;
- importance-sampling ESS;
- maximum importance weight;
- number of poor-ESS histories.

V7a is extremely healthy: median IS ESS ~1,729 and no low-ESS failures.

V7b is harder but generally acceptable: median ESS ~1,029, with seven of 1,500 histories below ESS 500.

For the robust-GLM pressure models, all 1,500 fits completed successfully with no failed fits.


### 3. Sensitivity/robustness checks

We have checked the conclusions against:

- V8 versus final V9 state histories;
- maximal-data versus known-age populations;
- with versus without chronological age;
- linear versus spline age;
- raw versus Jeffreys-smoothed infection pressure;
- pressure denominator ≥1 versus ≥3;
- pressure with versus without movement interaction;
- focal movement versus within-animal comparison;
- focal movement versus group-level turnover;
- follow-up probability in the destination analysis.

And the central conclusions have been stable.

### Still to do...

> **“Does the fitted statistical model generate data that look like the data we actually observed?”**

1. **Posterior predictive checking of the movement model.** Simulate captures/movements from posterior draws and compare with observed quantities such as annual displacement distribution, proportion of very long movements, numbers of social-group changes, repeated captures at the same sett, sex-specific movement distributions, and perhaps number of observed setts per animal/year.

2. **Check fitted versus observed state-related movement patterns.** For example, posterior-predicted distributions of observed annual displacement for intervals assigned high probability of local versus high state. This is not to “validate” the latent state using the same data, but to show that the model reproduces the observable separation it is supposed to explain.

3. **Disease-model predictive/calibration checks.** For V7a and V7b, posterior predictive counts are straightforward because we already have grouped-binomial cells. We can ask whether posterior simulations reproduce the observed number of high-mobility transitions or infection events by sex, movement state, quarter and period. For the pressure model we can compare predicted and observed infection rates across bins of infection pressure.

4. **Out-of-sample temporal prediction.** Something for the down the line analysis especially if we do some spatial-disease forecasting... fit earlier years, predict later years, then assess calibration/discrimination.

### Next modelling thoughts...

- **Move to the social-group level** — model annual group incidence/prevalence, turnover, size and movement connectivity.

- **Examine temporal change** — describe trends through time and compare key effects pre- vs post-2018.

- **Test movement-mediated spread** — ask whether infection in one group predicts later infection in groups connected by badger movement.

- **Use dynamic social-group boundaries** — incorporate the correct group geography for each year.

- **Build annual infection maps** — overlay infection patterns with badger movements and changing group structure.

- **Add pathogen genomics later** — compare predicted movement-linked transmission pathways with genetic relatedness of isolates.