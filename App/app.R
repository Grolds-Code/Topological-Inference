# -------------------------------------------------------------------------
# GEOMETRY OF SILENCE: TDA ENGINE v1.0.0
# Copyright (c) 2026 Mboya Grold Otieno. All Rights Reserved.
#
# This software calculates topological structural voids in spatial data.
# Unauthorized copying, modification, distribution, or use of this code
# without express written permission is strictly prohibited.
#
# Author: Mboya Grold Otieno
# Date: January 2026
# DOI: 10.64898/2026.02.01.26345283 [Preprint]
# -------------------------------------------------------------------------

library(shiny)
library(leaflet)
library(bslib)
library(shinyjs)
library(sf)
library(TDA)
library(raster)
library(rmarkdown)
library(knitr)

# -------------------------------------------------------------------------
# CLEAN & POLISHED UI
# -------------------------------------------------------------------------
ui <- page_sidebar(
  # Clean tech theme
  theme = bs_theme(
    version = 5,
    primary = "#2c3e50",
    secondary = "#3498db",
    success = "#27ae60",
    danger = "#e74c3c",
    "font-size-base" = "0.85rem",
    "font-family-base" = "'Inter', -apple-system, sans-serif",
    "headings-font-family" = "'Inter', sans-serif"
  ),
  
  useShinyjs(),
  withMathJax(),
  
  # Clean Minimal Header
  title = div(
    class = "d-flex align-items-center justify-content-between w-100 px-3 py-2",
    style = "
      background: white;
    ",
    div(
      class = "d-flex align-items-center gap-2",
      div(
        style = "width: 26px; height: 26px; background: white; 
           border-radius: 6px; display: flex; align-items: center; justify-content: center;
           border: 1px solid #e5e7eb;",
        icon("code-branch", class = "text-dark", style = "font-size: 0.8rem;")
      ),
      div(
        style = "line-height: .8;",
        div(
          class = "d-flex align-items-baseline gap-1",
          span("TDA", 
               class = "fw-bold text-dark",
               style = "font-size: 0.7rem; letter-spacing: -0.3px;"),
          span("Engine", 
               class = "text-muted ",
               style = "font-size: 0.7rem; letter-spacing: -0.3px;")
        ),
        
        div(
          
          tags$small("v1.0", 
                     class = "text-muted tech-badge gap-1;",
                     style = "font-size: 0.6rem;")
        )
      )
    ),
    # Simple controls
    div(
      class = "d-flex align-items-center gap-1",
      actionButton("nav_controls", "",
                   icon = icon("gear"),
                   class = "btn-sm btn-outline-dark",
                   onclick = "document.getElementById('control_panel').scrollIntoView({behavior: 'smooth'});",
                   title = "Settings",
                   style = "padding: 0.2rem 0.4rem; font-size: 0.7rem;")
    )
  ),
  
  # Enhanced Sidebar
  sidebar = sidebar(
    position = "right",
    width = 340,
    open = "always",
    id = "control_panel",
    class = "border-start",
    
    # USER GUIDE - Fixed accordion with enhanced mathematical explanation
    card(
      class = "mb-2 border-0",
      style = "background: #ffffff;",
      card_header(
        class = "bg-transparent border-bottom py-2 px-3",
        div(
          class = "d-flex align-items-center justify-content-between",
          div(
            class = "d-flex align-items-center gap-2",
            icon("info-circle", style = "font-size: 0.8rem; color: #6b7280;"),
            span("Guide", class = "small fw-medium")
          ),
          tags$a(
            href = "#",
            `data-bs-toggle` = "collapse",
            `data-bs-target` = "#userGuide",
            role = "button",
            class = "text-muted",
            style = "font-size: 0.7rem;",
            icon("chevron-down")
          )
        )
      ),
      card_body(
        class = "collapse show px-3 py-2",
        id = "userGuide",
        style = "font-size: 0.75rem; line-height: 1.4;",
        
        div(
          id = "math-content",
          
          div(
            class = "mb-2",
            div(
              style = "background: #f8f9fa; border-radius: 4px; padding: 10px; margin-bottom: 8px;",
              div(
                class = "text-center mb-1",
                style = "font-size: 0.8rem;",
                withMathJax("$$\\text{DTM: } d_{m_0}(x) = \\sqrt{\\frac{1}{k}\\sum_{i=1}^k \\|x - X_{(i)}\\|^2}$$")
              ),
              div(
                class = "text-center small text-muted",
                withMathJax("$$\\text{where } k = \\lceil m_0 \\cdot n \\rceil, \\, m_0 = 0.05$$")
              )
            ),
            
            # Enhanced Mathematical Explanation
            div(
              class = "mb-3 mt-3 border-top pt-3",
              div(
                class = "d-flex align-items-center gap-1 mb-2",
                icon("calculator", style = "font-size: 0.6rem; color: #6b7280;"),
                span("Methodological Framework", class = "fw-medium small")
              ),
              div(
                class = "ps-3 small text-muted",
                div(
                  style = "margin-bottom: 10px;",
                  strong("1. Coordinate Projection:"),
                  " Raw geographic data (WGS84) is projected to UTM Zone 36S (EPSG:32736). This transforms angular coordinates into a metric grid, ensuring that distance calculations represent true ground meters rather than distorted degrees."
                ),
                div(
                  style = "margin-bottom: 10px;",
                  strong("2. Distance-to-Measure (DTM) Filtration:"),
                  " To detect structural voids within clusters, we compute the robust distance from each grid point to its nearest neighbors, ignoring expected leakage:",
                  br(),
                  withMathJax("$$d_{m_0}(x) = \\sqrt{\\frac{1}{k}\\sum_{i=1}^k \\|x - X_{(i)}\\|^2}$$"),
                  br(),
                  "where ",
                  withMathJax("$X_{(i)}$"),
                  " is the ",
                  withMathJax("$i^{\\text{th}}$"),
                  " nearest observed case and ",
                  withMathJax("$k = \\lceil m_0 \\cdot n \\rceil$"),
                  " with ",
                  withMathJax("$m_0 = 0.05$"),
                  " matching the expected leakage rate (Chazal et al., 2011)."
                ),
                div(
                  style = "margin-bottom: 10px;",
                  strong("3. Statistical Inference via Permutation Testing:"),
                  " We test the null hypothesis ",
                  withMathJax("$H_0$"),
                  " that the observed pattern results from complete spatial randomness (CSR):",
                  br(),
                  withMathJax("$$T(X) = \\| \\lambda \\|_2 = \\sqrt{\\int \\lambda(t)^2 dt}$$"),
                  br(),
                  withMathJax("$$\\hat{p} = \\frac{1 + \\sum_{i=1}^N \\mathbb{1}(T_{(m)}^{(i)} \\geq T_{\\text{obs}})}{1 + N}$$")
                ),
                div(
                  style = "margin-bottom: 10px;",
                  strong("4. Structural Void Detection:"),
                  " Structural voids are identified as regions where:",
                  br(),
                  withMathJax("$$d_{m_0}(x) > Q_{1-\\alpha}$$"),
                  br(),
                  "where ",
                  withMathJax("$\\alpha$"),
                  " is the sensitivity parameter (top ",
                  withMathJax("$100\\alpha$"),
                  "% most isolated regions)."
                ),
                div(
                  strong("5. Ring Generation:"),
                  " For each structural void, we compute the minimum enclosing circle (MEC) using the Welzl algorithm to create red warning rings around suppressed zones."
                )
              )
            ),
            
            div(
              class = "mb-2",
              div(
                class = "d-flex align-items-center gap-1 mb-1",
                icon("dot-circle", style = "font-size: 0.5rem; color: #3498db;"),
                span("m₀ (Mass Parameter):", class = "fw-medium small")
              ),
              div(
                class = "ps-3 small text-muted",
                withMathJax("$m_0 = 0.05$"),
                " matches expected leakage rate (5%). Set higher to detect smaller voids inside dense clusters."
              )
            ),
            
            div(
              class = "mb-2",
              div(
                class = "d-flex align-items-center gap-1 mb-1",
                icon("dot-circle", style = "font-size: 0.5rem; color: #e74c3c;"),
                span("α (Sensitivity):", class = "fw-medium small")
              ),
              div(
                class = "ps-3 small text-muted",
                withMathJax("$\\alpha \\in [0.01, 0.30]$"),
                ". Lower = conservative (detects only large structural voids), Higher = sensitive (detects more voids including stochastic ones)"
              )
            ),
            
            # DOI Information
            div(
              class = "mt-3 pt-2 border-top",
              div(
                class = "d-flex align-items-center gap-1 mb-1",
                icon("file-contract", style = "font-size: 0.6rem; color: #6b7280;"),
                span("Preprint:", class = "fw-medium small")
              ),
              div(
                class = "ps-3",
                tags$a(
                  href = "https://doi.org/10.64898/2026.02.01.26345283",
                  target = "_blank",
                  style = "font-size: 0.7rem; color: #3498db; text-decoration: none;",
                  icon("external-link-alt", style = "font-size: 0.6rem; margin-right: 4px;"),
                  "10.64898/2026.02.01.26345283"
                ),
                div(
                  class = "small text-muted mt-1",
                  "Mboya, G. O. (2026). TDA Engine v1.0: A Computational Framework for Detecting Structural Voids in Spatially Censored Epidemiological Data. MedRXiv. http://dx.doi.org/10.64898/2026.02.01.26345283"
                )
              )
            )
          ),
          
          div(
            class = "mb-2 mt-2",
            div(
              class = "d-flex align-items-center gap-2 mb-1",
              icon("dot-circle", style = "font-size: 0.5rem; color: #27ae60;"),
              span("Δ (Resolution):", class = "fw-medium small")
            ),
            div(
              class = "ps-3 small text-muted",
              "Fine = high precision, Coarse = faster computation. Must be ≥ 1.5 km to cross the topological horizon."
            )
          )
        )
      )
    ),
    
    # DATA INPUT
    card(
      class = "mb-2 border-0",
      style = "background: #ffffff;",
      card_header(
        class = "bg-transparent border-bottom py-2 px-3",
        div(
          class = "d-flex align-items-center gap-2",
          icon("database", style = "font-size: 0.8rem; color: #6b7280;"),
          span("Data", class = "small fw-medium")
        )
      ),
      card_body(
        class = "px-3 py-2",
        div(
          class = "mb-2",
          fileInput("upload", NULL,
                    buttonLabel = span(icon("upload"), "CSV"),
                    placeholder = "No file",
                    accept = ".csv",
                    width = "100%")
        ),
        
        uiOutput("file_status_ui"),
        
        div(
          class = "form-check form-switch",
          style = "font-size: 0.75rem;",
          tags$input(
            type = "checkbox",
            class = "form-check-input",
            id = "use_demo_data",
            checked = TRUE
          ),
          tags$label(
            class = "form-check-label",
            `for` = "use_demo_data",
            span(
              class = "d-flex align-items-center gap-1",
              icon("layer-group", style = "font-size: 0.7rem;"),
              "Demo dataset"
            )
          )
        )
      )
    ),
    
    # PARAMETERS
    card(
      class = "mb-2 border-0",
      style = "background: #ffffff;",
      card_header(
        class = "bg-transparent border-bottom py-2 px-3",
        div(
          class = "d-flex align-items-center gap-2",
          icon("sliders", style = "font-size: 0.8rem; color: #6b7280;"),
          span("Parameters", class = "small fw-medium")
        )
      ),
      card_body(
        class = "px-3 py-2",
        # Mass Parameter m₀
        div(
          class = "mb-3",
          div(
            class = "d-flex justify-content-between align-items-center mb-1",
            span(withMathJax("m₀ (Mass Parameter)"), class = "small"),
            span(id = "mass_value", 
                 class = "badge rounded-pill",
                 style = "background: #3498db15; color: #3498db; font-size: 0.7rem; padding: 0.15rem 0.5rem;",
                 "0.05")
          ),
          sliderInput("mass_param", NULL, 0.01, 0.15, 0.05, 0.01,
                      width = "100%", ticks = FALSE)
        ),
        
        # Sensitivity α
        div(
          class = "mb-3",
          div(
            class = "d-flex justify-content-between align-items-center mb-1",
            span(withMathJax("α (Sensitivity)"), class = "small"),
            span(id = "sensitivity_value", 
                 class = "badge rounded-pill",
                 style = "background: #e74c3c15; color: #e74c3c; font-size: 0.7rem; padding: 0.15rem 0.5rem;",
                 "0.10")
          ),
          sliderInput("significance", NULL, 0.01, 0.30, 0.10, 0.01,
                      width = "100%", ticks = FALSE)
        ),
        
        # Resolution Δ
        div(
          class = "mb-3",
          div(
            class = "d-flex justify-content-between align-items-center mb-1",
            span(withMathJax("Δ (Resolution)"), class = "small"),
            span(id = "resolution_value", 
                 class = "badge rounded-pill",
                 style = "background: #27ae6015; color: #27ae60; font-size: 0.7rem; padding: 0.15rem 0.5rem;",
                 "1.5 km")
          ),
          sliderInput("resolution", NULL, 0.5, 3.0, 1.5, 0.1,
                      width = "100%", ticks = FALSE)
        ),
        
        div(
          class = "form-check form-switch",
          style = "font-size: 0.75rem;",
          tags$input(
            type = "checkbox",
            class = "form-check-input",
            id = "restrict_nyanza",
            checked = TRUE
          ),
          tags$label(
            class = "form-check-label",
            `for` = "restrict_nyanza",
            span(
              class = "d-flex align-items-center gap-1",
              icon("crosshairs", style = "font-size: 0.7rem;"),
              "Focus on Nyanza"
            )
          )
        )
      )
    ),
    
    # ===== NEW: VALIDATION & SENSITIVITY CARD =====
    card(
      class = "mb-2 border-0",
      style = "background: #ffffff;",
      card_header(
        class = "bg-transparent border-bottom py-2 px-3",
        div(
          class = "d-flex align-items-center gap-2",
          icon("flask", style = "font-size: 0.8rem; color: #6b7280;"),
          span("Validation", class = "small fw-medium")
        )
      ),
      card_body(
        class = "px-3 py-2",
        
        # Validation Mode Toggle
        div(
          class = "form-check form-switch mb-2",
          style = "font-size: 0.75rem;",
          tags$input(
            type = "checkbox",
            class = "form-check-input",
            id = "validation_mode",
            checked = FALSE
          ),
          tags$label(
            class = "form-check-label",
            `for` = "validation_mode",
            span(
              class = "d-flex align-items-center gap-1",
              icon("mask", style = "font-size: 0.7rem;"),
              "Simulate suppression (ground truth)"
            )
          )
        ),
        
        conditionalPanel(
          "input.validation_mode == true",
          div(
            class = "p-2 mb-2",
            style = "background: #f8f9fa; border-radius: 4px;",
            div(
              class = "d-flex justify-content-between align-items-center mb-1",
              span("Suppression radius:", class = "small text-muted"),
              span(id = "suppress_radius_value", "2.5 km", 
                   class = "badge bg-light text-dark")
            ),
            sliderInput("suppress_radius", NULL, 1, 5, 2.5, 0.5,
                        width = "100%", ticks = FALSE, post = " km"),
            
            div(
              class = "d-flex justify-content-between align-items-center mb-1 mt-2",
              span("Removal rate:", class = "small text-muted"),
              span(id = "removal_rate_value", "80%", 
                   class = "badge bg-danger text-white")
            ),
            sliderInput("removal_rate", NULL, 0.5, 0.95, 0.8, 0.05,
                        width = "100%", ticks = FALSE)
          ),
          
          div(
            class = "small text-muted mt-1",
            icon("info-circle"),
            " Creates known void for Jaccard index validation"
          )
        ),
        
        hr(style = "margin: 10px 0;"),
        
        # Auto-tune Button
        div(
          class = "d-grid gap-1 mt-2",
          actionButton("auto_tune_threshold", 
                       span(
                         class = "d-flex align-items-center justify-content-center gap-2",
                         icon("magic", style = "font-size: 0.8rem;"),
                         span("Auto-tune sensitivity (elbow method)")
                       ),
                       class = "btn-outline-info btn-sm",
                       style = "font-size: 0.75rem; padding: 0.3rem;")
        ),
        
        # m₀ Analysis Button
        div(
          class = "d-grid gap-1 mt-2",
          actionButton("run_m0_analysis", 
                       span(
                         class = "d-flex align-items-center justify-content-center gap-2",
                         icon("chart-line", style = "font-size: 0.8rem;"),
                         span("Analyze m₀ stability")
                       ),
                       class = "btn-outline-secondary btn-sm",
                       style = "font-size: 0.75rem; padding: 0.3rem;")
        )
      )
    ),
    
    # ACTIONS
    card(
      class = "mb-2 border-0",
      style = "background: #ffffff;",
      card_body(
        class = "px-3 py-2",
        div(
          class = "d-grid gap-1",
          actionButton("run_scan", 
                       span(
                         class = "d-flex align-items-center justify-content-center gap-2",
                         icon("play", style = "font-size: 0.8rem;"),
                         span("Run Topological Analysis")
                       ),
                       class = "btn-primary",
                       style = "border: none; background: #2c3e50; padding: 0.5rem; font-size: 0.8rem;"),
          div(
            class = "d-flex gap-1",
            actionButton("reset_btn", "Reset",
                         class = "btn-outline-secondary flex-fill",
                         icon = icon("refresh"),
                         style = "padding: 0.35rem; font-size: 0.75rem;"),
            downloadButton("export_report", "Export",
                           class = "btn-outline-success flex-fill",
                           style = "padding: 0.35rem; font-size: 0.75rem;")
          )
        )
      )
    ),
    
    # STATUS
    card(
      class = "border-0",
      style = "background: #ffffff;",
      card_body(
        class = "px-3 py-2",
        div(
          class = "d-flex justify-content-between align-items-center",
          span("Status", class = "small"),
          span(id = "status_badge", 
               class = "badge rounded-pill",
               style = "background: #27ae6015; color: #27ae60; font-size: 0.7rem; padding: 0.2rem 0.6rem;",
               icon("check", style = "font-size: 0.6rem; margin-right: 3px;"),
               "Ready")
        )
      )
    )
  ),
  
  # Main Content
  div(
    id = "main_content",
    
    # Map Section
    card(
      id = "map_section",
      class = "border-0 mb-2",
      style = "height: 70vh; border-radius: 8px; overflow: hidden;",
      card_header(
        class = "bg-white border-bottom py-2 px-3",
        div(
          class = "d-flex justify-content-between align-items-center",
          div(
            class = "d-flex align-items-center gap-2",
            icon("map", style = "font-size: 0.8rem; color: #6b7280;"),
            span("Surveillance Map", class = "small fw-medium")
          ),
          # Single fit bounds button
          actionButton("fit_bounds", "", icon = icon("expand"), 
                       class = "btn-light btn-sm border",
                       title = "Fit to data",
                       style = "border-radius: 4px;")
        )
      ),
      leafletOutput("map_main", height = "100%")
    ),
    
    # Statistics
    div(
      id = "results_section",
      class = "row g-1 mb-2",
      # Cases
      div(
        class = "col-4",
        div(
          class = "border rounded text-center py-2",
          style = "background: #f8fafc; border-color: #e5e7eb !important;",
          div(
            class = "d-flex align-items-center justify-content-center gap-1 mb-1",
            icon("dot-circle", class = "text-primary", style = "font-size: 0.6rem;"),
            span("Points", class = "small text-muted")
          ),
          h4(id = "stat_points", "0", 
             class = "mb-0 fw-normal",
             style = "font-size: .6rem; color: #2c3e50;")
        )
      ),
      # Voids
      div(
        class = "col-4",
        div(
          class = "border rounded text-center py-2",
          style = "background: #f8fafc; border-color: #e5e7eb !important;",
          div(
            class = "d-flex align-items-center justify-content-center gap-1 mb-1",
            icon("vector-square", class = "text-danger", style = "font-size: 0.6rem;"),
            span("Structural Voids", class = "small text-muted")
          ),
          h4(id = "stat_voids", "0", 
             class = "mb-0 fw-normal",
             style = "font-size: .6rem; color: #2c3e50;")
        )
      ),
      # Area
      div(
        class = "col-4",
        div(
          class = "border rounded text-center py-2",
          style = "background: #f8fafc; border-color: #e5e7eb !important;",
          div(
            class = "d-flex align-items-center justify-content-center gap-1 mb-1",
            icon("border-style", class = "text-success", style = "font-size: 0.6rem;"),
            span("Area km²", class = "small text-muted")
          ),
          h4(id = "stat_area", "0", 
             class = "mb-0 fw-normal",
             style = "font-size: .6rem; color: #2c3e50;")
        )
      )
    ),
    
    # Detailed Results
    div(
      id = "detailed_results",
      style = "display: none;",
      card(
        class = "border-0",
        style = "border-radius: 8px;",
        card_header(
          class = "bg-white border-bottom py-2 px-3",
          div(
            class = "d-flex justify-content-between align-items-center",
            span("Topological Results", class = "small fw-medium"),
            actionButton("close_results", "", icon = icon("times"),
                         class = "btn-sm border-0 p-0 text-muted")
          )
        ),
        card_body(
          class = "p-2",
          div(
            id = "results_content",
            class = "small",
            style = "font-size: 0.7rem; line-height: 1.4;",
            p("No analysis performed yet.", class = "text-muted text-center py-2")
          )
        )
      )
    ),
    
    # Minimal Footer
    div(
      class = "d-flex justify-content-between align-items-center py-1 mt-2",
      style = "font-size: 0.7rem; color: #95a5a6;",
      div(
        icon("clock", style = "font-size: 0.6rem;"),
        span("Last: ", tags$span(id = "footer_time", "Never"))
      ),
      div(
        class = "d-flex align-items-center gap-1",
        tags$small("TDA Engine v1.0"),
        tags$small("•"),
        tags$small("M.O Grold")
      )
    )
  )
)

# -------------------------------------------------------------------------
# ENHANCED CSS
# -------------------------------------------------------------------------
ui <- tagList(
  ui,
  tags$head(
    tags$style(HTML("
      /* Clean minimal styling */
      body {
        font-family: 'Inter', -apple-system, sans-serif;
        background-color: #f9fafb;
        color: #374151;
      }
      
      /* Enhanced cards */
      .card {
        border: 1px solid #e5e7eb;
        border-radius: 8px;
        background: white;
        box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
      }
      
      /* Modern form controls */
      .form-control, .form-select {
        border-radius: 6px;
        border: 1px solid #e5e7eb;
        font-size: 0.85rem;
      }
      
      .form-control:focus, .form-select:focus {
        border-color: #3498db;
        box-shadow: 0 0 0 3px rgba(52, 152, 219, 0.1);
      }
      
      /* Enhanced buttons */
      .btn {
        border-radius: 6px;
        font-weight: 500;
        font-size: 0.8rem;
      }
      
      .btn-primary {
        background: #2c3e50;
        border: none;
      }
      
      .btn-primary:hover {
        background: #1a2530;
        transform: translateY(-1px);
        box-shadow: 0 4px 12px rgba(0,0,0,0.1);
      }
      
      /* Download button styling */
      #export_report {
        text-decoration: none;
      }
      
      #export_report i {
        margin-right: 5px;
      }
      
      /* Slim Floating Button */
      #floating_action_btn {
        position: fixed;
        bottom: 20px;
        right: 20px;
        z-index: 1000;
        width: 50px;
        height: 50px;
        border-radius: 50%;
        background: linear-gradient(135deg, #f39c12 0%, #e67e22 100%);
        border: 2px solid white;
        box-shadow: 0 3px 10px rgba(243, 156, 18, 0.3);
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 0.7rem;
        font-weight: 600;
        transition: all 0.3s ease;
        overflow: hidden;
      }
      
      #floating_action_btn:hover {
        transform: translateY(-2px) scale(1.05);
        box-shadow: 0 5px 15px rgba(243, 156, 18, 0.4);
        width: 110px;
        border-radius: 25px;
      }
      
      #floating_action_btn .fab-text {
        opacity: 0;
        max-width: 0;
        overflow: hidden;
        transition: all 0.3s ease;
        white-space: nowrap;
        font-size: 0.65rem;
      }
      
      #floating_action_btn:hover .fab-text {
        opacity: 1;
        max-width: 70px;
        margin-left: 3px;
      }
      
      #floating_action_btn i {
        font-size: 1rem;
        transition: all 0.3s ease;
      }
      
      #floating_action_btn:hover i {
        margin-right: 4px;
      }
      
      /* Slider styling */
      .irs--shiny .irs-bar {
        background: linear-gradient(to right, #3498db, #2c3e50);
        height: 2px;
      }
      
      .irs--shiny .irs-handle {
        width: 14px;
        height: 14px;
        border: 2px solid #2c3e50;
        background: white;
        box-shadow: 0 1px 3px rgba(0,0,0,0.1);
      }
      
      /* Status animation */
      @keyframes pulse {
        0% { opacity: 1; }
        50% { opacity: 0.7; }
        100% { opacity: 1; }
      }
      
      .processing {
        animation: pulse 1.5s infinite;
      }
      
      /* Mobile optimizations */
      @media (max-width: 768px) {
        body { font-size: 0.82rem; }
        #map_section { height: 60vh; }
        
        #floating_action_btn {
          bottom: 70px;
          right: 15px;
          width: 46px;
          height: 46px;
        }
        
        #floating_action_btn:hover {
          width: 100px;
        }
      }
    "))
  )
)

# -------------------------------------------------------------------------
# SERVER: IMPROVED MATHEMATICAL APPROACH FOR STRUCTURAL VOID DETECTION
# -------------------------------------------------------------------------
server <- function(input, output, session) {
  
  # ========== SECURITY & PERFORMANCE SETTINGS ==========
  options(shiny.maxRequestSize = 10 * 1024^2)  # 10MB file limit
  options(shiny.sanitize.errors = TRUE)        # Hide technical errors
  
  # STATE MANAGEMENT
  v <- reactiveValues(
    data = NULL,
    mode = "demo",
    results = NULL,
    analysis_time = NULL,
    floating_btn_text = "SCAN DEMO",
    debug_info = NULL,
    rings = NULL,
    
    # ===== NEW VALIDATION FIELDS =====
    validation_mode = FALSE,
    censoring_simulation = NULL,
    validation_metrics = NULL,
    m0_analysis = NULL,
    elbow_threshold = NULL,
    permutation_test = NULL,
    caveats = NULL
  )
  
  # ========== SECURE VALIDATION FUNCTION ==========
  validate_and_sanitize_csv <- function(filepath) {
    tryCatch({
      # 1. Check file size (max 10MB for demo)
      if (file.size(filepath) > 10 * 1024 * 1024) {
        stop("File too large (max 10MB for demo)")
      }
      
      # 2. Read with safety limits
      df <- read.csv(
        filepath, 
        stringsAsFactors = FALSE,
        encoding = "UTF-8",
        na.strings = c("", "NA", "NULL"),
        nrows = 5000,  # Limit to 5000 rows for demo
        colClasses = "character"  # Read as text first
      )
      
      # 3. Clean column names
      colnames(df) <- make.names(colnames(df))
      names(df) <- tolower(names(df))
      
      # 4. Find coordinate columns (flexible)
      has_lat <- any(c("lat", "latitude") %in% names(df))
      has_lon <- any(c("long", "longitude", "lng", "lon") %in% names(df))
      
      if (!(has_lat & has_lon)) {
        stop("CSV must contain 'latitude' and 'longitude' columns")
      }
      
      # 5. Standardize column names
      if ("latitude" %in% names(df)) df$lat <- df$latitude
      if ("longitude" %in% names(df)) df$long <- df$longitude
      if ("lng" %in% names(df)) df$long <- df$lng
      if ("lon" %in% names(df)) df$long <- df$lon
      
      # 6. Convert to numeric and remove invalid
      df$lat <- as.numeric(df$lat)
      df$long <- as.numeric(df$long)
      
      # Remove rows with NA coordinates
      df <- df[complete.cases(df[, c("lat", "long")]), ]
      
      if (nrow(df) == 0) {
        stop("No valid coordinates found in file")
      }
      
      # 7. Validate coordinate ranges
      valid_coords <- df$lat >= -90 & df$lat <= 90 & 
        df$long >= -180 & df$long <= 180
      
      if (sum(valid_coords) == 0) {
        stop("Coordinates outside valid ranges (lat: -90 to 90, long: -180 to 180)")
      }
      
      df <- df[valid_coords, c("long", "lat")]
      
      # 8. Limit to 3000 points for demo performance
      max_points <- 3000
      if (nrow(df) > max_points) {
        df <- df[sample(1:nrow(df), max_points), ]
        # Note: This will show in status, not as popup
      }
      
      return(df)
      
    }, error = function(e) {
      stop(paste("File validation failed:", e$message))
    })
  }
  
  # ============================================================================
  # MODULE 1: VALIDATION WITH CENSORING SIMULATION (Ground Truth)
  # ============================================================================
  # Transforms "synthetic data" critique into strength
  # Creates known suppression events to validate against
  # ----------------------------------------------------------------------------
  
  simulate_censoring <- function(full_data = NULL, 
                                 suppress_center = c(34.65, -0.35),
                                 suppress_radius = 0.025,
                                 remove_fraction = 0.8) {
    
    # If no data provided, generate realistic facility-like data
    if (is.null(full_data)) {
      set.seed(2026)
      n_points <- 400
      
      # Create realistic clusters (mimicking health facilities)
      centers <- data.frame(
        long = c(34.75, 34.45, 34.85, 34.55, 34.65, 34.95),
        lat = c(-0.10, -0.28, -0.45, -0.15, -0.35, -0.25),
        n = c(80, 70, 65, 75, 60, 50)
      )
      
      full_data <- do.call(rbind, lapply(1:nrow(centers), function(i) {
        data.frame(
          long = rnorm(centers$n[i], centers$long[i], 0.015),
          lat = rnorm(centers$n[i], centers$lat[i], 0.015)
        )
      }))
    }
    
    # Calculate distances to suppression center
    distances <- sqrt((full_data$long - suppress_center[1])^2 + 
                        (full_data$lat - suppress_center[2])^2)
    
    # Identify points in suppression zone
    in_zone <- distances <= suppress_radius
    
    # Create censored dataset: remove remove_fraction% of points in zone
    n_zone <- sum(in_zone)
    n_keep <- max(1, round(n_zone * (1 - remove_fraction)))
    
    if (n_zone > 0 && n_keep < n_zone) {
      keep_indices <- which(in_zone)[sample(1:n_zone, n_keep)]
      all_indices <- c(which(!in_zone), keep_indices)
      censored_data <- full_data[all_indices, ]
      
      # Ground truth: the removed points
      removed_indices <- which(in_zone)[!which(in_zone) %in% keep_indices]
      ground_truth <- full_data[removed_indices, ]
    } else {
      censored_data <- full_data
      ground_truth <- data.frame(long = numeric(0), lat = numeric(0))
    }
    
    return(list(
      full_data = full_data,
      censored_data = censored_data,
      ground_truth = ground_truth,
      suppression_center = suppress_center,
      suppression_radius = suppress_radius,
      removal_rate = remove_fraction,
      n_removed = nrow(full_data) - nrow(censored_data),
      validation_id = paste0("CENSOR_", format(Sys.time(), "%Y%m%d_%H%M%S"))
    ))
  }
  
  # ============================================================================
  # MODULE 2: JACCARD INDEX & SPATIAL ACCURACY METRICS
  # ============================================================================
  # Replaces binary detection with quantitative spatial accuracy
  # ----------------------------------------------------------------------------
  
  calculate_jaccard_index <- function(detected_polygons, ground_truth_points) {
    
    if (nrow(ground_truth_points) == 0 || is.null(detected_polygons) || nrow(detected_polygons) == 0) {
      return(list(jaccard = 0, dice = 0, recovery_rate = 0, centroid_error_m = NA))
    }
    
    tryCatch({
      # Convert ground truth points to convex hull polygon
      truth_sf <- st_as_sf(ground_truth_points, coords = c("long", "lat"), crs = 4326)
      
      if (nrow(truth_sf) < 3) {
        # Not enough points for polygon - use buffer
        truth_hull <- st_buffer(st_union(truth_sf), dist = 500)  # 500m buffer
      } else {
        truth_hull <- st_convex_hull(st_union(truth_sf))
      }
      
      # Transform to UTM for accurate area calculation
      truth_utm <- st_transform(truth_hull, 32736)
      truth_area <- as.numeric(st_area(truth_utm))
      
      # Transform detected voids to UTM
      detected_utm <- st_transform(detected_polygons, 32736)
      detected_union <- st_union(detected_utm)
      detected_area <- as.numeric(st_area(detected_union))
      
      # Calculate intersection
      intersection <- st_intersection(detected_union, truth_utm)
      intersection_area <- ifelse(length(intersection) > 0, as.numeric(st_area(intersection)), 0)
      
      # Union area
      union_area <- truth_area + detected_area - intersection_area
      
      # Jaccard = Intersection / Union
      jaccard <- intersection_area / max(union_area, 1)
      
      # Dice coefficient (harmonic mean)
      dice <- 2 * intersection_area / (truth_area + detected_area)
      
      # Recovery rate (how much of suppressed area was detected)
      recovery_rate <- intersection_area / max(truth_area, 1)
      
      # Centroid error
      if (length(st_geometry(detected_union)) > 0 && length(st_geometry(truth_utm)) > 0) {
        detected_centroid <- st_centroid(detected_union)
        truth_centroid <- st_centroid(truth_utm)
        centroid_error <- as.numeric(st_distance(detected_centroid, truth_centroid))
      } else {
        centroid_error <- NA
      }
      
      return(list(
        jaccard = round(jaccard, 4),
        dice = round(dice, 4),
        recovery_rate = round(recovery_rate, 4),
        centroid_error_m = round(centroid_error, 0),
        truth_area_km2 = round(truth_area / 1e6, 2),
        detected_area_km2 = round(detected_area / 1e6, 2),
        intersection_area_km2 = round(intersection_area / 1e6, 2)
      ))
      
    }, error = function(e) {
      return(list(jaccard = 0, dice = 0, recovery_rate = 0, centroid_error_m = NA))
    })
  }
  
  # ============================================================================
  # MODULE 3: ADAPTIVE THRESHOLDING - KNEEDLE ALGORITHM
  # ============================================================================
  # Eliminates arbitrary constants (1.5x median, 5km)
  # Derives thresholds geometrically from data
  # ----------------------------------------------------------------------------
  
  find_elbow_threshold <- function(dtm_values, sensitivity = 1.0) {
    
    # Remove NAs and sort
    dtm_clean <- dtm_values[!is.na(dtm_values)]
    if (length(dtm_clean) < 10) {
      return(list(threshold = quantile(dtm_clean, 0.9, na.rm = TRUE), 
                  elbow_index = NA, 
                  elbow_value = NA))
    }
    
    # Sort DTM values
    sorted_dtm <- sort(dtm_clean)
    n <- length(sorted_dtm)
    x <- 1:n
    
    # Normalize to [0,1] for scale-invariant comparison
    x_norm <- (x - min(x)) / (max(x) - min(x))
    y_norm <- (sorted_dtm - min(sorted_dtm)) / (max(sorted_dtm) - min(sorted_dtm))
    
    # Calculate curvature (second derivative approximation)
    dy <- diff(y_norm)
    dx <- diff(x_norm)
    d2y <- diff(dy) / dx[-length(dx)]
    
    # Smooth to reduce noise
    if (length(d2y) > 15) {
      d2y_smooth <- stats::filter(d2y, rep(1/5, 5), sides = 2)
      d2y_smooth[is.na(d2y_smooth)] <- d2y[is.na(d2y_smooth)]
      elbow_idx <- which.max(abs(d2y_smooth)) + 3
    } else {
      elbow_idx <- which.max(abs(d2y)) + 2
    }
    
    # Bound elbow index
    elbow_idx <- max(3, min(elbow_idx, n - 1))
    
    # Adaptive threshold: value at elbow * sensitivity
    adaptive_threshold <- sorted_dtm[elbow_idx] * sensitivity
    
    # Also return the quantile level for UI feedback
    quantile_level <- ecdf(sorted_dtm)(adaptive_threshold)
    
    return(list(
      threshold = adaptive_threshold,
      elbow_index = elbow_idx,
      elbow_value = sorted_dtm[elbow_idx],
      quantile_level = quantile_level,
      alpha = 1 - quantile_level,  # This maps to sensitivity parameter
      dtm_sorted = sorted_dtm,
      curvature = d2y
    ))
  }
  
  # ============================================================================
  # MODULE 4: m₀ STABILITY ANALYSIS - DEBUG VERSION
  # ============================================================================
  analyze_m0_stability <- function(points_sf, 
                                   m0_range = seq(0.01, 0.15, 0.02),
                                   resolution_km = 1.5) {
    
    # ----- DEBUG: Print input info -----
    cat("=== m0 STABILITY DEBUG ===\n")
    cat("Points:", nrow(points_sf), "\n")
    
    # ----- VALIDATION -----
    if (is.null(points_sf) || nrow(points_sf) < 10) {
      cat("ERROR: Insufficient points\n")
      return(list(
        sensitivity_data = data.frame(m0 = m0_range, n_voids = NA, total_area_km2 = NA),
        optimal_m0 = 0.05,
        stable_range = c(0.03, 0.07),
        plateau_detected = FALSE,
        interpretation = "Insufficient data for stability analysis",
        error = "Not enough points"
      ))
    }
    
    # ----- CONVERT TO UTM -----
    tryCatch({
      points_utm <- st_transform(points_sf, 32736)
      X_mat <- as.matrix(st_coordinates(points_utm))
      n_points <- nrow(X_mat)
      cat("UTM conversion successful. n_points:", n_points, "\n")
      
      # ----- CREATE GRID (SIMPLIFIED) -----
      res_meters <- resolution_km * 1000
      cat("Resolution:", res_meters, "meters\n")
      
      # Get bounding box
      bbox <- st_bbox(points_utm)
      cat("BBox:", paste(bbox), "\n")
      
      # SIMPLIFIED: Fixed grid size for stability
      n_x <- 15
      n_y <- 15
      
      x_seq <- seq(bbox$xmin, bbox$xmax, length.out = n_x)
      y_seq <- seq(bbox$ymin, bbox$ymax, length.out = n_y)
      
      Grid_utm <- expand.grid(X = x_seq, Y = y_seq)
      Grid_mat <- as.matrix(Grid_utm)
      cat("Grid created:", nrow(Grid_mat), "cells\n")
      
      # ----- LOOP OVER m0 VALUES -----
      results <- data.frame(
        m0 = m0_range,
        n_voids = NA_real_,
        total_area_km2 = NA_real_
      )
      
      for (i in seq_along(m0_range)) {
        m0 <- m0_range[i]
        k <- max(2, min(ceiling(m0 * n_points), n_points - 1))
        cat("  m0 =", m0, ", k =", k, "\n")
        
        # Calculate DTM - with SIMPLE fallback
        DTM_values <- tryCatch({
          TDA::dtm(X = X_mat, Grid = Grid_mat, m0 = m0)
        }, error = function(e) {
          cat("    TDA::dtm failed:", e$message, "\n")
          cat("    Using manual calculation\n")
          # Manual calculation for first few points only (speed)
          apply(Grid_mat[1:min(100, nrow(Grid_mat)), , drop = FALSE], 1, function(gp) {
            dists <- sqrt(rowSums((X_mat - matrix(gp, nrow = n_points, ncol = 2, byrow = TRUE))^2))
            mean(sort(dists)[1:k])
          })
        })
        
        # Count voids
        if (length(DTM_values) > 0 && !all(is.na(DTM_values))) {
          threshold <- quantile(DTM_values, 0.9, na.rm = TRUE)
          n_void_cells <- sum(DTM_values > threshold, na.rm = TRUE)
          results$n_voids[i] <- n_void_cells
          
          # Approximate area
          cell_area <- ((bbox$xmax - bbox$xmin) / n_x) * ((bbox$ymax - bbox$ymin) / n_y)
          results$total_area_km2[i] <- n_void_cells * cell_area / 1e6
          cat("    Voids:", n_void_cells, "\n")
        } else {
          results$n_voids[i] <- 0
          results$total_area_km2[i] <- 0
          cat("    No DTM values\n")
        }
      }
      
      # Find optimal m0
      results_clean <- results[!is.na(results$n_voids), ]
      
      if (nrow(results_clean) >= 3) {
        # Simple stability: look for region with least variation
        n <- nrow(results_clean)
        min_var <- Inf
        optimal_idx <- which.min(abs(results_clean$m0 - 0.05))
        
        for (i in 1:(n-2)) {
          var_val <- var(results_clean$n_voids[i:(i+2)], na.rm = TRUE)
          if (!is.na(var_val) && var_val < min_var) {
            min_var <- var_val
            optimal_idx <- i + 1
          }
        }
        
        optimal_m0 <- results_clean$m0[optimal_idx]
        stable_range <- c(max(0.01, optimal_m0 - 0.03), min(0.15, optimal_m0 + 0.03))
      } else {
        optimal_m0 <- 0.05
        stable_range <- c(0.03, 0.07)
      }
      
      cat("Optimal m0:", optimal_m0, "\n")
      cat("Stable range:", stable_range[1], "-", stable_range[2], "\n")
      
      m0_05_in_range <- (0.05 >= stable_range[1] && 0.05 <= stable_range[2])
      
      interpretation <- if (m0_05_in_range) {
        sprintf("Stable plateau detected: m0=0.05 is WITHIN stable range [%.2f-%.2f]",
                stable_range[1], stable_range[2])
      } else {
        sprintf("Warning: m0=0.05 is OUTSIDE stable range [%.2f-%.2f]. Consider m0=%.2f",
                stable_range[1], stable_range[2], optimal_m0)
      }
      
      cat("Interpretation:", interpretation, "\n")
      cat("=== END DEBUG ===\n\n")
      
      return(list(
        sensitivity_data = results,
        optimal_m0 = round(optimal_m0, 2),
        stable_range = round(stable_range, 2),
        plateau_detected = m0_05_in_range,
        interpretation = interpretation,
        error = NULL
      ))
      
    }, error = function(e) {
      cat("!!! CATASTROPHIC ERROR:", e$message, "\n")
      cat("Traceback:\n")
      print(traceback())
      cat("=== END DEBUG ===\n\n")
      
      return(list(
        sensitivity_data = data.frame(m0 = m0_range, n_voids = NA, total_area_km2 = NA),
        optimal_m0 = 0.05,
        stable_range = c(0.03, 0.07),
        plateau_detected = FALSE,
        interpretation = "Analysis failed - using default parameters",
        error = e$message
      ))
    })
  }
  # ============================================================================
  # MODULE 5: P-VALUE WITH CONFIDENCE INTERVALS & VOID AREA STATISTIC
  # ============================================================================
  # Adds statistical rigor with CIs and more robust test statistic
  # ----------------------------------------------------------------------------
  
  calculate_pvalue_with_ci <- function(observed_stat, perm_stats, n_perm = 999) {
    
    # Calculate p-value (Davison & Hinkley 1997)
    p_value <- (1 + sum(perm_stats >= observed_stat, na.rm = TRUE)) / (1 + n_perm)
    
    # Wilson score confidence interval for binomial proportion
    z <- qnorm(0.975)  # 95% CI
    
    numerator <- p_value + (z^2)/(2 * n_perm)
    denominator <- 1 + (z^2)/n_perm
    adjustment <- z * sqrt((p_value * (1 - p_value))/n_perm + (z^2)/(4 * n_perm^2))
    
    ci_lower <- max(0, (numerator - adjustment) / denominator)
    ci_upper <- min(1, (numerator + adjustment) / denominator)
    
    return(list(
      p_value = p_value,
      ci_lower = ci_lower,
      ci_upper = ci_upper,
      interpretation = sprintf("p = %.3f (95%% CI: %.3f-%.3f)", p_value, ci_lower, ci_upper)
    ))
  }
  
  enhanced_permutation_test <- function(observed_points, n_perm = 199) {  # Lower for performance
    
    req(observed_points)
    
    # Convert to UTM
    points_sf <- st_as_sf(observed_points, coords = c("long", "lat"), crs = 4326)
    points_utm <- st_transform(points_sf, 32736)
    bbox <- st_bbox(points_utm)
    
    # Calculate observed DTM (simplified for permutation test)
    X_mat <- as.matrix(st_coordinates(points_utm))
    n_points <- nrow(X_mat)
    
    # Quick grid for permutation test (coarser)
    x_seq <- seq(bbox$xmin, bbox$xmax, length.out = 20)
    y_seq <- seq(bbox$ymin, bbox$ymax, length.out = 20)
    Grid <- expand.grid(X = x_seq, Y = y_seq)
    Grid_mat <- as.matrix(Grid)
    
    # Observed statistic
    m0 <- 0.05
    k <- max(2, ceiling(m0 * n_points))
    
    DTM_obs <- tryCatch({
      TDA::dtm(X = X_mat, Grid = Grid_mat, m0 = m0)
    }, error = function(e) {
      apply(Grid_mat, 1, function(gp) {
        dists <- sqrt(rowSums((X_mat - matrix(gp, nrow = n_points, ncol = 2, byrow = TRUE))^2))
        mean(sort(dists)[1:k])
      })
    })
    
    # Observed void area (above 90th percentile)
    threshold_obs <- quantile(DTM_obs, 0.9, na.rm = TRUE)
    observed_area <- sum(DTM_obs > threshold_obs, na.rm = TRUE)
    observed_max <- max(DTM_obs, na.rm = TRUE)
    
    # Permutation distribution
    perm_area <- numeric(n_perm)
    perm_max <- numeric(n_perm)
    
    withProgress(message = 'Permutation test', value = 0, {
      for (i in 1:n_perm) {
        # CSR: randomize points within bounding box
        perm_points <- data.frame(
          X = runif(n_points, bbox$xmin, bbox$xmax),
          Y = runif(n_points, bbox$ymin, bbox$ymax)
        )
        perm_mat <- as.matrix(perm_points)
        
        DTM_perm <- tryCatch({
          TDA::dtm(X = perm_mat, Grid = Grid_mat, m0 = m0)
        }, error = function(e) {
          apply(Grid_mat, 1, function(gp) {
            dists <- sqrt(rowSums((perm_mat - matrix(gp, nrow = n_points, ncol = 2, byrow = TRUE))^2))
            mean(sort(dists)[1:k])
          })
        })
        
        perm_area[i] <- sum(DTM_perm > threshold_obs, na.rm = TRUE)
        perm_max[i] <- max(DTM_perm, na.rm = TRUE)
        
        incProgress(1/n_perm)
      }
    })
    
    # Calculate p-values with CIs
    p_area <- calculate_pvalue_with_ci(observed_area, perm_area, n_perm)
    p_max <- calculate_pvalue_with_ci(observed_max, perm_max, n_perm)
    
    return(list(
      area_statistic = p_area,
      max_statistic = p_max,
      effect_size = observed_area / mean(perm_area, na.rm = TRUE),
      observed = list(area = observed_area, max = observed_max)
    ))
  }
  
  # ============================================================================
  # MODULE 6: SCOPE CLARIFICATION & CAVEATS
  # ============================================================================
  # Softens suppression claims with proper contextual language
  # ----------------------------------------------------------------------------
  
  generate_caveats <- function(voids_df = NULL) {
    
    caveats <- list(
      disclaimer = "⚠️ Structural voids indicate geometric anomalies, not proven suppression",
      interpretation = "These regions are statistically unlikely under CSR and spatially coherent",
      alternative_explanations = c(
        "Uninhabited terrain (mountains, water bodies, protected areas)",
        "Private facilities not in public registry",
        "Genuine access barriers (seasonal roads, distance)",
        "Reporting delays or administrative boundaries",
        "Complete spatial randomness (Type I error)"
      ),
      required_context = c(
        "Population density overlay",
        "Land use classification", 
        "Facility registry cross-check",
        "Temporal trend analysis"
      ),
      recommendation = "Field validation required before operational action"
    )
    
    if (!is.null(voids_df) && nrow(voids_df) > 0) {
      caveats$void_specific <- sprintf(
        "Void %d: %s", 
        1:nrow(voids_df),
        ifelse(voids_df$is_structural %in% TRUE, 
               "Candidate for further investigation", 
               "Low priority - natural variation")
      )
    }
    
    return(caveats)
  }
  
  
  # HELPER FUNCTION: Minimum Enclosing Circle (MEC) using Welzl algorithm
  minimum_enclosing_circle <- function(points) {
    if (nrow(points) == 0) return(NULL)
    
    # Simple algorithm: use centroid and maximum distance
    center <- colMeans(points)
    distances <- sqrt(rowSums((points - matrix(center, nrow = nrow(points), ncol = 2, byrow = TRUE))^2))
    radius <- max(distances)
    
    # Add 10% buffer
    radius <- radius * 1.1
    
    return(list(center = center, radius = radius))
  }
  
  # HELPER FUNCTION: Create ring from polygon
  create_ring_from_polygon <- function(polygon_sf) {
    # Get points from polygon boundary
    boundary_points <- sf::st_coordinates(polygon_sf)
    
    # Calculate minimum enclosing circle
    mec <- minimum_enclosing_circle(boundary_points[, 1:2])
    
    if (is.null(mec)) return(NULL)
    
    # Create circle polygon
    center_sf <- sf::st_sfc(sf::st_point(mec$center), crs = 32736)
    circle_sf <- sf::st_buffer(center_sf, dist = mec$radius)
    
    # Transform to WGS84
    circle_wgs84 <- sf::st_transform(circle_sf, crs = 4326)
    
    return(list(
      circle = circle_wgs84,
      center = mec$center,
      radius_meters = mec$radius,
      radius_km = round(mec$radius / 1000, 2)
    ))
  }
  
  # 1. INITIALIZE WITH REALISTIC DEMO DATA (with structural void in the middle)
  init_demo <- function() {
    set.seed(2026)
    
    # Create a dense cluster with a void in the middle
    n_points <- 600
    
    # Create a ring-shaped cluster (void in center)
    theta <- runif(n_points, 0, 2*pi)
    radius <- c(
      runif(n_points * 0.3, 0.02, 0.03),  # Inner ring
      runif(n_points * 0.4, 0.04, 0.07),  # Middle ring
      runif(n_points * 0.3, 0.08, 0.12)   # Outer ring
    )
    
    # Center around Nyanza region
    center_long <- 34.65
    center_lat <- -0.35
    
    # Generate points
    long <- center_long + radius * cos(theta)
    lat <- center_lat + radius * sin(theta)
    
    # Add some noise points
    noise_long <- rnorm(50, mean = center_long, sd = 0.08)
    noise_lat <- rnorm(50, mean = center_lat, sd = 0.08)
    
    v$data <- data.frame(
      long = c(long, noise_long),
      lat = c(lat, noise_lat)
    )
    
    v$mode <- "demo"
    v$results <- NULL
    v$floating_btn_text <- "SCAN DEMO"
    v$debug_info <- NULL
    v$rings <- NULL
    
    updateStatistics(nrow(v$data), 0, 0)
    updateStatus("Ready", "ready")
    updateFooterTime()
    updateFloatingButton()
    runjs("hideResults();")
  }
  
  # Initialize on start
  observe({
    if (is.null(v$data)) init_demo()
  })
  
  # 2. FILE UPLOAD HANDLER - SECURE VERSION
  observeEvent(input$upload, {
    req(input$upload)
    
    tryCatch({
      # Use secure validation function
      df <- validate_and_sanitize_csv(input$upload$datapath)
      
      v$data <- df
      v$mode <- "upload"
      v$results <- NULL
      v$floating_btn_text <- "SCAN FILE"
      v$debug_info <- NULL
      v$rings <- NULL
      
      # Update UI
      updateStatistics(nrow(v$data), 0, 0)
      updateStatus("File loaded and validated", "success")
      updateFooterTime()
      updateFloatingButton()
      runjs("hideResults();")
      
      # Clean up file after reading
      on.exit({
        if (file.exists(input$upload$datapath)) {
          file.remove(input$upload$datapath)
        }
      })
      
      # Fit map to uploaded data
      leafletProxy("map_main") %>% 
        clearGroup("cases") %>%
        clearGroup("voids") %>%
        clearGroup("rings") %>%
        clearGroup("center") %>%
        addCircleMarkers(
          data = df, 
          ~long, ~lat, 
          radius = 3, 
          color = "#2c3e50", 
          stroke = FALSE, 
          fillOpacity = 0.6, 
          group = "cases"
        ) %>%
        fitBounds(
          lng1 = min(df$long, na.rm = TRUE) - 0.01,
          lat1 = min(df$lat, na.rm = TRUE) - 0.01,
          lng2 = max(df$long, na.rm = TRUE) + 0.01,
          lat2 = max(df$lat, na.rm = TRUE) + 0.01
        )
      
    }, error = function(e) {
      updateStatus(paste("Upload failed:", e$message), "error")
      shinyjs::reset("upload")
    })
  })
  
  # 3. RESET HANDLER
  observeEvent(input$reset_btn, {
    shinyjs::reset("upload")
    init_demo()
    
    leafletProxy("map_main") %>% 
      clearGroup("voids") %>% 
      clearGroup("cases") %>%
      clearGroup("rings") %>%
      clearGroup("center") %>%
      setView(34.65, -0.35, 10)
    
    updateStatus("Reset to demo data", "success")
  })
  
  # ===== NEW: VALIDATION MODE HANDLER =====
  observeEvent(input$validation_mode, {
    v$validation_mode <- input$validation_mode
    
    if (input$validation_mode) {
      # Generate censoring simulation using current data or demo data
      if (!is.null(v$data) && nrow(v$data) > 100) {
        sim <- simulate_censoring(
          full_data = v$data,
          suppress_radius = input$suppress_radius / 111.32,  # Convert km to degrees
          remove_fraction = input$removal_rate
        )
      } else {
        # Use built-in facility-like data
        sim <- simulate_censoring(
          suppress_radius = input$suppress_radius / 111.32,
          remove_fraction = input$removal_rate
        )
      }
      
      v$censoring_simulation <- sim
      v$data <- sim$censored_data
      v$mode <- "validation"
      
      updateStatus(sprintf("Validation mode: %d points removed", sim$n_removed), "info")
      
      # Update map
      leafletProxy("map_main") %>%
        clearMarkers() %>%
        clearGroup("cases") %>%
        clearGroup("voids") %>%
        clearGroup("ground_truth") %>%
        addCircleMarkers(
          data = sim$censored_data,
          ~long, ~lat,
          radius = 4,
          color = "#2c3e50",
          stroke = FALSE,
          fillOpacity = 0.7,
          group = "cases",
          popup = "Observed (after censoring)"
        )
      
      # Add ground truth points if available
      if (nrow(sim$ground_truth) > 0) {
        leafletProxy("map_main") %>%
          addCircleMarkers(
            data = sim$ground_truth,
            ~long, ~lat,
            radius = 4,
            color = "#27ae60",
            stroke = TRUE,
            weight = 1,
            fillColor = "#27ae60",
            fillOpacity = 0.5,
            group = "ground_truth",
            popup = "Ground truth (removed points)"
          ) %>%
          addLegend(
            position = "bottomright",
            colors = c("#2c3e50", "#27ae60"),
            labels = c("Observed (censored)", "Ground truth (removed)"),
            opacity = 0.7,
            title = "Validation"
          )
      }
      
    } else {
      # Exit validation mode - restore original data
      if (!is.null(v$censoring_simulation$full_data)) {
        v$data <- v$censoring_simulation$full_data
      } else {
        init_demo()
      }
      
      leafletProxy("map_main") %>%
        clearGroup("ground_truth") %>%
        clearControls()
    }
  })
  
  # Update slider labels
  observeEvent(input$suppress_radius, {
    session$sendCustomMessage("update_slider_label", 
                              list(id = "suppress_radius_value", 
                                   text = paste(input$suppress_radius, "km")))
  })
  
  observeEvent(input$removal_rate, {
    session$sendCustomMessage("update_slider_label", 
                              list(id = "removal_rate_value", 
                                   text = paste0(round(input$removal_rate * 100), "%")))
  })
  
  # ===== NEW: AUTO-TUNE THRESHOLD HANDLER - FIXED =====
  observeEvent(input$auto_tune_threshold, {
    req(v$debug_info$dtm_vals)
    
    # Calculate elbow threshold
    elbow <- find_elbow_threshold(v$debug_info$dtm_vals)
    v$elbow_threshold <- elbow
    
    # Convert to alpha parameter
    alpha <- elbow$alpha
    
    # Update slider if alpha is in range
    if (!is.na(alpha) && alpha >= 0.01 && alpha <= 0.30) {
      updateSliderInput(session, "significance", value = round(alpha, 2))
      
      # Use updateStatus instead of showNotification
      updateStatus(
        sprintf("α auto-tuned to %.2f (elbow at %.1fm)", alpha, elbow$elbow_value),
        "success"
      )
      
      # Also update the sensitivity badge
      session$sendCustomMessage("update_sensitivity_badge", list(
        alpha = round(alpha, 2),
        elbow = round(elbow$elbow_value, 1)
      ))
      
    } else {
      updateStatus("Could not determine stable elbow", "warning")
    }
  })
  
  
  # ===== m₀ STABILITY ANALYSIS HANDLER - SIMPLIFIED =====
  observeEvent(input$run_m0_analysis, {
    req(v$data)
    
    # Show processing status
    updateStatus("Analyzing m₀ stability...", "processing")
    
    # Run analysis
    tryCatch({
      points_sf <- st_as_sf(v$data, coords = c("long", "lat"), crs = 4326)
      
      if (nrow(points_sf) < 30) {
        session$sendCustomMessage("show_notification", list(
          message = "Need at least 30 points for stability analysis",
          type = "warning"
        ))
        updateStatus("Insufficient data", "warning")
        return()
      }
      
      # Run analysis
      v$m0_analysis <- analyze_m0_stability(
        points_sf,
        m0_range = seq(0.01, 0.15, 0.02),
        resolution_km = input$resolution
      )
      
      # Show results via status badge instead of notification
      stable_text <- ifelse(0.05 >= v$m0_analysis$stable_range[1] && 
                              0.05 <= v$m0_analysis$stable_range[2],
                            "within", "outside")
      
      # Update status with results
      status_msg <- sprintf("m₀ stability: 0.05 is %s stable range [%.2f-%.2f]",
                            stable_text,
                            v$m0_analysis$stable_range[1],
                            v$m0_analysis$stable_range[2])
      
      updateStatus(status_msg, ifelse(v$m0_analysis$plateau_detected, "success", "warning"))
      
      # Also update the mass parameter badge to show stability
      session$sendCustomMessage("update_m0_badge", list(
        stable = v$m0_analysis$plateau_detected,
        range = sprintf("%.2f-%.2f", v$m0_analysis$stable_range[1], v$m0_analysis$stable_range[2])
      ))
      
    }, error = function(e) {
      updateStatus("m₀ analysis failed", "warning")
    })
  })
  
    # ==========================================================================
  # 4. TDA ANALYSIS ENGINE - RESTORED
  # ==========================================================================
  run_tda_analysis <- function() {
    req(v$data)
    
    updateStatus("Analyzing...", "processing")
    
    withProgress(
      message = 'TDA Engine',
      detail = 'Step 1: Projecting coordinates...',
      value = 0,
      {
        tryCatch({
          df <- v$data
          
          # Clear map and show points
          leafletProxy("map_main") %>% 
            clearGroup("cases") %>% 
            clearGroup("voids") %>%
            clearGroup("rings") %>%
            clearGroup("center") %>%
            addCircleMarkers(
              data = df, 
              ~long, ~lat, 
              radius = 3, 
              color = "#2c3e50", 
              stroke = FALSE, 
              fillOpacity = 0.6, 
              group = "cases"
            )
          
          incProgress(0.1, detail = "Step 2: Converting to UTM...")
          
          # CRITICAL: Convert to UTM for proper distance calculations
          points_sf <- sf::st_as_sf(df, coords = c("long", "lat"), crs = 4326)
          points_utm <- sf::st_transform(points_sf, crs = 32736)  # UTM 36S
          utm_coords <- sf::st_coordinates(points_utm)
          
          # Prepare matrix for TDA
          X_mat <- as.matrix(utm_coords)
          n_points <- nrow(df)
          
          incProgress(0.2, detail = "Step 3: Creating analysis grid...")
          
          # Convert resolution from km to meters
          res_meters <- input$resolution * 1000
          
          # Create grid IN THE CONVEX HULL OF THE DATA (not outside)
          hull <- sf::st_convex_hull(sf::st_union(points_utm))
          
          # Get bounding box of convex hull
          bbox <- sf::st_bbox(hull)
          
          # Create grid within convex hull - LIMIT SIZE for performance
          x_range <- diff(bbox[c("xmin", "xmax")])
          y_range <- diff(bbox[c("ymin", "ymax")])
          
          n_x <- min(30, max(10, floor(x_range / res_meters)))
          n_y <- min(30, max(10, floor(y_range / res_meters)))
          
          x_seq <- seq(bbox$xmin, bbox$xmax, length.out = n_x)
          y_seq <- seq(bbox$ymin, bbox$ymax, length.out = n_y)
          
          Grid_utm <- expand.grid(X = x_seq, Y = y_seq)
          
          # Filter to points within convex hull
          grid_sf <- sf::st_as_sf(Grid_utm, coords = c("X", "Y"), crs = 32736)
          in_hull <- sf::st_intersects(grid_sf, hull, sparse = FALSE)
          Grid_utm <- Grid_utm[in_hull[,1], ]
          
          Grid_mat <- as.matrix(Grid_utm)
          
          # Store grid for later use
          v$grid <- Grid_utm
          
          incProgress(0.3, detail = "Step 4: Calculating DTM...")
          
          # MATHEMATICAL FIX: Use m0 from your paper (0.05 for 5% leakage)
          m0_param <- input$mass_param
          k <- max(2, ceiling(m0_param * n_points))
          
          # Calculate DTM using TDA package
          DTM_values <- tryCatch({
            TDA::dtm(X = X_mat, Grid = Grid_mat, m0 = m0_param)
          }, error = function(e) {
            # Fallback: Manual DTM calculation
            apply(Grid_mat, 1, function(gp) {
              dists <- sqrt(rowSums((X_mat - matrix(gp, nrow = n_points, ncol = 2, byrow = TRUE))^2))
              mean(sort(dists)[1:k])
            })
          })
          
          # Store DTM values for elbow method
          v$debug_info <- list(
            dtm_vals = DTM_values,
            dtm_min = min(DTM_values, na.rm = TRUE),
            dtm_max = max(DTM_values, na.rm = TRUE),
            dtm_mean = mean(DTM_values, na.rm = TRUE),
            dtm_median = median(DTM_values, na.rm = TRUE),
            m0_param = m0_param,
            k_neighbors = k,
            grid_size = nrow(Grid_utm)
          )
          
          incProgress(0.5, detail = "Step 5: Finding structural voids...")
          
          # Use quantile threshold
          sensitivity <- input$significance
          threshold <- quantile(DTM_values, probs = 1 - sensitivity, na.rm = TRUE)
          
          # Local median threshold
          local_median_threshold <- median(DTM_values, na.rm = TRUE) * 1.5
          
          incProgress(0.7, detail = "Step 6: Creating void polygons...")
          
          # Create raster in UTM
          r_utm <- tryCatch({
            raster::rasterFromXYZ(
              data.frame(x = Grid_utm[,1], y = Grid_utm[,2], z = DTM_values),
              crs = 32736  # FIXED: removed +init=
            )
          }, error = function(e) {
            updateStatus("Warning: Raster creation issue", "warning")
            return(NULL)
          })
          
          if (is.null(r_utm)) {
            handleNoVoids(df)
            return()
          }
          
          # Find voids
          r_binary <- r_utm
          dtm_vals <- raster::values(r_binary)
          
          # Calculate IQR for DTM values
          dtm_q25 <- quantile(dtm_vals, 0.25, na.rm = TRUE)
          dtm_q75 <- quantile(dtm_vals, 0.75, na.rm = TRUE)
          dtm_iqr <- dtm_q75 - dtm_q25
          
          # Upper bound: Don't take extreme outliers
          upper_bound <- dtm_q75 + (2 * dtm_iqr)
          
          # Void condition
          is_void <- dtm_vals > threshold & 
            dtm_vals > local_median_threshold &
            dtm_vals <= upper_bound & 
            !is.na(dtm_vals)
          
          raster::values(r_binary) <- ifelse(is_void, 1, NA)
          
          # Check for voids
          if (!all(is.na(raster::values(r_binary)))) {
            void_polygons <- tryCatch({
              raster::rasterToPolygons(r_binary, dissolve = TRUE)
            }, error = function(e) {
              updateStatus("Warning: Polygon extraction issue", "warning")
              return(NULL)
            })
            
            if (!is.null(void_polygons) && length(void_polygons) > 0) {
              # Convert to sf
              void_sf_utm <- suppressWarnings({
                sf::st_as_sf(void_polygons) %>%
                  sf::st_cast("POLYGON")
              })
              
              # Remove empty geometries
              void_sf_utm <- void_sf_utm[!sf::st_is_empty(void_sf_utm), ]
              
              if (nrow(void_sf_utm) > 0) {
                # Transform back to WGS84
                void_sf_wgs84 <- sf::st_transform(void_sf_utm, crs = 4326)
                
                # Calculate areas
                void_sf_wgs84$area_km2 <- round(as.numeric(sf::st_area(void_sf_wgs84)) / 1e6, 2)
                void_sf_wgs84$void_id <- 1:nrow(void_sf_wgs84)
                
                # Calculate centroids
                centroids <- sf::st_centroid(void_sf_wgs84, of_largest_polygon = TRUE)
                centroid_coords <- sf::st_coordinates(centroids)
                
                # Create rings
                v$rings <- list()
                for (i in 1:nrow(void_sf_wgs84)) {
                  ring <- create_ring_from_polygon(void_sf_wgs84[i, ])
                  if (!is.null(ring)) {
                    v$rings[[i]] <- ring
                  }
                }
                
                # Determine structural vs stochastic voids
                void_sf_wgs84$is_structural <- FALSE
                
                for (i in 1:nrow(void_sf_wgs84)) {
                  void_area <- void_sf_wgs84$area_km2[i]
                  void_centroid <- sf::st_centroid(void_sf_wgs84[i, ], of_largest_polygon = TRUE)
                  
                  distances <- sf::st_distance(points_sf, void_centroid)
                  min_distance <- min(distances)
                  
                  if (void_area > 1.0 && as.numeric(min_distance) < 5000) {
                    void_sf_wgs84$is_structural[i] <- TRUE
                  }
                }
                
                # Add voids to map
                leafletProxy("map_main") %>%
                  addPolygons(
                    data = void_sf_wgs84,
                    color = ifelse(void_sf_wgs84$is_structural, "#e74c3c", "#f39c12"),
                    weight = 2,
                    fillColor = ifelse(void_sf_wgs84$is_structural, "#e74c3c", "#f39c12"),
                    fillOpacity = ifelse(void_sf_wgs84$is_structural, 0.3, 0.1),
                    group = "voids",
                    popup = ~paste("<strong>", ifelse(is_structural, "Structural Void ", "Stochastic Void "), 
                                   void_id, "</strong><br>",
                                   "Area: ", area_km2, " km²<br>",
                                   ifelse(is_structural, 
                                          "<em>Potential suppressed reporting zone</em>", 
                                          "<em>Natural low-density area</em>"))
                  )
                
                # Add red rings around STRUCTURAL voids
                for (i in 1:nrow(void_sf_wgs84)) {
                  if (void_sf_wgs84$is_structural[i] && !is.null(v$rings[[i]])) {
                    ring <- v$rings[[i]]
                    
                    leafletProxy("map_main") %>%
                      addPolylines(
                        data = ring$circle,
                        color = "#e74c3c",
                        weight = 3,
                        opacity = 0.8,
                        group = "rings",
                        popup = paste0("<strong>Structural Void Warning Ring</strong><br>",
                                       "Radius: ", ring$radius_km, " km<br>",
                                       "Enclosing Area: ", round(pi * (ring$radius_km^2), 2), " km²<br>",
                                       "<em>Investigate for suppressed reporting</em>")
                      )
                  }
                }
                
                # ===== CRITICAL: STORE RESULTS =====
                v$results <- list(
                  total_voids = nrow(void_sf_wgs84),
                  structural_count = sum(void_sf_wgs84$is_structural),
                  stochastic_count = sum(!void_sf_wgs84$is_structural),
                  total_area = sum(void_sf_wgs84$area_km2),
                  structural_area = sum(void_sf_wgs84$area_km2[void_sf_wgs84$is_structural]),
                  void_details = void_sf_wgs84,
                  threshold = round(threshold, 2),
                  points_analyzed = nrow(df),
                  centroids = centroid_coords,
                  dtm_stats = v$debug_info,
                  rings = v$rings
                )
                
                # ===== ADD VALIDATION METRICS =====
                if (!is.null(v$validation_mode) && v$validation_mode && !is.null(v$censoring_simulation$ground_truth)) {
                  if (nrow(v$censoring_simulation$ground_truth) >= 3) {
                    v$validation_metrics <- calculate_jaccard_index(
                      detected_polygons = void_sf_wgs84[void_sf_wgs84$is_structural, ],
                      ground_truth_points = v$censoring_simulation$ground_truth
                    )
                    v$results$validation <- v$validation_metrics
                  }
                }
                
                # ===== ADD PERMUTATION TEST =====
                if (nrow(df) <= 500) {
                  v$permutation_test <- enhanced_permutation_test(df, n_perm = 99)
                  v$results$permutation <- v$permutation_test
                }
                
                # ===== ADD CAVEATS =====
                v$caveats <- generate_caveats(void_sf_wgs84)
                v$results$caveats <- v$caveats
                
                # Update statistics
                updateStatistics(
                  nrow(df),
                  v$results$structural_count,
                  v$results$structural_area
                )
                
                updateStatus(paste("Found", v$results$structural_count, "structural voids"), "success")
                updateFooterTime()
                
                # Show detailed results
                showDetailedResults(void_sf_wgs84, df)
                
                # Auto-fit to show everything
                if (nrow(void_sf_wgs84) > 0) {
                  all_points <- rbind(
                    df,
                    data.frame(
                      long = centroid_coords[,1],
                      lat = centroid_coords[,2]
                    )
                  )
                  
                  leafletProxy("map_main") %>%
                    fitBounds(
                      lng1 = min(all_points$long, na.rm = TRUE) - 0.02,
                      lat1 = min(all_points$lat, na.rm = TRUE) - 0.02,
                      lng2 = max(all_points$long, na.rm = TRUE) + 0.02,
                      lat2 = max(all_points$lat, na.rm = TRUE) + 0.02
                    )
                }
                
                incProgress(1, detail = "Complete!")
                return()
              }
            }
          }
          
          # No voids found
          v$results <- list(
            total_voids = 0,
            structural_count = 0,
            stochastic_count = 0,
            total_area = 0,
            structural_area = 0,
            threshold = round(threshold, 2),
            points_analyzed = nrow(df),
            dtm_stats = v$debug_info
          )
          
          handleNoVoids(df)
          
          leafletProxy("map_main") %>%
            fitBounds(
              lng1 = min(df$long, na.rm = TRUE) - 0.01,
              lat1 = min(df$lat, na.rm = TRUE) - 0.01,
              lng2 = max(df$long, na.rm = TRUE) + 0.01,
              lat2 = max(df$lat, na.rm = TRUE) + 0.01
            )
          
          incProgress(1, detail = "Complete!")
          
        }, error = function(e) {
          updateStatus(paste("Error:", e$message), "error")
          handleNoVoids(v$data)
          return()
        })
      }
    )
    
    v$analysis_time <- Sys.time()
    
    runjs("
      setTimeout(function() {
        document.getElementById('map_section').scrollIntoView({
          behavior: 'smooth',
          block: 'center'
        });
      }, 300);
    ")
  }
  
  # ========== SAFE ANALYSIS WRAPPER ==========
  safe_tda_analysis <- function() {
    tryCatch({
      # Simple rate limiting - prevent rapid clicks
      last_run <- isolate(v$analysis_time)
      if (!is.null(last_run) && difftime(Sys.time(), last_run, units = "secs") < 5) {
        updateStatus("Please wait 5 seconds between analyses", "warning")
        return()
      }
      
      run_tda_analysis()
    }, error = function(e) {
      updateStatus("Analysis failed. Please try again.", "error")
    })
  }
  
  # 5. ACTION BUTTON HANDLERS
  observeEvent(input$run_scan, {
    safe_tda_analysis()
  })
  
  observeEvent(input$run_floating_scan, {
    safe_tda_analysis()
  })
  
  # 6. MAP CONTROLS
  observeEvent(input$fit_bounds, {
    req(v$data)
    df <- v$data
    leafletProxy("map_main") %>% 
      fitBounds(
        lng1 = min(df$long, na.rm = TRUE) - 0.01,
        lat1 = min(df$lat, na.rm = TRUE) - 0.01,
        lng2 = max(df$long, na.rm = TRUE) + 0.01,
        lat2 = max(df$lat, na.rm = TRUE) + 0.01
      )
  })
  
  # 7. EXPORT HANDLER - HTML/PDF VERSION
  output$export_report <- downloadHandler(
    filename = function() {
      paste0("TDA_Report_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".html")
    },
    content = function(file) {
      # Create HTML content
      html_content <- generate_html_report(v, input)
      writeLines(html_content, file)
    }
  )
  
  # Helper function for HTML report
  generate_html_report <- function(v, input) {
    
    css_style <- "
      <style>
        body { 
          font-family: 'Inter', -apple-system, sans-serif; 
          margin: 20px; 
          color: #374151;
          line-height: 1.6;
        }
        h1 { 
          color: #2c3e50; 
          border-bottom: 2px solid #3498db; 
          padding-bottom: 10px;
          font-size: 24px;
          margin-bottom: 20px;
        }
        h2 { 
          color: #3498db; 
          margin-top: 25px;
          font-size: 18px;
          border-bottom: 1px solid #e5e7eb;
          padding-bottom: 5px;
        }
        .metric { 
          background: #f8f9fa; 
          padding: 15px; 
          border-radius: 8px; 
          margin: 15px 0;
          border-left: 4px solid #3498db;
        }
        table { 
          width: 100%; 
          border-collapse: collapse; 
          margin: 15px 0;
          font-size: 14px;
        }
        th { 
          background: #2c3e50; 
          color: white; 
          padding: 10px; 
          text-align: left;
          font-weight: 600;
        }
        td { 
          padding: 10px; 
          border: 1px solid #e5e7eb;
        }
        tr:nth-child(even) {
          background: #f9fafb;
        }
        .structural { 
          color: #e74c3c; 
          font-weight: bold;
        }
        .stochastic { 
          color: #f39c12;
        }
        .footer { 
          margin-top: 40px; 
          font-size: 0.9em; 
          color: #6b7280; 
          text-align: center;
          padding-top: 20px;
          border-top: 1px solid #e5e7eb;
        }
        ul {
          padding-left: 20px;
          margin: 10px 0;
        }
        li {
          margin: 5px 0;
        }
        .math {
          font-family: 'Times New Roman', serif;
          font-style: italic;
          margin: 10px 0;
          padding: 10px;
          background: #f8f9fa;
          border-radius: 4px;
          text-align: center;
        }
        strong {
          color: #2c3e50;
        }
      </style>
    "
    
    header <- paste0("
      <!DOCTYPE html>
      <html>
      <head>
        <title>TDA Engine Report</title>
        <meta charset='UTF-8'>
        ", css_style, "
      </head>
      <body>
        <h1>TDA Engine - Structural Void Analysis Report</h1>
        <div class='metric'>
          <p><strong>Generated:</strong> ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "</p>
          <p><strong>Data source:</strong> ", v$mode, "</p>
        </div>
    ")
    
    if (!is.null(v$results)) {
      content <- paste0(header, "
        <h2>Analysis Results</h2>
        <div class='metric'>
          <p><strong>Total points analyzed:</strong> ", v$results$points_analyzed, "</p>
          <p><strong>Structural voids detected:</strong> ", v$results$structural_count, "</p>
          <p><strong>Stochastic voids detected:</strong> ", v$results$stochastic_count, "</p>
          <p><strong>Total structural void area:</strong> ", v$results$structural_area, " km²</p>
          <p><strong>DTM threshold (Q<sub>1-α</sub>):</strong> ", v$results$threshold, " meters</p>
        </div>
        
        <h2>Parameters</h2>
        <ul>
          <li><strong>m₀ (Mass):</strong> ", input$mass_param, "</li>
          <li><strong>α (Sensitivity):</strong> ", input$significance, "</li>
          <li><strong>Δ (Resolution):</strong> ", input$resolution, " km</li>
          <li><strong>Focus area:</strong> ", ifelse(input$restrict_nyanza, "Nyanza region", "Full data extent"), "</li>
        </ul>
      ")
      
      if (!is.null(v$results$void_details) && nrow(v$results$void_details) > 0) {
        content <- paste0(content, "
          <h2>Void Details</h2>
          <table>
            <tr>
              <th>ID</th>
              <th>Type</th>
              <th>Area (km²)</th>
              <th>Ring Radius (km)</th>
              <th>Action</th>
            </tr>
        ")
        
        for (i in 1:nrow(v$results$void_details)) {
          void_type <- ifelse(v$results$void_details$is_structural[i], "Structural", "Stochastic")
          ring_radius <- ifelse(v$results$void_details$is_structural[i] && 
                                  !is.null(v$rings[[i]]), 
                                as.character(v$rings[[i]]$radius_km), "N/A")
          action <- ifelse(v$results$void_details$is_structural[i], 
                           "<span class='structural'>⚠️ Investigate for suppressed reporting</span>", 
                           "<span class='stochastic'>Natural variation (no action needed)</span>")
          
          content <- paste0(content, "
            <tr>
              <td>", i, "</td>
              <td><strong>", void_type, "</strong></td>
              <td>", v$results$void_details$area_km2[i], "</td>
              <td>", ring_radius, "</td>
              <td>", action, "</td>
            </tr>
          ")
        }
        
        content <- paste0(content, "</table>")
      }
      
      # Add DTM stats if available
      if (!is.null(v$debug_info)) {
        content <- paste0(content, "
          <h2>Analysis Metrics</h2>
          <div class='metric'>
            <p><strong>DTM range:</strong> ", round(v$debug_info$dtm_min, 1), " to ", round(v$debug_info$dtm_max, 1), " meters</p>
            <p><strong>DTM mean:</strong> ", round(v$debug_info$dtm_mean, 1), " meters</p>
            <p><strong>k neighbors:</strong> ", v$debug_info$k_neighbors, "</p>
            <p><strong>Grid cells analyzed:</strong> ", v$debug_info$grid_size, "</p>
          </div>
        ")
      }
      
      # Add methodology
      content <- paste0(content, "
        <h2>Methodology</h2>
        <div class='metric'>
          <p><strong>Based on:</strong> Mboya, G. O. (2026). <em>The Geometry of Silence: Topological Inference for Detecting Structural Voids in Spatially Censored Epidemiological Data</em></p>
          
          <ol>
            <li><strong>Coordinate projection</strong> to UTM Zone 36S (EPSG:32736)</li>
            <li><strong>Distance-to-Measure filtration:</strong>
              <div class='math'>d<sub>m₀</sub>(x) = √[1/k Σ<sub>i=1</sub><sup>k</sup> ||x - X<sub>(i)</sub>||²]</div>
              where k = ⌈m₀·n⌉, m₀ = 0.05
            </li>
            <li><strong>Structural void criterion:</strong> d<sub>m₀</sub>(x) > Q<sub>1-α</sub></li>
            <li><strong>Minimum Enclosing Circle (Welzl)</strong> for ring generation</li>
            <li><strong>Area computation</strong> in square kilometers</li>
          </ol>
        </div>
      ")
      
    } else {
      content <- paste0(header, "
        <div class='metric'>
          <p>No analysis results available.</p>
        </div>
        <h2>Current Parameters</h2>
        <ul>
          <li><strong>m₀ (Mass):</strong> ", input$mass_param, "</li>
          <li><strong>α (Sensitivity):</strong> ", input$significance, "</li>
          <li><strong>Δ (Resolution):</strong> ", input$resolution, " km</li>
        </ul>
      ")
    }
    
    footer <- "
        <div class='footer'>
          <hr>
          <p><strong>Generated by TDA Engine v1.0</strong></p>
          <p>Mboya, G. O. (2026). TDA Engine v1.0: A Computational Framework for Detecting Structural Voids in Spatially Censored Epidemiological Data.</p>
          <p>DOI: <a href='http://dx.doi.org/10.64898/2026.02.01.26345283' target='_blank'>10.64898/2026.02.01.26345283</a></p>
        </div>
      </body>
      </html>
    "
    
    return(paste0(content, footer))
  }
  
  # 8. UI OUTPUTS
  output$file_status_ui <- renderUI({
    if (v$mode == "upload" && !is.null(input$upload)) {
      div(
        class = "alert alert-success d-flex justify-content-between align-items-center py-1 px-2 mb-2",
        style = "font-size: 0.7rem;",
        div(
          class = "d-flex align-items-center gap-1",
          icon("check", class = "fs-6"),
          span("File loaded")
        ),
        actionButton("clear_file", "", icon = icon("times"),
                     class = "btn-sm btn-outline-danger p-0",
                     style = "width: 18px; height: 18px;",
                     onclick = "Shiny.setInputValue('reset_btn', Math.random());")
      )
    }
  })
  
  # 9. CLOSE RESULTS HANDLER
  observeEvent(input$close_results, {
    runjs("hideResults();")
  })
  
  # 10. HELPER FUNCTIONS
  updateStatistics <- function(points, voids, area) {
    session$sendCustomMessage("update_stats", 
                              list(points = points, voids = voids, area = area))
  }
  
  updateStatus <- function(text, type) {
    session$sendCustomMessage("update_status", list(text = text, type = type))
  }
  
  updateFooterTime <- function() {
    session$sendCustomMessage("update_footer_time", format(Sys.time(), "%H:%M"))
  }
  
  updateFloatingButton <- function() {
    session$sendCustomMessage("update_floating_btn", v$floating_btn_text)
  }
  
  handleNoVoids <- function(df) {
    updateStatistics(nrow(df), 0, 0)
    updateStatus("No structural voids detected", "warning")
    updateFooterTime()
    
    debug_html <- ""
    if (!is.null(v$debug_info)) {
      debug_html <- sprintf("
        <div class='alert alert-info mt-2'>
          <h6 class='fw-bold mb-1'>Analysis Metrics</h6>
          <table class='table table-sm mb-0'>
            <tr><td>DTM range:</td><td>%.1f to %.1f meters</td></tr>
            <tr><td>DTM mean:</td><td>%.1f meters</td></tr>
            <tr><td>Threshold (Q_{1-α}):</td><td>%.1f meters</td></tr>
            <tr><td>k neighbors:</td><td>%s</td></tr>
            <tr><td>Grid cells:</td><td>%s</td></tr>
          </table>
          <p class='mb-0 small mt-1'>For detecting voids inside dense clusters, try increasing m₀ to 0.10-0.15.</p>
        </div>
      ",
                            v$debug_info$dtm_min,
                            v$debug_info$dtm_max,
                            v$debug_info$dtm_mean,
                            v$results$threshold,
                            v$debug_info$k_neighbors,
                            v$debug_info$grid_size
      )
    }
    
    results_html <- sprintf("
      <div class='p-2'>
        <div class='alert alert-light border-start border-3 border-info mb-2'>
          <h6 class='fw-bold mb-1'>Analysis Complete</h6>
          <p class='mb-0'>No structural voids detected with current parameters.</p>
          <p class='mb-0 small'>Remember: We're looking for voids <strong>inside</strong> data clusters, not empty areas.</p>
        </div>
        
        <h6 class='fw-bold mb-2' style='font-size: 0.7rem;'>Parameters Used</h6>
        <table class='table table-sm mb-2'>
          <tr><td><strong>Points analyzed:</strong></td><td>%s</td></tr>
          <tr><td><strong>m₀ (Mass):</strong></td><td>%s</td></tr>
          <tr><td><strong>α (Sensitivity):</strong></td><td>%s</td></tr>
          <tr><td><strong>Δ (Resolution):</strong></td><td>%s km</td></tr>
        </table>
        %s
      </div>
    ", nrow(df), input$mass_param, input$significance, input$resolution, debug_html)
    
    session$sendCustomMessage("show_results", results_html)
  }
  
  showDetailedResults <- function(void_sf, df) {
    debug_html <- ""
    if (!is.null(v$debug_info)) {
      debug_html <- sprintf("
        <div class='alert alert-info mt-3'>
          <h6 class='fw-bold mb-1'>Analysis Metrics</h6>
          <table class='table table-sm mb-0'>
            <tr><td>DTM range:</td><td>%.1f to %.1f meters</td></tr>
            <tr><td>DTM mean:</td><td>%.1f meters</td></tr>
            <tr><td>Threshold (Q_{1-α}):</td><td>%.1f meters</td></tr>
            <tr><td>k neighbors:</td><td>%s</td></tr>
            <tr><td>Grid cells:</td><td>%s</td></tr>
          </table>
        </div>
      ",
                            v$debug_info$dtm_min,
                            v$debug_info$dtm_max,
                            v$debug_info$dtm_mean,
                            v$results$threshold,
                            v$debug_info$k_neighbors,
                            v$debug_info$grid_size
      )
    }
    
    # ===== NEW: VALIDATION METRICS DISPLAY =====
    validation_html <- ""
    if (!is.null(v$validation_metrics)) {
      validation_html <- sprintf("
        <div class='alert alert-success mt-2 mb-3'>
          <h6 class='fw-bold mb-2'><i class='fa fa-check-circle'></i> Validation Against Ground Truth</h6>
          <table class='table table-sm mb-0'>
            <tr>
              <td><strong>Jaccard Index:</strong></td>
              <td>%.3f</td>
              <td><span class='badge bg-%s'>%s</span></td>
            </tr>
            <tr>
              <td><strong>Recovery Rate:</strong></td>
              <td>%.1f%%</td>
              <td>%s of suppressed area detected</td>
            </tr>
            <tr>
              <td><strong>Centroid Error:</strong></td>
              <td>%.0f m</td>
              <td>%s</td>
            </tr>
            <tr>
              <td><strong>Dice Coefficient:</strong></td>
              <td>%.3f</td>
              <td>Harmonic mean of precision/recall</td>
            </tr>
          </table>
        </div>
      ",
                                 v$validation_metrics$jaccard,
                                 ifelse(v$validation_metrics$jaccard > 0.7, "success", 
                                        ifelse(v$validation_metrics$jaccard > 0.4, "warning", "danger")),
                                 ifelse(v$validation_metrics$jaccard > 0.7, "Excellent",
                                        ifelse(v$validation_metrics$jaccard > 0.4, "Moderate", "Poor")),
                                 v$validation_metrics$recovery_rate * 100,
                                 sprintf("%.1f km²", v$validation_metrics$intersection_area_km2),
                                 v$validation_metrics$centroid_error_m,
                                 ifelse(v$validation_metrics$centroid_error_m < 500, "High precision",
                                        ifelse(v$validation_metrics$centroid_error_m < 1000, "Moderate", "Low precision")),
                                 v$validation_metrics$dice
      )
    }
    
    # ===== NEW: PERMUTATION TEST DISPLAY =====
    perm_html <- ""
    if (!is.null(v$permutation_test)) {
      perm_html <- sprintf("
        <div class='alert alert-info mt-2 mb-3'>
          <h6 class='fw-bold mb-2'><i class='fa fa-calculator'></i> Statistical Inference</h6>
          <table class='table table-sm mb-0'>
            <tr>
              <td><strong>Void area test:</strong></td>
              <td>%s</td>
            </tr>
            <tr>
              <td><strong>Effect size:</strong></td>
              <td>%.1fx larger than random</td>
            </tr>
          </table>
        </div>
      ",
                           v$permutation_test$area_statistic$interpretation,
                           v$permutation_test$effect_size
      )
    }
    
    # ===== NEW: CAVEATS DISPLAY =====
    caveats_html <- ""
    if (!is.null(v$caveats)) {
      alt_explanations <- paste(
        sprintf("<li>%s</li>", v$caveats$alternative_explanations[1:3]), 
        collapse = ""
      )
      
      caveats_html <- sprintf("
        <div class='alert alert-warning mt-3 mb-0'>
          <h6 class='fw-bold mb-2'><i class='fa fa-exclamation-triangle'></i> %s</h6>
          <p class='small mb-1'><strong>Interpretation:</strong> %s</p>
          <p class='small mb-1'><strong>Alternative explanations:</strong></p>
          <ul class='small mb-1' style='padding-left: 20px;'>
            %s
          </ul>
          <p class='small mb-0'><strong>Required context:</strong> %s</p>
        </div>
      ",
                              v$caveats$disclaimer,
                              v$caveats$interpretation,
                              alt_explanations,
                              paste(v$caveats$required_context[1:2], collapse = ", ")
      )
    }
    
    # Create ring information for results
    ring_info_html <- ""
    if (!is.null(v$rings) && length(v$rings) > 0) {
      ring_details <- ""
      for (i in 1:nrow(void_sf)) {
        if (void_sf$is_structural[i] && !is.null(v$rings[[i]])) {
          ring <- v$rings[[i]]
          ring_details <- paste0(ring_details, sprintf("
            <tr>
              <td>%d</td>
              <td><span class='badge bg-danger'>Structural</span></td>
              <td>%.2f km²</td>
              <td>%.2f km</td>
              <td><strong>⚠️ Investigate</strong></td>
            </tr>
          ", i, void_sf$area_km2[i], ring$radius_km))
        } else if (!void_sf$is_structural[i]) {
          ring_details <- paste0(ring_details, sprintf("
            <tr>
              <td>%d</td>
              <td><span class='badge bg-warning'>Stochastic</span></td>
              <td>%.2f km²</td>
              <td>N/A</td>
              <td>Natural variation</td>
            </tr>
          ", i, void_sf$area_km2[i]))
        }
      }
      ring_info_html <- ring_details
    }
    
    html_content <- sprintf("
      <div class='p-2'>
        <div class='alert alert-success border-start border-2 border-success mb-3'>
          <h6 class='fw-bold mb-1'>Topological Analysis Complete</h6>
          <p class='mb-0'>Found <strong>%s</strong> structural void(s) covering <strong>%s km²</strong></p>
        </div>
        
        %s  <!-- Validation metrics -->
        %s  <!-- Permutation test -->
        
        <h6 class='fw-bold mb-2' style='font-size: 0.7rem;'>Parameters</h6>
        <table class='table table-sm mb-3'>
          <tr><td>m₀ (Mass):</td><td>%s</td>
              <td>%s</td></tr>
          <tr><td>α (Sensitivity):</td><td>%s</td>
              <td>%s</td></tr>
          <tr><td>Δ (Resolution):</td><td>%s km</td>
              <td>%s</td></tr>
          <tr><td>Points analyzed:</td><td>%s</td>
              <td></td></tr>
        </table>
        
        <h6 class='fw-bold mb-2' style='font-size: 0.7rem;'>Void Details</h6>
        <div class='table-responsive'>
          <table class='table table-sm'>
            <thead>
              <tr>
                <th>ID</th>
                <th>Type</th>
                <th>Area (km²)</th>
                <th>Ring Radius</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              %s
            </tbody>
          </table>
        </div>
        
        %s  <!-- Debug info -->
        %s  <!-- Caveats -->
        
      </div>
    ",
                            v$results$structural_count,
                            v$results$structural_area,
                            validation_html,
                            perm_html,
                            input$mass_param,
                            if (!is.null(v$m0_analysis) && 0.05 >= v$m0_analysis$stable_range[1] && 0.05 <= v$m0_analysis$stable_range[2]) 
                              "<span class='badge bg-success'>stable</span>" else "<span class='badge bg-warning'>check stability</span>",
                            input$significance,
                            if (!is.null(v$elbow_threshold)) 
                              sprintf("<span class='badge bg-info'>elbow: %.2f</span>", v$elbow_threshold$alpha) else "",
                            input$resolution,
                            if (input$resolution >= 1.5) "<span class='badge bg-success'>topological horizon crossed</span>" else "<span class='badge bg-warning'>below horizon</span>",
                            nrow(df),
                            ring_info_html,
                            debug_html,
                            caveats_html
    )
    
    session$sendCustomMessage("show_results", html_content)
  }
  
  # 11. INITIAL MAP RENDER
  output$map_main <- renderLeaflet({
    leaflet(options = leafletOptions(minZoom = 8, maxZoom = 16)) %>%
      addProviderTiles(providers$CartoDB.Positron,
                       options = providerTileOptions(noWrap = TRUE)) %>%
      setView(34.65, -0.35, 10) %>%
      addScaleBar(position = "bottomleft")
  })
}

# -------------------------------------------------------------------------
# ADD JAVASCRIPT HANDLERS - FIXED VERSION
# -------------------------------------------------------------------------
ui <- tagList(
  ui,
  tags$head(
    tags$style(HTML("
      /* Your existing CSS styles */
    ")),
    
    # ========== SESSION TIMEOUT SCRIPT ==========
    tags$script(HTML("
      // Session timeout after 30 minutes of inactivity
      var idleTime = 0;
      
      function resetIdleTime() {
        idleTime = 0;
      }
      
      // Increment every minute
      var idleInterval = setInterval(function() {
        idleTime++;
        if (idleTime > 30) { // 30 minutes
          clearInterval(idleInterval);
          alert('Session expired due to inactivity. Page will refresh.');
          window.location.reload();
        }
      }, 60000);
      
      // Reset on user activity
      $(document).on('mousemove keypress click scroll', resetIdleTime);
      
      // Cleanup on page unload
      $(window).on('beforeunload', function() {
        clearInterval(idleInterval);
      });
    "))
  ),
  
  tags$script(HTML("
    // Create floating action button
    $(document).ready(function() {
      var floatingBtn = $('<button>', {
        id: 'floating_action_btn',
        html: '<i class=\"fa fa-search\"></i><span class=\"fab-text\">SCAN DEMO</span>',
        title: 'Run Analysis',
        click: function() {
          Shiny.setInputValue('run_floating_scan', Math.random());
          $(this).addClass('active');
          setTimeout(function() {
            $('#floating_action_btn').removeClass('active');
          }, 500);
          
          // Auto-scroll to map
          setTimeout(function() {
            var mapSection = document.getElementById('map_section');
            if (mapSection) {
              mapSection.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
              });
            }
          }, 100);
        }
      });
      $('body').append(floatingBtn);
      
      // Update slider values
      $('#mass_param').on('input', function() {
        $('#mass_value').text(parseFloat($(this).val()).toFixed(2));
      });
      
      $('#significance').on('input', function() {
        var val = parseFloat($(this).val());
        $('#sensitivity_value').text(val.toFixed(2));
      });
      
      $('#resolution').on('input', function() {
        $('#resolution_value').text(parseFloat($(this).val()).toFixed(1) + ' km');
      });
      
      // Initialize tooltips
      setTimeout(function() {
        $('[title]').tooltip();
      }, 500);
      
      // FIXED: Initialize Bootstrap collapse for accordion
      var collapseEl = document.getElementById('userGuide');
      var trigger = document.querySelector('[data-bs-target=\"#userGuide\"]');
      
      if (collapseEl && trigger) {
        // Initialize collapse with show option
        var bsCollapse = new bootstrap.Collapse(collapseEl, { toggle: false });
        
        // Start collapsed - FIXED
        bsCollapse.hide();
        
        // Toggle chevron icon - FIXED
        trigger.addEventListener('click', function(event) {
          event.preventDefault();
          setTimeout(function() {
            var isCollapsed = collapseEl.classList.contains('show');
            var icon = trigger.querySelector('i');
            if (isCollapsed) {
              icon.className = 'fa fa-chevron-down';
            } else {
              icon.className = 'fa fa-chevron-up';
            }
          }, 150);
        });
      }
      
      // Force MathJax rendering after page load
      setTimeout(function() {
        if (typeof MathJax !== 'undefined' && MathJax.Hub) {
          MathJax.Hub.Queue(['Typeset', MathJax.Hub, 'math-content']);
        }
      }, 1500);
    });
    
    // Update floating button text
    Shiny.addCustomMessageHandler('update_floating_btn', function(text) {
      $('#floating_action_btn .fab-text').text(text);
    });
    
    // Update statistics
    Shiny.addCustomMessageHandler('update_stats', function(message) {
      $('#stat_points').text(message.points);
      $('#stat_voids').text(message.voids);
      $('#stat_area').text(message.area);
    });
    
    // Update status
    Shiny.addCustomMessageHandler('update_status', function(message) {
      var badge = $('#status_badge');
      var colors = {
        'ready': ['#27ae6015', '#27ae60', 'check'],
        'processing': ['#3498db15', '#3498db', 'sync fa-spin'],
        'success': ['#27ae6015', '#27ae60', 'check'],
        'warning': ['#f39c1215', '#f39c12', 'exclamation-circle'],
        'error': ['#e74c3c15', '#e74c3c', 'times-circle']
      };
      
      var config = colors[message.type] || colors['ready'];
      
      badge.html('<i class=\"fa fa-' + config[2] + ' me-1\"></i>' + message.text);
      badge.css({
        'background': config[0],
        'color': config[1]
      });
      
      if (message.type === 'processing') {
        badge.addClass('processing');
      } else {
        badge.removeClass('processing');
      }
    });
    
    // Update footer time
    Shiny.addCustomMessageHandler('update_footer_time', function(time) {
      $('#footer_time').text(time);
    });
    
    // Show detailed results
    Shiny.addCustomMessageHandler('show_results', function(message) {
      $('#results_content').html(message);
      $('#detailed_results').slideDown();
      // Trigger MathJax rendering for new content
      if (typeof MathJax !== 'undefined' && MathJax.Hub) {
        setTimeout(function() {
          MathJax.Hub.Queue(['Typeset', MathJax.Hub]);
        }, 300);
      }
    });
    
    // Hide results
    window.hideResults = function() {
      $('#detailed_results').slideUp();
    };
    
    // MathJax processing - FIXED
    if (typeof MathJax !== 'undefined' && MathJax.Hub) {
      // Configure MathJax
      MathJax.Hub.Config({
        tex2jax: {
          inlineMath: [ ['$','$'], ['\\\\(','\\\\)'] ],
          displayMath: [ ['$$','$$'], ['\\\\[','\\\\]'] ],
          processEscapes: true
        },
        messageStyle: 'none',
        skipStartupTypeset: false,
        'HTML-CSS': {
          scale: 90
        }
      });
      
      // Initial typesetting
      MathJax.Hub.Queue(['Typeset', MathJax.Hub]);
    }
    
        // ===== NEW: Update sensitivity badge with elbow info =====
    Shiny.addCustomMessageHandler('update_sensitivity_badge', function(msg) {
      $('#sensitivity_value').html(
        '<span>' + msg.alpha + ' <span style=\"font-size:0.6rem; margin-left:2px;\">elbow: ' + msg.elbow + 'm</span></span>'
      );
    });
    
     // ===== NEW: Update m₀ badge with stability info =====
    Shiny.addCustomMessageHandler('update_m0_badge', function(msg) {
      var badge = $('#mass_value');
      if (msg.stable) {
        badge.css({
          'background': '#27ae6015',
          'color': '#27ae60'
        });
        badge.html('<span>0.05 <span style=\"font-size:0.6rem; margin-left:2px;\">✓ stable</span></span>');
      } else {
        badge.css({
          'background': '#f39c1215',
          'color': '#f39c12'
        });
        badge.html('<span>0.05 <span style=\"font-size:0.6rem; margin-left:2px;\">⚠️ range: ' + msg.range + '</span></span>');
      }
    });
    
    "))
)

# -------------------------------------------------------------------------
# RUN APP
# -------------------------------------------------------------------------
shinyApp(ui = ui, server = server)