SYNTHETIC NYANZA BASIN DATASET
===============================

Generated: 
2026-01-29 00:10:23.72292
Seed: 20260615

DESCRIPTION
-----------
This synthetic dataset simulates health facility distribution in the Nyanza Basin,
Kenya, with artificially created voids for testing topological void detection methods.

FILES
-----
1. synthetic_nyanza_distribution.png - Visualization map
2. synthetic_nyanza_facilities.csv - Health facility coordinates (long, lat)
3. synthetic_nyanza_population_grid.csv - Population density grid
4. synthetic_nyanza_voids_metadata.csv - Specifications of all voids

VOID SPECIFICATIONS
-------------------
Structural Voids: 3 (total area: 42.4 km²)
  - Ahero_Corridor: Radius 2.5 km, 95%% suppression
  - Katito_Gap: Radius 2.0 km, 90%% suppression
  - Kendu_Periphery: Radius 1.8 km, 92%% suppression

Stochastic Voids: 5 (total area: 105.2 km²)
  - Lake_Victoria_West: Radius 5.0 km
  - Rusinga_Forest: Radius 2.0 km
  - Homa_Hills: Radius 1.5 km
  - Lambwe_Valley: Radius 1.2 km
  - Gwasi_Hills: Radius 0.9 km

COORDINATE SYSTEM
-----------------
Coordinates are in WGS84 (EPSG:4326)
Longitude range: 34.45°E to 35.10°E
Latitude range: -0.70°S to -0.05°S

USE IN TDA ENGINE
-----------------
1. Load synthetic_nyanza_facilities.csv as case data
2. Use synthetic_nyanza_population_grid.csv for population denominator
3. The TDA Engine should detect the 3 structural voids as high-risk suppressed zones
4. The 5 stochastic voids should be classified as natural empty areas
