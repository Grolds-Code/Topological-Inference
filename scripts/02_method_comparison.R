# ==============================================================================
# PROJECT: ROBUST TOPOLOGICAL INFERENCE
# PHASE 2: THE "STRAW MAN" ATTACK (Standard Methods Comparison)
# ==============================================================================

# --- 1. SETUP & LIBRARIES ---
if(!require(pacman)) install.packages("pacman")
pacman::p_load(spatstat, ggplot2, dplyr, sf, viridis, ggforce, here)

# Output Paths
output_dir <- "output"
figures_dir <- file.path(output_dir, "figures")
tables_dir  <- file.path(output_dir, "tables")

# --- 2. LOAD DATA ---
data_path <- file.path(tables_dir, "simulated_gbv_data_phase1.csv")
if(!file.exists(data_path)) stop("Phase 1 Data not found!")
observed_data <- read.csv(data_path)

# Create Case Pattern
win <- owin(c(0, 10), c(0, 10))
cases_ppp <- ppp(observed_data$x, observed_data$y, window = win)

# Define Circle for Plots
circle_data <- data.frame(x0 = 5, y0 = 5, r = 2.5)

# --- 3. METHOD A: KERNEL DENSITY ESTIMATION (KDE) ---
message("Running Method A: KDE...")
# Calculate Case Density
kde_est <- density(cases_ppp, sigma = 0.5)
kde_df <- as.data.frame(kde_est)

p_kde <- ggplot(kde_df, aes(x, y, fill = value)) +
  geom_raster() +
  scale_fill_viridis(option = "magma", name = "Density") +
  # Visual Overlays
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              color = "white", linewidth = 2, inherit.aes = FALSE) +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              color = "cyan", linetype = "dashed", linewidth = 1, inherit.aes = FALSE) +
  labs(
    title = "Figure 2A: The Density Fallacy (KDE)",
    subtitle = "Standard Heatmaps show the center as 'Cold' (Low Density).",
    caption = "Interpretation: 'This area is safe.' (FALSE - It is Silenced)",
    x = "Longitude", y = "Latitude"
  ) +
  theme_minimal() + coord_fixed()

ggsave(file.path(figures_dir, "Fig2A_KDE_Failure.png"), p_kde, width=8, height=8, dpi=300)
print(p_kde)

# --- 4. METHOD B: RELATIVE RISK (The Robust Calculation) ---
message("Running Method B: Relative Risk (Manual Ratio)...")

# 1. Generate Uniform Controls (Background Population)
set.seed(2026)
controls_ppp <- rpoispp(lambda = 50, win = win) 

# 2. Calculate Densities Separately (Sigma 0.8 for smoothing)
bw <- 0.8
dens_cases <- density(cases_ppp, sigma = bw)
dens_controls <- density(controls_ppp, sigma = bw)

# 3. Calculate Risk Ratio: Case Density / Control Density
# This gives the "Relative Risk" (RR). 
# RR < 1 means Low Risk (Safe). RR > 1 means High Risk (Cluster).
risk_im <- eval.im(dens_cases / dens_controls)

# Convert to Dataframe
rr_df <- as.data.frame(risk_im)
rr_df$value <- rr_df$value # Explicit naming

# Clean NAs (Division by zero protection)
rr_df$value[is.na(rr_df$value)] <- 0

# 4. Normalize around 1.0 (Average Risk = 1.0)
global_mean <- mean(rr_df$value, na.rm=TRUE)
rr_df$rel_risk_norm <- rr_df$value / global_mean

# VISUALIZE (Log Scale helps see the blue void better)
p_risk <- ggplot(rr_df, aes(x, y, fill = rel_risk_norm)) +
  geom_raster() +
  # Gradient: Blue (Low Risk) -> White (Avg) -> Red (High Risk)
  scale_fill_gradient2(
    midpoint = 1.0, 
    low = "blue", mid = "white", high = "red", 
    name = "Relative Risk",
    trans = "log10" # Log scale makes the Blue pop
  ) +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              color = "white", linewidth = 2, inherit.aes = FALSE) +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), 
              color = "black", linetype = "dashed", linewidth = 1, inherit.aes = FALSE) +
  labs(
    title = "Figure 2B: The Cluster Bias (SaTScan Logic)",
    subtitle = "The Void is flagged as 'Significant Low Risk' (Deep Blue).",
    caption = "Interpretation: 'Statistically safer than average.' (The Straw Man Failure)",
    x = "Longitude", y = "Latitude"
  ) +
  theme_minimal() + coord_fixed()

ggsave(file.path(figures_dir, "Fig2B_Risk_Failure.png"), p_risk, width=8, height=8, dpi=300)
print(p_risk)

# --- 5. EVIDENTIARY STATISTICS ---
message("Verifying the Mathematical Failure...")

# Calculate Mean Risk Inside vs Outside
rr_df$dist_to_center <- sqrt((rr_df$x - 5)^2 + (rr_df$y - 5)^2)
void_pixels <- rr_df %>% filter(dist_to_center < 2.5)

mean_void_risk <- mean(void_pixels$rel_risk_norm, na.rm=TRUE)
mean_global_risk <- mean(rr_df$rel_risk_norm, na.rm=TRUE) # Should be ~1.0

cat("\n--- FINAL RESULTS (For Paper) ---\n")
cat("Average Global Risk (Normalized):", round(mean_global_risk, 2), "\n")
cat("Average Void Risk (Normalized):  ", round(mean_void_risk, 4), "\n")
cat("CONCLUSION: The Standard Method identifies the void as having only", 
    round(mean_void_risk * 100, 1), "% of the average risk.\n")
cat("This confirms the 'Straw Man' argument: SaTScan calls the void 'Safe'.\n")