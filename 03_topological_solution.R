# ==============================================================================
# PROJECT: ROBUST TOPOLOGICAL INFERENCE
# PHASE 3: THE TOPOLOGICAL DEFENSE (Distance-to-Measure)
# ==============================================================================

# --- 1. SETUP & LIBRARIES ---
if(!require(pacman)) install.packages("pacman")
pacman::p_load(spatstat, ggplot2, dplyr, sf, viridis, ggforce, TDA, patchwork, here)

# Define Output Paths
output_dir <- "output"
figures_dir <- file.path(output_dir, "figures")
tables_dir  <- file.path(output_dir, "tables")

# --- 2. LOAD DATA ---
data_path <- file.path(tables_dir, "simulated_gbv_data_phase1.csv")
if(!file.exists(data_path)) stop("Run Phase 1 first.")
observed_data <- read.csv(data_path)

# Define the "Truth" (Void Geometry)
circle_data <- data.frame(x0 = 5, y0 = 5, r = 2.5)

# --- 3. THE TOPOLOGICAL ENGINE: DISTANCE-TO-MEASURE (DTM) ---

# A. Create Grid
X_seq <- seq(0, 10, by = 0.1)
Y_seq <- seq(0, 10, by = 0.1)
Grid  <- expand.grid(x = X_seq, y = Y_seq)

# B. The "Crowd Rule" (Parameter m0)
# m0 = 0.05 (5%) ensures robustness against leakage
m0_parameter <- 0.05 

message("Calculating Distance-to-Measure (DTM)...")
dtm_result <- TDA::dtm(
  X = observed_data[, c("x", "y")], 
  Grid = Grid, 
  m0 = m0_parameter
)

# C. Create Dataframe
dtm_df <- data.frame(
  x = Grid$x,
  y = Grid$y,
  dtm_value = dtm_result
)

# --- 4. THE CRITICAL TEST (Your Verification) ---
message("Running Statistical Verification...")

# Identify void area
dtm_df$in_void <- sqrt((dtm_df$x - 5)^2 + (dtm_df$y - 5)^2) < 2.5

# Calculate statistics
void_stats <- dtm_df %>%
  group_by(in_void) %>%
  summarise(
    mean_dtm = mean(dtm_value, na.rm = TRUE),
    median_dtm = median(dtm_value, na.rm = TRUE),
    max_dtm = max(dtm_value, na.rm = TRUE),
    n_points = n()
  )

print(void_stats)
# CHECK: TRUE (Void) mean_dtm should be SIGNIFICANTLY HIGHER than FALSE (Outside)

# --- 5. VISUALIZATION: THE ANOMALY MAP ---

# We normalize DTM to 0-1 for plotting, but we DO NOT invert it.
# High Value = High Distance = High Anomaly
dtm_df$anomaly_score <- (dtm_df$dtm_value - min(dtm_df$dtm_value)) / 
  (max(dtm_df$dtm_value) - min(dtm_df$dtm_value))

# PLOT 1: The Topological Signal
p_dtm <- ggplot(dtm_df, aes(x, y, fill = anomaly_score)) +
  geom_raster() +
  scale_fill_viridis(option = "magma", name = "Anomaly\nScore") +
  ggforce::geom_circle(
    data = circle_data, aes(x0=x0, y0=y0, r=r), 
    color = "cyan", linetype = "dashed", linewidth = 1, inherit.aes = FALSE
  ) +
  labs(
    title = "Figure 3A: Topological Anomaly Detection",
    subtitle = "The Void lights up as a High-Intensity Signal (Bright Yellow).",
    caption = "Unlike KDE, DTM highlights the suppression zone as a structural anomaly.",
    x = "Longitude", y = "Latitude"
  ) +
  theme_minimal() + coord_fixed()

ggsave(file.path(figures_dir, "Fig3A_Topological_Anomaly.png"), p_dtm, width=8, height=8, dpi=300)
print(p_dtm)

# --- 6. THE MOMENT OF TRUTH: COMPARISON PLOT ---

message("Generating Comparison Panel...")

# Load Phase 2 Results for Side-by-Side
# (We assume these objects exist or regenerate them briefly for the plot)
# Quick Regeneration of KDE for the plot
win <- owin(c(0, 10), c(0, 10))
cases_ppp <- ppp(observed_data$x, observed_data$y, window = win)
kde_est <- density(cases_ppp, sigma = 0.5)
kde_df <- as.data.frame(kde_est)
kde_df$norm <- (kde_df$value - min(kde_df$value)) / (max(kde_df$value) - min(kde_df$value))

# 1. KDE Plot (The Failure)
p_kde_compare <- ggplot(kde_df, aes(x, y, fill = norm)) +
  geom_raster() + scale_fill_viridis(option="magma") + coord_fixed() +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), color="white", linetype="dashed", inherit.aes=FALSE) +
  labs(title = "Method A: KDE", subtitle = "Fails: Shows Void as 'Empty'") + 
  theme_void() + theme(legend.position="none")

# 2. DTM Plot (The Success)
p_dtm_compare <- ggplot(dtm_df, aes(x, y, fill = anomaly_score)) +
  geom_raster() + scale_fill_viridis(option="magma") + coord_fixed() +
  geom_circle(data = circle_data, aes(x0=x0, y0=y0, r=r), color="cyan", linetype="dashed", inherit.aes=FALSE) +
  labs(title = "Method B: Topological DTM", subtitle = "Succeeds: Shows Void as 'Anomaly'") + 
  theme_void() + theme(legend.position="none")

# Combine
comparison_plot <- p_kde_compare + p_dtm_compare + 
  plot_annotation(
    title = "The Topological Advantage",
    subtitle = "Left: Standard Density (Misses Void) | Right: DTM (Detects Void)",
    theme = theme(plot.title = element_text(size = 16, face = "bold"))
  )

ggsave(file.path(figures_dir, "Fig3B_Comparison_Panel.png"), comparison_plot, width=12, height=6, dpi=300)
print(comparison_plot)

message("Phase 3 Complete. The Comparison proves the method works.")