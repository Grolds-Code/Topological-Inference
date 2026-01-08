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
Instead of a simple Uniform Distribution ($H_0$), I modeled the population as an **Inhomogeneous Poisson Point Process (IPPP)**. The intensity function $\lambda(u)$ varies across the study window $W \subset \mathbb{R}^2$:

$$N(A) \sim \text{Poisson}\left(\int_A \lambda(u) du\right)$$

* **Background Heterogeneity:** $\lambda(u)$ is defined by Gaussian kernels to simulate urban clusters (towns) and sparse rural areas. This ensures the method is robust against natural population variance.
* **The Censoring Mechanism:** A "Void" $V$ is defined at location $c$ with radius $r$. The reporting probability $P(\text{report})$ is conditional on location:
    $$P(\text{report} \mid u) = \begin{cases} \epsilon & \text{if } u \in V \text{ (Leakage $\approx$ 5\%)} \\ p_{base} & \text{if } u \notin V \text{ (Normal Reporting)} \end{cases}$$

**Biostatistical Relevance:** Real data is never clean. By including $\epsilon$ (leakage), I ensure the void contains *some* noise points. This "messy" data breaks standard topological tools (like Vietoris-Rips) and necessitates the robust DTM approach.

---

## 4. Phase 2: The "Straw Man" Attack (Methodological Comparison)
**Objective:** To mathematically prove that the current "Gold Standard" methods fail to detect the simulated void.

### Method A: Kernel Density Estimation (KDE)
**Rationale:** KDE is the standard method for visualizing disease "heatmaps."
**Formula:**
$$\hat{f}(x) = \frac{1}{nh} \sum_{i=1}^n K\left(\frac{x - X_i}{h}\right)$$
* **The Failure:** KDE depends strictly on the presence of points. In a structural void, $n \to 0$, forcing $\hat{f}(x) \to 0$. The map inevitably shows the warlord's zone as a "Cold Spot" (Low Density), indistinguishable from an empty forest (see Figure 2A).

### Method B: Relative Risk (Spatial Scan Statistic Logic)
**Rationale:** This logic, used by **SaTScan**, compares the density of cases to the density of controls (population).
**Formula:**
$$RR(u) = \frac{\text{Density}(Cases \text{ at } u)}{\text{Density}(Controls \text{ at } u)}$$
* **The Failure:** In the simulated void, the Case Density drops to near zero (due to suppression), but the Control Density (Background Population) remains high (people still live there).
* **Mathematical Consequence:**
    $$RR_{void} = \frac{\approx 0}{\text{High}} \to 0$$
* **Result:** As demonstrated in **Figure 2B**, the method flags the silenced zone as a **Statistically Significant Low-Risk Cluster** ($RR \approx 0.40$). It essentially certifies the most dangerous area as the safest.

### Phase 2 Outputs
* **`figures/Fig2A_KDE_Failure.png`**: KDE Heatmap showing the "Density Fallacy."
* **`figures/Fig2B_Risk_Failure.png`**: Relative Risk Map showing the "Cluster Bias."

![Relative Risk Failure](output/figures/Fig2B_Risk_Failure.png)

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