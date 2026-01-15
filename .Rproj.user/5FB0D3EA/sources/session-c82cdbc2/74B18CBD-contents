# Defense demo: The Geometry of Silence 

# Purpose:  Fast, live demonstration for Defense.

# Logic:    Runs live DTM detection but loads pre-computed stats.

if(!require(pacman)) install.packages("pacman")
pacman::p_load(TDA, spatstat, ggplot2, dplyr, viridis, ggforce)

# 1. LIVE SIMULATION 
message("--- STEP 1: Generative Process (Live) ---")
set.seed(42) 
win <- owin(c(0, 10), c(0, 10))

# Define the Void Geometry
void_center <- c(5, 5)
void_radius <- 2.5
circle_data <- data.frame(x0 = 5, y0 = 5, r = 2.5) # For cleaner plotting

# Background population (Inhomogeneous)
lambda_func <- function(x, y) { 30 * exp(-0.1 * ((x - 5)^2 + (y - 5)^2)) }
pp_full <- rpoispp(lambda_func, win = win)

# Apply Censoring
dist_to_center <- sqrt((pp_full$x - void_center[1])^2 + (pp_full$y - void_center[2])^2)
inside_void <- dist_to_center < void_radius

# 5% Leakage (The "Messy" Reality)
keep <- inside_void & runif(pp_full$n) < 0.05 | !inside_void
observed_data <- as.data.frame(pp_full[keep, ])

# Plot the "Raw" Data
p1 <- ggplot() +
  # Points from observed data
  geom_point(data = observed_data, aes(x, y), alpha=0.6, color="black") +
  # Circle from specific single-row data (Fixes the warning)
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              linetype="dashed", color="red") +
  labs(title="1. The Data Input", 
       subtitle="Sparse reports. Is the center safe or silenced?") +
  coord_fixed(xlim=c(0,10), ylim=c(0,10)) + 
  theme_minimal()

print(p1)
readline(prompt="Press [Enter] to continue")

# 2. LIVE DETECTION (The DTM Algorithm)
message("--- STEP 2: Running Topological Detection (Live) ---")

Grid <- expand.grid(X = seq(0, 10, length.out = 80), 
                    Y = seq(0, 10, length.out = 80))


dtm_result <- dtm(X = observed_data[, c("x", "y")], 
                  Grid = Grid, 
                  m0 = 0.05) 

df_grid <- data.frame(Grid, DTM = dtm_result)

# Plot the Result
p2 <- ggplot(df_grid, aes(x = X, y = Y, fill = DTM)) +
  geom_tile() +
  scale_fill_viridis(option = "magma", direction = -1) +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              linetype="dashed", color="white", inherit.aes=FALSE) +
  labs(title="2. Topological Anomaly Detected", 
       subtitle="The algorithm identifies the structural void (Bright Yellow).") +
  coord_fixed() + 
  theme_minimal()

print(p2)
readline(prompt="Press [Enter] to continue")

# 3. STATISTICAL PROOF (Loading Pre-Computed)
message("--- STEP 3: Statistical Validation (Loading Results) ---")

# Checking if file exists, otherwise generate dummy plot for demo
if(file.exists("output/tables/sensitivity_analysis_final.csv")) {
  sensitivity_data <- read.csv("output/tables/sensitivity_analysis_final.csv")
  
  p3 <- ggplot(sensitivity_data, aes(x = Scale, y = P_Value)) +
    geom_hline(yintercept = 0.05, linetype="dashed", color="red") +
    geom_line(color="steelblue", linewidth=1.2) +
    geom_point(size=4, color="darkblue") +
    labs(title="3. Robustness Check", 
         subtitle="P-value < 0.05 for all valid scales (1.5km+).") +
    ylim(0, 0.1) + 
    theme_minimal()
  print(p3)
} else {
  message("Note: Sensitivity data not found. Run Phase 5 to generate Step 3 plot.")
}

message("--- DEMO COMPLETE ---")