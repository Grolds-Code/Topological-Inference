![R](https://img.shields.io/badge/R-%23276DC3.svg?style=for-the-badge&logo=r&logoColor=white) ![License](https://img.shields.io/badge/License-GPL--3.0-blue.svg?style=for-the-badge) ![Version](https://img.shields.io/badge/App-v2.1-orange.svg?style=for-the-badge) ![Status](https://img.shields.io/badge/Status-Active%20Development-brightgreen.svg?style=for-the-badge) [![Live Demo](https://img.shields.io/badge/Live_Demo-Active-2ea44f?style=for-the-badge&logo=googlechrome&logoColor=white)](https://gro7d.shinyapps.io/TDA-Engine-Preview/) [![Preprint](https://img.shields.io/badge/Preprint-MedRxiv-blue.svg?style=for-the-badge)](https://doi.org/10.64898/2026.02.01.26345283)

------------------------------------------------------------------------

# TDA — v2.1

### *Topological Inference for Detecting Structural Voids in Spatially Censored Epidemiological Data*

**Sole Investigator:** Mboya Grold Otieno **Application DOI:** [10.64898/2026.02.01.26345283](https://doi.org/10.64898/2026.02.01.26345283) **License:** GPL-3.0

------------------------------------------------------------------------

## Table of Contents

1.  [Abstract & Epidemiological Rationale](#1-abstract--epidemiological-rationale)
2.  [Novelty & Contribution Statement](#2-novelty--contribution-statement)
3.  [Technical Stack & Dependencies](#3-technical-stack--dependencies)
4.  [Repository Structure](#4-repository-structure)
5.  [Research Foundation — Phases 1–5](#5-research-foundation--phases-15)
    -   [Phase 1 — Simulation](#phase-1--the-digital-laboratory)
    -   [Phase 2 — Failure Proof](#phase-2--the-failure-proof)
    -   [Phase 3 — DTM Detection](#phase-3--topological-detection)
    -   [Phase 4 — Statistical Inference](#phase-4--statistical-inference)
    -   [Phase 5 — Sensitivity Analysis](#phase-5--sensitivity-analysis)
6.  [Key Results Summary](#6-key-results-summary)
7.  [The Application — Geometry of Silence v2.1](#7-the-application--geometry-of-silence-v21)
8.  [Analysis Methods in Detail](#8-analysis-methods-in-detail)
9.  [Data Inputs](#9-data-inputs)
10. [Quick Start](#10-quick-start)
11. [Analysis Pipeline](#11-analysis-pipeline)
12. [Outputs and Exports](#12-outputs-and-exports)
13. [Limitations & Ethics](#13-limitations--ethics)
14. [Reproducibility](#14-reproducibility)
15. [Citation](#15-citation)

------------------------------------------------------------------------

## 1. Abstract & Epidemiological Rationale

In conflict-affected regions, disease surveillance data is rarely complete. It is often **Censored Not at Random (CNAR)**. High-risk zones controlled by armed groups or subject to extreme stigma frequently report *zero* cases — not because the population is healthy, but because they are silenced.

**The Core Issue:** Standard epidemiological tools like Kernel Density Estimation (KDE) and SaTScan rely on **Spatial Scan Statistic Logic**. They assume that a low case count implies low risk. When fed censored data, these tools misclassify "Structural Voids" (silenced zones) as "Low-Risk Clusters." This is a dangerous error that can divert humanitarian aid away from the areas that need it most.

**The Solution:** This framework uses **Topological Data Analysis (TDA)** — specifically **Distance-to-Measure (DTM)** — to distinguish between two fundamentally different types of silence:

1.  **Stochastic Voids** — Areas with no cases because no one lives there (true low risk).
2.  **Structural Voids** — Areas with dense populations but suppressed reporting (high risk, hidden by the data).

**Statistical Validation:** Permutation testing confirmed the topological void's statistical significance ($p = 0.02$), providing rigorous evidence that the detected suppression zone is a real structural feature — not random variation in case reporting.

This repository allows full reproduction of all results, figures, and analyses. It also provides a **production-ready Shiny application** (v2.1) that operationalises the framework for real surveillance data.

------------------------------------------------------------------------

## 2. Novelty & Contribution Statement

This research introduces three specific innovations to spatial epidemiology:

**1. First Application of DTM to Censorship Detection**

While Topological Data Analysis is commonly used for clustering (finding high-density zones), this is the first application of **Distance-to-Measure (DTM)** designed specifically to detect **structural censoring** — suppressed data in conflict zones and inaccessible areas.

**2. Robustness to Imperfect Silencing (**$\epsilon$-Leakage)

Theoretical models often assume perfect censorship. This simulation framework incorporates a **5% Leakage Probability** ($\epsilon = 0.05$) to mimic real-world messiness. Standard topological tools (such as Vietoris-Rips complexes) fail under this noise, necessitating the robust DTM approach developed here.

**3. The "Density Fallacy" Proof**

A direct mathematical comparison proves that density-based methods (KDE) and ratio-based methods (Relative Risk) *must* fail in silenced zones, whereas geometric methods (DTM) succeed. This is not a limitation of implementation — it is a mathematical inevitability.

------------------------------------------------------------------------

## 3. Technical Stack & Dependencies

The project is built entirely in **R**. The application requires:

| Package   | Role                                              |
|-----------|---------------------------------------------------|
| `shiny`   | Interactive web application framework             |
| `leaflet` | Interactive map rendering                         |
| `shinyjs` | Stage gates and JS-from-R calls                   |
| `sf`      | Spatial features, projections, polygon operations |
| `TDA`     | Distance-to-Measure computation                   |
| `raster`  | Raster construction and polygon dissolution       |

The research reproduction scripts additionally require:

| Package    | Role                                                    |
|------------|---------------------------------------------------------|
| `spatstat` | Point process simulation and Relative Risk calculations |
| `ggplot2`  | Manuscript figure generation                            |
| `TDAstats` | Persistent homology computation                         |
| `viridis`  | Perceptually uniform colour maps                        |
| `ggforce`  | Geometric annotations (void boundaries)                 |

------------------------------------------------------------------------

## 4. Repository Structure

``` text
.
├── app.R                        # Complete Shiny application (~3,150 lines)
│                                # UI · server · CSS · all analysis functions
├── README.md                    # This document
├── scripts/
│   ├── 01_generate_process.R    # Phase 1: Point Process Simulation
│   ├── 02_compare_methods.R     # Phase 2: KDE vs Relative Risk Analysis
│   ├── 03_topological_scan.R    # Phase 3: DTM Filtration
│   ├── 04_inference.R           # Phase 4: Permutation Testing
│   └── 05_sensitivity.R         # Phase 5: Robustness Checks
├── output/
│   └── figures/
│       ├── Fig1_Simulated_Void.png
│       ├── Fig2A_KDE_Failure.png
│       ├── Fig2B_Risk_Failure.png
│       ├── Fig3A_Topological_Anomaly.png
│       ├── Fig3B_Comparison_Panel.png
│       ├── Fig4_Statistical_Inference_Enhanced.png
│       ├── Fig5_Sensitivity_Analysis_HighRes.png
│       └── Fig5_Sensitivity_Analysis_Fixed.png
└── DESCRIPTION                  # Package dependencies
```

`app.R` is fully self-contained — all reference data (44-sub-county Kenya Nyanza geography, WHO incidence rates, disease reference tables, and demo data generators) is embedded. No external data files are required to run the application.

------------------------------------------------------------------------

## 5. Research Foundation — Phases 1–5

### Phase 1 — The Digital Laboratory

**Objective:** Construct a rigorous "ground truth" dataset that mimics the complexity of real-world surveillance data.

The study population is modelled as an **Inhomogeneous Poisson Point Process (IPPP)**. The intensity function $\lambda(u)$ varies across the study window $W \subset \mathbb{R}^2$:

$$N(A) \sim \text{Poisson}\!\left(\int_A \lambda(u)\, du\right)$$

| Symbol | Meaning |
|------------------------------------|------------------------------------|
| $N(A)$ | Number of cases in area $A$ |
| $\lambda(u)$ | Intensity function (population density) at location $u$ |
| $\int_A \lambda(u)\, du$ | Total expected cases integrated across area $A$ |

**The Censoring Mechanism:** A void $V$ is defined at location $c$ with radius $r$. Reporting probability is conditional on location:

$$P(\text{report} \mid u) = \begin{cases} \epsilon & \text{if } u \in V \\ p_{\text{base}} & \text{if } u \notin V \end{cases}$$

| Symbol | Meaning |
|------------------------------------|------------------------------------|
| $V$ | The structural void (e.g., conflict-controlled zone) |
| $\epsilon$ | Leakage probability ($\approx 5\%$) — cases that escape suppression |
| $p_{\text{base}}$ | Base reporting rate in non-suppressed areas |

The leakage probability $\epsilon = 0.05$ ensures the void contains some noise points — making it indistinguishable from background noise to density-based methods, while remaining geometrically anomalous to DTM.

| Component | Description |
|------------------------------------|------------------------------------|
| Intensity function | Population density varies realistically across the study window |
| Structural void | Populated but silenced central zone |
| Leakage points | 5% of void cases escape into the record (real-world noise) |
| Background cases | Normal reporting in non-suppressed areas |

------------------------------------------------------------------------

### Phase 2 — The Failure Proof

**Objective:** Demonstrate mathematically that current gold-standard methods cannot detect the void.

#### Method A — Kernel Density Estimation

$$\hat{f}(x) = \frac{1}{nh} \sum_{i=1}^n K\!\left(\frac{x - X_i}{h}\right)$$

**Failure:** In the void, $n \to 0 \Rightarrow \hat{f}(x) \to 0$. The map shows the void as a dark cold spot — indistinguishable from an empty forest. The most dangerous zone looks safe.

#### Method B — Relative Risk (SaTScan logic)

$$RR(u) = \frac{\text{Density}(\text{Cases at } u)}{\text{Density}(\text{Controls at } u)}$$

**Failure:** In the void, case density → 0 while control density remains high:

$$RR_{\text{void}} = \frac{\approx 0}{\text{High}} \to 0$$

The method flags the silenced zone as a **statistically significant low-risk cluster** ($RR \approx 0.40$, $p < 0.05$) — actively certifying the most dangerous area as the safest.

> Both methods produce false negatives *with statistical confidence*. The void is not missed by accident; it is certified as safe.

------------------------------------------------------------------------

### Phase 3 — Topological Detection

**Objective:** Detect the structural void by measuring the geometry of point absence rather than point presence.

The Distance-to-Measure function is computed for every pixel $x$ in the study grid:

$$d_{m_0}(x) = \sqrt{\frac{1}{k} \sum_{i=1}^k \|x - X_{(i)}\|^2}$$

| Symbol | Meaning |
|------------------------------------|------------------------------------|
| $x$ | Grid location being tested |
| $X_{(i)}$ | The $i$-th nearest observed case |
| $k = \lceil m_0 \cdot n \rceil$ | Neighbours needed to satisfy mass parameter $m_0$ |

**Why** $m_0 = 0.05$? With 5% leakage, a single leaked report inside the void would collapse the signal if $k = 1$. Setting $m_0 = 0.05$ forces the algorithm to accumulate 5% of all observations before reporting — robust to the same leakage rate built into the simulation.

**Result:** The void glows as a high-intensity anomaly (maximum DTM value) precisely where both KDE and Relative Risk produced darkness.

------------------------------------------------------------------------

### Phase 4 — Statistical Inference

**Objective:** Prove the detected void is not a visual artefact or random noise.

**Null hypothesis** $H_0$: The observed cases follow Complete Spatial Randomness (CSR).

**Test statistic — the "Void Score":** The L2 norm of the Persistence Landscape (Dimension 1), quantifying the total magnitude of all topological voids in the dataset:

$$T(X) = \|\lambda\|_2 = \sqrt{\int \lambda(t)^2\, dt}$$

| Symbol | Meaning |
|------------------------------------|------------------------------------|
| $T(X)$ | Void Score for point pattern $X$ |
| $\lambda(t)$ | Persistence Landscape — lifespan of topological features across scales $t$ |
| Higher $T(X)$ | Data contains large, persistent holes surviving across many spatial scales |

**Permutation procedure (**$N = 99$):

1.  Compute $T_{\text{obs}}$ on the real data
2.  Generate $N = 99$ null datasets from a Homogeneous Poisson Process (CSR) with the same intensity
3.  Compute $T_{\text{null}}^{(i)}$ for each null dataset

**P-value:**

$$\hat{p} = \frac{1 + \sum_{i=1}^{N} \mathbf{1}\!\left(T_{\text{null}}^{(i)} \geq T_{\text{obs}}\right)}{1 + N}$$

**Results:**

| Statistic                               | Value    |
|-----------------------------------------|----------|
| Observed void score $T_{\text{obs}}$    | 4.86     |
| Mean null score $\bar{T}_{\text{null}}$ | 1.22     |
| Effect size (Z-score)                   | \> 3.5   |
| P-value                                 | **0.02** |

The observed score falls more than 3.5 standard deviations above the null distribution — statistically confirmed as a real structural feature ($\alpha = 0.05$).

------------------------------------------------------------------------

### Phase 5 — Sensitivity Analysis

**Objective:** Verify that results are not dependent on arbitrary parameter choices.

Tested across filtration scales 1.0 km – 3.0 km with $N = 999$ permutations.

**Finding — The Topological Horizon:**

| Scale  | P-value | Significant? |
|--------|---------|--------------|
| 1.0 km | \> 0.10 | ❌ No        |
| 1.5 km | \< 0.01 | ✅ Yes       |
| 2.0 km | \< 0.01 | ✅ Yes       |
| 2.5 km | \< 0.01 | ✅ Yes       |
| 3.0 km | \< 0.01 | ✅ Yes       |

At 1.0 km the detector is too short-sighted to bridge leakage points inside the void. Once the scale exceeds 1.5 km, the signal is robust and stable — results are not dependent on precise parameter tuning once this geometric threshold is crossed.

------------------------------------------------------------------------

## 6. Key Results Summary

| Method | Detects void? | Classification in void | Verdict |
|------------------|------------------|------------------|------------------|
| KDE | ❌ No | Low density — "safe area" | **FALSE** |
| Relative Risk | ❌ No | Significant low-risk cluster ($RR \approx 0.40$) | **FALSE** |
| **DTM (this work)** | ✅ **Yes** | High-intensity anomaly — "investigate" | **CORRECT** |

**Quantitative validation:**

| Metric                         | Value                             |
|--------------------------------|-----------------------------------|
| Observed void score            | 4.86                              |
| Mean null score (CSR baseline) | 1.22                              |
| Effect size (Z-score)          | \> 3.5                            |
| P-value                        | 0.02                              |
| Permutations (primary test)    | 99                                |
| Permutations (sensitivity)     | 999                               |
| Robustness                     | Confirmed for all scales ≥ 1.5 km |

------------------------------------------------------------------------

## 7. The Application — TDA v2.1

The research is operationalized as a production-ready Shiny application (`app.R`, \~3,150 lines). A surveillance officer with a CSV exported from DHIS2 or KHIS can load their data, run spatial and temporal void analysis, and receive a classified, downloadable report without writing a line of code.

### Interface Layout

```         
┌─────────────────────────────────────────────────────────────────────┐
│  TOPBAR                                                             │
│  [logo] TDA v2.1   [Map][Alerts][Temporal][Guide] ≡ │
├───────────────────────────────────────┬─────────────────────────────┤
│                                       │  SIDEBAR                    │
│  MAIN CONTENT AREA                    │  (persistent — never hidden │
│                                       │   by tab switching)         │
│  Map      — Leaflet dark map          │                             │
│  Alerts   — Priority alert cards      │  ▣ Stage 1: Disease/Period  │
│  Temporal — Classification table      │  ▣ Stage 2: Data source     │
│  Guide    — Inline documentation      │  ▣ Stage 3: Load data       │
│                                       │  ▣ Stage 4: Run analysis    │
│                                       │                             │
│                                       │  ── KPIs ──────────────     │
│                                       │  Critical │ Moderate │ Voids│
│                                       │                             │
│                                       │  ── Downloads ─────────     │
│                                       │  Brief · GeoJSON · CSV      │
│                                       │  Temporal Report            │
│                                       │                             │
│                                       │  ── Status ────────────     │
│                                       │  ● Ready                    │
└───────────────────────────────────────┴─────────────────────────────┘
```

> **Architectural note:** The sidebar is a DOM sibling to all tab panels — not a child of any of them. `display:none` on a tab panel cannot cascade into it, and all download handlers remain registered with Shiny regardless of which tab is active.

### Progressive Stage Gates

| Stage | Unlocks when | Controls revealed | Indicator |
|------------------|------------------|------------------|------------------|
| **1** | App load | Disease selector + Reporting period | 🔓 Always open |
| **2** | Disease + period selected | Data source pills | 🔒 → 🔓 |
| **3** | Source selected | Load / upload controls | 🔒 → 🔓 |
| **4** | Valid data loaded | Parameters + Run buttons + KPI strip | 🔒 → 🔓 → ✓ |

### The Four Tabs

**Map** — Interactive Leaflet map on a CartoDB Dark Matter basemap. Three toggleable overlay groups: *Completeness* (circle markers colour-coded by O/E ratio), *Voids* (DTM-derived polygons in red), *Rings* (Minimum Enclosing Circles for field planning).

**Alerts** — Prioritised alert cards per sub-county below threshold, sorted by severity. Each card shows O/E ratio, expected vs. reported counts, causal classification badge with action recommendation, and coordinates for field deployment. Exportable as HTML brief → PDF.

**Temporal** — Classification table showing `STRUCTURAL` / `INTERMITTENT` / `STOCHASTIC` labels, $P(\text{structural})$, Fano factor, critical/total period counts, and mean O/E per unit. Exportable as HTML temporal report → PDF.

**Guide** — Inline reference covering O/E formula, DTM methodology, temporal classification theory, causal taxonomy, real data source walkthroughs, and citation.

------------------------------------------------------------------------

## 8. Analysis Methods in Detail

### O/E Ratio and Completeness Engine

**Expected case count:**

$$\text{Expected} = \frac{\text{Population} \times \text{Rate per 1,000}}{1,000 \times \text{Period divisor}}$$

| Period    | Divisor |
|-----------|---------|
| Annual    | 1       |
| Quarterly | 4       |
| Monthly   | 12      |
| Weekly    | 52      |

**O/E ratio:**

$$\frac{O}{E} = \frac{\text{Reported cases}}{\max(\text{Expected},\ 0.1)}$$

The 0.1 floor prevents division-by-zero in sparsely populated units.

**Completeness classes** (thresholds are disease-specific):

| Class | O/E range | Meaning |
|------------------------|------------------------|------------------------|
| **Critical** | \< `critical` | Severe surveillance gap — likely structural |
| **Moderate** | `critical` – `moderate` | Significant gap — monitoring required |
| **Mild** | `moderate` – `mild` | Below-adequate but not alarming |
| **Adequate** | ≥ `mild` | Reporting within expected bounds |

------------------------------------------------------------------------

### DTM Spatial Void Detection

**Step 1 — Projection.** Input coordinates (WGS84) are projected to the appropriate UTM zone, EPSG code auto-detected from the centroid.

**Step 2 — Weighted point cloud.** Each admin unit is weighted by its `deficit_rate` (deficit cases per 1,000 population). Units are replicated proportionally so larger deficits exert more geometric influence on the DTM surface.

**Step 3 — Grid construction.** A regular grid is placed over the convex hull of the study area (10–35 cells per axis, adaptive).

**Step 4 — DTM computation.**

$$d_{m_0}(x) = \sqrt{\frac{1}{k} \sum_{i=1}^k \|x - X_{(i)}\|^2}, \quad k = \left\lceil m_0 \cdot n \right\rceil$$

Computed via `TDA::dtm()` with automatic fallback to direct k-NN mean for degenerate inputs.

**Step 5 — Threshold detection.** The Kneedle algorithm detects the curvature knee on the sorted DTM distribution to identify the void/non-void boundary.

**Step 6 — Rasterisation and polygonisation.** Void cells above threshold are rasterised via `raster::rasterFromXYZ()` and dissolved into polygons via `raster::rasterToPolygons(dissolve=TRUE)`. Each polygon is enriched with area (km²), enclosed admin units, mean O/E, total deficit, and total population.

**Step 7 — Minimum Enclosing Circles.** Welzl's algorithm computes the minimum enclosing circle for each polygon. Circles with radius \> 500 m are added as Ring overlays on the map.

**Stability check:** Automatically re-runs at $m_0 \times \{0.6,\ 1.0,\ 1.4\}$ — results flagged as `stable` (count range ≤ 2) or `variable`.

------------------------------------------------------------------------

### Causal Classification

```         
Is the void near an international border AND mean O/E < 0.25?
    ├── YES → BORDER
    │         Cross-border population — cases reported in neighbouring system
    └── NO  ↓

Is road density index < 0.35?
    ├── YES → ACCESS
    │         Physical inaccessibility — geographic barrier to facility use
    └── NO  ↓

Is facility density < 0.5 per 100 km²?
    ├── YES → INFRASTRUCTURE
    │         No proximate reporting point — facility gap
    └── NO  ↓

Is O/E > 0.05 despite deficit?
    ├── YES → SYSTEM
    │         Facilities present but data not reaching the system
    │         (data entry, submission, or aggregation failure)
    └── NO  → UNKNOWN
              Silence confirmed — mechanism requires field investigation
```

Each cause class carries a `detail` explanation and `action` recommendation displayed in the Alerts panel and the exported Brief.

------------------------------------------------------------------------

### Temporal Classification — Fano Factor + HMM

Given that a unit is silent — *is that silence persistent and structural, or just random fluctuation?*

**Method 1 — Fano Factor:**

$$F = \frac{\text{Var}(O/E)}{\text{Mean}(O/E)}$$

For a Poisson process, $F \approx 1$. Structural silencing produces either a stable low-floor series ($F < 1$, low CV) or an erratic series with deep drops ($F \gg 1$). Stochastic silencing fluctuates around an adequate mean.

**Method 2 — Two-State HMM with Viterbi Decoding:**

A two-state Hidden Markov Model fitted entirely in base R — no external package. The two latent states are **Silent** ($O/E <$ threshold) and **Reporting** ($O/E$ adequate).

| Parameter | Value |
|------------------------------------|------------------------------------|
| Emission | $\mathcal{N}(\mu_k, \sigma_k)$ per state |
| Transition matrix $A$ | 2×2, initialised with persistence bias ($A_{ii} = 0.80$–$0.85$) |
| Initial state distribution $\pi_0$ | $[0.3,\ 0.7]$ |
| Fitting | Baum-Welch EM, 3 iterations |
| Decoding | Viterbi algorithm |

The fraction of periods assigned to the Silent state by Viterbi becomes $P(\text{structural})$.

**Final decision rule:**

| $P(\text{structural})$ | Label | Action |
|------------------------|------------------------|------------------------|
| ≥ 0.60 | `STRUCTURAL` | Persistent barrier. Field investigation required. |
| 0.35 – 0.60 | `INTERMITTENT` | Partial/seasonal suppression. Monitor 2 more periods. |
| \< 0.35 | `STOCHASTIC` | Poisson noise. No structural barrier evident. |

**Fano override:** If HMM returns `INTERMITTENT` but CV \< 0.20 and mean O/E \< 1.5× threshold → upgraded to `STRUCTURAL`. If CV \> 0.50 → downgraded to `STOCHASTIC`.

------------------------------------------------------------------------

## 9. Data Inputs

### Demo Data

The built-in demo covers **44 sub-counties from Kenya's Nyanza region** — Kisumu, Homa Bay, Siaya, Migori, Kisii, and Nyamira counties — with real-geography coordinates, population estimates, facility counts, and road density indices. Case counts are generated from WHO-calibrated incidence rates with controlled stochastic noise.

A **six-period temporal demo** is embedded with structured STRUCTURAL and STOCHASTIC trajectories so both classification paths are visible from the first run.

### Upload Your Own CSV

**Required columns** (flexible aliasing):

| Field | Primary | Also accepted as |
|------------------------|------------------------|------------------------|
| Admin unit | `admin_unit` | `orgunit`, `org_unit`, `subcounty`, `facility` |
| Reported cases | `reported_cases` | `cases`, `value`, `count` |
| Population | `population` | `pop`, `total_pop` |
| Latitude | `lat` | `latitude`, `y` |
| Longitude | `long` | `longitude`, `lon`, `x` |

**Optional:** `county`, `period`, `area_km2`, `road_index`, `facility_count`

**Artifacts handled automatically:** trailing whitespace, mixed case headers, numeric-as-string values, missing-period rows, DHIS2 `org_unit_uid` columns, \~3% duplicate rows.

A **"Realistic Noisy CSV" generator** is available in Stage 3 — it produces a correctly-formatted file with all the above artifacts injected for parser testing or as a formatting template.

### Real Data Sources

**WHO GHO API** — Disease-specific CSV download links from the WHO Global Health Observatory v8 API. Country-level annual aggregates.

**DHIS2 Demo Server**

```         
URL:         https://play.dhis2.org/40.6.1/dhis-web-data-visualizer/index.html
Credentials: admin / district
Path:        Apps → Data Visualiser → Pivot Table → indicator + org unit + period
             → Download → Plain data source → CSV → rename columns
```

**Kenya KHIS**

```         
URL:  https://hiskenya.org/dhis-web-data-visualizer/index.html
Auth: Free registration required
Path: Data Visualiser → Pivot Table → sub-county level → export CSV
```

### Supported Diseases

| Disease | ICD | Reference rate | Unit | Critical O/E |
|---------------|---------------|---------------|---------------|---------------|
| Malaria | B50–B54 | 225 | cases / 1,000 / yr | 0.20 |
| Cholera / AWD | A00 | 3.5 | cases / 1,000 / yr | 0.15 |
| Tuberculosis | A15–A19 | 220 | cases / 100,000 / yr | 0.30 |
| Measles | B05 | 8.2 | cases / 1,000 under-5 / yr | 0.10 |
| Maternal Deaths | O00–O99 | 0.53 | deaths / 1,000 live births | 0.20 |
| Meningitis | G00–G03 | 10 | cases / 100,000 / yr | 0.20 |
| HIV New Infections | B20–B24 | 3.0 | new infections / 1,000 adults / yr | 0.25 |

------------------------------------------------------------------------

## 10. Quick Start

### Installation

``` r
install.packages(c("shiny", "leaflet", "shinyjs", "sf", "TDA", "raster"))
```

### Launch

``` r
shiny::runApp(".")
# or open app.R in RStudio and click Run App
```

### Fastest path to results

```         
1.  App opens — Stage 1 active
2.  Select disease (default: Malaria) and period (default: Monthly)
3.  Stage 2 unlocks → select "Demo Data"
4.  Stage 3 unlocks → click "Use Demo Dataset"
5.  Stage 4 unlocks → click "Detect Surveillance Gaps"
    → Map populates in ~5 seconds
    → KPI counters update: Critical / Moderate / Voids
6.  Click Alerts tab → prioritised sub-county cards with causal labels
7.  Click "Run Temporal Analysis" in the sidebar
    → Auto-loads 6-period demo if no history present
    → Runs Fano + HMM classification immediately
    → Switches to Temporal tab automatically
8.  Read STRUCTURAL / INTERMITTENT / STOCHASTIC per-unit results
9.  Download: Spatial Brief · GeoJSON · Completeness CSV · Temporal Report
```

------------------------------------------------------------------------

## 11. Analysis Pipeline

```         
Input (CSV upload or demo)
        │
        ▼
.parse_csv()
├── Column aliasing  (orgunit → admin_unit, value → reported_cases …)
├── Type coercion    (character numerics, whitespace stripping)
├── Duplicate removal
└── Validation       (≥5 rows with valid lat/long required)
        │
        ▼
.compute_completeness()
├── Expected  = population × rate / (1000 × period_divisor)
├── O/E ratio = reported_cases / max(expected, 0.1)
├── Deficit   = max(expected − reported_cases, 0)
└── Class: Critical / Moderate / Mild / Adequate
        │
        ▼
.dtm_voids()
├── .utm_epsg()               UTM zone auto-detection
├── Deficit-weighted point cloud
├── Convex hull grid          (10–35 cells per axis)
├── TDA::dtm()                [+ fallback k-NN mean]
├── .kneedle()                curvature-based threshold
├── raster::rasterFromXYZ + rasterToPolygons(dissolve=TRUE)
├── Polygon attribute enrichment
└── .mec()                    minimum enclosing circles
        │
        ▼
.classify_cause()             per void polygon
└── BORDER / ACCESS / INFRASTRUCTURE / SYSTEM / UNKNOWN
        │
        ▼
Stability check
└── Re-run at m0 × {0.6, 1.0, 1.4} → stable / variable
        │
        ▼
[v$results updated — Map, Alerts, KPIs refresh]
        │
        ▼
[Optional — when ≥2 reporting periods available]
        │
        ▼
.classify_void_temporality()      per admin unit × O/E series
├── .fano_factor()    Var(O/E) / Mean(O/E)
├── .hmm_2state()     Baum-Welch EM (3 iter) + Viterbi [pure base R]
└── STRUCTURAL / INTERMITTENT / STOCHASTIC + interpretation text
        │
        ▼
[v$temporal updated — Temporal tab refreshes automatically]
```

------------------------------------------------------------------------

## 12. Outputs and Exports

| Export | Format | Contents |
|------------------------|------------------------|------------------------|
| **Spatial Brief** | Self-contained HTML → PDF | Summary stats, void list with causal labels, completeness breakdown, per-unit O/E table, citation |
| **GeoJSON** | `.geojson` | Void polygons: ID, area km², admin units, mean O/E, deficit, population |
| **Completeness CSV** | `.csv` | Per-unit: admin unit, county, O/E, deficit, class, expected, reported, population, lat, long |
| **Temporal Report** | Self-contained HTML → PDF | Per-unit classification, P(structural), Fano, critical/total periods, mean O/E, interpretation |
| **Sample CSV** | `.csv` | Clean correctly-formatted template |
| **Noisy CSV** | `.csv` | DHIS2-artifact template for parser testing |

All HTML reports include `@media print` CSS for clean white PDF conversion via the browser print dialog, generation timestamp, and a DOI citation watermark.

------------------------------------------------------------------------

## 13. Limitations & Ethics

### Computational Limitations

**Scale.** DTM requires $O(n^2)$ pairwise distance calculations. The implementation handles sub-county scale data without issue; for larger datasets the fallback k-NN mean is triggered automatically. For national-scale point-level data (\>10,000 observations), pre-aggregation to admin unit level is recommended.

**Parameter sensitivity.** The $m_0$ parameter assumes domain knowledge about expected leakage rates. The automatic stability check at $m_0 \times \{0.6, 1.0, 1.4\}$ flags sensitive results, but selecting an appropriate baseline for a new context requires epidemiological judgment. Users should test multiple $m_0$ values, consult local reporting estimates, and validate against ground truth where possible.

**Causal classification.** The BORDER / ACCESS / INFRASTRUCTURE / SYSTEM decision tree is a structured approximation. It produces investigative leads, not definitive diagnoses. All classifications must be validated with field knowledge before driving resource allocation decisions.

**2D-only implementation.** Current methods operate in two-dimensional space. Real epidemiology often requires spatiotemporal analysis (space + time), network-based analyses (transportation routes, referral pathways), or multi-level hierarchical modelling.

### Ethics Statement

This tool is designed to direct resources *toward* silenced populations — not to identify them for surveillance or targeting.

**Dual-use risk.** Void detection identifies geographic areas where reporting is suppressed. In conflict or humanitarian contexts, this could be misused to identify populations avoiding detection for safety reasons, target resources away from contested areas, or enable political surveillance. Any real deployment must include explicit use agreements prohibiting non-humanitarian applications, community oversight committees, and transparent data governance protocols.

**Data sovereignty and consent.** Any application to real sub-national administrative data must comply with national data governance frameworks, obtain institutional ethical clearance, and be implemented in active partnership with affected communities.

**Permitted use.** The outputs — surveillance gap maps, void classifications, alert cards — are designed exclusively as inputs to healthcare resource deployment decisions. They are not intelligence products, law enforcement surveillance tools, or evidence for punitive actions.

**Transparency obligation.** All analyses, parameters, and classifications should be publicly documented, reproducible by independent researchers, subject to regular ethical review, and open to community audit.

> The ethical foundation of this work rests on the principle that statistical methods should serve vulnerable populations — not expose them to additional risk.

------------------------------------------------------------------------

## 14. Reproducibility

### Reproduce all manuscript figures

``` r
set.seed(20260615)

source("scripts/01_generate_process.R")
source("scripts/02_compare_methods.R")
source("scripts/03_topological_scan.R")
source("scripts/04_inference.R")
source("scripts/05_sensitivity.R")
```

**Requirements:** R ≥ 4.3.0, packages: `spatstat`, `ggplot2`, `sf`, `TDA`, `TDAstats`, `viridis`, `ggforce`

### Run the application

``` r
# Requirements: shiny, leaflet, shinyjs, sf, TDA, raster
shiny::runApp(".")
```

All simulated data is regenerated from code on every run. There are no external data file dependencies.

------------------------------------------------------------------------

## 15. Citation

### Companion Preprint (Mathematical Foundations)

``` bibtex
@article{mboya2026geometry,
  title   = {TDA Engine v1.0: A Computational Framework for Detecting Structural Voids in Spatially Censored Epidemiological Data},
  author  = {Mboya, Grold Otieno},
  journal = {Preprint on Zenodo},
  year    = {2026},
  doi     = {10.5281/zenodo.18244299},
  url     = {https://doi.org/10.5281/zenodo.18244299}
}
```

### Application (Software Citation)

``` bibtex
@software{mboya2026tda,
  title   = {TDA Engine v2.1: Geometry of Silence ---
             A Sentinel Silence Monitor for Disease Surveillance Systems},
  author  = {Mboya, Grold Otieno},
  year    = {2026},
  doi     = {10.64898/2026.02.01.26345283},
  url     = {https://doi.org/10.64898/2026.02.01.26345283},
  license = {GPL-3.0}
}
```

### DOI Quick Reference

| Resource | DOI | Link |
|------------------------|------------------------|------------------------|
| Preprint | 10.5281/zenodo.18244299 | [doi.org/10.5281/zenodo.18244299](https://doi.org/10.5281/zenodo.18244299) |
| Application | 10.64898/2026.02.01.26345283 | [doi.org/10.64898/2026.02.01.26345283](https://doi.org/10.64898/2026.02.01.26345283) |
| Live Demo | — | [gro7d.shinyapps.io/TDA-Engine-Preview](https://gro7d.shinyapps.io/TDA-Engine-Preview/) |

------------------------------------------------------------------------

*Mboya Grold Otieno · doi: [10.64898/2026.02.01.26345283](https://doi.org/10.64898/2026.02.01.26345283)*
