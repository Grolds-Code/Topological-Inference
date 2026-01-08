# Topological Inference for Detecting Structural Voids in Spatially Censored Epidemiological Data

**Principal Investigator:** Grold Otieno Mboya  
**Status:** Ongoing (Phases 1 & 2 Complete)

---

## 1. Abstract & Epidemiological Rationale
In conflict-affected regions, disease surveillance data is often **Censored Not at Random (CNAR)**. High-risk zones controlled by warlords or subject to extreme stigma often report *zero* cases, not because they are safe, but because they are silenced.

**The Problem:** Standard epidemiological tools (Kernel Density Estimation, SaTScan) rely on **Spatial Scan Statistic Logic**, which assumes that low case counts imply low risk. When applied to censored data, these tools dangerously misclassify "Structural Voids" (silenced zones) as "Low-Risk Clusters," potentially diverting humanitarian aid away from the areas that need it most.

**The Solution:** This project proposes a novel framework using **Topological Data Analysis (TDA)**—specifically **Distance-to-Measure (DTM)** and **Persistence Landscapes**—to distinguish between:
1.  **Stochastic Voids:** Areas with no cases because no one lives there (True Low Risk).
2.  **Structural Voids:** Areas with dense populations but suppressed reporting (High Risk).

---

## 2. Technical Stack & Dependencies
This project is built entirely in **R**. The following packages are required for reproducibility:

| Package | Usage in Project |
| :--- | :--- |
| **`spatstat`** | Core engine for Point Process simulations (`rpoispp`) and Relative Risk calculations (`relrisk`). |
| **`ggplot2`** | High-precision visualization of spatial layers. |
| **`sf`** | Handling spatial geometries (Simple Features) and boundaries. |
| **`TDA` / `TDAstats`** | (Phase 3) Computation of Persistent Homology and DTM filtrations. |
| **`viridis`** | Perceptually uniform color maps for accessible scientific plotting. |
| **`ggforce`** | Drawing accurate geometric annotations (circles/void boundaries). |

---

## 3. Phase 1: The Digital Laboratory (Simulation)
**Objective:** To generate a rigorous "Ground Truth" dataset that mimics the complexity of real-world surveillance data.

### Mathematical Formulation
Instead of a simple Uniform Distribution, I modeled the population as an **Inhomogeneous Poisson Point Process (IPPP)**. The intensity function $\lambda(u)$ varies across the study window $W \subset \mathbb{R}^2$:

$$
N(A) \sim \text{Poisson}\left(\int_A \lambda(u) du\right)
$$

**Where:**
* $N(A)$: Number of cases in area $A$.
* $\lambda(u)$: The **Intensity Function** (Population Density) at location $u$.
* $\int_A$: Summation of density across the area.

---

**The Censoring Mechanism:**
A "Void" $V$ is defined at location $c$ with radius $r$. The reporting probability is conditional on location:

$$
P(\text{report} \mid u) = \begin{cases} 
\epsilon & \text{if } u \in V \\ 
p_{base} & \text{if } u \notin V 
\end{cases}
$$

**Where:**
* $V$: The **Structural Void** (e.g., sort of warlord-controlled zone).
* $\epsilon$ (Epsilon): **Leakage Probability** ($\approx 5\%$). The chance a case leaks out of the void.
* $p_{base}$: **Base Reporting Rate** (Normal reporting in safe areas).

**Biostatistical Relevance:** Real data is never clean. By including $\epsilon$ (leakage), I ensure the void contains *some* noise points. This "messy" data breaks standard topological tools (like Vietoris-Rips) and necessitates the robust DTM approach.

### Phase 1 Output
* **Figure 1:** Visualization of the Inhomogeneous Point Process with the true void boundary overlaid.

![Figure 1: Simulated Void](output/figures/Fig1_Simulated_Void.png)

---

## 4. Phase 2: The "Straw Man" Attack (Methodological Comparison)
**Objective:** To mathematically prove that the current "Gold Standard" methods fail to detect the simulated void.

### Method A: Kernel Density Estimation (KDE)
**Rationale:** KDE is the standard method for visualizing disease "heatmaps."

**Formula:**

$$
\hat{f}(x) = \frac{1}{nh} \sum_{i=1}^n K\left(\frac{x - X_i}{h}\right)
$$

**Where:**
* $\hat{f}(x)$: The estimated density at location $x$.
* $n$: Total number of observed cases.
* $h$: The **Bandwidth** (smoothing parameter).
* $K$: The **Kernel Function** (usually Gaussian) that spreads influence from each point $X_i$.

* **The Failure:** KDE depends strictly on the presence of points ($n$). In a structural void, $n \to 0$, forcing the density $\hat{f}(x)$ to zero. The map inevitably shows the warlord's zone as a "Cold Spot," indistinguishable from an empty forest.

**Figure 2A Output (The Density Fallacy):**
![Figure 2A: KDE Failure](output/figures/Fig2A_KDE_Failure.png)

---

### Method B: Relative Risk (Spatial Scan Statistic Logic)
**Rationale:** This logic, used by **SaTScan**, compares the density of cases to the density of controls (population).

**Formula:**

$$
RR(u) = \frac{\text{Density}(Cases \text{ at } u)}{\text{Density}(Controls \text{ at } u)}
$$

**Where:**
* $RR(u)$: **Relative Risk** at location $u$.
* $Cases$: The observed disease/crime events.
* $Controls$: The background population at risk.

* **The Failure:** In the simulated void, the Case Density drops to near zero (due to suppression), but the Control Density remains high (people still live there).
* **Mathematical Consequence:**
    $$RR_{void} = \frac{\approx 0}{\text{High}} \to 0$$
* **Result:** As demonstrated below, the method flags the silenced zone as a **Statistically Significant Low-Risk Cluster** ($RR \approx 0.40$). It essentially certifies the most dangerous area as the safest.

**Figure 2B Output (The Cluster Bias):**
![Figure 2B: Relative Risk Failure](output/figures/Fig2B_Risk_Failure.png)

---

## 5. Project Roadmap
* **[x] Phase 1:** Construction of the Inhomogeneous Point Process (Ground Truth).
* **[x] Phase 2:** Demonstration of the "Straw Man" Fallacy (KDE/SaTScan Failure).
* **[ ] Phase 3:** Implementation of Distance-to-Measure (DTM) filtration.
* **[ ] Phase 4:** Persistence Landscape statistical inference and permutation testing.

---

## Citation & Usage
This repository contains the source code for the ongoing research project: *"Topological Inference for Detecting Structural Voids."*

**Usage:**
This code is open for academic review and reproduction of results. If you utilize this framework in your own research, please cite the forthcoming manuscript (citation pending) or reference this repository:

> Mboya Grold Otieno. (2026). *Topological Surveillance Framework*. GitHub Repository. https://github.com/Grolds-Code/Topological-Inference

**License:**
MIT License - You are free to use, modify, and distribute this software, provided proper credit is given to the original author.