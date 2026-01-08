# Topological Inference for Detecting Structural Voids in Spatially Censored Epidemiological Data
**Principal Investigator:** Grold Otieno Mboya  
**Status:** Phase 1 (Simulation & Ground Truth Generation)  
**Language:** R (spatstat, sf, ggplot2)

---

## 1. Project Overview
In conflict-affected or high-stigma regions, the absence of disease/violence reports does not always imply safety. Often, it implies **systematic suppression**—a "Zone of Silence." 

Standard spatial statistics (KDE, SaTScan) typically misclassify these zones as "Low Risk" because they rely on density. This project develops a **Topological Data Analysis (TDA)** framework using **Distance-to-Measure (DTM)** and **Persistence Landscapes** to correctly identify these structural voids as anomalies, not safe havens.

---

## 2. Phase 1: The Digital Laboratory (Data Simulation)
Before testing the method, we established a rigorous "Ground Truth" dataset representing a Kenyan sub-county ($10 \times 10$ km).

### Methodology
Unlike simple uniform simulations, this project utilizes an **Inhomogeneous Poisson Point Process (IPPP)** to mimic realistic population heterogeneity.

#### A. Population Density (The Background)
We modeled population density $\lambda(x,y)$ using Gaussian kernels to create:
* **Town Cluster:** High density (simulating an urban center).
* **Village Cluster:** Moderate density.
* **Rural Background:** Low sparse density.
* **Significance:** This ensures that voids are detected against a varying background, preventing trivial findings based on simple low-population areas.

#### B. The "Siege of Silence" (The Anomaly)
We injected a structural void to simulate suppressed reporting of Gender-Based Violence (GBV).
* **Location:** Centered at $(5, 5)$ with radius $r=2.5$ km.
* **The "Leakage" Factor:** Inside the void, reporting is not 0%. It is suppressed to **5% probability**.
* **Why Leakage Matters:** Real data is noisy. A few "brave" reports often leak out from silenced zones. These outliers break standard Topological methods (Vietoris-Rips). This simulation creates the specific "messy" conditions required to demonstrate the superiority of the **Distance-to-Measure (DTM)** filtration used in Phase 3.

### Phase 1 Outputs
The simulation generated the following artifacts (stored in `output/`):

* **`figures/Fig1_Simulated_Void.png`**: Visualization of the Inhomogeneous Point Process with the true void boundary overlaid.
![Simulated Void](output/figures/Fig1_Simulated_Void.png)

* **`tables/simulated_gbv_data_phase1.csv`**: The raw $(x,y)$ coordinate data for observed cases.

---

## 3. Project Roadmap
* **Phase 1:** Realistic Data Simulation (Completed) ✅
* **Phase 2:** The "Straw Man" Attack (Demonstrating failure of SaTScan/KDE)
* **Phase 3:** Topological Solution (DTM + Persistence Landscapes) 
* **Phase 4:** Statistical Validation (Permutation Testing) 

---
*Repository maintained by Grolds-Code.*