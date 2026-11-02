# Statistical Methods Guide

**Project:** football-talent-hotspots, i.e. where England's Premier League and Championship footballers come from
**Author:** Dennis Wambua
**Reference:** [Technical Research Proposal v2.1](Talent_Hotspots_Technical_Research_Proposal.pdf) · [Work Plan](WORKPLAN.md)

A plain-language explanation of every statistical method used in the project.

---

## How the methods fit together

The analysis follows a chain. Each method answers one question and passes its result to the next:

```
1. Expected counts & SR      → "How many players should each area have?"
2. Empirical Bayes smoothing → "Make small-area numbers trustworthy"
3. KDE & relative risk       → "Let me see the pattern"
4. Ripley's K / L            → RQ1: "Is there clustering at all?"
5. Spatial weights           → "Who counts as a neighbour?"
6. Moran's I                 → RQ2: "Is there clustering overall in the area data?"
7. Gi* and LISA (+ FDR)      → RQ2: "Exactly WHERE are the hotspots?"
8. Negative binomial model   → RQ3: "WHY are they there?"
9. Spatial error / lag       → RQ3: "Fix the model if neighbours affect each other"
10. Robustness checks        → "Do results survive different choices?"
```

---

## 1. Expected counts and the Standardised Ratio (SR)

**The problem:** Birmingham will always produce more players than a small town because it has more babies. Raw counts mostly tell you where people live.

**The idea:** for each area, work out how many players it *should* have if every baby in England had the same chance of becoming a player.

**Example:**
- England had about 600,000 births in 1990, and suppose 60 English players in the study were born that year. The rate is 60 ÷ 600,000 = **1 player per 10,000 births**.
- Town A had 5,000 births in 1990, so it is expected to produce 0.5 players from that year.
- Add this up across every birth year 1975–2005 to get **E**, the expected count.

**Formula:**

> E<sub>i</sub> = Σ<sub>y</sub> Births<sub>i,y</sub> × (Players<sub>England,y</sub> ÷ Births<sub>England,y</sub>)

**Then compare with what actually happened:**

> **SR = Observed ÷ Expected**

| SR | Meaning |
|---|---|
| 1.0 | Produces exactly what births predict |
| 2.0 | Twice as many players as expected (possible hotspot) |
| 0.5 | Half as many as expected (possible coldspot) |

**Why births and not population:** a university town has many 20-year-olds who weren't born there, which would make it look like it under-produces. Births count the actual pool each player came from.

---

## 2. Empirical Bayes (EB) smoothing

**The problem:** small areas give unstable SRs.
- A village expected to produce 0.2 players that produces 1 gets SR = **5.0**, which looks like a huge hotspot but is probably luck.
- A city expected to produce 50 that produces 60 gets SR = **1.2**. That is far more reliable, because it's based on many players.

**The idea:** pull each area's SR toward the England average, and pull harder when the area is small.
- Big areas keep almost their own SR, since there's plenty of evidence.
- Small areas get pulled strongly toward 1.0, since there's little evidence.

**A football analogy:** a striker who scores 2 goals in 2 games isn't really a one-goal-a-game player. You'd adjust that estimate toward a normal scoring rate until they've played more matches. EB does the same for areas.

**What you get:** a "smoothed SR" for each area, which you then map and test.

---

## 3. Kernel Density Estimation (KDE) and relative risk

**KDE** turns a scatter of dots (birthplaces) into a smooth heat map. Picture placing a small hill over every birthplace; where many hills overlap, the surface is high.

You make **two** KDE maps:
1. player birthplaces
2. births (population)

Then you divide one by the other:

> **Relative risk surface = player density ÷ birth density**

Values above 1 mean the area produces more players than its births predict, and values below 1 mean fewer.

**Purpose:** this is **exploratory**. It shows you the pattern before any formal test. There's no p-value yet.

**Key setting:** the bandwidth, i.e. how wide each hill is. Too narrow and the map is spiky noise; too wide and everything blurs together. spatstat can choose it automatically.

---

## 4. Ripley's K and L functions (inhomogeneous) → RQ1

**The question:** are birthplaces more clustered than births alone would cause?

**How K works:**
1. Stand on each player's birthplace.
2. Draw a circle of radius *r* (say 5 km) and count the other players inside.
3. Average that over all players.
4. Repeat for r = 1 km, 2 km, 5 km, 10 km, 20 km and so on.

**"Inhomogeneous"** means the comparison isn't "random everywhere". It's "random, but following where babies are born". London will naturally have many players close together, and that's expected. Only clustering **beyond** that counts.

**L function:** a transformed version of K that's easier to read on a graph, where the expected line is flat.

**Simulation envelopes (999 simulations):**
1. Generate 999 fake datasets in which players are placed purely according to births.
2. Calculate L for each one. Together they form a grey band showing what "no extra clustering" looks like.
3. Plot your real L line on top.

**How to read the graph:**

```
L(r)
 │        ╱ real data      ← above the band = CLUSTERED beyond births
 │      ╱
 │ ░░░░░░░░░░░░░           ← grey band = what chance produces
 │ ░░░░░░░░░░░░░
 └──────────────── r (km)
```

| Real line is… | Meaning |
|---|---|
| Above the band | Players cluster beyond births at that distance |
| Inside the band | No evidence of extra clustering |
| Below the band | Players are more spread out than expected |

The x-axis also tells you the scale of clustering, for example "players cluster within about 10 km more than expected".

---

## 5. Spatial weights: who is a neighbour?

Every area-based method from here on (Moran's I, Gi\*, LISA, spatial regression) needs a definition of "neighbour". The proposal uses two:

| Rule | Used for | Meaning |
|---|---|---|
| **Queen contiguity** | Local authorities | Areas that share any border or even a corner are neighbours (like a queen's moves in chess) |
| **k-nearest neighbours (k = 6)** | Hexagons | The 6 closest hexagons are neighbours |

**Row-standardised** means each neighbour gets an equal share: an area with 4 neighbours weights each at ¼.

**Islands problem:** the Isle of Wight touches nothing, so it's manually linked to its nearest mainland area. Otherwise the methods break.

**Why you also test other definitions:** if a hotspot only appears under one definition of "neighbour", it isn't robust.

---

## 6. Global Moran's I (Empirical Bayes version) → RQ2

**The question:** across the whole of England, do areas with high SR tend to sit next to other areas with high SR?

**Result: one number for the whole map.**

| Moran's I | Meaning | Picture |
|---|---|---|
| Positive (e.g. +0.3) | Similar values cluster together | High areas next to high, low next to low |
| About 0 | Random arrangement | No pattern |
| Negative | Opposites sit together | Checkerboard |

**How significance is tested (999 permutations):**
1. Randomly shuffle the SR values across the map 999 times.
2. Calculate Moran's I each time. This shows what chance alone produces.
3. If your real value is larger than almost all the shuffled ones, it's significant. For example, beating 990 of 999 gives p ≈ 0.01.

**Why the EB version:** ordinary Moran's I gets fooled by small areas with extreme rates. The EB version (Assunção–Reis) adjusts for population size.

**Limitation:** it says clustering *exists*, but not *where*. That's the next step.

---

## 7. Local hotspots: Getis-Ord Gi\* and LISA → RQ2

### Getis-Ord Gi\*

**The question:** is this area **and its neighbours** together unusually high or low?

For each area it takes the sum of the area's own SR plus its neighbours' SRs, and compares that with what you'd expect by chance. The result is a **z-score**:

| Gi\* z-score | Label |
|---|---|
| Large positive (e.g. > 2.58) | 🔴 **Hotspot**: a cluster of high-producing areas |
| Large negative (e.g. < −2.58) | 🔵 **Coldspot**: a cluster of low-producing areas |
| Near 0 | Not significant |

**Important:** one high area surrounded by low ones is *not* a Gi\* hotspot. Gi\* finds **groups**.

### LISA (Local Moran's I)

LISA compares **each area with its neighbours** and puts it in one of four groups:

| Class | Meaning | Example |
|---|---|---|
| **High-High** | High area, high neighbours | Core of a hotspot |
| **Low-Low** | Low area, low neighbours | Core of a coldspot |
| **High-Low** | High area, low neighbours | An "island" talent factory, one town outperforming its region |
| **Low-High** | Low area, high neighbours | An under-producer inside a hotspot |

**Why use both:** Gi\* is better at finding clusters, while LISA also finds **outliers** (High-Low, Low-High), which can be the most interesting areas to explain.

### FDR correction (Benjamini–Hochberg)

**The problem:** you test about 300 areas. At p < 0.05, roughly 15 would look "significant" by pure chance.

**The fix:** FDR adjusts the p-values so that, of the areas you call significant, only about 5% are expected to be false alarms.

In practice, fewer areas end up significant, and you can trust the ones that remain.

---

## 8. Negative binomial regression with an offset → RQ3

**The question:** what explains the hotspots? Deprivation? Urbanisation? Distance to a professional club?

### Why not ordinary regression?
- The outcome is **counts** (0, 1, 2, 5…), not a continuous measure, and it can't go below zero.
- Many areas have small numbers.

### Why negative binomial and not Poisson?
Poisson regression assumes the variance equals the mean. Football counts are more spread out than that (**overdispersion**): some areas get many players and some get none. Negative binomial adds an extra parameter to handle this. If you used Poisson, your p-values would be too optimistic.

### The model

> O<sub>i</sub> ~ NegBin(μ<sub>i</sub>)
> log μ<sub>i</sub> = **log E<sub>i</sub>** + β<sub>1</sub>·IMD + β<sub>2</sub>·Urban + β<sub>3</sub>·DistClub + γ<sub>region</sub>

### The offset: log(E)
The **offset** is where expected counts come in. Including log(E) with its coefficient fixed at 1 means the model explains **SR** (observed vs. expected), not raw counts. Without it, the model would mostly find that areas with more births have more players, which is obvious.

### Reading the results: rate ratios
Coefficients come out on a log scale. Exponentiate them to get **rate ratios (RR)**:

| Variable | RR | Interpretation |
|---|---|---|
| IMD (per 10-point increase) | 1.15 | Each 10-point rise in deprivation is linked to **15% more** players than expected |
| Distance to club (per 10 km) | 0.92 | Each extra 10 km from a club is linked to **8% fewer** players |
| Urban share | 1.00 | No effect |

*(These numbers are made up, just to show how to read the table.)*

If the 95% confidence interval includes 1.0, the effect isn't significant.

**Region fixed effects (γ):** these allow each region of England its own baseline level, so you compare areas within regions and not, say, the North East against London.

**Academy-era sub-model:** the same model, run only for players born 1996–2005, with distance to Category 1 academy added.

---

## 9. Spatial regression: error and lag models → RQ3

**The problem:** standard regression assumes each area is independent. Neighbouring areas usually aren't: they share local leagues, scouts and culture. If that's ignored, the model looks more certain than it really is.

**Step 1, test for it:** run Moran's I on the model's **residuals** (the part the model couldn't explain).
- Not significant → the negative binomial model is fine. Stop.
- Significant → there's a leftover spatial pattern, so continue.

**Step 2, choose a model with Lagrange Multiplier (LM) tests:**

| Model | Idea | Football interpretation | Key parameter |
|---|---|---|---|
| **Spatial Error** | Unmeasured factors are shared by neighbours | Something not in the model (e.g. a strong regional youth league) affects a whole cluster of areas | **λ (lambda)** |
| **Spatial Lag** | An area's outcome directly depends on its neighbours' outcomes | Talent "spills over": a strong area raises its neighbours (shared academies, scouting networks) | **ρ (rho)** |

The robust LM tests (`lm.RStests`) produce statistics for both. Pick the one that's significant, or the stronger one if both are.

**Reading λ or ρ:** values range from about −1 to 1. Something like 0.4 and significant means strong spatial dependence.

**Model comparison:** **AIC**, where lower is better, and log-likelihood, where higher is better.

### Optional: BYM2
A Bayesian model built specifically for area counts, widely used in disease mapping. It splits the unexplained variation into a **spatial** part (shared with neighbours) and a **random** part (unique to the area). It's optional because it needs the R-INLA package and more time.

---

## 10. Robustness checks: do the results hold up?

Every analysis involves choices. Robustness checks rerun it with different choices to see whether the conclusions survive.

| Check | Worry it addresses |
|---|---|
| Different scales (local authority vs. 10/20 km hexagons) | **MAUP**: results can change just because of where boundaries are drawn |
| Cohort split (1975–89 vs. 1990–2005) | Are hotspots stable over time, or before/after EPPP? |
| Premier League only | Are hotspots different for the very top players? |
| Exclude the big cities | Are "hotspots" just big-city effects? |
| Total population instead of births | Does the baseline choice matter? |
| Exclude ambiguous season players | Do uncertain Wikidata dates change anything? |
| Different neighbour definitions | Are hotspots sensitive to how "neighbour" is defined? |
| **Null test** (fake data placed only by births) | Does the method create false hotspots? It should find **none** |

**Interpretation:** a hotspot that appears in most checks is a **strong finding**. One that appears in only one check should be reported cautiously.

---

## Quick reference

| Method | Answers | Output to look at | R function |
|---|---|---|---|
| SR | How far from expected? | SR per area | (calculated) |
| EB smoothing | Stabilise small areas | Smoothed SR | `spdep::EBest` |
| KDE / relative risk | What does the pattern look like? | Heat map | `spatstat::density`, `relrisk` |
| Inhomogeneous L | Clustering beyond births? (RQ1) | Line vs. envelope | `spatstat::Linhom`, `envelope` |
| EB Moran's I | Overall clustering? (RQ2) | I and p-value | `spdep::EBImoran.mc` |
| Gi\* | Where are the clusters? (RQ2) | z-scores, hot/cold map | `spdep::localG_perm` |
| LISA | Clusters and outliers? (RQ2) | HH / LL / HL / LH map | `spdep::localmoran_perm` |
| FDR | Avoid false positives | Adjusted p-values | `p.adjust(method = "BH")` |
| Negative binomial | Why? (RQ3) | Rate ratios and CIs | `MASS::glm.nb` |
| LM tests | Error or lag model? | Test statistics | `spdep::lm.RStests` |
| Spatial error / lag | Correct for neighbour effects | λ or ρ, AIC | `spatialreg::errorsarlm`, `lagsarlm` |

---

## Suggested learning order

1. **SR**
2. **EB smoothing**
3. **Moran's I**
4. **Gi\***

These four are the core of the project, and the rest builds on them.
