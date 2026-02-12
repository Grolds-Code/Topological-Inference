# PREP SCRIPT: Simulate "Suppressed Reporting" in Nyanza
# Run this ONCE locally.

library(dplyr)
library(readr)

# 1. Load your real facility data
# (Ensure you have this file from the previous step)
df <- read_csv("nyanza_real_data.csv", show_col_types = FALSE)

# 2. Assign Synthetic HIV Prevalence (The "Risk" Layer)
# Based on 2023 estimates: Homa Bay/Kisumu (~15-18%), others lower
df_sim <- df %>%
  mutate(
    risk_profile = case_when(
      county %in% c("Homa Bay", "Kisumu") ~ "High",
      county %in% c("Siaya", "Migori") ~ "Medium",
      TRUE ~ "Low"
    ),
    # Simulate prevalence: High = 15-25%, Med = 10-15%, Low = 2-8%
    sim_prevalence = case_when(
      risk_profile == "High" ~ runif(n(), 15, 25),
      risk_profile == "Medium" ~ runif(n(), 10, 15),
      TRUE ~ runif(n(), 2, 8)
    )
  )

# 3. THE CENSORSHIP EVENT (The "Void")
# Scenario: "Surveillance Failure in Homa Bay"
# We systematically DELETE 40% of facilities in high-prevalence areas of Homa Bay.
# This creates a "Structural Void" that correlates with high disease burden.

set.seed(2026) # Reproducibility is key!

# Identify targets for censorship (Homa Bay + High Prevalence)
targets <- which(df_sim$county == "Homa Bay" & df_sim$sim_prevalence > 18)

# Remove 60% of them to create a visible hole
censored_indices <- sample(targets, size = length(targets) * 0.6)

# Create the final dataset
df_final <- df_sim[-censored_indices, ]

# 4. Save for the App
write_csv(df_final, "simulated_censorship.csv")

# Stats for your thesis
cat(sprintf("Original Facilities: %d\n", nrow(df)))
cat(sprintf("Censored Facilities: %d\n", nrow(df_final)))
cat(sprintf("Removed %d facilities from high-burden Homa Bay zones.\n", length(censored_indices)))