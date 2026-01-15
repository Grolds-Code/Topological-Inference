# PHASE 5: SENSITIVITY ANALYSIS (Publication Grade)

# Objective: Prove robustness across scales with N=999 precision.
# Warning:   This script is computationally intensive. Expect ~45-60 mins runtime.

# --- 1. SETUP ---
if(!require(pacman)) install.packages("pacman")
pacman::p_load(TDA, spatstat, ggplot2, dplyr)

# Load Phase 1 Data
if(!exists("observed_data")) {
  message("Loading Phase 1 Data...")
  source("01_simulation.R")
}

# Define Output Paths
figures_dir <- "output/figures"
tables_dir <- "output/tables"

# --- 2. DEFINE SCORING FUNCTION ---
get_void_score <- function(point_data, max_scale) {
  if(inherits(point_data, "ppp")) {
    coords <- data.frame(x = point_data$x, y = point_data$y)
  } else {
    coords <- point_data[, c("x", "y")]
  }
  
  diag <- ripsDiag(X = coords, maxdimension = 1, maxscale = max_scale,
                   library = "GUDHI", printProgress = FALSE)
  tseq <- seq(0, max_scale, length = 500)
  land <- landscape(Diag = diag[["diagram"]], dimension = 1, KK = 1, tseq = tseq)
  return(sqrt(sum(land^2)))
}

# --- 3. RUN SENSITIVITY LOOP (HIGH PRECISION) ---
scales <- c(1.0, 1.5, 2.0, 2.5, 3.0)
win <- owin(c(0, 10), c(0, 10))
gbv_cases <- ppp(observed_data$x, observed_data$y, window = win)
n_points <- gbv_cases$n

# SETTINGS FOR PUBLICATION
N_perms <- 999  # Precision down to p = 0.001

message(paste("--- STARTING HIGH-PRECISION ANALYSIS (N =", N_perms, ") ---"))
message("This will take time. Please wait...")

sensitivity_results <- data.frame()

for(s in scales) {
  message(paste("\nTesting Scale parameter:", s, "km..."))
  
  # 1. Observed Score
  obs <- get_void_score(gbv_cases, max_scale = s)
  
  # 2. Null Distribution Loop (with Progress Bar)
  null_scores <- numeric(N_perms)
  pb <- txtProgressBar(min = 0, max = N_perms, style = 3)
  
  for(i in 1:N_perms) {
    random_pp <- rpoint(n_points, win = win)
    null_scores[i] <- get_void_score(random_pp, max_scale = s)
    setTxtProgressBar(pb, i)
  }
  close(pb)
  
  # 3. Calculate Precision P-Value
  p_val <- (sum(null_scores >= obs) + 1) / (N_perms + 1)
  
  # Store
  sensitivity_results <- rbind(sensitivity_results, 
                               data.frame(Scale = s, 
                                          Observed_Score = obs, 
                                          P_Value = p_val,
                                          Null_Mean = mean(null_scores),
                                          N_Perms = N_perms))
}

# --- 4. VISUALIZATION (Reviewer-Ready) ---
p5 <- ggplot(sensitivity_results, aes(x = Scale, y = P_Value)) +
  # Significance Thresholds
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "red") +
  geom_hline(yintercept = 0.01, linetype = "dotted", color = "darkred") +
  
  annotate("text", x = max(scales), y = 0.055, label = "p = 0.05 (Significant)", 
           color = "red", vjust = 0, hjust = 1, size = 3) +
  annotate("text", x = max(scales), y = 0.015, label = "p = 0.01 (Very Significant)", 
           color = "darkred", vjust = 0, hjust = 1, size = 3) +
  
  # The Results
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(size = 4, color = "darkblue") +
  
  # Formatting
  labs(title = "Figure 5: Sensitivity Analysis (High Precision)",
       subtitle = paste0("Robustness check with N=", N_perms, " permutations per scale"),
       x = "Max Scale Parameter (km)",
       y = "P-Value") +
  theme_minimal() +
  ylim(0, 0.1)

print(p5)
ggsave(file.path(figures_dir, "Fig5_Sensitivity_Analysis_HighRes.png"), p5, width = 8, height = 5, bg="white")
write.csv(sensitivity_results, file.path(tables_dir, "sensitivity_analysis_final.csv"), row.names = FALSE)

message("--- PHASE 5 COMPLETE: Ready for Publication ---")


# Load the results we just calculated
sensitivity_results <- read.csv(file.path(tables_dir, "sensitivity_analysis_final.csv"))

# Re-plot with a flexible Y-axis
p5_fixed <- ggplot(sensitivity_results, aes(x = Scale, y = P_Value)) +
  # Threshold Lines
  geom_hline(yintercept = 0.05, linetype = "dashed", color = "red") +
  annotate("text", x = max(scales), y = 0.06, label = "Significance (0.05)", 
           color = "red", vjust = 0, hjust = 1, size = 3) +
  
  # The Data
  geom_line(color = "steelblue", linewidth = 1.2) +
  geom_point(size = 4, color = "darkblue") +
  
  # Formatting
  labs(title = "Figure 5: Sensitivity Analysis (High Precision)",
       subtitle = paste0("Robustness check (N=", N_perms, "). Note loss of significance at low scale."),
       x = "Max Scale Parameter (km)",
       y = "P-Value") +
  theme_minimal() +
  # FIX: Allow axis to go up to the max p-value observed (plus a little buffer)
  ylim(0, max(sensitivity_results$P_Value) * 1.1) 

print(p5_fixed)
ggsave(file.path(figures_dir, "Fig5_Sensitivity_Analysis_Fixed.png"), 
       p5_fixed, width = 8, height = 5, bg="white")