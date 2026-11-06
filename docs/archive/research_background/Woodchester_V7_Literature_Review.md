# Woodchester V7 literature review: badger movement states, sex and bTB

**Search date:** 27 August 2026  
**Scope:** Targeted literature review, not a formal PRISMA systematic review.

---

# 1. Question

The current modelling suggests:

1. most badgers are spatially stable in a given year;
2. a minority undergo high-mobility/relocation episodes;
3. high mobility is mainly episodic rather than a fixed lifetime class;
4. males appear more likely to enter the high-mobility state, but do not clearly move farther than females once in that state;
5. the next question is whether infection predicts future relocation, and/or relocation predicts future infection.

The purpose of this review is to determine which of these ideas are already established and where the genuine methodological/biological gap lies.

---

# 2. Bottom line

## Findings that are **not new in broad biological terms**

The literature has already shown that:

- badger movement is heterogeneous and often temporary/episodic;
- permanent dispersal is relatively uncommon in high-density populations;
- males often make more inter-group or extra-territorial movements than females;
- a small subset of individuals can show sustained broad ranging;
- movement and bTB incidence are related at individual, group or population levels;
- infected/test-positive badgers can show wider ranging, altered sett use or altered social-network position;
- male-biased socio-spatial behaviour is linked to sex-specific epidemiology.

## What still appears to be a real gap

The targeted search did **not** identify a published Woodchester analysis that combines:

- dynamic annual activity centres in a spatial capture-recapture framework;
- a latent time-varying stable/local versus high-mobility state;
- sex-specific transition into that movement state;
- probabilistic longitudinal infection histories;
- explicit temporal tests of **infection -> future relocation** and **relocation -> future infection** while propagating uncertainty.

This is especially important because a 2018 synthesis of the Woodchester system explicitly stated that the **directionality** of associations between socio-spatial behaviour and infection acquisition/progression remained unclear, and pointed to probabilistic Bayesian infection status as the tool that could enable those analyses.

Thus the strongest novelty claim is **not** “males move more” or “infected badgers range more widely”. It is the proposed individual-level, temporally ordered integration of uncertain disease state with dynamic relocation-state transitions.

---

# 3. Woodchester movement literature

## Rogers et al. 1998: the essential precedent

**Rogers, L. M., Delahay, R., Cheeseman, C. L., Langton, S., Smith, G. C. & Clifton-Hadley, R. S. (1998). Movement of badgers (Meles meles) in a high-density population: individual, population and disease effects. Proceedings of the Royal Society B, 265, 1269–1276. DOI: 10.1098/rspb.1998.0429.**

This paper analysed 1,763 Woodchester badgers across 36 social groups over 18 years.

Among animals whose movement history could be categorized:

- 43.79% had moved;
- among movers, 73.1% were “occasional movers”;
- 22.1% were “permanent movers”;
- 4.8% were “frequent movers”;
- most moving adults were occasional movers;
- 70% of females were non-movers versus 37% of males.

It also showed that temporal changes in movement were related to bTB incidence in the following year.

### Relevance to V6c

This is a major precedent for the current conclusion that movement is often **episodic rather than permanent**.

Therefore the claim “badgers have episodic movement states” cannot be presented as unprecedented.

However, Rogers et al. used capture-history categories rather than a latent spatial state process with posterior uncertainty.

---

## Vicente et al. 2007: movement and subsequent TB incidence

**Vicente, J., Delahay, R. J., Walker, N. J. & Cheeseman, C. L. (2007). Social organization and movement influence the incidence of bovine tuberculosis in an undisturbed high-density badger Meles meles population. Journal of Animal Ecology, 76, 348–360. DOI: 10.1111/j.1365-2656.2006.01199.x.**

This paper is even more directly relevant to V7.

Key findings included:

- individual movement from year \(t-1\) to \(t\) was significantly associated with probability of becoming an incident excretor case;
- group movement in the previous year was associated with individual or group incidence;
- within-core movement was associated with greater incident risk;
- sex modified some movement–incidence relationships;
- serological status and physical condition in the previous year did **not** significantly predict subsequent movement after accounting for sex and group size.

### Why this matters

The direction **movement -> subsequent detectable infection/incidence** has therefore already been investigated using deterministic/observed movement categories and imperfect diagnostic proxies.

The reverse **infection -> movement** was also considered in a limited form and was not supported using prior serological status.

V7 is consequently not the first analysis to ask whether movement and infection are temporally associated.

Its contribution would instead be to revisit the directionality question with:

- probabilistic infection state rather than a single serological proxy;
- a latent movement-state process rather than raw category assignment;
- explicit observation uncertainty in spatial location/detection;
- dynamic activity centres;
- posterior inference on state transitions.

This makes Vicente et al. one of the most important papers to compare against directly.

---

# 4. Movement and sex

## Macdonald et al. 2008

**Macdonald, D. W., Newman, C., Buesching, C. D. & Johnson, P. J. (2008). Male-biased movement in a high-density population of the Eurasian badger (Meles meles). Journal of Mammalogy, 89, 1077–1086. DOI: 10.1644/07-MAMM-A-185.1.**

In the Wytham Woods high-density population:

- permanent dispersal was uncommon;
- males moved between groups more often than females;
- most animals were never captured in more than two groups.

### Relevance

The broad male-bias in movement is well established.

The V6c result is more specific:

> the sex difference is expressed mainly through the **probability of entering the high-mobility state**, while movement magnitude conditional on state shows little sex effect.

That decomposition appears more novel than the simple statement that male movement is greater.

---

## Byrne et al. 2019

**Byrne, A. W. et al. (2019). Push and pull factors driving movement in a social mammal: context dependent behavioral plasticity at the landscape scale. Current Zoology, 65, 517–525. DOI: 10.1093/cz/zoy081.**

In 463 Irish badgers:

- males were more likely to make visits into territories than females;
- animals that had immigrated previously were more likely to emigrate later;
- movement propensity depended on age, group structure, prior movement and group size.

### Relevance

This provides evidence for **history-dependent movement propensity**, i.e. movement is not independent between occasions.

That supports the decision to use a Markov state-transition process rather than treating annual relocation events as independent Bernoulli outcomes.

---

# 5. Episodic versus persistent high mobility

## Gaughran et al. 2018: super-ranging

**Gaughran, A., Kelly, D. J., MacWhite, T., Mullen, E., Maher, P., Good, M. & Marples, N. M. (2018). Super-ranging. A new ranging strategy in European badgers. PLOS ONE, 13, e0191818. DOI: 10.1371/journal.pone.0191818.**

GPS monitoring over seven years found that:

- most adults remained within traditional group boundaries;
- on average ~22% of adult males regularly ranged across two or more social-group territories;
- these “super-ranges” could persist for 2–36 months.

### Relevance

This shows that persistent high mobility can exist in badgers.

The current V6c result of only one strictly classified persistent high-mobility individual does **not** contradict this paper automatically because:

- the populations differ;
- population density/context differs;
- our data are capture histories, not fine-scale continuous GPS;
- our temporal resolution is annual;
- our state refers to AC relocation, not every extra-territorial foray.

The literature therefore argues against assuming that all high mobility is episodic in every population. It supports retaining a mechanism that can permit state persistence.

---

## Kelly et al. 2020: extra-territorial excursions

**Kelly, D. J. et al. (2020). Extra Territorial Excursions by European badgers are not limited by age, sex or season. Scientific Reports, 10, 9665. DOI: 10.1038/s41598-020-66809-w.**

Extra-territorial excursions occurred across sexes, ages and seasons, though breeding males made longer and more frequent excursions than breeding females.

### Relevance

An excursion is not necessarily permanent dispersal.

This supports careful terminology in V7: the latent high-mobility state is better described as **relocation/high mobility** unless permanent transfer can be established.

---

## Gaughran et al. 2019: dispersal is a process, not a straight line

**Gaughran, A. et al. (2019). Dispersal patterns in a medium-density Irish badger population: Implications for understanding the dynamics of tuberculosis transmission. Ecology and Evolution, 9, 13142–13152. DOI: 10.1002/ece3.5753.**

The study identified 25 dispersers from 139 monitored badgers and showed that actual GPS dispersal paths could be substantially longer and more complex than the straight-line distance between origin and destination groups.

### Relevance

The Woodchester annual AC model estimates **net relocation of an activity centre**, not the complete path travelled.

This limitation should be stated explicitly in any paper.

---

# 6. Infection-associated space use

## Garnett et al. 2005

**Garnett, B. T., Delahay, R. J. & Roper, T. J. (2005). Ranging behaviour of European badgers (Meles meles) in relation to bovine tuberculosis (Mycobacterium bovis) infection. Applied Animal Behaviour Science, 94, 331–340. DOI: 10.1016/j.applanim.2005.02.013.**

In eight matched infected/uninfected pairs:

- infected badgers had home ranges around 50% larger;
- a larger fraction of their home range extended into neighbouring territories;
- infected animals foraged farther from their main sett.

### Relevance

The association “infection ↔ wider space use” is not new.

However, the study could not establish whether infection altered behaviour or whether wider-ranging behaviour increased infection risk.

---

## Weber et al. 2013: denning behaviour

**Weber, N., Bearhop, S., Dall, S. R. X., Delahay, R. J., McDonald, R. A. & Carter, S. P. (2013). Denning behaviour of the European badger (Meles meles) correlates with bovine tuberculosis infection status. Behavioral Ecology and Sociobiology, 67, 471–479. DOI: 10.1007/s00265-012-1467-4.**

Test-positive badgers spent more time away from their main sett after controlling for season, sex and age.

The authors explicitly noted two possible directions:

- wider ranging could increase exposure;
- infection could modify behaviour.

### Relevance

Again, association is established but directionality remains unresolved.

---

## Weber et al. 2013: social networks

**Weber, N. et al. (2013). Badger social networks correlate with tuberculosis infection. Current Biology, 23, R915–R916. DOI: 10.1016/j.cub.2013.09.011.**

TB test-positive badgers were more socially isolated within their own groups but more important for between-group network flow.

### Relevance

This supports the biological plausibility that infection and between-group spatial behaviour are linked, but does not by itself determine causal direction.

---

# 7. Sex-specific disease ecology

## Graham et al. 2013

**Graham, J. et al. (2013). Multi-state modelling reveals sex-dependent transmission, progression and severity of tuberculosis in wild badgers. Epidemiology & Infection, 141.**

Multi-state models showed:

- males had higher infection risk;
- males experienced faster disease progression;
- disease-dependent mortality differed by sex/state.

### Relevance

Sex must remain in V7. Otherwise an apparent infection–movement relationship could be partly generated because both infection risk and movement-state transition differ by sex.

---

## Silk et al. 2018

**Silk, M. J. et al. (2018). Contact networks structured by sex underpin sex-specific epidemiology of infection. Ecology Letters, 21, 309–318. DOI: 10.1111/ele.12898.**

Male–male and between-sex networks were structured at broader spatial scales than female–female networks. Infection was associated with out-group contacts in male–male and between-sex networks.

### Relevance

This provides a mechanistic link between:

```text
sex
 -> broader between-group social connectivity
 -> infection acquisition / spread
```

The V6c sex effect on entering the high-mobility state is therefore biologically credible and should be interpreted in this established context rather than as a wholly novel discovery.

---

# 8. Probabilistic infection status

## Buzdugan et al. 2017

**Buzdugan, S. N., Vergne, T., Grosbois, V., Delahay, R. J. et al. (2017). Inference of the infection status of individuals using longitudinal testing data from cryptic populations: Towards a probabilistic approach to diagnosis. Scientific Reports, 7, 1111. DOI: 10.1038/s41598-017-00806-4.**

This paper is central to V7 because it replaces deterministic test-positive/test-negative classification with posterior probability of true infection from longitudinal diagnostic histories.

### Relevance

V7 should retain this uncertainty rather than thresholding posterior infection probability at 0.5.

If the infection trajectories arriving for V7 are posterior samples from such a model, posterior draws are preferable to point probabilities.

---

# 9. The 2018 Woodchester synthesis identifies the V7 gap explicitly

## McDonald, Robertson & Silk 2018

**McDonald, J. L., Robertson, A. & Silk, M. J. (2018). Wildlife disease ecology from the individual to the population: Insights from a long-term study of a naturally infected European badger population. Journal of Animal Ecology, 87, 101–112. DOI: 10.1111/1365-2656.12743.**

This synthesis is unusually important for positioning V7.

It states that there is extensive Woodchester evidence linking behaviour and bTB, but that the **directionality of relationships between socio-spatial behaviour and infection acquisition/progression remains unclear**.

It also states that Bayesian probabilistic infection inference should improve lifetime tracking of disease status and allow uncertainty to be propagated into subsequent analyses.

### Interpretation

This is essentially a published statement of the problem V7 is now positioned to address.

That makes a particularly strong narrative:

```text
1998-2013:
movement, sex and infection associations established

2017:
probabilistic infection histories become available

2018:
review identifies directionality of behaviour-infection co-dynamics as unresolved

2025:
disease-integrated SCR models infection and fixed-AC space use

V7:
dynamic AC relocation state + probabilistic infection + temporally ordered reciprocal effects
```

---

# 10. Ketwaroo et al. 2025: disease-integrated SCR

**Ketwaroo, F. R., Matechou, E., Silk, M. & Delahay, R. (2025). Modeling Disease Dynamics From Spatially Explicit Capture-Recapture Data. Environmetrics, 36, e2888. DOI: 10.1002/env.2888.**

Their Woodchester model jointly estimates:

- latent presence;
- latent infection;
- imperfect DPP, IFN and culture results;
- infection-dependent survival;
- infection-dependent encounter rate;
- infection-dependent spatial detection/home-range scale;
- density-dependent infection transition;
- abundance and prevalence.

They found infected badgers had lower survival and larger spatial scale.

### Key difference from V7

Their activity centres are fixed through time:

\[
s_{it}=s_i.
\]

Their Discussion explicitly notes that the framework could be extended using independent or Markovian activity-centre movement.

Thus V7's annual AC relocation process is not duplicating their disease-associated detection sigma.

### Important implementation lesson

Ketwaroo et al. report using:

- vectorization;
- block sampling of correlated parameters;
- user-defined NIMBLE functions;
- node-count reduction.

These are directly relevant to the computational optimization of V7.

---

# 11. Fine-scale movement methods: Furber et al. 2025

**Furber, J. R. et al. (2025). Data-driven analysis of fine-scale badger movement in the UK. PLOS Computational Biology, 21, e1013372. DOI: 10.1371/journal.pcbi.1013372.**

This recent GPS-based work analysed fine-scale badger movements from several UK regions using diffusion analysis and extended dynamic mode decomposition.

### Relevance

It reinforces that:

- movement patterns depend on sex, time and region;
- social organization can emerge from fine-scale movement;
- culling/management can alter movement structure.

It operates at a different temporal and observational scale from the annual capture-based V7 model and therefore complements rather than duplicates the present work.

---

# 12. General movement-state methodology

## Langrock et al. 2012

**Langrock, R., King, R., Matthiopoulos, J., Thomas, L., Fortin, D. & Morales, J. M. (2012). Flexible and practical modeling of animal telemetry data: hidden Markov models and extensions. Ecology, 93, 2336–2342. DOI: 10.1890/11-2241.1.**

This establishes the general use of hidden Markov states to represent distinct animal movement behaviours and shows that state-transition probabilities can depend on covariates or individual heterogeneity.

### Relevance

The latent stable/high-mobility state is methodologically consistent with a large movement-HMM literature. The novelty therefore lies in its integration with long-term SCR and probabilistic disease history, not in the existence of two-state movement HMMs themselves.

---

# 13. General open-SCR movement methodology

## Ergon & Gardner 2014

**Ergon, T. & Gardner, B. (2014). Separating mortality and emigration: modelling space use, dispersal and survival with robust-design spatial capture-recapture data. Methods in Ecology and Evolution. DOI: 10.1111/2041-210X.12133.**

This is a principal ancestor of the annual-AC robust-design framework.

## Schaub & Royle 2014

**Schaub, M. & Royle, J. A. (2014). Estimating true instead of apparent survival using spatial Cormack–Jolly–Seber models. Methods in Ecology and Evolution, 5, 1316–1326. DOI: 10.1111/2041-210X.12134.**

This demonstrates how spatial information can help separate movement/emigration from mortality and emphasizes sensitivity to the assumed dispersal kernel.

## Efford & Schofield 2022

**Efford, M. G. & Schofield, M. R. (2022). A review of movement models in open population capture–recapture. Methods in Ecology and Evolution, 13, 2106–2118. DOI: 10.1111/2041-210X.13947.**

This review is especially relevant to V6/V7 because it warns that:

- movement kernel choice matters;
- estimates can depend on spatial buffer;
- survival and movement may be poorly separated when data contain a mixture of short and long movements or do not span the movement range.

### Relevance

V6a's failure when a heavy-tailed kernel and a latent disperser state both competed to explain long steps is consistent with this broader identifiability problem.

---

# 14. Does the current V6c result replicate old findings?

## Stable/local versus episodic movement

**Yes, broadly.**  
Rogers et al. (1998) already showed that occasional movement was much more common than permanent/frequent movement among movers.

V6c adds uncertainty-aware annual latent spatial states, but should acknowledge this ecological precedent.

## Male-biased mobility

**Yes, broadly.**  
Rogers et al. (1998), Macdonald et al. (2008), Byrne et al. (2019), Kelly et al. (2020) and Silk et al. (2018) all provide relevant evidence.

The more specific V6c result—that sex primarily affects transition into high mobility rather than movement magnitude conditional on state—appears more distinct.

## Persistent high-mobility individuals

**Previously described elsewhere.**  
Gaughran et al. (2018) described persistent male super-ranging.

The fact that V6c identifies only one strictly persistent high-mobility individual should therefore be treated as a population/method-specific result, not a universal badger pattern.

## Infection-associated broader space use

**Already established.**  
Garnett et al. (2005), Weber et al. (2013) and Ketwaroo et al. (2025) all support an association.

## Movement preceding infection

**Previously supported.**  
Rogers et al. (1998) found population-level movement in one year related to incidence in the following year. Vicente et al. (2007) found individual/group movement associated with subsequent incidence.

## Infection preceding movement

**Much less clear.**  
Vicente et al. found previous serological status did not significantly predict movement after controlling for sex and group size, while later studies found cross-sectional associations between infection and space use. McDonald et al. (2018) explicitly concluded that directionality remained unresolved.

This is where probabilistic infection histories are potentially transformative.

---

# 15. Most defensible novelty statement at present

A cautious working statement is:

> Previous Woodchester studies have established strong associations among sex, inter-group movement and bTB epidemiology, including evidence that movement can precede increased disease incidence and that infected or test-positive animals may use space differently. However, the directionality of individual behaviour–infection co-dynamics remains unresolved. The proposed V7 framework extends this work by combining dynamic annual activity-centre movement, a latent relocation-state process and probabilistic longitudinal infection histories to estimate temporally ordered movement–infection relationships while propagating uncertainty in both spatial and disease states.

This is stronger and more defensible than:

> “We discovered that badgers have resident and disperser types.”

or:

> “We discovered that males disperse more.”

---

# 16. Literature-driven V7 hypotheses

### H1 — Sex and relocation
\[
P(R\rightarrow D|\mathrm{male}) >
P(R\rightarrow D|\mathrm{female})
\]

Supported as a priori plausible by previous movement and social-network studies.

### H2 — Infection predicts relocation
\[
\beta_{RD,\mathrm{inf}}\neq0
\]

This directly addresses whether infection state changes the probability of a future high-mobility episode.

### H3 — Relocation predicts infection acquisition
\[
\beta_{I,D}>0
\]

Strongly motivated by Rogers et al. and Vicente et al., but now tested with probabilistic infection histories and latent movement state.

### H4 — Disease effects may be sex-dependent
\[
\beta_{RD,\mathrm{inf}\times\mathrm{sex}}\neq0
\]

Biologically plausible given Graham et al. and Silk et al., but should be added only if supported by sample size and identifiability.

### H5 — High mobility may be episodic
\[
P(D\rightarrow D)<1
\]

The current model supports low persistence overall, consistent with the earlier Woodchester literature on occasional movement, while permitting a minority of persistent high-mobility individuals.

---

# 17. Literature-search conclusion

The broad ecological patterns emerging from V6c have substantial historical precedent, especially in Woodchester itself. That is an advantage rather than a problem: it provides an external biological check that the latent model is recovering sensible structure.

The strongest research opportunity is the **next step**:

> estimating the temporal co-dynamics of relocation and probabilistic infection state.

The 2018 Woodchester review explicitly identified this directionality problem as unresolved. Ketwaroo et al. (2025) then demonstrated that disease can be integrated formally within SCR, but retained fixed activity centres. The proposed V7 model therefore occupies a well-motivated space between those two literatures.

Before publication, the novelty claim should still be checked with a formal database search (e.g. Web of Science/Scopus) and collaborators familiar with unpublished/APHA analyses, but the targeted search to 27 August 2026 did not identify an existing analysis that directly matches the proposed V7 combination.

---

# References

- Buzdugan, S. N. et al. (2017). Inference of the infection status of individuals using longitudinal testing data from cryptic populations: Towards a probabilistic approach to diagnosis. *Scientific Reports*, 7, 1111. https://doi.org/10.1038/s41598-017-00806-4
- Byrne, A. W. et al. (2019). Push and pull factors driving movement in a social mammal: context dependent behavioral plasticity at the landscape scale. *Current Zoology*, 65, 517–525. https://doi.org/10.1093/cz/zoy081
- Efford, M. G. & Schofield, M. R. (2022). A review of movement models in open population capture–recapture. *Methods in Ecology and Evolution*, 13, 2106–2118. https://doi.org/10.1111/2041-210X.13947
- Ergon, T. & Gardner, B. (2014). Separating mortality and emigration: modelling space use, dispersal and survival with robust-design spatial capture-recapture data. *Methods in Ecology and Evolution*. https://doi.org/10.1111/2041-210X.12133
- Furber, J. R. et al. (2025). Data-driven analysis of fine-scale badger movement in the UK. *PLOS Computational Biology*, 21, e1013372. https://doi.org/10.1371/journal.pcbi.1013372
- Garnett, B. T., Delahay, R. J. & Roper, T. J. (2005). Ranging behaviour of European badgers (Meles meles) in relation to bovine tuberculosis (Mycobacterium bovis) infection. *Applied Animal Behaviour Science*, 94, 331–340. https://doi.org/10.1016/j.applanim.2005.02.013
- Gaughran, A. et al. (2018). Super-ranging. A new ranging strategy in European badgers. *PLOS ONE*, 13, e0191818. https://doi.org/10.1371/journal.pone.0191818
- Gaughran, A. et al. (2019). Dispersal patterns in a medium-density Irish badger population: Implications for understanding the dynamics of tuberculosis transmission. *Ecology and Evolution*, 9, 13142–13152. https://doi.org/10.1002/ece3.5753
- Graham, J. et al. (2013). Multi-state modelling reveals sex-dependent transmission, progression and severity of tuberculosis in wild badgers. *Epidemiology & Infection*.
- Kelly, D. J. et al. (2020). Extra Territorial Excursions by European badgers are not limited by age, sex or season. *Scientific Reports*, 10, 9665. https://doi.org/10.1038/s41598-020-66809-w
- Ketwaroo, F. R., Matechou, E., Silk, M. & Delahay, R. (2025). Modeling Disease Dynamics From Spatially Explicit Capture-Recapture Data. *Environmetrics*, 36, e2888. https://doi.org/10.1002/env.2888
- Langrock, R. et al. (2012). Flexible and practical modeling of animal telemetry data: hidden Markov models and extensions. *Ecology*, 93, 2336–2342. https://doi.org/10.1890/11-2241.1
- Macdonald, D. W. et al. (2008). Male-biased movement in a high-density population of the Eurasian badger (Meles meles). *Journal of Mammalogy*, 89, 1077–1086. https://doi.org/10.1644/07-MAMM-A-185.1
- McDonald, J. L., Robertson, A. & Silk, M. J. (2018). Wildlife disease ecology from the individual to the population: Insights from a long-term study of a naturally infected European badger population. *Journal of Animal Ecology*, 87, 101–112. https://doi.org/10.1111/1365-2656.12743
- Rogers, L. M. et al. (1998). Movement of badgers (Meles meles) in a high-density population: individual, population and disease effects. *Proceedings of the Royal Society B*, 265, 1269–1276. https://doi.org/10.1098/rspb.1998.0429
- Schaub, M. & Royle, J. A. (2014). Estimating true instead of apparent survival using spatial Cormack–Jolly–Seber models. *Methods in Ecology and Evolution*, 5, 1316–1326. https://doi.org/10.1111/2041-210X.12134
- Silk, M. J. et al. (2018). Contact networks structured by sex underpin sex-specific epidemiology of infection. *Ecology Letters*, 21, 309–318. https://doi.org/10.1111/ele.12898
- Vicente, J. et al. (2007). Social organization and movement influence the incidence of bovine tuberculosis in an undisturbed high-density badger Meles meles population. *Journal of Animal Ecology*, 76, 348–360. https://doi.org/10.1111/j.1365-2656.2006.01199.x
- Weber, N. et al. (2013). Badger social networks correlate with tuberculosis infection. *Current Biology*, 23, R915–R916. https://doi.org/10.1016/j.cub.2013.09.011
- Weber, N. et al. (2013). Denning behaviour of the European badger (Meles meles) correlates with bovine tuberculosis infection status. *Behavioral Ecology and Sociobiology*, 67, 471–479. https://doi.org/10.1007/s00265-012-1467-4
