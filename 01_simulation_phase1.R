# ==============================================================================
# PROJECT: THE GEOMETRY OF SILENCE
# PHASE 1: REALISTIC DATA SIMULATION & DATA MANAGEMENT
# ==============================================================================

# --- 1. LIBRARIES & SETUP ---
if(!require(pacman)) install.packages("pacman")
pacman::p_load(spatstat, ggplot2, dplyr, ggforce, viridis, sf, here)

# Set seed for reproducibility (Legacy Year)
set.seed(2026) 

# --- 2. PROJECT ARCHITECTURE (File Management) ---
# We define a structured output system. 
# This ensures "tables and figures" are saved automatically.

# Define the output directory path
output_dir <- "output"
figures_dir <- file.path(output_dir, "figures")
tables_dir  <- file.path(output_dir, "tables")

# Create directories if they don't exist
if(!dir.exists(output_dir)) dir.create(output_dir)
if(!dir.exists(figures_dir)) dir.create(figures_dir)
if(!dir.exists(tables_dir)) dir.create(tables_dir)

message("Project Architecture Created:")
message(paste(" - Figures will be saved to:", figures_dir))
message(paste(" - Tables will be saved to: ", tables_dir))

# --- 3. THE SIMULATION (Digital Kenya) ---
# 10km x 10km Study Window
win <- owin(c(0, 10), c(0, 10))

# Define Inhomogeneous Density (Towns vs Villages)
density_function <- function(x, y) {
  50 * exp(-0.15 * ((x - 8)^2 + (y - 8)^2)) +  # Dense Town
    20 * exp(-0.10 * ((x - 2)^2 + (y - 2)^2)) +  # Small Village
    10                                           # Rural Background
}

# Generate True Population
true_pop <- rpoispp(density_function, win = win)
pop_df <- data.frame(x = true_pop$x, y = true_pop$y)

# --- 4. INJECT THE VOID (The Anomaly) ---
# Center (5,5), Radius 2.5km
void_x <- 5; void_y <- 5; void_r <- 2.5

# Define Reporting Probabilities (Simulating Suppression)
pop_df <- pop_df %>%
  mutate(
    dist_to_center = sqrt((x - void_x)^2 + (y - void_y)^2),
    # 5% reporting inside void (Noise), 42% outside (KDHS Standard)
    prob_report = ifelse(dist_to_center < void_r, 0.05, 0.42),
    is_reported = rbinom(n(), 1, prob_report)
  )

# Filter for Observed Data (What the Analyst sees)
observed_data <- pop_df %>% filter(is_reported == 1)

# --- 5. SAVE THE TABLE (The Data Artifact) ---
# We save the simulated dataset. This is crucial for reproducibility.
# Later, you can load this exact file to test DTM vs SaTScan.
table_path <- file.path(tables_dir, "simulated_gbv_data_phase1.csv")
write.csv(observed_data, table_path, row.names = FALSE)
message(paste("Data Table Saved:", table_path))

# --- 6. VISUALIZE & SAVE FIGURE (The Visual Evidence) ---
p1 <- ggplot(observed_data, aes(x = x, y = y)) +
  geom_point(alpha = 0.6, color = "black", size = 1.5) +
  geom_circle(aes(x0 = void_x, y0 = void_y, r = void_r), 
              color = "firebrick", linetype = "dashed", linewidth = 1, inherit.aes = FALSE) +
  labs(
    title = "Figure 1: Simulated GBV Reports with Structural Void",
    subtitle = "Simulating 'Digital Kenya' with Inhomogeneous Density + Suppression",
    caption = "Red Circle = True Void Boundary. Note the noise points inside (5% Leakage).",
    x = "Longitude (km)", y = "Latitude (km)"
  ) +
  theme_minimal() +
  coord_fixed()

# Print to screen
print(p1)

# Save to File (High Resolution for Publication)
figure_path <- file.path(figures_dir, "Fig1_Simulated_Void.png")
ggsave(filename = figure_path, plot = p1, width = 8, height = 8, dpi = 300)
message(paste("Figure Saved:", figure_path))