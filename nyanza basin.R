# Load necessary libraries
library(tibble)
library(dplyr)
library(sf)
library(ggplot2)

# SET SEED FOR REPRODUCIBILITY
set.seed(20260615)

# 1. SET OUTPUT DIRECTORY
output_dir <- "synthetic_nyanza_data"
dir.create(output_dir, showWarnings = FALSE)
cat(sprintf("Output directory: %s/\n", output_dir))

# 2. SETUP: Define the Region (Kisumu to Homa Bay Corridor)
bbox <- list(
  xmin = 34.45,  # West of Kisumu
  xmax = 35.10,  # East of Homa Bay
  ymin = -0.70,  # South of Homa Bay
  ymax = -0.05   # North of Kisumu
)

# Total study area (approx)
area_width_km <- (bbox$xmax - bbox$xmin) * 111.32
area_height_km <- (bbox$ymax - bbox$ymin) * 111.32
total_area_km2 <- area_width_km * area_height_km

cat(sprintf("Study Area: %.1f km x %.1f km = %.1f km²\n", 
            area_width_km, area_height_km, total_area_km2))

# 3. GENERATE BACKGROUND POPULATION (Inhomogeneous Poisson Process)
n_total <- 800  # Total facility points

background_points <- function(n, bbox) {
  urban_centers <- list(
    kisumu = list(x = 34.76, y = -0.09, weight = 0.4),
    ahero = list(x = 34.92, y = -0.18, weight = 0.2),
    katito = list(x = 34.88, y = -0.25, weight = 0.15),
    homa_bay = list(x = 34.47, y = -0.53, weight = 0.25)
  )
  
  points <- tibble()
  
  for(i in 1:n) {
    center <- sample(urban_centers, 1, prob = sapply(urban_centers, function(c) c$weight))[[1]]
    sd_factor <- ifelse(center$weight > 0.3, 0.02, 0.04)
    
    lon <- rnorm(1, center$x, sd_factor)
    lat <- rnorm(1, center$y, sd_factor)
    
    lon <- pmax(bbox$xmin, pmin(lon, bbox$xmax))
    lat <- pmax(bbox$ymin, pmin(lat, bbox$ymax))
    
    points <- bind_rows(points, tibble(
      id = i,
      long = lon,
      lat = lat,
      type = "facility"
    ))
  }
  
  return(points)
}

df <- background_points(n_total, bbox)

# 4. CARVE STRUCTURAL VOIDS (3 voids, total ~42.7 km²)
structural_voids <- list(
  list(
    name = "Ahero_Corridor",
    center = c(34.86, -0.17),
    radius_km = 2.5,  # Area ~19.6 km²
    density_multiplier = 0.05
  ),
  list(
    name = "Katito_Gap",
    center = c(34.83, -0.25),
    radius_km = 2.0,  # Area ~12.6 km²
    density_multiplier = 0.10
  ),
  list(
    name = "Kendu_Periphery",
    center = c(34.65, -0.36),
    radius_km = 1.8,  # Area ~10.2 km²
    density_multiplier = 0.08
  )
)

structural_area <- sum(sapply(structural_voids, function(v) pi * v$radius_km^2))
cat(sprintf("Structural Voids: 3 voids, total area = %.1f km²\n", structural_area))

apply_void <- function(data, void) {
  center_lon <- void$center[1]
  center_lat <- void$center[2]
  radius_deg <- void$radius_km / 111.32
  
  data %>%
    mutate(
      distance_deg = sqrt((long - center_lon)^2 + (lat - center_lat)^2),
      in_void = distance_deg < radius_deg,
      keep = ifelse(in_void, runif(n()) > void$density_multiplier, TRUE)
    ) %>%
    filter(keep) %>%
    select(-distance_deg, -in_void, -keep)
}

for(void in structural_voids) {
  df <- apply_void(df, void)
}

# 5. CARVE STOCHASTIC VOIDS (5 voids, total ~105.3 km²)
stochastic_voids <- list(
  list(
    name = "Lake_Victoria_West",
    center = c(34.48, -0.10),
    radius_km = 5.0  # Area ~78.5 km²
  ),
  list(
    name = "Rusinga_Forest",
    center = c(34.20, -0.42),
    radius_km = 2.0  # Area ~12.6 km²
  ),
  list(
    name = "Homa_Hills",
    center = c(34.55, -0.45),
    radius_km = 1.5  # Area ~7.1 km²
  ),
  list(
    name = "Lambwe_Valley",
    center = c(34.40, -0.65),
    radius_km = 1.2  # Area ~4.5 km²
  ),
  list(
    name = "Gwasi_Hills",
    center = c(34.30, -0.70),
    radius_km = 0.9  # Area ~2.6 km²
  )
)

stochastic_area <- sum(sapply(stochastic_voids, function(v) pi * v$radius_km^2))
cat(sprintf("Stochastic Voids: 5 voids, total area = %.1f km²\n", stochastic_area))

apply_stochastic_void <- function(data, void) {
  center_lon <- void$center[1]
  center_lat <- void$center[2]
  radius_deg <- void$radius_km / 111.32
  
  data %>%
    filter(!(sqrt((long - center_lon)^2 + (lat - center_lat)^2) < radius_deg))
}

for(void in stochastic_voids) {
  df <- apply_stochastic_void(df, void)
}

# 6. ADD NOISE (real-world imperfections)
add_noise <- function(data, n_noise = 15) {
  noise_points <- tibble(
    id = (max(data$id) + 1):(max(data$id) + n_noise),
    long = runif(n_noise, bbox$xmin, bbox$xmax),
    lat = runif(n_noise, bbox$ymin, bbox$ymax),
    type = "noise"
  )
  
  bind_rows(data, noise_points)
}

df <- add_noise(df)

# 7. CREATE POPULATION DENSITY GRID
create_population_grid <- function(bbox, df, resolution_km = 2) {
  res_deg <- resolution_km / 111.32
  
  # Create grid
  long_seq <- seq(bbox$xmin, bbox$xmax, by = res_deg)
  lat_seq <- seq(bbox$ymin, bbox$ymax, by = res_deg)
  
  grid <- expand.grid(long = long_seq, lat = lat_seq) %>%
    as_tibble()
  
  # Initialize columns
  grid$pop_density <- 1000  # Baseline
  grid$in_structural_void <- FALSE
  grid$in_stochastic_void <- FALSE
  
  # Calculate facility influence
  facility_coords <- as.matrix(df[, c("long", "lat")])
  
  # Vectorized distance calculation
  for(i in 1:nrow(grid)) {
    distances <- sqrt((grid$long[i] - facility_coords[,1])^2 + 
                        (grid$lat[i] - facility_coords[,2])^2)
    influence <- sum(exp(-distances * 100))
    
    # Update based on influence
    grid$pop_density[i] <- grid$pop_density[i] * (1 + influence/50)
  }
  
  # Mark structural voids
  for(void in structural_voids) {
    radius_deg <- void$radius_km / 111.32
    distances <- sqrt((grid$long - void$center[1])^2 + (grid$lat - void$center[2])^2)
    grid$in_structural_void <- grid$in_structural_void | (distances < radius_deg)
  }
  
  # Mark stochastic voids
  for(void in stochastic_voids) {
    radius_deg <- void$radius_km / 111.32
    distances <- sqrt((grid$long - void$center[1])^2 + (grid$lat - void$center[2])^2)
    grid$in_stochastic_void <- grid$in_stochastic_void | (distances < radius_deg)
  }
  
  # Apply void adjustments
  grid <- grid %>%
    mutate(
      pop_density = case_when(
        in_stochastic_void ~ 0,
        in_structural_void ~ pop_density * 0.8,
        TRUE ~ pop_density
      )
    )
  
  return(grid)
}

pop_grid <- create_population_grid(bbox, df)

# 8. VISUALIZATION
p <- ggplot() +
  # Population density background
  geom_tile(data = pop_grid, 
            aes(x = long, y = lat, fill = pop_density),
            alpha = 0.3) +
  scale_fill_viridis_c("Population\n(persons/km²)", option = "plasma") +
  
  # Facility points
  geom_point(data = df, aes(x = long, y = lat), 
             size = 1.5, alpha = 0.7, color = "#2c3e50") +
  
  # Structural voids (red outlines)
  annotate("path", 
           x = structural_voids[[1]]$center[1] + 
             structural_voids[[1]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = structural_voids[[1]]$center[2] + 
             structural_voids[[1]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "red", size = 1.2, linetype = "solid") +
  annotate("path", 
           x = structural_voids[[2]]$center[1] + 
             structural_voids[[2]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = structural_voids[[2]]$center[2] + 
             structural_voids[[2]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "red", size = 1.2, linetype = "solid") +
  annotate("path", 
           x = structural_voids[[3]]$center[1] + 
             structural_voids[[3]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = structural_voids[[3]]$center[2] + 
             structural_voids[[3]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "red", size = 1.2, linetype = "solid") +
  
  # Stochastic voids (blue outlines)
  annotate("path", 
           x = stochastic_voids[[1]]$center[1] + 
             stochastic_voids[[1]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = stochastic_voids[[1]]$center[2] + 
             stochastic_voids[[1]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "blue", size = 1, linetype = "dashed", alpha = 0.7) +
  annotate("path", 
           x = stochastic_voids[[2]]$center[1] + 
             stochastic_voids[[2]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = stochastic_voids[[2]]$center[2] + 
             stochastic_voids[[2]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "blue", size = 1, linetype = "dashed", alpha = 0.7) +
  annotate("path", 
           x = stochastic_voids[[3]]$center[1] + 
             stochastic_voids[[3]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = stochastic_voids[[3]]$center[2] + 
             stochastic_voids[[3]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "blue", size = 1, linetype = "dashed", alpha = 0.7) +
  annotate("path", 
           x = stochastic_voids[[4]]$center[1] + 
             stochastic_voids[[4]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = stochastic_voids[[4]]$center[2] + 
             stochastic_voids[[4]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "blue", size = 1, linetype = "dashed", alpha = 0.7) +
  annotate("path", 
           x = stochastic_voids[[5]]$center[1] + 
             stochastic_voids[[5]]$radius_km/111.32 * cos(seq(0, 2*pi, length.out = 100)),
           y = stochastic_voids[[5]]$center[2] + 
             stochastic_voids[[5]]$radius_km/111.32 * sin(seq(0, 2*pi, length.out = 100)),
           color = "blue", size = 1, linetype = "dashed", alpha = 0.7) +
  
  # Labels
  geom_label(data = tibble(
    label = c("Kisumu", "Ahero", "Katito", "Kendu Bay", "Homa Bay"),
    long = c(34.76, 34.92, 34.88, 34.65, 34.47),
    lat = c(-0.09, -0.18, -0.25, -0.36, -0.53)
  ), aes(x = long, y = lat, label = label),
  size = 3, alpha = 0.8) +
  
  # Theme
  labs(
    title = "Synthetic Nyanza Basin Health Facility Distribution",
    subtitle = "Red circles: Structural voids (high pop, suppressed)\nBlue dashed: Stochastic voids (natural empty)",
    x = "Longitude",
    y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    plot.subtitle = element_text(size = 10, color = "gray40"),
    legend.position = "right"
  ) +
  coord_equal()

# Display plot
print(p)

# 9. SAVE ALL FILES TO THE SAME DIRECTORY
cat("\n=== SAVING FILES ===\n")

# Save plot
plot_path <- file.path(output_dir, "synthetic_nyanza_distribution.png")
ggsave(plot_path, 
       plot = p,
       width = 10,
       height = 8,
       dpi = 300,
       bg = "white")
cat(sprintf("✓ Plot saved: %s\n", plot_path))

# Save facility locations
facilities_path <- file.path(output_dir, "synthetic_nyanza_facilities.csv")
write.csv(df %>% select(long, lat), 
          facilities_path, 
          row.names = FALSE)
cat(sprintf("✓ Facilities saved: %s (%d points)\n", facilities_path, nrow(df)))

# Save population grid
popgrid_path <- file.path(output_dir, "synthetic_nyanza_population_grid.csv")
write.csv(pop_grid, 
          popgrid_path, 
          row.names = FALSE)
cat(sprintf("✓ Population grid saved: %s (%d cells)\n", popgrid_path, nrow(pop_grid)))

# Save void metadata
void_metadata <- bind_rows(
  lapply(structural_voids, function(v) {
    tibble(
      type = "structural",
      name = v$name,
      center_long = v$center[1],
      center_lat = v$center[2],
      radius_km = v$radius_km,
      area_km2 = pi * v$radius_km^2,
      suppression_rate = 1 - ifelse(is.null(v$density_multiplier), 0, v$density_multiplier)
    )
  }),
  lapply(stochastic_voids, function(v) {
    tibble(
      type = "stochastic",
      name = v$name,
      center_long = v$center[1],
      center_lat = v$center[2],
      radius_km = v$radius_km,
      area_km2 = pi * v$radius_km^2,
      suppression_rate = 1.0
    )
  })
)

metadata_path <- file.path(output_dir, "synthetic_nyanza_voids_metadata.csv")
write.csv(void_metadata, 
          metadata_path, 
          row.names = FALSE)
cat(sprintf("✓ Void metadata saved: %s (%d voids)\n", metadata_path, nrow(void_metadata)))

# 10. CREATE README FILE FOR THE DATASET
readme_content <- paste(
  "SYNTHETIC NYANZA BASIN DATASET",
  "===============================",
  "",
  "Generated: ", Sys.time(),
  "Seed: 20260615",
  "",
  "DESCRIPTION",
  "-----------",
  "This synthetic dataset simulates health facility distribution in the Nyanza Basin,",
  "Kenya, with artificially created voids for testing topological void detection methods.",
  "",
  "FILES",
  "-----",
  "1. synthetic_nyanza_distribution.png - Visualization map",
  "2. synthetic_nyanza_facilities.csv - Health facility coordinates (long, lat)",
  "3. synthetic_nyanza_population_grid.csv - Population density grid",
  "4. synthetic_nyanza_voids_metadata.csv - Specifications of all voids",
  "",
  "VOID SPECIFICATIONS",
  "-------------------",
  sprintf("Structural Voids: %d (total area: %.1f km²)", length(structural_voids), structural_area),
  "  - Ahero_Corridor: Radius 2.5 km, 95%% suppression",
  "  - Katito_Gap: Radius 2.0 km, 90%% suppression",
  "  - Kendu_Periphery: Radius 1.8 km, 92%% suppression",
  "",
  sprintf("Stochastic Voids: %d (total area: %.1f km²)", length(stochastic_voids), stochastic_area),
  "  - Lake_Victoria_West: Radius 5.0 km",
  "  - Rusinga_Forest: Radius 2.0 km",
  "  - Homa_Hills: Radius 1.5 km",
  "  - Lambwe_Valley: Radius 1.2 km",
  "  - Gwasi_Hills: Radius 0.9 km",
  "",
  "COORDINATE SYSTEM",
  "-----------------",
  "Coordinates are in WGS84 (EPSG:4326)",
  "Longitude range: 34.45°E to 35.10°E",
  "Latitude range: -0.70°S to -0.05°S",
  "",
  "USE IN TDA ENGINE",
  "-----------------",
  "1. Load synthetic_nyanza_facilities.csv as case data",
  "2. Use synthetic_nyanza_population_grid.csv for population denominator",
  "3. The TDA Engine should detect the 3 structural voids as high-risk suppressed zones",
  "4. The 5 stochastic voids should be classified as natural empty areas",
  sep = "\n"
)

readme_path <- file.path(output_dir, "README.txt")
writeLines(readme_content, readme_path)
cat(sprintf("✓ README saved: %s\n", readme_path))

# 11. SUMMARY
cat("\n=== SYNTHETIC DATA GENERATION COMPLETE ===\n")
cat(sprintf("All files saved to: %s/\n", output_dir))
cat(sprintf("Total facilities: %d\n", nrow(df)))
cat(sprintf("Study area: %.1f km²\n", total_area_km2))
cat(sprintf("Structural voids: %d, total area = %.1f km²\n", 
            length(structural_voids), structural_area))
cat(sprintf("Stochastic voids: %d, total area = %.1f km²\n", 
            length(stochastic_voids), stochastic_area))
cat(sprintf("Total void area: %.1f km² (%.1f%% of study area)\n",
            structural_area + stochastic_area,
            (structural_area + stochastic_area) / total_area_km2 * 100))

cat("\n=== FILES CREATED ===\n")
files <- list.files(output_dir, full.names = FALSE)
for(file in files) {
  file_size <- file.size(file.path(output_dir, file))
  cat(sprintf("• %s (%.1f KB)\n", file, file_size/1024))
}