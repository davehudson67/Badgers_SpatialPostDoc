# Woodchester Badger Project  
## Live Modelling Roadmap: Movement, Disease, Survival, Social Structure and Persistence

### 1. The overarching scientific question

The long-term aim is not simply to model badger movement or estimate bTB prevalence. The more interesting question is:

**Why does *Mycobacterium bovis* persist in some parts of the Woodchester badger population, disappear from others, and subsequently reappear?**

We want to understand how persistence emerges from the interaction between:

- individual infection histories;
- movement and dispersal;
- mortality and survival;
- immigration and emigration;
- social-group turnover;
- changing territory structure;
- spatial connectivity;
- and the major external perturbation created by culling from 2018 onwards.

Ultimately, the system can be thought of as:


$$
\text{Disease}
\leftrightarrow
\text{Movement}
\rightarrow
\text{Survival / demographic turnover}
$$


embedded within:


$$
\text{a changing social and spatial landscape}.
$$


The analyses therefore need to move progressively from individual badgers to social groups and, finally, to the persistence of infection across the whole system.

---

# 2. What we have already done

A substantial part of the scientific programme has already been explored using earlier versions of the movement model.

We have investigated:

- sex and age differences in movement;
- high-mobility versus local movement;
- infection predicting subsequent movement;
- movement predicting subsequent infection;
- within-individual sensitivities;
- same-group infection pressure;
- external infection pressure/connectivity;
- movement × infection-pressure interactions;
- social-group turnover;
- destination composition;
- immigration-like behaviour;
- later-period changes in the system;
- and preliminary survival/disappearance questions.

Those analyses were useful and should not be discarded.

However, many of them depended on movement probabilities estimated using earlier movement models.

The current V10B work is therefore **not restarting the science**.

It is replacing the movement engine underneath those analyses with a model that has:

- better use of the capture data;
- clearer biological interpretation;
- better convergence;
- a more defensible within-year structure;
- and a fully audited data pipeline.

Once final V10B movement estimates are available, many of the existing disease/movement analyses should simply be rerun as confirmation analyses.

---

# 3. The movement model: what it is actually doing

For each badger $i$ and year $t$, we estimate an annual spatial activity centre:


$$
A_{i,t}.
$$


This should be thought of as the centre of the animal's spatial use during that year.

We do **not** assume that a capture at a particular sett means that the badger's true centre is exactly at that sett.

Instead, there is another spatial layer for each quarterly trapping campaign:


$$
Q_{i,t,q}.
$$


Observed captures occur spatially around those quarterly centres.

The hierarchy is therefore approximately:


$$
\text{Annual activity centre}
\rightarrow
\text{Quarterly spatial centre}
\rightarrow
\text{Observed capture locations}.
$$


This lets us distinguish three different processes that would otherwise be mixed together:


$$
\text{capture-location variation}
$$



$$
\text{within-year spatial variation}
$$



$$
\text{between-year movement}.
$$


The annual activity centre can then change between years.

Each annual transition can arise from one of two movement processes:


$$
\text{local/resident movement}
$$


or


$$
\text{high-mobility movement}.
$$


Importantly, these are not defined using an arbitrary distance threshold.

For each animal-year transition we estimate:


$$
P(H_{i,t}=1 \mid \text{data}),
$$


the posterior probability that the transition arose from the high-mobility process.

A 300 m movement is therefore not automatically labelled “dispersal”. Its interpretation depends on the movement distributions and the animal's entire spatial history.

---

# 4. Why we changed how the movement model was fitted

Earlier V10B versions explicitly sampled a binary local/high state for every annual transition.

There are thousands of these states.

The MCMC chains could become stuck in alternative explanations.

For example, one chain could infer:

> annual activity centre moved substantially → high-mobility state.

Another could infer:

> annual activity centre stayed local → resident state.

Once those two parts of the model reinforced each other, it was difficult for the chain to move between the alternatives.

The biological model itself did not need changing.

Instead, we changed the computational treatment.

The current model analytically integrates over both movement possibilities:


$$
P(\Delta A_t)
=
P(L_t)f_L(\Delta A_t)
+
P(H_t)f_H(\Delta A_t).
$$


This is a standard hidden-Markov-model forward calculation.

The MCMC therefore estimates the continuous activity centres and global movement parameters without sampling thousands of binary states.

After fitting, we use forward-backward smoothing to calculate:


$$
P(H_t\mid\text{entire movement history}).
$$


We can also use FFBS to generate complete plausible local/high histories.

The 300-badger validation showed that this substantially reduced the previous state-path convergence problem.

We therefore regard this as the appropriate final movement architecture.

---

# 5. The movement-scale diagnostic and the old 5 m boundary

The 300-badger diagnostic also revealed another issue.

The model previously imposed:


$$
\sigma_{\text{movement}} > 5\,\mathrm{m}
$$


as a purely computational safeguard.

It was never intended as a biological assumption.

However, the posterior for male local movement was visibly accumulating near that 5 m boundary.

That meant the computational bound was inadvertently influencing biological inference.

The lower numerical boundary has therefore been relaxed to:


$$
0.5\,\mathrm{m}.
$$


This does not imply that we expect biologically meaningful annual movements of 50 cm.

It simply ensures that the artificial numerical boundary is far enough away that the data determine the local movement distribution.

The diagnostic also showed a strong negative relationship between:


$$
\alpha_{\text{local movement}}
$$


and


$$
\beta_{\text{high-mobility contrast}}.
$$


This explains why those raw parameters can mix relatively slowly even when the resulting high-mobility movement scale itself is much more stable.

---

# 6. Where movement now stands

The final model is being fitted to the full movement-eligible population:


$$
n=1,932.
$$


The three chains deliberately begin from very different plausible movement regimes.

That is useful because genuine convergence will require the chains to forget those starting values and arrive at the same posterior distribution.

Assuming that:

- the full run converges satisfactorily;
- forward-backward state recovery behaves properly;
- and the spatial-state-space audit passes;

we should then consider the **geographical movement model complete**.

At that point, for every badger-year we will have posterior information on:

- annual activity-centre location;
- annual movement distance;
- probability of high mobility;
- within-year spatial centres;
- and uncertainty in all of these quantities.

We should resist developing further movement variants unless genuinely new information changes the scientific problem.

---

# 7. The annual bait-marking maps

The annual bait-marking maps are likely to be extremely valuable, but they answer a somewhat different question from V10B.

V10B tells us:

> Where was the badger spatially, and how much did its activity centre move?

The bait-marking maps will tell us:

> Which social territory occupied that part of the landscape in that particular year?

Eventually we should have something conceptually like:


$$
SG(x,y,t),
$$


where social-group identity depends on both geographical location and year.

This will allow us to classify movements as:

- within the same territory;
- across a neighbouring boundary;
- across several territories;
- into peripheral space;
- or apparently changing group because the territory boundary itself moved.

That distinction is important.

For example:

> a badger moves 150 m and crosses a territory boundary

is biologically different from:

> a badger hardly moves, but the territory boundary moves around it.

Initially, therefore, the bait-marking maps should be used to **interpret the final V10B movement posterior**, rather than automatically rebuilding V10B.

Only if the time-varying territory information clearly provides important information about uncertain annual locations should we consider incorporating social boundaries directly into the movement model.

Thus:

**V10B = geographical movement model.**

**Annual bait-marking maps = dynamic social-landscape layer.**

---

# 8. The 2018 cull as a major system perturbation

Culling began in 2018 and should be treated explicitly in the scientific programme.

It potentially affects several processes simultaneously:


$$
\text{Cull}
\rightarrow
\text{mortality}
$$



$$
\text{Cull}
\rightarrow
\text{social disruption}
$$



$$
\text{Cull}
\rightarrow
\text{movement / immigration / turnover}
$$


and therefore potentially:


$$
\text{Cull}
\rightarrow
\text{disease persistence and transmission}.
$$


The simplest first representation is:


$$
Cull_t =
\begin{cases}
0, & t < 2018,\\
1, & t \ge 2018.
\end{cases}
$$


But a simple pre/post comparison should only be the starting point.

We should eventually examine an event-study style sequence around 2018:


$$
2014,\;2015,\;2016,\;2017
\;\big|\;
2018
\;\big|\;
2019,\;2020,\;2021,\ldots
$$


This allows us to distinguish:

- an immediate effect;
- a delayed response;
- a temporary perturbation;
- and a persistent structural change.

This is particularly relevant because some of our earlier exploratory analyses suggested that aspects of the system may change around 2020–2021.

The cull provides a plausible ecological explanation that can be tested, rather than simply fitting an arbitrary late-period effect.

If spatially explicit information on cull intensity becomes available, we should go further.

For each badger-year we could estimate:


$$
CullExposure_{i,t}
$$


based on its inferred activity centre and the local cull footprint.

Likewise, for each social group:


$$
CullIntensity_{g,t}.
$$


That would be much more informative than treating the entire population as equally exposed from 2018 onward.

---

# 9. Immediate next step after movement: refresh the disease–movement analyses

We have already explored both directions.

### Disease → movement

Does infection state in year $t$ predict movement in:


$$
t\rightarrow t+1?
$$


For example:


$$
P(H_{i,t}=1)
=
f(D_{i,t},\mathrm{sex},\mathrm{age},\ldots).
$$


### Movement → disease

Does movement in:


$$
t\rightarrow t+1
$$


predict subsequent infection?

For example:


$$
P(D_{i,t+1}=1)
=
f(H_{i,t},D_{i,t},\mathrm{sex},\mathrm{age},\ldots).
$$


We should rerun these using the final V10B posterior.

These should be viewed as **confirmation analyses**, not new model-development projects.

We should also retain several extensions previously discussed:

- within-individual analyses;
- age and sex interactions;
- time since infection;
- before/after infection event studies;
- infectious/excretor versus merely infected animals;
- source mobility versus recipient mobility.

---

# 10. Source mobility versus recipient mobility

This distinction may be much more important epidemiologically than simply asking whether mobile animals become infected.

Transmission could arise because:

### Susceptible animals move towards infection


$$
\text{resident infected source}
\rightarrow
\text{mobile susceptible recipient}.
$$


Or because:

### Infectious animals carry infection elsewhere


$$
\text{mobile infected source}
\rightarrow
\text{resident susceptible recipient}.
$$


These mechanisms imply very different disease dynamics.

We can therefore distinguish four situations:


$$
\text{resident source} \rightarrow \text{resident recipient}
$$



$$
\text{mobile source} \rightarrow \text{resident recipient}
$$



$$
\text{resident source} \rightarrow \text{mobile recipient}
$$



$$
\text{mobile source} \rightarrow \text{mobile recipient}.
$$


This should remain an explicit part of the future transmission analysis.

---

# 11. Survival: the major genuinely unfinished component

The current movement model deliberately conditions on the interval between:


$$
\text{first observed alive}
$$


and


$$
\text{last observed alive}.
$$


It therefore does not attempt to explain what happens after an animal disappears.

If an animal is never caught again, several explanations are possible:

- it died;
- it permanently emigrated;
- it remained alive but was not detected.

This is where the final survival model comes in.

We should extend the spatial model with an alive/dead state:


$$
Z_{i,t}\in\{0,1\}.
$$


Then:


$$
Z_{i,t+1}
\sim
\operatorname{Bernoulli}\!\left(Z_{i,t}\phi_{i,t}\right),
$$


where:


$$
\phi_{i,t}
$$


is annual survival.

The important advantage of using the spatial model is that disappearance can be interpreted in the context of movement.

A badger with a high probability of long-distance movement should not be treated identically to an animal that had been highly resident and suddenly disappeared.

Post-mortem recoveries also provide direct information about mortality.

This gives us the possibility of separating, much better than a simple non-spatial CJS model:


$$
\text{mortality}
$$


from:


$$
\text{emigration}
$$


from:


$$
\text{nondetection}.
$$


---

# 12. Biological predictors of survival

Once the baseline survival model works, we can test:


$$
\mathrm{Disease}_t
\rightarrow
\mathrm{Survival}_{t\rightarrow t+1},
$$



$$
\mathrm{HighMobility}_t
\rightarrow
\mathrm{Survival}_{t\rightarrow t+1},
$$


and potentially:


$$
\mathrm{Disease}_t \times \mathrm{HighMobility}_t.
$$


Other useful predictors include:

- sex;
- age;
- time since infection;
- infectious/excretor state;
- calendar period;
- cull exposure after 2018.

This allows us to ask whether infection carries a survival cost and whether highly mobile animals represent a distinct demographic component of the population.

---

# 13. Mapping disease through individual badgers

One of the most powerful things we can do with the final movement posterior is map disease through time using each animal's inferred spatial location.

For each badger $i$ and year $t$, we will have:


$$
A_{i,t}=(x_{i,t},y_{i,t}),
$$


its inferred annual activity centre.

Separately, using diagnostic histories, we can estimate:


$$
P(D_{i,t}=1),
$$


the probability that it is infected.

Ideally, we can also distinguish infection from infectiousness:


$$
P(I_{i,t}=1),
$$


where $I$ indicates an animal likely to be actively infectious or excreting.

Then every animal-year has:


$$
\text{Location}
+
\text{Disease probability}.
$$


For example:


$$
\text{Badger A:}\quad
(x,y),\;P(D)=0.98
$$



$$
\text{Badger B:}\quad
(x,y),\;P(D)=0.04
$$


and so forth.

Repeating this from the 1970s to 2025 gives us a posterior reconstruction of disease through space and time.

This would be fundamentally better than plotting positive captures alone because both spatial location and disease state are imperfectly observed.

---

# 14. Continuous infection-pressure surfaces

Individual disease locations can be converted into a continuous spatial surface.

For point $x$ in year $t$:


$$
I(x,t)
=
\sum_i
P(D_{i,t}=1)
K\!\left(\lVert x-A_{i,t}\rVert\right),
$$


where $K$ is a spatial kernel.

In plain language:

> infected animals contribute infection pressure around their inferred locations, with that contribution declining with distance.

If we use infectiousness rather than infection:


$$
I(x,t)
=
\sum_i
P(\mathrm{Infectious}_{i,t}=1)
K\!\left(\lVert x-A_{i,t}\rVert\right).
$$


That may be even more biologically meaningful.

The result could be visualised as annual maps or an animation showing disease pressure moving through Woodchester over decades.

Because location and infection are posterior distributions rather than fixed values, uncertainty can also be propagated.

For posterior draw $s$:


$$
A^{(s)}_{i,t}
$$


and:


$$
D^{(s)}_{i,t}
$$


generate a disease surface.

Across posterior draws we then obtain:


$$
E[I(x,t)]
$$


and uncertainty around it.

This allows us to distinguish strong evidence of a hotspot from a spatial pattern that is highly uncertain.

---

# 15. Mapping disease is descriptive; transmission requires lagged prediction

A spatial disease map shows where infection probably occurred.

It does not by itself tell us what caused new infection.

For transmission, the important quantity is exposure.

For susceptible badger $i$:


$$
\mathrm{FOI}_{i,t}
=
\sum_{j\ne i}
P(\mathrm{Infectious}_{j,t}=1)
K(d_{ij,t}).
$$


This is the focal animal's local force of infection.

Then test:


$$
\mathrm{FOI}_{i,t}
\rightarrow
P(D_{i,t+1}=1).
$$


This asks:

> Does being spatially close to infectious badgers this year increase the probability of becoming infected subsequently?

This is a continuous-space extension of the infection-pressure analyses we have already conducted.

---

# 16. Infectious movers as disease bridges

Movement can then become an explicit transmission mechanism.

Suppose badger $j$ is infectious in year $t$ and moves substantially between $t$ and $t+1$.

Its contribution to infection pressure at its destination could be represented by something like:


$$
\mathrm{ImportPressure}_{i,t}
=
\sum_j
P(\mathrm{Infectious}_{j,t})
P(H_{j,t})
K\!\left(
d(A_{j,t+1},A_{i,t+1})
\right).
$$


Then test:


$$
\mathrm{ImportPressure}_{i,t}
\rightarrow
P(D_{i,t+1}=1).
$$


This directly asks:

> Are infectious high-mobility badgers responsible for introducing infection into new parts of the population?

This is more informative than simply testing whether movers themselves become infected.

---

# 17. Importation versus establishment

Another important distinction is between:


$$
\text{infection arriving}
$$


and:


$$
\text{infection becoming established}.
$$


An infectious animal entering a previously infection-free area does not necessarily create persistent transmission.

We can therefore separate:

### Importation

Did an infectious animal arrive?

from:

### Establishment

Were subsequent local infections generated?

That gives us questions such as:

> How frequently is infection imported into apparently disease-free groups?

and:

> What determines whether that introduction disappears or becomes established?

Possible predictors of establishment include:

- number of infectious arrivals;
- resident group size;
- local susceptibility;
- group turnover;
- mortality;
- cull exposure;
- territory structure;
- previous infection history.

---

# 18. Disease persistence at social-group level

Once annual social-group maps are available, we can define a latent infection state for each social group and year:


$$
Z_{g,t}=0/1.
$$


Then two different transitions become important.

### Persistence


$$
P(Z_{g,t+1}=1\mid Z_{g,t}=1).
$$


This asks:

> If infection is present, what determines whether it remains?

### Recolonisation / reseeding


$$
P(Z_{g,t+1}=1\mid Z_{g,t}=0).
$$


This asks:

> If infection has disappeared, what determines whether it returns?

These processes may have different drivers.

Persistence may depend mostly on:


$$
\text{resident infectious burden}
+
\text{group size}
+
\text{survival}
+
\text{within-group transmission}.
$$


Reseeding may depend more on:


$$
\text{infected immigrant arrivals}
+
\text{movement connectivity}
+
\text{territory adjacency}.
$$


This provides a very attractive conceptual separation:


$$
\boxed{\text{Local maintenance}}
$$


versus


$$
\boxed{\text{External reseeding}}.
$$


---

# 19. Demographic turnover and resilience

A social group remaining infected does not necessarily mean the same infected animals remain there.

Two quite different mechanisms can create persistent group-level infection.

### Stable persistence

Infected residents survive and continue transmitting infection.

Or:

### Demographic replacement


$$
\text{death}
\rightarrow
\text{vacancy}
\rightarrow
\text{immigration}
\rightarrow
\text{new transmission}.
$$


Once survival and movement are integrated, we can quantify:


$$
\text{mortality}
$$



$$
\text{emigration}
$$



$$
immigration
$$



$$
\text{replacement}
$$



$$
\text{infection burden}.
$$


Then ask:

> Does infection persist because infected animals themselves persist, or because the social group repeatedly replaces animals while maintaining transmission?

This is where the project becomes a study of **disease-system resilience**, rather than simply individual epidemiology.

---

# 20. The role of the 2018 cull in persistence and resilience

The cull may act as a large demographic perturbation.

Conceptually:


$$
\text{Cull}
\rightarrow
\text{Mortality}
$$


which may cause:


$$
\text{Vacancies}
\rightarrow
\text{Immigration}
\rightarrow
\text{Social turnover}.
$$


At the same time:


$$
\text{Cull}
\rightarrow
\text{Reduced density}
$$


may reduce local transmission.

Alternatively:


$$
\text{Cull}
\rightarrow
\text{Social disruption}
$$


could increase movement or connectivity.

These competing pathways mean that the effect of culling on disease persistence may not be captured simply by asking whether prevalence declined after 2018.

We should eventually test:


$$
\text{Cull}
\rightarrow
\text{Survival}
$$



$$
\text{Cull}
\rightarrow
\text{Movement}
$$



$$
\text{Cull}
\rightarrow
\text{Turnover}
$$



$$
\text{Cull}
\rightarrow
\text{Local persistence}
$$


and:


$$
\text{Cull}
\rightarrow
\text{Recolonisation}.
$$


The strongest version would use spatially explicit cull intensity rather than a simple pre/post indicator.

---

# 21. The eventual individual-level dataset

At the end of this programme, we should effectively have for every badger and every year:


$$
\boxed{
\begin{aligned}
&\text{Location}
+\text{Movement}
+\text{Disease}\\
&+\text{Infectiousness}
+\text{Survival}
+\text{Social group}\\
&+\text{Cull exposure}
\end{aligned}
}
$$


with uncertainty retained where appropriate.

That becomes an extraordinarily rich longitudinal dataset.

---

# 22. The eventual social-group-level dataset

Likewise, for every social group and every year we could estimate:


$$
\boxed{
\begin{aligned}
&\text{Infection burden}
+\text{Infectious burden}
+\text{Group size}\\
&+\text{Deaths}
+\text{Immigration}
+\text{Emigration}\\
&+\text{Turnover}
+\text{Connectivity}
+\text{Cull exposure}
\end{aligned}
}
$$


This is the level at which we can ask the final persistence questions.

---

# 23. The modelling progression from here

The practical sequence should now be:

**A. Complete V10B movement**

Finish the full 1,932-badger fit, state recovery and spatial audit.

Then freeze the geographical movement architecture.

**B. Refresh existing disease–movement analyses**

Rerun the analyses we have already developed using the final movement posterior.

This includes:

- disease → movement;
- movement → disease;
- sex and age;
- within-individual effects;
- infection pressure;
- source versus recipient mobility;
- time since infection;
- infectious movers where possible.

**C. Build the final survival model**

Integrate:

- alive/dead states;
- capture/noncapture;
- annual movement;
- PM recoveries;
- disease;
- sex;
- age;
- cull period/exposure.

This is the next major new model.

**D. Build continuous-space disease exposure**

Use annual activity centres and latent disease/infectiousness states to estimate:


$$
FOI_{i,t}.
$$


Then test whether spatial infectious pressure predicts subsequent infection.

**E. Separate importation from establishment**

Test whether infectious movers introduce infection into new areas and whether those introductions establish onward transmission.

**F. Model social-group persistence and recolonisation**

Once yearly bait-marking maps are available, construct dynamic social-group infection histories.

Model separately:


$$
\text{Persistence}
$$


and:


$$
\text{Recolonisation}.
$$


**G. Explain persistence through demography and connectivity**

Integrate:

- resident infectious burden;
- survival;
- immigration;
- emigration;
- turnover;
- movement connectivity;
- territory change;
- culling.

This becomes the resilience analysis.

---

# 24. The final scientific story

The final study should not simply conclude:

> infected badgers move more or less.

Nor:

> movement increases or decreases infection risk.

Those are useful component questions.

The deeper question is:

**How is *M. bovis* maintained within a spatially structured host population despite infection, mortality, movement, changing social groups and major demographic perturbation?**

The system may ultimately operate through something like:


$$
\text{Local transmission}
$$


maintaining infection within particular social groups,

combined with:


$$
\text{Rare infectious movement}
$$


providing connections and reseeding,

while:


$$
\text{Mortality + immigration + turnover}
$$


continually reorganise the host population.

The 2018 cull then provides a major perturbation with which to test how this system responds when mortality and social structure are externally altered.

The annual bait-marking maps will eventually allow the geographical movement model to be interpreted in terms of the true social landscape.

The resulting programme therefore links:


$$
\boxed{
\begin{aligned}
\text{Individual epidemiology}
&\rightarrow \text{Movement}
\rightarrow \text{Demography}\\
&\rightarrow \text{Transmission}
\rightarrow \text{Social persistence}\\
&\rightarrow \text{System resilience}
\end{aligned}
}
$$


That is the overarching modelling framework we should now work towards.

---

## 2026-10-22 update — annual observed social-group territory polygons (1977–2025)

**New available source:** 49 year-specific shapefiles (`data/spatial/social_group_boundaries/territories_YYYY.shp`) with named polygons. These are observed/reconstructed annual boundaries and should take precedence over constructing a new static Thiessen map for years with usable polygon data. Keep source files unchanged; record provenance and interpretation of polygon names, which may derive from principal setts.

**Field/CRS audit:** the source name field alternates between `SocialName`, `Sett`, `SETT` and `Social_grp`; some years have original `Confidence` values; numerous 2011–2024 files lack CRS metadata. Where coordinates independently confirm British National Grid, assign EPSG:27700 with an explicit inference flag rather than silently projecting. Retain original name, field, source filename, confidence, polygon ID, geometry-validity flags and areas in a derived annual GeoPackage. Compound names must not be automatically split or reconciled.

**Immediate diagnostic work (no refit of V11S):**
1. Run `scripts/Spatial/01_audit_social_group_boundaries.R` to produce an annual polygon layer, field/CRS/geometry/name checks, year summaries, same-name intersection/Jaccard persistence and a discrete 1977–2025 GIF. The animation must show only observed years, without fabricated intermediate boundaries, using a common extent and stable name colours. Verify year labels and review the output/flags.
2. Check per-year mapped spatial coverage, overlap, missing/duplicate names, mapped union area, and (where possible) distinguish true social-group loss from names, boundary changes or survey extent. The marked long-term population decline is independently known; fewer groups are biologically plausible, but polygon count alone is not a group-population estimate.
3. Compare spatially and by name against capture-level recorded social groups, historical sett-to-group assignments and study-domain point data. Resolve what `Confidence` means from data provenance before weighting inference by it.
4. Overlay posterior **draws** of annual activity centres from the current full 1,932-badger V11S movement fit against **year-specific** polygons; retain out-of-polygon and ambiguous assignments as uncertain rather than forcing a group. For transitions, classify both endpoint centres against both year's boundary layers to separate movement-induced reassignment from boundary change. Check robustness of the observed high-mobility state against between-group switching, without defining that state by switching.

**Biological hypotheses to test, not assume:** (a) losses of occupied territories as population declines, (b) compensatory expansion or contraction of surviving named territories, (c) changing boundary-crossing probabilities and dispersal at lower density, (d) potentially longer within-territory movements even when social-group switching becomes rarer, and (e) changing spatial connectivity, arrival/establishment and turnover after social-group loss. The same 300 m displacement can have a different social consequence under different annual territory geometries.

**Candidate derived measures:** mapped group count, total mapped union extent, per-territory area and annual intersection/retention, adjacent groups and contact edge-length, same-name continuity, probabilistic badger-to-territory assignment, posterior crossing probability by local/high movement state, origin/destination group, and network edge flows. Interpret named territory continuity separately from continuity of its social members. Account for time-varying capture effort, population density estimation and potential post-2018 cull effects when relating spatial change to demography.

**Model-development decision gate:** complete geometry/GIF audit and descriptive posterior overlay first; do not modify or refit V11S solely because polygons are now available. Consider a boundary-resistance movement-kernel extension only if spatial overlay provides a substantive new estimand, shows residual support beyond physical distance and territory geometry, and passes identifiability/robustness checks. If considered, compare movement-state-specific resistance rather than imposing impermeable territories.

**Later workstreams:** connect territory contraction/loss and network connectivity to V12 apparent survival, immigration/emigration and establishment, then use changing territory membership/connectivity and source infectiousness in V13 force-of-infection and persistence analyses. Distinguish disease introductions from sustained establishment, and observed associations from causal effects of population decline or culling.


---

## 2026-10-22 — V11S annual-boundary overlay completed; historical capture-group validation next

The full V11S overlay was executed over **1,932 animals, 8,248 badger-years and 6,316 annual transitions**, with 75 subsampled posterior draws (25 × 3 chains) per activity centre. The derived spatial membership and transitions are in `outputs/V11S_social_group_overlay/`. These are exploratory outputs, **not** a refitted movement model or validated social-group membership estimates.

**Initial audit summary (conditional on sampled posterior draws):** approximately 76.8% of annual locations fall in a single polygon, 20.5% outside mapped polygons and 2.7% in overlapping polygons. The conservative strict-boundary-change flag is rare (about 1.1% of transition draws); approximately 33.8% are map-dependent and 32.4% have ambiguous classifications (flags overlap, so percentages do not sum to 100). Never equate strict crossing with the full dispersal rate. These numbers should be confirmed against generated CSVs when published.

**Biological context:** marked population decline and social-group attrition are independently known. As density drops, territories may expand and become less well-defined. This is a testable interpretation, not grounds to erase overlapping polygons or impute group membership where annual maps disagree.

**Immediate validation work (script `scripts/Spatial/03_validate_V11S_territories_against_capture_groups.R`):**
- Join overlay `individual_id × year` to the audited `results/V7_population_inclusion_audit.rds` individual-ID/tattoo crosswalk, then to *live* `data/badger_encounters_useful.rds` records.
- Use capture-level `recorded_social_group_name` (or documented field fallback); preserve original strings and use only transparent case/whitespace normalisation. Do not substitute present-day sett/group names, silently fuzzy-match historical/compound labels, or treat `CHESTNUT` and `HOLLOW TREE` legacy sett-as-group anomalies as valid historical group labels.
- Report per badger-year unique modal captured group, capture-group counts and tie status, posterior probability that mapped polygons contain **any contemporaneously recorded group**, probability of agreement with the unique annual modal group, and capture-count-weighted agreement. Keep outside/overlapping/unmapped spatial classes distinct and retain disagreement/name audit rows.
- Compare concordance by calendar year and population-decline period; report denominators of *observable* group records and territory coverage separately. Agreement is not independent validation of V11S ACs: V11S coordinates are themselves inferred using many of these same captures; this is a **cross-source spatial consistency check**.
- Cross-check against the established Vicente-inspired annual resident-group algorithm in `scripts/behaviour/Woodchester_assign_annual_resident_social_group.R` if that output is available. Modal group within a year is an initial sensitivity, **not** an automatic replacement for the full five-criterion resident assignment.
- Review major mismatches before using annual group assignments in mechanistic movement or epidemiological models. Consider capture-level observed SG switches and excursions separately from annual residency.

**Decision gate:** Do not inject time-varying boundaries into NIMBLE yet. After reviewing validation and the spatial coverage trend, connect the overlay to **joint** V11S HMM high-mobility state draws/probabilities, taking care with posterior pairing. Only then assess density-dependent geography vs social-boundary crossing, and ultimately group loss, territory expansion/overlap, apparent survival/entry and infectious-source connectivity.

**Known visualization issue:** the GIF renders, but its displayed year remains `NA` on the server. This is a display-only issue to revisit later; derive all analyses from explicit `year` columns in the GeoPackage/CSVs, never from GIF frame labels.


---

## 2026-10-22 — conservative historical SG name crosswalk and field-team verification

**Decision:** distinguish deterministic typography reconciliation from biological identity claims. Formatting-only key uppercases and removes spaces/punctuation; it preserves all source strings, does *not* split compound polygon names and does *not* infer that similar distinct words are equivalent. Examples suitable for automatic text matching: WOODFARM/WOOD FARM, OLDOAK/OLD OAK, FIELDFARM/FIELD FARM, SEPTICTANK/SEPTIC TANK, HOLLYWOOD/HOLLY WOOD. This is an analytical matching key, not a write-back to canonical social-group IDs.

Reanalysis of 542,400 posterior badger-year location draws with recorded capture groups (7,232 badger-years; 75 draws each) shows **any-recorded-name exact concordance ~43.1%**, increasing to **~57.8%** with formatting-only matching. This is a consistency metric, not independent validation, because AC locations use the same captures. Differences in polygon coverage and overlapping territory units still contribute to nonagreement.

**Remain pending field-team confirmation:** JACKSMIREY/JACKS, COLLIERSWOOD/COLLIERS, original names paired with clearly different polygon names (e.g., ARTHURS/JUNCTION and LARCH/BOX), and hyphenated/compound historical territories (e.g. YEW-TOP and YEW-TAXUS-TOP-WYCH ELM). Never assume split/merger or membership merely from a string; ask what the mapped territorial units were intended to represent in each period, and whether name relationships are date-bounded. Capture-level anomalies CHESTNUT and HOLLOW TREE must remain excluded from inferred group IDs per database governance unless explicitly corrected by source evidence.

**Next action:** run `scripts/Spatial/04_reconcile_historical_social_group_names.R` to generate (1) candidate pairs for field review with year and frequency, (2) source-string dictionary with formatting keys, (3) badger-year concordance comparison, (4) annual comparison and (5) ranked unresolved-pair queue. Keep any approved aliases in a separate, versioned crosswalk with source, reviewer, evidence, effective dates and relationship type (equivalent name vs merger/compound vs different social group). Do not recode raw data; rerun validation after approvals. Then inspect residual spatial mismatches before introducing group membership into V12/V13.


---

## 2026-10-23 update — V11S resolution limit and protected path to demography / disease

The long full-data V11S continuation confirmed a structural ridge in the
freely-estimated resident annual movement scale. This does **not** change the
overarching scientific programme.

Annual activity centres remain continuous. The 50 m raster describes spatial
habitat/support and should not be converted into a hard rule that a resident
must remain in the same raster cell. However, an annual resident-process scale
of only a few to a few tens of metres is not usefully distinguishable given
the 50 m landscape raster and approximately 150--160 m observation/activity
scale.

The resident state should therefore be interpreted as:

> **no resolvable annual relocation**

rather than as an exact small-distance movement distribution.

The final movement correction remains in the **V11 family** (provisionally
V11R). V12 remains reserved for entry, immigration/settlement, survival,
retention and apparent emigration.

V11R should preserve the V11S biological transition structure initially and
fix/anchor only the non-identifiable resident process scale. Use a pre-specified
small sensitivity set around the unresolved scale (e.g. 25, 50 and 100 m mean
radial displacement), and ask whether inferred relocation histories and
biological effects remain stable. Only simplify age/sex/individual or Markov
transition biology if convergence still fails after this nuisance ridge is
removed.

The now-available 1977--2025 territory polygons form a parallel,
time-varying **social landscape**, not the definition of geographical movement.
For every annual transition distinguish:

- geographic relocation;
- capture-derived resident-group change;
- polygon-defined territory crossing;
- apparent reassignment caused by boundary movement itself.

This distinction is essential because territory contraction/expansion, group
loss, overlap and post-2018 social reorganisation can change group identity
without equivalent animal movement.

After V11R is frozen, proceed directly to the demographic/immigration model.
Immigrant status must be inferred from full entry + settlement + movement +
territory/residency history and never equated automatically with adult first
capture or high mobility.

The disease programme then uses infectiousness and source/recipient social
connectivity to distinguish local maintenance from external reseeding.
Time-varying boundaries are especially important here because they define
changing membership, adjacency and plausible infectious pressure.

This sequence preserves the final scientific target:

**individual movement -> immigration/emigration and demographic turnover ->
infectious movement / exposure -> social-group persistence and recolonisation
-> system resilience.**

The older instruction to broadly "refresh" disease-movement analyses should not
be interpreted as permission to repeat generic infected -> movement or movement
-> infection models unchanged. Those questions have already been addressed;
future disease analyses require a changed estimand such as infectiousness,
demography, dynamic exposure, importation/establishment or a materially improved
joint state formulation.


---

## 2026-10-23 — annual sett / social-group / polygon crosswalk for infection transmission

Sett locations are fixed; annual capture-recorded SG and Vicente annual residence are separate from changing bait-marked territory polygons. Published Woodchester sources describe marker deployment at main setts, but not a universal GIS polygon naming rule. A documented 2005 exception is the Larch group with main setts Larch and Box; Taxus and Top were treated as one Yew *supergroup* at that time, with trapping labels still tied to individual setts. These are dated cases, not timeless aliases.

**Next data product:** evidence-graded, year-specific crosswalk using annual polygon labels, sett-to-capture-SG evidence, source names, counts, competing groups and confidence. Keep candidate (not proven) assignments and their provenance separate from approved aliases; leave compound, overlapping and ambiguous polygons unresolved. No fuzzy auto-merges or editing raw data. Obtain field-team decisions with effective years, relationship type and evidence.

**Why this matters for V13:** an infected badger moving across a territory edge does not itself establish between-social-group transmission. Separately estimate residency, movement/contact opportunity, infectious source status, incident recipient infection, introduction, and subsequent local establishment. Incorporate mapping uncertainty and use temporally lagged analyses. Do not use year-to-year polygon row IDs as group IDs.

Implementation: `scripts/Spatial/06_build_historical_polygon_SG_crosswalk.R` produces `outputs/social_group_crosswalk/` evidence and field-review tables. Review before using as a group-specific force-of-infection input.
