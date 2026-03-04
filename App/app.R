# =============================================================================
# GEOMETRY OF SILENCE — v2.1
# Sentinel Silence Monitor for Disease Surveillance Systems
#
# Author:  Mboya Grold Otieno
# DOI:     10.64898/2026.02.01.26345283
# License: GPL-3.0 — see https://www.gnu.org/licenses/gpl-3.0.html
#
# WHAT'S NEW IN v2.1
# ──────────────────
# 1. STOCHASTIC vs STRUCTURAL VOID CLASSIFIER
#    Each temporal void is now labelled:
#      • STRUCTURAL — persistent, geography/system-driven silence
#        (Fano factor >> 1 AND mean O/E consistently low)
#      • STOCHASTIC — random fluctuation around a near-adequate mean
#        (Fano ≈ Poisson; single-period dip, not a pattern)
#    Method: Fano factor (variance/mean of O/E across periods) as primary
#    classifier; 2-state HMM posterior (Viterbi path) as confidence score.
#    No external HMM package needed — pure R EM implementation.
#
# 2. PROGRESSIVE INPUT — INLINE REVEAL WITH VALIDATION GATES
#    The sidebar unlocks in stages:
#      Stage 1 — Disease + Period (always visible)
#      Stage 2 — Data source selector (unlocks after stage 1)
#      Stage 3 — Upload or demo toggle (unlocks after stage 2)
#      Stage 4 — Parameters + Run button (unlocks after valid data loaded)
#    Each stage has a visual gate indicator (locked/unlocked/complete).
#
# 3. REAL DATA SOURCES
#    Three buttons give users tested, working CSV sources:
#      A. WHO GHO API  — direct CSV download link for the selected disease
#      B. DHIS2 play   — export URL for the DHIS2 demo server
#      C. KHIS Kenya   — link to Kenya Health Information System
#    Plus a "Realistic Noisy CSV" generator that mimics true DHIS2 export
#    artifacts: missing periods, zero-report weeks, encoding junk, duplicates.
#
# INPUT FORMAT (DHIS2-compatible):
#   CSV with columns: period, admin_unit, population, reported_cases
#   Optional: lat, long, facility_count, road_index, area_km2
# =============================================================================

suppressPackageStartupMessages({
  library(shiny)
  library(leaflet)
  library(shinyjs)
  library(sf)
  library(TDA)
  library(raster)
})

# =============================================================================
# WATERMARK
# =============================================================================
WM_AUTHOR   <- "Mboya Grold Otieno"
WM_DOI      <- "10.64898/2026.02.01.26345283"
WM_TOOL     <- "TDA Engine— v2.1"
WM_URL      <- "https://doi.org/10.64898/2026.02.01.26345283"
WM_CITATION <- paste0("Mboya, G. O. (2026). TDA Engine v1.0: A Computational Framework for Detecting Structural Voids in Spatially Censored Epidemiological Data. doi:", WM_DOI)
.stamp <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S UTC")

# =============================================================================
# DISEASE REFERENCE INCIDENCE RATES
# =============================================================================
.DISEASE_REF <- list(
  malaria = list(
    label      = "Malaria",
    rate_per_k = 225,
    unit       = "cases/1000/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "Malaria Atlas Project 2022; WHO World Malaria Report 2023",
    icd        = "B50-B54",
    zero_floor = 0.1,
    critical   = 0.20,
    moderate   = 0.50,
    mild       = 0.75,
    # WHO GHO indicator code for real data download
    gho_code   = "MALARIA_EST_INCIDENCE",
    dhis2_de   = "fbfJHSPpUQD"   # DHIS2 play server data element (malaria cases)
  ),
  cholera = list(
    label      = "Cholera / AWD",
    rate_per_k = 3.5,
    unit       = "cases/1000/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "WHO AFRO Cholera Surveillance 2023",
    icd        = "A00",
    zero_floor = 0.01,
    critical   = 0.15,
    moderate   = 0.40,
    mild       = 0.70,
    gho_code   = "CHOLERA_0000000001",
    dhis2_de   = "h0xKKjijTdI"
  ),
  tb = list(
    label      = "Tuberculosis",
    rate_per_k = 220,
    unit       = "cases/100000/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "WHO Global Tuberculosis Report 2023",
    icd        = "A15-A19",
    zero_floor = 1,
    critical   = 0.30,
    moderate   = 0.55,
    mild       = 0.80,
    gho_code   = "MDG_0000000020",
    dhis2_de   = "bCqRGKLSA53"
  ),
  measles = list(
    label      = "Measles",
    rate_per_k = 8.2,
    unit       = "cases/1000 under-5/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "WHO WUENIC 2022; UNICEF State of the World's Children 2023",
    icd        = "B05",
    zero_floor = 0.01,
    critical   = 0.10,
    moderate   = 0.35,
    mild       = 0.65,
    gho_code   = "WHS3_62",
    dhis2_de   = "jtF0GCxCH5L"
  ),
  maternal = list(
    label      = "Maternal Deaths",
    rate_per_k = 0.53,
    unit       = "deaths/1000 live births/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "WHO/UNICEF MMEIG Maternal Mortality 2020",
    icd        = "O00-O99",
    zero_floor = 0.001,
    critical   = 0.20,
    moderate   = 0.45,
    mild       = 0.70,
    gho_code   = "MDG_0000000003",
    dhis2_de   = "K2TvBWoZ5p7"
  ),
  meningitis = list(
    label      = "Meningitis",
    rate_per_k = 10,
    unit       = "cases/100000/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "WHO Meningitis Initiative 2023",
    icd        = "G00-G03",
    zero_floor = 0.01,
    critical   = 0.20,
    moderate   = 0.50,
    mild       = 0.75,
    gho_code   = "MENINGITIS_CASES",
    dhis2_de   = "n6aMJNLdvep"
  ),
  hiv = list(
    label      = "HIV New Infections",
    rate_per_k = 3.0,
    unit       = "new infections/1000 adults/year",
    period_div = list(annual=1, monthly=12, weekly=52, quarterly=4),
    source     = "UNAIDS Global AIDS Update 2023",
    icd        = "B20-B24",
    zero_floor = 0.01,
    critical   = 0.25,
    moderate   = 0.55,
    mild       = 0.80,
    gho_code   = "HIV_0000000026",
    dhis2_de   = "PLq9sJluXvc"
  )
)

# =============================================================================
# KENYA NYANZA REFERENCE DATA
# =============================================================================
.KENYA_RATES <- data.frame(
  admin_unit = c(
    "Kisumu Central","Kisumu East","Kisumu West","Seme","Muhoroni","Nyando",
    "Nyakach","Kajulu","Homa Bay Town","Rangwe","Rachuonyo North",
    "Rachuonyo South","Mbita","Suba North","Suba South","Karachuonyo",
    "Ndhiwa","Siaya Town","Gem","Ugenya","Ugunja","Bondo","Rarieda",
    "Migori Town","Awendo","Uriri","Kuria East","Kuria West","Nyatike",
    "Rongo","Suna East","Suna West","Kisii Town","Bomachoge","Bobasi",
    "South Mugirango","Bonchari","Kitutu North","Kitutu South",
    "Nyamira Town","Manga","Masaba North","Borabu","North Mugirango"),
  county = c(
    rep("Kisumu",8), rep("Homa Bay",9), rep("Siaya",6),
    rep("Migori",9), rep("Kisii",7), rep("Nyamira",5)),
  population = c(
    409000,178000,155000,93000,176000,192000,203000,84000,
    131000,82000,162000,143000,77000,45000,61000,123000,198000,
    228000,145000,123000,87000,132000,109000,
    176000,98000,89000,72000,84000,113000,141000,118000,97000,
    343000,98000,143000,112000,87000,129000,119000,
    148000,82000,76000,112000,128000),
  area_km2 = c(
    22,88,44,219,368,445,524,38,
    69,312,419,287,673,812,445,267,423,
    292,548,319,207,474,388,
    67,287,412,447,389,1024,312,178,244,
    52,198,334,287,198,312,267,
    89,145,178,289,312),
  malaria_rate_k = c(
    180,220,190,160,120,200,210,170,
    380,350,420,400,480,460,440,370,310,
    280,320,290,250,310,270,
    180,160,190,210,230,220,170,195,185,
    60,55,70,65,50,45,55,
    40,45,50,35,55),
  facility_count = c(
    28,19,16,12,18,21,23,11,
    17,10,19,16,9,6,8,15,22,
    24,16,14,11,15,13,
    19,12,11,9,10,14,17,13,12,
    35,11,16,13,10,14,13,
    16,10,9,13,15),
  road_index = c(
    0.92,0.84,0.78,0.55,0.67,0.61,0.58,0.72,
    0.69,0.48,0.55,0.51,0.31,0.28,0.35,0.52,0.44,
    0.75,0.63,0.68,0.71,0.59,0.64,
    0.71,0.65,0.57,0.42,0.44,0.38,0.66,0.61,0.59,
    0.88,0.71,0.64,0.68,0.72,0.69,0.66,
    0.79,0.73,0.69,0.74,0.71),
  lat = c(
    -0.0917,-0.0512,-0.1234,-0.0423,-0.1567,-0.2012,-0.3456,-0.0345,
    -0.5234,-0.6123,-0.5789,-0.7234,-0.4312,-0.3789,-0.5123,-0.6789,
    -0.7456,-0.0612,-0.1234, 0.0891, 0.1567,-0.1934,-0.0712,
    -1.0634,-0.9512,-1.1234,-1.3234,-1.2567,-0.8912,-0.9234,-1.0234,-1.0891,
    -0.6817,-0.8123,-0.7512,-0.7234,-0.7456,-0.6234,-0.6789,
    -0.5634,-0.4912,-0.4345,-0.6234,-0.5123),
  long = c(
    34.7617,34.8312,34.6934,34.6512,35.1823,35.0234,34.9123,34.7823,
    34.4567,34.3891,34.5678,34.4912,34.2134,34.1567,34.2345,34.6234,
    34.8123,34.2717,34.1456,34.2891,34.3234,34.2612,34.1234,
    34.4723,34.5678,34.5234,34.7456,34.6123,34.3789,34.6789,34.5012,34.4234,
    34.7756,34.8456,34.9234,34.8912,34.7234,34.6789,34.6512,
    34.9345,35.0123,34.9678,35.0567,34.8789),
  stringsAsFactors = FALSE
)

# =============================================================================
# DEMO DATA BUILDER
# =============================================================================
.build_demo <- function(disease = "malaria", period_type = "monthly") {
  set.seed(2024)
  ref  <- .KENYA_RATES
  dis  <- .DISEASE_REF[[disease]]
  pdiv <- dis$period_div[[period_type]]
  rm   <- if (disease %in% c("tb","meningitis")) 1/100 else 1
  
  if (disease == "malaria") {
    ref$expected <- ref$population * ref$malaria_rate_k / 1000 / pdiv
  } else {
    ref$expected <- ref$population * dis$rate_per_k * rm / pdiv
  }
  
  ref$oe_true <- sapply(seq_len(nrow(ref)), function(i) {
    au <- ref$admin_unit[i]
    if (disease == "malaria") {
      if (au %in% c("Mbita","Suba North","Suba South","Rarieda"))
        return(runif(1, .10, .18))
      if (au %in% c("Kuria East","Kuria West","Nyatike"))
        return(runif(1, .17, .25))
    } else if (disease == "tb") {
      if (au %in% c("Kisii Town","Bomachoge","Bobasi","South Mugirango"))
        return(runif(1, .22, .38))
      if (au %in% c("Kuria East","Kuria West","Nyatike","Uriri"))
        return(runif(1, .28, .42))
    } else if (disease == "cholera") {
      if (au %in% c("Mbita","Suba South","Bondo","Rarieda","Ugenya"))
        return(runif(1, .08, .20))
      if (au %in% c("Nyatike","Suna East","Suna West"))
        return(runif(1, .15, .28))
    } else if (disease == "measles") {
      if (au %in% c("Kuria East","Kuria West","Nyatike","Uriri"))
        return(runif(1, .12, .25))
      if (au %in% c("Kisumu Central","Kisumu East","Migori Town"))
        return(runif(1, .30, .50))
    } else if (disease == "maternal") {
      if (au %in% c("Mbita","Suba North","Suba South","Ndhiwa","Rangwe"))
        return(runif(1, .08, .18))
      if (au %in% c("Kuria East","Kuria West","Nyatike"))
        return(runif(1, .12, .22))
    } else if (disease == "meningitis") {
      if (au %in% c("Kisii Town","Nyamira Town","Manga","Masaba North","Borabu"))
        return(runif(1, .15, .30))
      if (au %in% c("North Mugirango","South Mugirango","Bonchari"))
        return(runif(1, .20, .35))
    } else if (disease == "hiv") {
      if (au %in% c("Mbita","Suba North","Suba South","Rarieda","Bondo"))
        return(runif(1, .18, .32))
      if (au %in% c("Nyatike","Suna East","Suna West","Kuria West"))
        return(runif(1, .20, .36))
    }
    runif(1, .62, .94)
  })
  
  ref$reported_cases <- pmax(round(ref$expected * ref$oe_true), 0)
  ref$oe_ratio       <- round(ref$reported_cases / pmax(ref$expected, 0.1), 3)
  ref$period         <- "2024-01"
  ref$deficit        <- round(ref$expected - ref$reported_cases)
  ref$deficit_rate   <- round(ref$deficit / pmax(ref$population, 1) * 1000, 4)
  ref$reference_rate <- NA_real_
  
  ref$completeness <- cut(ref$oe_ratio,
                          breaks = c(-Inf, dis$critical, dis$moderate, dis$mild, Inf),
                          labels = c("Critical","Moderate","Mild","Adequate"),
                          right  = FALSE)
  
  ref
}

# Build multi-period demo (6 periods) — used for temporal/stochastic analysis
.build_demo_temporal <- function(disease = "malaria", n_periods = 6) {
  set.seed(42)
  periods <- paste0("2024-", sprintf("%02d", 1:n_periods))
  lapply(seq_along(periods), function(pi) {
    set.seed(2024 + pi * 7)
    df <- .build_demo(disease, "monthly")
    df$period <- periods[pi]
    # Add temporal noise: stochastic units fluctuate randomly;
    # structural voids stay consistently low
    df$oe_ratio <- sapply(seq_len(nrow(df)), function(i) {
      au  <- df$admin_unit[i]
      cur <- df$oe_ratio[i]
      # Structural: lake/border communities — stays low across periods
      if (au %in% c("Mbita","Suba North","Suba South","Rarieda",
                    "Kuria East","Kuria West","Nyatike")) {
        return(max(0, rnorm(1, mean = cur, sd = 0.03)))
      }
      # Stochastic: occasional dip units — random walk around adequate mean
      if (au %in% c("Muhoroni","Gem","Awendo","Kisuu Central")) {
        return(max(0, min(1.2, rnorm(1, mean = 0.72, sd = 0.20))))
      }
      # General background variation
      max(0, min(1.5, rnorm(1, mean = cur, sd = 0.10)))
    })
    df$reported_cases <- pmax(round(df$expected * df$oe_ratio), 0)
    df$deficit        <- pmax(round(df$expected - df$reported_cases), 0)
    df
  })
}

.DEMO_MALARIA <- .build_demo("malaria", "monthly")

# =============================================================================
# REAL DATA SOURCE HELPERS
# Returns a list(url, instructions, format_note) for each disease
# =============================================================================
.real_data_sources <- function(disease) {
  dis <- .DISEASE_REF[[disease]]
  gho <- dis$gho_code
  list(
    who_gho = list(
      label        = "WHO GHO API",
      url          = paste0(
        "https://ghoapi.azureedge.net/api/", gho,
        "?$filter=SpatialDim eq 'KEN'&$format=csv"),
      instructions = paste0(
        "1. Click the link — your browser will download a CSV directly.\n",
        "2. The CSV has columns: SpatialDim (country), TimeDim (year), ",
        "NumericValue (rate), etc.\n",
        "3. You'll need to: rename 'SpatialDim' → admin_unit, ",
        "'NumericValue' → reported_cases, add a population column.\n",
        "4. The GHO returns national-level data; sub-national requires ",
        "the DHIS2 or KHIS source below."),
      format_note  = "WHO GHO v8 API — country aggregate, annual"
    ),
    dhis2_play = list(
      label        = "DHIS2 Demo Server",
      url          = "https://play.dhis2.org/40.6.1/dhis-web-data-visualizer/index.html",
      instructions = paste0(
        "DHIS2 Demo Server (browser login required):\n",
        "  URL:      https://play.dhis2.org/40.6.1\n",
        "  Username: admin\n",
        "  Password: district\n\n",
        "Steps:\n",
        "  1. Open the URL and log in.\n",
        "  2. Click Apps -> Data Visualizer.\n",
        "  3. Change chart type to Pivot Table.\n",
        "  4. Add indicator, Org Unit level, and Period.\n",
        "  5. Click the Download icon -> Plain data source -> CSV.\n",
        "  6. Rename columns: Data->admin_unit, Period->period, Value->reported_cases."),
      format_note  = "DHIS2 40.6 demo — credentials: admin / district"
    ),
    khis_kenya = list(
      label        = "Kenya KHIS",
      url          = "https://hiskenya.org/dhis-web-data-visualizer/index.html",
      instructions = paste0(
        "Kenya HMIS — KHIS (free registration required):\n",
        "  Site: https://hiskenya.org\n\n",
        "Steps:\n",
        "  1. Register a free account at hiskenya.org.\n",
        "  2. Login -> Apps -> Data Visualizer.\n",
        "  3. Select your disease indicator.\n",
        "  4. Set Period: last 12 months.  Org Unit: Sub-county.\n",
        "  5. Click Download -> CSV.\n",
        "  6. Column map: Organisation unit->admin_unit, Period->period, Value->reported_cases.\n",
        "Note: sub-county names match this tool geography for Nyanza region."),
      format_note  = "Kenya KHIS — real sub-county HMIS (free account)"
    )
  )
}

# =============================================================================
# REALISTIC NOISY CSV GENERATOR
# Mimics actual DHIS2 export artifacts:
# - Missing periods for some units (facility didn't submit)
# - Zero-report weeks (submitted but zero — different from missing)
# - Occasional duplicate rows (DHIS2 export bug)
# - UTF-8 encoding artifacts in admin unit names
# - Trailing whitespace, inconsistent capitalisation
# - One column with a DHIS2 UID instead of a human name
# =============================================================================
.generate_noisy_csv <- function(disease = "malaria", n_periods = 6) {
  set.seed(999)
  ref     <- .KENYA_RATES
  dis     <- .DISEASE_REF[[disease]]
  periods <- paste0("2024-", sprintf("%02d", 1:n_periods))
  rm      <- if (disease %in% c("tb","meningitis")) 1/100 else 1
  
  if (disease == "malaria") {
    ref$expected <- ref$population * ref$malaria_rate_k / 1000 / 12
  } else {
    ref$expected <- ref$population * dis$rate_per_k * rm / 12
  }
  
  rows <- list()
  for (pi in seq_along(periods)) {
    for (i in seq_len(nrow(ref))) {
      # Simulate 15% missing submission rate
      if (runif(1) < 0.15) next
      
      au  <- ref$admin_unit[i]
      oe  <- if (au %in% c("Mbita","Suba North","Suba South","Rarieda",
                           "Kuria East","Kuria West","Nyatike")) {
        runif(1, 0.10, 0.22)
      } else {
        max(0, rnorm(1, 0.78, 0.15))
      }
      cases <- pmax(round(ref$expected[i] * oe), 0)
      
      # 5% zero-reports (submitted, genuinely zero OR data entry failure)
      if (runif(1) < 0.05) cases <- 0
      
      # Inject DHIS2 artifacts: trailing space, mixed case
      au_dirty <- au
      if (runif(1) < 0.10) au_dirty <- paste0(au, " ")           # trailing space
      if (runif(1) < 0.05) au_dirty <- toupper(au)               # all caps
      if (runif(1) < 0.05) au_dirty <- tolower(au)               # all lower
      if (runif(1) < 0.03) au_dirty <- paste0(au, "\xc2\xa0")   # non-breaking space
      
      rows[[length(rows)+1]] <- data.frame(
        period         = periods[pi],
        admin_unit     = au_dirty,
        org_unit_uid   = paste0("UID", sprintf("%06d", i * 100 + pi)), # DHIS2 UID column
        county         = ref$county[i],
        population     = ref$population[i],
        reported_cases = cases,
        lat            = ref$lat[i],
        long           = ref$long[i],
        facility_count = ref$facility_count[i],
        road_index     = ref$road_index[i],
        area_km2       = ref$area_km2[i],
        stringsAsFactors = FALSE
      )
    }
  }
  
  df <- do.call(rbind, rows)
  
  # Inject 3% duplicate rows (DHIS2 export duplicates)
  n_dup <- max(1, floor(nrow(df) * 0.03))
  dup_idx <- sample(seq_len(nrow(df)), n_dup, replace=FALSE)
  df <- rbind(df, df[dup_idx, ])
  df <- df[sample(nrow(df)), ]  # shuffle
  
  header <- c(
    "# REALISTIC NOISY DHIS2-FORMAT CSV — Geometry of Silence v2.1",
    paste0("# Disease: ", dis$label, "  |  Periods: ", paste(periods, collapse=", ")),
    "# This file intentionally contains DHIS2 export artifacts:",
    "#   - 15% missing submissions (facility didn't report)",
    "#   - 5% zero-reports (submitted but zero)",
    "#   - 3% duplicate rows (DHIS2 export bug)",
    "#   - Mixed capitalisation and trailing spaces in admin_unit",
    "#   - org_unit_uid column (DHIS2 internal ID — ignored by the tool)",
    "# The tool's CSV parser handles all of these automatically.",
    "#",
    paste(names(df), collapse=",")
  )
  data_lines <- apply(df, 1, paste, collapse=",")
  paste(c(header, data_lines), collapse="\n")
}

# Sample CSV (clean single-period format for Quick Start)
.sample_csv <- function() {
  d <- .build_demo("malaria", "monthly")
  d <- d[, c("period","admin_unit","county","population","reported_cases",
             "lat","long","facility_count","road_index","area_km2")]
  d$period <- "2024-01"
  paste(c(
    "# SAMPLE DHIS2-FORMAT CSV FOR GEOMETRY OF SILENCE",
    "# Columns: period, admin_unit, county, population, reported_cases",
    "# Optional: lat, long, facility_count, road_index (0-1), area_km2",
    "# This sample uses SIMULATED malaria cases for Nyanza, Kenya",
    "# Replace reported_cases with your real DHIS2 export values",
    "#",
    paste(names(d), collapse=","),
    apply(d, 1, paste, collapse=",")),
    collapse="\n")
}

# =============================================================================
# CORE MATHEMATICS
# =============================================================================
.utm_epsg <- function(lon, lat) {
  z <- floor((lon + 180) / 6) + 1
  as.integer(if (lat >= 0) paste0("326", sprintf("%02d", z))
             else           paste0("327", sprintf("%02d", z)))
}

# Welzl Minimum Enclosing Circle
.c1 <- function(p) list(cx=p[1],cy=p[2],r=0)
.c2 <- function(a,b) list(cx=(a[1]+b[1])/2,cy=(a[2]+b[2])/2,
                          r=sqrt(sum((a-b)^2))/2)
.c3 <- function(a,b,cc) {
  ax=b[1]-a[1];ay=b[2]-a[2];bx=cc[1]-a[1];by=cc[2]-a[2]
  D=2*(ax*by-ay*bx); if(abs(D)<1e-10) return(.c2(a,cc))
  ux=(by*(ax^2+ay^2)-ay*(bx^2+by^2))/D
  uy=(ax*(bx^2+by^2)-bx*(ax^2+ay^2))/D
  list(cx=a[1]+ux,cy=a[2]+uy,r=sqrt(ux^2+uy^2))
}
.inc <- function(C,p,e=1e-7) sqrt((p[1]-C$cx)^2+(p[2]-C$cy)^2)<=C$r+e
.welzl <- function(pts){
  pts <- pts[sample(nrow(pts)),,drop=FALSE]; n <- nrow(pts); D <- .c1(pts[1,])
  for(i in seq_len(n)){
    if(.inc(D,pts[i,])) next; D <- .c1(pts[i,])
    for(j in seq_len(i-1)){
      if(.inc(D,pts[j,])) next; D <- .c2(pts[i,],pts[j,])
      for(k in seq_len(j-1)) if(!.inc(D,pts[k,])) D <- .c3(pts[i,],pts[j,],pts[k,])
    }
  }; D
}
.mec <- function(pts){
  if(nrow(pts)<2) return(NULL)
  if(nrow(pts)>400){ch<-chull(pts[,1],pts[,2]);pts<-pts[ch,,drop=FALSE]}
  m<-.welzl(pts); list(center=c(m$cx,m$cy),radius=m$r*1.05)
}

# Kneedle elbow
.kneedle <- function(v){
  v <- v[!is.na(v)]
  if(length(v)<10) return(list(threshold=median(v),alpha=0.10))
  s <- sort(v); n <- length(s)
  x <- seq(0,1,l=n); y <- (s-min(s))/max(s-min(s)+1e-10)
  d2 <- diff(diff(y-x))
  if(n>20){k<-max(3,floor(n*.05));d2s<-stats::filter(d2,rep(1/k,k),sides=2);
  d2s[is.na(d2s)]<-d2[is.na(d2s)]}else d2s<-d2
  idx <- max(3,min(which.max(abs(d2s))+3,n-1))
  list(threshold=s[idx],alpha=round(1-stats::ecdf(s)(s[idx]),3))
}

# =============================================================================
# STOCHASTIC vs STRUCTURAL VOID CLASSIFIER  ← NEW in v2.1
# =============================================================================
# Method 1: Fano Factor
# Fano = Var(x) / Mean(x) for a vector x of O/E ratios across time periods.
# For a Poisson process, Fano ≈ 1.
# A structural void: mean << 1 AND Fano can be < 1 (over-dispersed low signal)
#   or Fano > 1 (inconsistent reporting with structural floor).
# Decision rule:
#   IF mean_oe < critical_threshold AND fano > 0.5  → STRUCTURAL
#   IF mean_oe < threshold BUT fano < 0.5 AND cv < 0.25 → STRUCTURAL (stable floor)
#   IF mean_oe fluctuates widely (cv > 0.40) → STOCHASTIC
#   IF n_critical_periods / n_total < 0.5 → STOCHASTIC

.fano_factor <- function(x) {
  x <- x[!is.na(x) & x >= 0]
  if (length(x) < 2) return(NA_real_)
  m <- mean(x)
  if (m < 1e-10) return(NA_real_)
  var(x) / m
}

# Method 2: 2-State HMM (Viterbi) — pure R, no external packages
# States: 1 = Reporting (O/E adequate), 0 = Silent (O/E below threshold)
# Emission: Gaussian per state
# Transition: estimated from data
# Returns: list(state_seq, p_structural, p_stochastic)
.hmm_2state <- function(oe_series, critical_threshold = 0.20) {
  x <- oe_series[!is.na(oe_series)]
  n <- length(x)
  if (n < 3) return(list(
    state_seq     = rep(NA, length(oe_series)),
    p_structural  = NA_real_,
    p_stochastic  = NA_real_,
    label         = "INSUFFICIENT_DATA"))
  
  # Initial parameter estimates
  silent_idx    <- x < critical_threshold
  rep_idx       <- !silent_idx
  if (sum(silent_idx) < 1 || sum(rep_idx) < 1) {
    return(list(
      state_seq    = rep(if(mean(x) < critical_threshold) 0L else 1L, n),
      p_structural = if(mean(x) < critical_threshold) 0.85 else 0.10,
      p_stochastic = if(mean(x) < critical_threshold) 0.15 else 0.90,
      label        = if(mean(x) < critical_threshold) "STRUCTURAL" else "STOCHASTIC"))
  }
  
  mu    <- c(mean(x[silent_idx]),  mean(x[rep_idx]))
  sigma <- c(max(sd(x[silent_idx]),  0.05), max(sd(x[rep_idx]), 0.05))
  # Transition matrix (row = from, col = to; states 1=silent, 2=reporting)
  A     <- matrix(c(0.80, 0.20, 0.15, 0.85), nrow=2, byrow=TRUE)
  pi0   <- c(0.3, 0.7)
  
  # EM: Baum-Welch (3 iterations sufficient for n < 50)
  for (iter in 1:3) {
    # E-step: forward-backward
    B <- matrix(0, nrow=2, ncol=n)
    for (k in 1:2) B[k,] <- dnorm(x, mu[k], sigma[k]) + 1e-300
    
    alpha_m <- matrix(0, 2, n)
    alpha_m[,1] <- pi0 * B[,1]; alpha_m[,1] <- alpha_m[,1]/sum(alpha_m[,1])
    for (t in 2:n) {
      alpha_m[,t] <- (A %*% alpha_m[,t-1]) * B[,t]
      s <- sum(alpha_m[,t]); if(s > 0) alpha_m[,t] <- alpha_m[,t]/s
    }
    beta_m <- matrix(1, 2, n)
    for (t in (n-1):1) {
      beta_m[,t] <- A %*% (B[,t+1] * beta_m[,t+1])
      s <- sum(beta_m[,t]); if(s > 0) beta_m[,t] <- beta_m[,t]/s
    }
    gamma <- alpha_m * beta_m
    gamma <- sweep(gamma, 2, colSums(gamma), "/")
    
    # M-step
    for (k in 1:2) {
      wt    <- gamma[k,]
      mu[k]    <- sum(wt * x) / sum(wt)
      sigma[k] <- sqrt(sum(wt * (x - mu[k])^2) / sum(wt))
      sigma[k] <- max(sigma[k], 0.03)
    }
    # Update transition matrix
    for (k in 1:2) {
      for (j in 1:2) {
        num <- 0
        for (t in 1:(n-1)) num <- num + gamma[k,t] * A[k,j] * B[j,t+1] * beta_m[j,t+1]
        A[k,j] <- num
      }
      A[k,] <- A[k,] / sum(A[k,])
    }
  }
  
  # Viterbi decoding
  delta <- matrix(-Inf, 2, n); psi <- matrix(0L, 2, n)
  for (k in 1:2) B[k,] <- dnorm(x, mu[k], sigma[k]) + 1e-300
  delta[,1] <- log(pi0) + log(B[,1])
  for (t in 2:n) {
    for (j in 1:2) {
      scores  <- delta[,t-1] + log(A[,j])
      psi[j,t] <- which.max(scores)
      delta[j,t] <- max(scores) + log(B[j,t])
    }
  }
  state_seq <- integer(n)
  state_seq[n] <- which.max(delta[,n])
  for (t in (n-1):1) state_seq[t] <- psi[state_seq[t+1], t+1]
  state_seq <- state_seq - 1L  # 0 = silent, 1 = reporting
  
  # Structural if majority of periods in silent state
  p_silent      <- mean(state_seq == 0)
  p_structural  <- round(p_silent, 3)
  p_stochastic  <- round(1 - p_silent, 3)
  label         <- if (p_structural >= 0.60) "STRUCTURAL"
  else if (p_structural >= 0.35) "INTERMITTENT"
  else "STOCHASTIC"
  
  list(state_seq    = state_seq,
       p_structural = p_structural,
       p_stochastic = p_stochastic,
       label        = label,
       mu_silent    = round(mu[1], 3),
       mu_reporting = round(mu[2], 3))
}

# Main temporal classifier — combines Fano + HMM
.classify_void_temporality <- function(oe_history, critical_threshold = 0.20) {
  if (is.null(oe_history) || length(oe_history) < 2) {
    return(list(
      label        = "SINGLE_PERIOD",
      fano         = NA_real_,
      cv           = NA_real_,
      p_structural = NA_real_,
      p_stochastic = NA_real_,
      n_critical   = NA_integer_,
      n_total      = NA_integer_,
      interpretation = "Only one reporting period available. Upload multiple periods for temporal classification.",
      badge_class  = "tm"))
  }
  
  x           <- oe_history[!is.na(oe_history)]
  n           <- length(x)
  n_critical  <- sum(x < critical_threshold)
  fano        <- .fano_factor(x)
  cv          <- if (mean(x) > 1e-10) sd(x)/mean(x) else NA_real_
  hmm_res     <- .hmm_2state(x, critical_threshold)
  
  # Combined decision
  label <- hmm_res$label  # HMM has final word
  
  # Override with Fano if HMM label is INTERMITTENT and Fano is extreme
  if (!is.na(fano) && label == "INTERMITTENT") {
    if (!is.na(cv) && cv < 0.20 && mean(x) < critical_threshold * 1.5) {
      label <- "STRUCTURAL"  # Low CV + consistently low = structural
    } else if (!is.na(cv) && cv > 0.50) {
      label <- "STOCHASTIC"  # High variance = noise
    }
  }
  
  badge_class <- switch(label,
                        STRUCTURAL   = "tr2",
                        INTERMITTENT = "ta",
                        STOCHASTIC   = "tc",
                        "tm")
  
  interpretation <- switch(label,
                           STRUCTURAL = paste0(
                             "Consistently silent across ", n_critical, "/", n, " periods ",
                             "(HMM p_structural=", hmm_res$p_structural, "). ",
                             "This void is STRUCTURAL — likely geographic, infrastructure, or system barrier. ",
                             "Requires active intervention, not just monitoring."),
                           INTERMITTENT = paste0(
                             "Silent in ", n_critical, "/", n, " periods. ",
                             "Pattern is irregular — may reflect seasonal access, staff turnover, or ",
                             "temporary system failure. Monitor for 2 more periods to confirm nature."),
                           STOCHASTIC = paste0(
                             "Only ", n_critical, "/", n, " periods below threshold (CV=",
                             round(cv,2), "). ",
                             "Variation is consistent with Poisson noise in a near-adequate system. ",
                             "No structural barrier evident — reassess threshold or investigate single-period cause."),
                           paste0("Insufficient data for classification (", n, " periods).")
  )
  
  list(
    label          = label,
    fano           = round(fano, 3),
    cv             = round(cv, 3),
    p_structural   = hmm_res$p_structural,
    p_stochastic   = hmm_res$p_stochastic,
    n_critical     = as.integer(n_critical),
    n_total        = as.integer(n),
    mu_silent      = hmm_res$mu_silent,
    mu_reporting   = hmm_res$mu_reporting,
    state_seq      = hmm_res$state_seq,
    interpretation = interpretation,
    badge_class    = badge_class
  )
}

# =============================================================================
# SURVEILLANCE COMPLETENESS ENGINE
# =============================================================================
.compute_completeness <- function(df, disease = "malaria") {
  dis <- .DISEASE_REF[[disease]]
  df$oe_ratio    <- df$reported_cases / pmax(df$expected, 0.1)
  df$deficit     <- pmax(df$expected - df$reported_cases, 0)
  df$deficit_pct <- round((1 - df$oe_ratio) * 100, 1)
  df$completeness <- cut(df$oe_ratio,
                         breaks = c(-Inf, dis$critical, dis$moderate, dis$mild, Inf),
                         labels = c("Critical","Moderate","Mild","Adequate"),
                         right  = FALSE)
  df$deficit_rate <- round(df$deficit / pmax(df$population, 1) * 1000, 3)
  df
}

# =============================================================================
# CAUSAL CLASSIFIER
# =============================================================================
.classify_cause <- function(road_index, facility_count, area_km2,
                            near_border = FALSE, oe_ratio = 0.3) {
  density <- facility_count / pmax(area_km2, 1) * 100
  if (isTRUE(near_border) && !is.na(oe_ratio) && oe_ratio < 0.25)
    return(list(cause="BORDER", label="Cross-border population",
                detail="Sub-county abuts international border; cases may be reported in neighbouring country system",
                action="Coordinate with cross-border surveillance focal person; request bilateral data sharing",
                icon="fa-right-left"))
  if (isTRUE(!is.na(road_index) && road_index < 0.35))
    return(list(cause="ACCESS", label="Physical inaccessibility",
                detail="Low road density index suggests geographic barriers to facility access",
                action="Deploy community health workers; consider mobile reporting units",
                icon="fa-road"))
  if (isTRUE(!is.na(density) && density < 0.5))
    return(list(cause="INFRASTRUCTURE", label="Facility gap",
                detail="Fewer than 0.5 facilities per 100 km² — population has no proximate reporting point",
                action="Review facility catchment mapping; prioritise satellite clinic construction",
                icon="fa-hospital"))
  if (isTRUE(!is.na(oe_ratio) && oe_ratio > 0.05))
    return(list(cause="SYSTEM", label="Reporting system failure",
                detail="Facilities present but case counts far below expected — data entry, submission, or aggregation failure",
                action="Audit DHIS2 submission logs; check for data entry bottlenecks at sub-county level",
                icon="fa-server"))
  list(cause="UNKNOWN", label="Cause undetermined",
       detail="Deficit is severe and covariates do not indicate a clear mechanism",
       action="Conduct rapid surveillance assessment including facility visit and community survey",
       icon="fa-circle-question")
}

# =============================================================================
# DTM SPATIAL CLUSTERING
# =============================================================================
.dtm_voids <- function(df, m0 = 0.05, alpha = 0.10, min_area_km2 = 0) {
  df_d <- df[df$deficit_rate > 0 & !is.na(df$lat) & !is.na(df$long), ]
  if (nrow(df_d) < 5) return(NULL)
  
  ep  <- .utm_epsg(mean(df_d$long, na.rm=TRUE), mean(df_d$lat, na.rm=TRUE))
  ps  <- sf::st_as_sf(df_d, coords=c("long","lat"), crs=4326)
  pu  <- sf::st_transform(ps, ep)
  Xm  <- as.matrix(sf::st_coordinates(pu))
  
  w   <- df_d$deficit_rate / max(df_d$deficit_rate, 1)
  Xw  <- Xm[rep(seq_len(nrow(Xm)), times=pmax(round(w*3), 1)), ]
  n   <- nrow(Xw)
  
  hull <- sf::st_convex_hull(sf::st_union(pu))
  bb   <- sf::st_bbox(hull)
  nx   <- min(35, max(10, floor(diff(bb[c("xmin","xmax")])/5000)))
  ny   <- min(35, max(10, floor(diff(bb[c("ymin","ymax")])/5000)))
  G    <- expand.grid(X=seq(bb$xmin,bb$xmax,l=nx),
                      Y=seq(bb$ymin,bb$ymax,l=ny))
  gsf  <- sf::st_as_sf(G, coords=c("X","Y"), crs=ep)
  ih_mat <- sf::st_intersects(gsf, hull, sparse=FALSE)
  ih <- if (is.matrix(ih_mat)) as.logical(ih_mat[,1L]) else as.logical(ih_mat)
  ih[is.na(ih)] <- FALSE
  if (!any(ih)) return(NULL)
  G    <- G[ih, ]; Gm <- as.matrix(G)
  k    <- max(2, ceiling(m0*n))
  
  DV <- tryCatch(TDA::dtm(X=Xw, Grid=Gm, m0=m0),
                 error=function(e) apply(Gm, 1, function(gp) {
                   d <- sqrt(rowSums((Xw - matrix(gp, nrow=n, ncol=2, byrow=TRUE))^2))
                   mean(sort(d)[1:k]) }))
  
  el  <- .kneedle(DV)
  thr <- tryCatch(max(quantile(DV, 1-alpha, na.rm=TRUE), el$threshold * 0.85),
                  error=function(e) median(DV, na.rm=TRUE),
                  warning=function(w) median(DV, na.rm=TRUE))
  if (is.na(thr) || !is.finite(thr)) return(NULL)
  iv  <- !is.na(DV) & DV > thr & DV <= (quantile(DV,.75,na.rm=TRUE)+2.5*IQR(DV,na.rm=TRUE))
  
  if (!any(iv, na.rm=TRUE)) return(NULL)
  
  r3 <- tryCatch({
    r_obj <- raster::rasterFromXYZ(
      data.frame(x=Gm[iv,1], y=Gm[iv,2], z=1), crs=ep)
    r_obj
  }, error=function(e) NULL)
  if (is.null(r3)) return(NULL)
  
  vp <- tryCatch(raster::rasterToPolygons(r3, dissolve=TRUE),
                 error=function(e) NULL)
  if (is.null(vp) || length(vp) == 0) return(NULL)
  
  vs  <- suppressWarnings(sf::st_as_sf(vp) |> sf::st_cast("POLYGON"))
  vs  <- vs[!sf::st_is_empty(vs), ]
  vs  <- sf::st_transform(vs, 4326)
  vs$area_km2 <- round(as.numeric(sf::st_area(sf::st_transform(vs, ep)))/1e6, 2)
  vs  <- vs[vs$area_km2 >= min_area_km2, ]
  if (nrow(vs) == 0) return(NULL)
  vs$void_id  <- seq_len(nrow(vs))
  
  pts_sf <- sf::st_as_sf(df_d, coords=c("long","lat"), crs=4326)
  ji     <- sf::st_intersects(pts_sf, vs, sparse=TRUE)
  vs$admin_units <- sapply(seq_len(nrow(vs)), function(i) {
    idx <- which(sapply(ji, function(x) i %in% x))
    if (length(idx) == 0) return("")
    paste(df_d$admin_unit[idx], collapse=", ")
  })
  vs$n_admin <- sapply(seq_len(nrow(vs)), function(i) {
    sum(sapply(ji, function(x) i %in% x)) })
  vs$mean_oe <- sapply(seq_len(nrow(vs)), function(i) {
    idx <- which(sapply(ji, function(x) i %in% x))
    if (length(idx) == 0) return(NA_real_)
    round(mean(df_d$oe_ratio[idx], na.rm=TRUE), 3) })
  vs$total_deficit <- sapply(seq_len(nrow(vs)), function(i) {
    idx <- which(sapply(ji, function(x) i %in% x))
    if (length(idx) == 0) return(0)
    round(sum(df_d$deficit[idx], na.rm=TRUE)) })
  vs$total_pop <- sapply(seq_len(nrow(vs)), function(i) {
    idx <- which(sapply(ji, function(x) i %in% x))
    if (length(idx) == 0) return(0)
    sum(df_d$population[idx], na.rm=TRUE) })
  
  vs$ring_radius_km <- NA_real_
  vs$ring_lon <- NA_real_; vs$ring_lat <- NA_real_
  for (i in seq_len(nrow(vs))) {
    tryCatch({
      bp  <- sf::st_coordinates(sf::st_transform(vs[i,], ep))[,1:2,drop=FALSE]
      mc  <- .mec(bp)
      if (!is.null(mc) && mc$radius > 500) {
        ctr <- sf::st_transform(
          sf::st_sfc(sf::st_point(mc$center), crs=ep), 4326)
        co  <- sf::st_coordinates(ctr)
        vs$ring_radius_km[i] <- round(mc$radius/1000, 1)
        vs$ring_lon[i] <- co[1]; vs$ring_lat[i] <- co[2]
      }
    }, error=function(e) NULL)
  }
  
  list(voids=vs, Gm=Gm, DV=DV, thr=thr, ep=ep, elbow=el, n=n)
}

# =============================================================================
# CSS  — v2.1 additions: gate indicators, temporal badges, data-source panel
# =============================================================================
CSS <- '
:root{
  --ink:#06080e;--paper:#0b1220;--card:#0f1a2a;--edge:#172437;
  --edge2:#1e3050;--amber:#f59e0b;--amber-d:#f59e0b1a;--amber-m:#f59e0b44;
  --cyan:#22d3ee;--cyan-d:#22d3ee15;--red:#f87171;--red-d:#f8717118;
  --green:#4ade80;--green-d:#4ade8015;--purple:#a78bfa;--purple-d:#a78bfa15;
  --text:#c8d8e8;--muted:#3a5570;--mid:#5a7fa0;
  --mono:"JetBrains Mono",monospace;--sans:"Space Grotesk",sans-serif;
  --r:5px;--sw:320px;
}
*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}
html,body{height:100%;background:var(--ink);color:var(--text);
  font-family:var(--mono);font-size:12px;overflow:hidden}
::-webkit-scrollbar{width:3px}::-webkit-scrollbar-thumb{background:var(--edge2);border-radius:2px}

/* SHELL */
#shell{display:flex;flex-direction:column;height:100vh;height:100dvh}

/* TOPBAR */
#tb{height:48px;min-height:48px;padding:0 14px;
  background:var(--paper);border-bottom:1px solid var(--edge);
  display:flex;align-items:center;justify-content:space-between;flex-shrink:0;z-index:100}
.tb-left{display:flex;align-items:center;gap:10px}
.tb-sig{width:30px;height:30px;background:var(--amber-d);border:1px solid var(--amber-m);
  border-radius:5px;display:flex;align-items:center;justify-content:center;
  color:var(--amber);font-size:13px;flex-shrink:0}
.tb-name{font-family:var(--sans);font-size:14px;font-weight:700;
  letter-spacing:-.3px;color:var(--text)}
.tb-ver{font-size:9px;color:var(--muted);background:var(--card);
  border:1px solid var(--edge);border-radius:3px;padding:2px 7px;letter-spacing:.4px}
.tb-right{display:flex;align-items:center;gap:6px}

/* ICON BUTTONS */
.icon-btn{width:30px;height:30px;background:var(--card);
  border:1px solid var(--edge2);border-radius:5px;color:var(--mid);
  font-size:12px;cursor:pointer;display:flex;align-items:center;
  justify-content:center;transition:color .12s,border-color .12s;flex-shrink:0}
.icon-btn:hover{color:var(--amber);border-color:var(--amber)}

/* NAV */
#nav{display:flex;background:var(--paper);border-bottom:1px solid var(--edge);
  overflow-x:auto;scrollbar-width:none;flex-shrink:0;gap:0}
#nav::-webkit-scrollbar{display:none}
.nb{display:flex;align-items:center;gap:5px;padding:10px 16px;
  font-family:var(--mono);font-size:10px;color:var(--muted);
  background:none;border:none;border-bottom:2px solid transparent;
  cursor:pointer;white-space:nowrap;letter-spacing:.5px;text-transform:uppercase;
  transition:color .12s,border-color .12s}
.nb:hover{color:var(--mid)}
.nb.on{color:var(--amber);border-bottom-color:var(--amber)}

/* CONTENT */
#content{flex:1;display:flex;overflow:hidden}
.tp{display:none;width:100%;height:100%;overflow:hidden}
.tp.on{display:flex}
#pm{flex-direction:row}
#mc{flex:1;position:relative;overflow:hidden}
#map_main{width:100%!important;height:100%!important}
/* Desktop: sidebar starts open; padding reserves space */
@media(min-width:769px){
  body.sb-open #content{padding-right:var(--sw)}
  body.sb-open #sb{transform:translateX(0)}
}

/* SIDEBAR — fixed overlay, visible from ALL tabs */
#sb{width:var(--sw);background:var(--paper);
  border-left:1px solid var(--edge);display:flex;flex-direction:column;
  overflow:hidden;transition:transform .28s cubic-bezier(.4,0,.2,1);
  position:fixed;top:96px;right:0;bottom:0;z-index:400;
  transform:translateX(100%)}
#sb.open{transform:translateX(0)}
.sbscroll{flex:1;overflow-y:auto;overflow-x:hidden;padding:10px;
  scrollbar-width:thin;scrollbar-color:var(--edge) transparent;
  min-width:0;box-sizing:border-box}
#sb-close{display:none;position:absolute;top:9px;right:9px;z-index:10}

/* STATUS BAR */
#sbar{padding:6px 10px;border-top:1px solid var(--edge);
  display:flex;align-items:center;gap:7px;font-size:10px;
  color:var(--muted);background:var(--paper);flex-shrink:0;min-height:32px}
.sdot{width:5px;height:5px;border-radius:50%;flex-shrink:0;
  background:var(--muted);transition:background .3s}
.sdot.ready{background:var(--green)}
.sdot.working{background:var(--amber);animation:blink .7s infinite}
.sdot.success{background:var(--green)}
.sdot.error{background:var(--red)}
@keyframes blink{0%,100%{opacity:1}50%{opacity:.2}}

/* CARDS */
.sc{background:var(--card);border:1px solid var(--edge);
  border-radius:var(--r);margin-bottom:6px;overflow:hidden}
.sch{display:flex;align-items:center;justify-content:space-between;
  padding:7px 10px;cursor:pointer;user-select:none;
  border-bottom:1px solid var(--edge)}
.sch:hover{background:rgba(255,255,255,.012)}
.sct{display:flex;align-items:center;gap:6px;
  font-family:var(--sans);font-size:10px;font-weight:600;
  color:var(--mid);text-transform:uppercase;letter-spacing:.6px}
.sct i{font-size:9px;color:var(--amber)}
.scb{padding:10px}
.scv{font-size:8px;color:var(--muted);transition:transform .18s}
.scv.open{transform:rotate(180deg)}
.fg{margin-bottom:10px}
.fl{font-size:9px;color:var(--muted);text-transform:uppercase;
  letter-spacing:.5px;margin-bottom:4px;display:flex;
  justify-content:space-between;align-items:center}
.fv{color:var(--amber);text-transform:none;letter-spacing:0}

/* ── PROGRESSIVE INPUT GATES — NEW v2.1 ── */
.stage{border:1px solid var(--edge);border-radius:var(--r);
  margin-bottom:8px;overflow:hidden;transition:opacity .25s,border-color .25s}
.stage.locked{opacity:.38;pointer-events:none;border-color:var(--edge)}
.stage.unlocked{opacity:1;pointer-events:all;border-color:var(--edge2)}
.stage.complete{border-color:var(--green);opacity:1}
.stage-hd{display:flex;align-items:center;gap:7px;padding:7px 10px;
  background:var(--card);border-bottom:1px solid var(--edge)}
.stage-num{width:18px;height:18px;border-radius:50%;
  display:flex;align-items:center;justify-content:center;
  font-size:9px;font-weight:700;flex-shrink:0;
  border:1px solid var(--edge2);color:var(--muted)}
.stage.unlocked .stage-num{border-color:var(--amber);color:var(--amber)}
.stage.complete .stage-num{background:var(--green);border-color:var(--green);
  color:#06080e}
.stage-title{font-family:var(--sans);font-size:10px;font-weight:600;
  color:var(--mid);text-transform:uppercase;letter-spacing:.5px;flex:1}
.stage.unlocked .stage-title{color:var(--text)}
.stage.complete .stage-title{color:var(--green)}
.stage-lock{font-size:9px;color:var(--muted)}
.stage.complete .stage-lock{color:var(--green)}
.stage-body{padding:10px}

/* METRICS ROW */
.metrics{display:grid;grid-template-columns:repeat(3,1fr);gap:4px;margin-bottom:8px}
.met{background:var(--card);border:1px solid var(--edge);
  border-radius:var(--r);padding:7px 6px;text-align:center}
.mel{font-size:8px;color:var(--muted);text-transform:uppercase;
  letter-spacing:.6px;margin-bottom:3px}
.mev{font-family:var(--sans);font-size:16px;font-weight:600;
  color:var(--text);line-height:1}
.met.a .mev{color:var(--amber)}
.met.r .mev{color:var(--red)}
.met.g .mev{color:var(--green)}
.met.c .mev{color:var(--cyan)}

/* BUTTONS */
.btn-run{width:100%;padding:10px 14px;background:var(--amber);color:#06080e;
  border:none;border-radius:var(--r);font-family:var(--sans);font-size:12px;
  font-weight:700;cursor:pointer;display:flex;align-items:center;
  justify-content:center;gap:7px;transition:opacity .12s,transform .1s;
  letter-spacing:.1px}
.btn-run:hover{opacity:.88;transform:translateY(-1px)}
.btn-run:active{opacity:.75;transform:translateY(0)}
.btn-sec{width:100%;padding:7px 10px;background:transparent;color:var(--mid);
  border:1px solid var(--edge2);border-radius:var(--r);font-family:var(--mono);
  font-size:10px;cursor:pointer;display:flex;align-items:center;
  justify-content:center;gap:5px;transition:all .12s;margin-bottom:4px}
.btn-sec:hover{border-color:var(--amber);color:var(--amber)}
.btn-2{display:grid;grid-template-columns:1fr 1fr;gap:4px;margin-bottom:4px}

/* DATA SOURCE PILLS — NEW v2.1 */
.ds-grid{display:grid;grid-template-columns:1fr 1fr;gap:4px;margin-bottom:8px}
.ds-pill{padding:7px 8px;background:var(--card);border:1px solid var(--edge2);
  border-radius:var(--r);cursor:pointer;text-align:center;
  transition:border-color .15s,background .15s}
.ds-pill:hover{border-color:var(--amber);background:var(--amber-d)}
.ds-pill.active{border-color:var(--amber);background:var(--amber-d)}
.ds-pill-icon{font-size:14px;margin-bottom:3px;color:var(--amber)}
.ds-pill-lbl{font-size:8.5px;color:var(--mid);text-transform:uppercase;
  letter-spacing:.4px;line-height:1.3}
.ds-info{background:var(--ink);border:1px solid var(--edge);
  border-radius:var(--r);padding:9px;margin-bottom:8px;
  font-size:9.5px;color:var(--muted);line-height:1.7}
.ds-info a{color:var(--cyan)}
.ds-info code{background:var(--card);padding:1px 4px;border-radius:2px;
  font-size:9px;color:var(--amber)}

/* UPLOAD BUTTON */
.upload-btn{display:flex;align-items:center;gap:8px;padding:8px 12px;
  background:var(--card);border:1px solid var(--edge2);border-radius:var(--r);
  cursor:pointer;color:var(--amber);font-size:10.5px;font-family:var(--mono);
  width:100%;transition:border-color .15s;margin-bottom:6px}
.upload-btn:hover{border-color:var(--amber);background:var(--amber-d)}

/* SELECT */
.custom-select{width:100%;padding:6px 10px;background:var(--ink);
  border:1px solid var(--edge2);border-radius:var(--r);color:var(--text);
  font-family:var(--mono);font-size:11px;outline:none;cursor:pointer;
  appearance:none;
  background-image:url("data:image/svg+xml,%3Csvg xmlns=\'http://www.w3.org/2000/svg\' width=\'10\' height=\'6\'%3E%3Cpath d=\'M0 0l5 6 5-6z\' fill=\'%233a5570\'/%3E%3C/svg%3E");
  background-repeat:no-repeat;background-position:right 10px center}
.custom-select:focus{border-color:var(--amber)}

/* SLIDERS */
.irs--shiny .irs-bar{background:var(--amber);height:2px}
.irs--shiny .irs-line{background:var(--edge2);height:2px}
.irs--shiny .irs-handle>i:first-child{background:var(--amber);
  border:2px solid var(--ink);width:12px;height:12px;
  box-shadow:0 0 0 2px var(--amber-m)}
.irs--shiny .irs-from,.irs--shiny .irs-to,.irs--shiny .irs-single{
  background:var(--amber);color:var(--ink);font-family:var(--mono);font-size:9px}

/* TOGGLE */
.tr-row{display:flex;align-items:center;justify-content:space-between;
  padding:4px 0;margin-bottom:5px}
.tr-label{font-size:10px;color:var(--mid)}
.form-check-input{width:28px!important;height:15px!important;
  background-color:var(--edge2)!important;border-color:var(--edge2)!important}
.form-check-input:checked{background-color:var(--amber)!important;
  border-color:var(--amber)!important}

/* TAGS */
.tag{display:inline-flex;align-items:center;padding:2px 7px;
  border-radius:3px;font-size:9px;font-family:var(--mono);
  margin-right:3px;margin-bottom:3px;border:1px solid;font-weight:500}
.ta{background:var(--amber-d);color:var(--amber);border-color:var(--amber-m)}
.tc{background:var(--cyan-d);color:var(--cyan);border-color:#22d3ee35}
.tr2{background:var(--red-d);color:var(--red);border-color:#f8717135}
.tg{background:var(--green-d);color:var(--green);border-color:#4ade8035}
.tp2{background:var(--purple-d);color:var(--purple);border-color:#a78bfa35}
.tm{background:var(--card);color:var(--muted);border-color:var(--edge)}

/* TEMPORAL VOID LABELS — NEW v2.1 */
.void-structural{color:var(--red);font-weight:700}
.void-intermittent{color:var(--amber);font-weight:700}
.void-stochastic{color:var(--cyan);font-weight:700}
.void-single{color:var(--muted);font-weight:500}
.hmm-bar{height:6px;border-radius:3px;background:var(--edge);
  margin:4px 0;position:relative;overflow:hidden}
.hmm-fill{height:100%;border-radius:3px;transition:width .5s}
.hmm-fill.structural{background:var(--red)}
.hmm-fill.stochastic{background:var(--cyan)}

/* COMPLETENESS BADGE */
.cb-critical{background:#f8717118;color:var(--red);border:1px solid #f8717135;
  border-radius:3px;padding:1px 6px;font-size:9px;font-weight:600;font-family:var(--mono)}
.cb-moderate{background:var(--amber-d);color:var(--amber);border:1px solid var(--amber-m);
  border-radius:3px;padding:1px 6px;font-size:9px;font-weight:600;font-family:var(--mono)}
.cb-mild{background:var(--cyan-d);color:var(--cyan);border:1px solid #22d3ee35;
  border-radius:3px;padding:1px 6px;font-size:9px;font-weight:600;font-family:var(--mono)}
.cb-adequate{background:var(--green-d);color:var(--green);border:1px solid #4ade8035;
  border-radius:3px;padding:1px 6px;font-size:9px;font-weight:600;font-family:var(--mono)}

/* CAUSE BADGE */
.cause-ACCESS{color:#22d3ee;font-weight:600}
.cause-INFRASTRUCTURE{color:var(--amber);font-weight:600}
.cause-SYSTEM{color:var(--red);font-weight:600}
.cause-BORDER{color:var(--purple);font-weight:600}
.cause-UNKNOWN{color:var(--muted);font-weight:600}

/* RESULTS PANEL */
#pr{flex-direction:column;overflow-y:auto;padding:16px;background:var(--ink);
  width:100%;scrollbar-width:thin;scrollbar-color:var(--edge) transparent}
.rb{background:var(--card);border:1px solid var(--edge);
  border-radius:var(--r);padding:13px;margin-bottom:10px}
.rb-title{font-family:var(--sans);font-size:12px;font-weight:700;
  color:var(--text);display:flex;align-items:center;gap:8px;margin-bottom:10px}
.rb-title i{color:var(--amber);font-size:11px}
.vt{width:100%;border-collapse:collapse;font-size:10px}
.vt th{font-size:8px;text-transform:uppercase;letter-spacing:.5px;
  color:var(--muted);padding:5px 8px;border-bottom:1px solid var(--edge);text-align:left}
.vt td{padding:6px 8px;border-bottom:1px solid var(--edge);color:var(--mid)}
.vt tr:last-child td{border-bottom:none}
.vt tr:hover td{background:var(--amber-d);color:var(--text)}
.vt .crit td{background:#f8717108}
.alert-card{border-left:3px solid;border-radius:var(--r);
  padding:10px 13px;margin-bottom:8px;background:var(--card)}
.alert-card.critical{border-color:var(--red);background:var(--red-d)}
.alert-card.moderate{border-color:var(--amber);background:var(--amber-d)}
.alert-card.mild{border-color:var(--cyan);background:var(--cyan-d)}
.ac-head{font-family:var(--sans);font-size:11px;font-weight:700;
  color:var(--text);margin-bottom:5px;display:flex;align-items:center;gap:7px;flex-wrap:wrap}
.ac-body{font-size:10.5px;color:var(--mid);line-height:1.75}
.ac-action{margin-top:6px;font-size:10px;
  background:rgba(0,0,0,.25);padding:6px 9px;border-radius:4px;
  color:var(--text);line-height:1.6}
.ac-action i{color:var(--amber);margin-right:4px}

/* TEMPORAL PANEL — NEW v2.1 */
.temporal-card{background:var(--ink);border:1px solid var(--edge2);
  border-radius:var(--r);padding:9px;margin-top:8px}
.temporal-card-title{font-size:9px;color:var(--amber);text-transform:uppercase;
  letter-spacing:.5px;margin-bottom:7px;display:flex;align-items:center;gap:5px}
.period-sparkline{display:flex;align-items:center;gap:3px;margin:5px 0}
.spark-cell{width:14px;height:22px;border-radius:2px;flex-shrink:0;
  display:flex;align-items:flex-end}
.spark-bar{width:100%;border-radius:2px 2px 0 0;transition:height .3s}

/* WATERMARK */
.wm-footer{margin-top:14px;padding:9px 12px;border:1px solid var(--edge);
  border-radius:var(--r);font-size:9px;color:var(--muted);
  background:var(--card);line-height:1.7}
.wm-footer a{color:var(--amber);text-decoration:none}

/* GUIDE */
#pg{flex-direction:column;overflow-y:auto;padding:22px;
  background:var(--ink);width:100%;
  scrollbar-width:thin;scrollbar-color:var(--edge) transparent}

/* LEAFLET POPUP — no white border, dark theme */
.leaflet-popup-content-wrapper{
  background:transparent!important;
  border:none!important;
  box-shadow:none!important;
  padding:0!important;
  border-radius:0!important}
.leaflet-popup-content{margin:0!important;padding:0!important}
.leaflet-popup-tip-container{display:none!important}
.leaflet-popup-close-button{
  color:#5a7fa0!important;top:6px!important;right:8px!important;
  font-size:14px!important;width:18px!important;height:18px!important;
  line-height:18px!important;text-align:center!important}
.leaflet-popup-close-button:hover{color:var(--amber)!important}
.gi{max-width:700px;margin:0 auto;width:100%}
.gs{margin-bottom:26px}
.gs h2{font-family:var(--sans);font-size:14px;font-weight:700;
  color:var(--text);margin-bottom:9px;padding-bottom:6px;
  border-bottom:1px solid var(--edge);display:flex;align-items:center;gap:8px}
.gs h2 i{color:var(--amber);font-size:12px}
.gs p,.gs li{font-size:11.5px;color:var(--mid);line-height:1.85;margin-bottom:6px}
.gs ul,.gs ol{padding-left:18px}
.gs strong{color:var(--text)}
.gs code{background:var(--card);border:1px solid var(--edge);border-radius:3px;
  padding:1px 6px;font-family:var(--mono);font-size:10px;color:var(--amber)}
.fb{background:var(--card);border:1px solid var(--edge);
  border-left:3px solid var(--amber);border-radius:var(--r);
  padding:11px 14px;margin:9px 0}
.fb-t{font-family:var(--sans);font-size:10px;font-weight:700;
  color:var(--amber);text-transform:uppercase;letter-spacing:.6px;margin-bottom:6px}
.fb p{font-size:11px;color:var(--mid);line-height:1.7;margin-bottom:4px}
.callout{background:var(--cyan-d);border:1px solid #22d3ee30;
  border-radius:var(--r);padding:10px 13px;font-size:11px;
  color:var(--mid);margin:9px 0;line-height:1.8}

/* MOBILE */
#mobov{display:none;position:fixed;inset:0;background:rgba(0,0,0,.75);
  z-index:299;-webkit-tap-highlight-color:transparent}
#mobov.open{display:block}
#fabrun{position:fixed;bottom:68px;left:50%;transform:translateX(-50%);
  z-index:250;padding:13px 30px;background:var(--amber);color:var(--ink);
  border:none;border-radius:50px;font-family:var(--sans);font-size:13px;
  font-weight:700;box-shadow:0 4px 24px #f59e0b55;cursor:pointer;
  display:none;align-items:center;gap:8px;transition:opacity .12s;
  -webkit-tap-highlight-color:transparent}
#fabresults{position:fixed;bottom:16px;left:50%;transform:translateX(-50%);
  z-index:250;padding:11px 24px;background:var(--card);color:var(--cyan);
  border:1px solid var(--cyan);border-radius:50px;font-family:var(--sans);
  font-size:12px;font-weight:600;cursor:pointer;
  display:none;align-items:center;gap:7px;
  -webkit-tap-highlight-color:transparent}

@media(max-width:768px){
  #pm{flex-direction:column}
  #mc{flex:1;min-height:46vh;position:relative;z-index:1}
  /* On mobile sidebar overlays full-screen from right */
  #sb{top:0;width:min(290px,88vw);z-index:600;
    box-shadow:-6px 0 32px rgba(0,0,0,.9);will-change:transform}
  #sb.open{transform:translateX(0)}
  #sb-close{display:flex!important}
  #mobov.open{display:block}
  #fabrun{display:flex}
  #fabresults{display:flex}
  #nav .nb{padding:7px 9px;font-size:8.5px}
  #nav .nb span{display:inline;font-size:8.5px}
  #pg,#pr{padding:10px;-webkit-overflow-scrolling:touch}
  .gi{max-width:100%}
  #mobmbtn{display:flex!important;align-items:center;justify-content:center}
  .icon-btn,.btn-run,.btn-sec{min-height:40px}
  /* Stage cards: compact so Disease/Period fit on narrow screens */
  .stage{margin-bottom:5px}
  .stage-hd{padding:5px 8px}
  .stage-body{padding:6px 8px;min-width:0;overflow:hidden;box-sizing:border-box}
  .fg{margin-bottom:6px}
  .fl{font-size:7.5px;letter-spacing:.2px}
  .custom-select{font-size:9px;padding:4px 6px;
    width:100%;max-width:100%;box-sizing:border-box;display:block}
  .ds-grid{gap:3px}
  .ds-pill{padding:4px 4px}
  .ds-pill-icon{font-size:11px;margin-bottom:1px}
  .ds-pill-lbl{font-size:6.5px;letter-spacing:.1px}
  .metrics{gap:2px;margin-bottom:5px}
  .mev{font-size:12px}
  .mel{font-size:6.5px}
  .met{padding:4px 3px}
  .sbscroll{padding:6px}
}
@media(min-width:769px){
  #fabrun{display:none!important}
  #fabresults{display:none!important}
}
'

# =============================================================================
# UI
# =============================================================================
ui <- tagList(
  tags$head(
    tags$meta(name="viewport",
              content="width=device-width,initial-scale=1,maximum-scale=1"),
    tags$link(rel="preconnect", href="https://fonts.googleapis.com"),
    tags$link(rel="preconnect", href="https://fonts.gstatic.com", crossorigin=NA),
    tags$link(rel="stylesheet", href=paste0(
      "https://fonts.googleapis.com/css2?",
      "family=JetBrains+Mono:wght@300;400;500&",
      "family=Space+Grotesk:wght@400;600;700&display=swap")),
    tags$link(rel="stylesheet",
              href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css"),
    tags$style(HTML(CSS))
  ),
  useShinyjs(),
  
  div(id="shell",
      
      # ── TOPBAR ──────────────────────────────────────────────────────────────
      div(id="tb",
          div(class="tb-left",
              div(class="tb-sig", tags$i(class="fas fa-satellite-dish")),
              span("TDA Engine", class="tb-name"),
              span("v2.1", class="tb-ver", style="margin-left:6px;")
          ),
          div(class="tb-right",
              tags$button(class="icon-btn", title="Reset all data",
                          onclick="Shiny.setInputValue('reset_app',Math.random())",
                          tags$i(class="fas fa-rotate-left")),
              tags$button(id="mobmbtn", class="icon-btn",
                          onclick="toggleSB()",
                          tags$i(class="fas fa-bars-staggered"))
          )
      ),
      
      # ── TABS ────────────────────────────────────────────────────────────────
      div(id="nav",
          tags$button(class="nb on", `data-tab`="pm",
                      tags$i(class="fas fa-map"), tags$span(" Map")),
          tags$button(class="nb", `data-tab`="pr",
                      tags$i(class="fas fa-triangle-exclamation"), tags$span(" Alerts")),
          tags$button(class="nb", `data-tab`="pt",
                      tags$i(class="fas fa-wave-square"), tags$span(" Temporal")),
          tags$button(class="nb", `data-tab`="pg",
                      tags$i(class="fas fa-book-open"), tags$span(" Guide"))
      ),
      
      div(id="content",
          
          # ── MAP + SIDEBAR ────────────────────────────────────────────────────
          div(id="pm", class="tp on",
              div(id="mc", leafletOutput("map_main", width="100%", height="100%"))
          ),
          
          # sidebar lives outside every .tp so it is NEVER hidden by tab switch
          div(id="sb",
              tags$button(id="sb-close", class="icon-btn",
                          onclick="toggleSB()", tags$i(class="fas fa-xmark")),
              div(class="sbscroll",
                  
                  # KPI metrics
                  div(class="metrics",
                      div(class="met r",
                          div(class="mel","Critical"),
                          div(class="mev",id="s-crit","—")),
                      div(class="met a",
                          div(class="mel","Moderate"),
                          div(class="mev",id="s-mod","—")),
                      div(class="met",
                          div(class="mel","Voids"),
                          div(class="mev",id="s-voids","—"))
                  ),
                  
                  # ── STAGE 1: DISEASE & PERIOD ──────────────────────────────────
                  div(id="stage1", class="stage unlocked",
                      div(class="stage-hd",
                          div(class="stage-num","1"),
                          div(class="stage-title","Disease & Period"),
                          tags$i(class="fas fa-lock-open stage-lock")
                      ),
                      div(class="stage-body",
                          div(class="fg",
                              div(class="fl","Disease / Syndrome"),
                              tags$select(id="sel_disease", class="custom-select",
                                          tags$option(value="malaria",   selected=NA, "Malaria"),
                                          tags$option(value="cholera",   "Cholera / AWD"),
                                          tags$option(value="tb",        "Tuberculosis (TB)"),
                                          tags$option(value="measles",   "Measles"),
                                          tags$option(value="maternal",  "Maternal Deaths"),
                                          tags$option(value="meningitis","Meningitis"),
                                          tags$option(value="hiv",       "HIV New Infections")
                              )
                          ),
                          div(class="fg",
                              div(class="fl","Reporting Period"),
                              tags$select(id="sel_period", class="custom-select",
                                          tags$option(value="monthly",  selected=NA, "Monthly"),
                                          tags$option(value="weekly",   "Weekly"),
                                          tags$option(value="quarterly","Quarterly"),
                                          tags$option(value="annual",   "Annual")
                              )
                          )
                      )
                  ),
                  
                  # ── STAGE 2: DATA SOURCE ───────────────────────────────────────
                  div(id="stage2", class="stage locked",
                      div(class="stage-hd",
                          div(class="stage-num","2"),
                          div(class="stage-title","Data Source"),
                          tags$i(class="fas fa-lock stage-lock", id="lock2")
                      ),
                      div(class="stage-body",
                          div(class="ds-grid",
                              # Demo tile
                              div(class="ds-pill active", id="ds-demo",
                                  onclick="selectDS('demo')",
                                  div(class="ds-pill-icon", tags$i(class="fas fa-flask")),
                                  div(class="ds-pill-lbl","Simulated Demo")
                              ),
                              # Upload tile
                              div(class="ds-pill", id="ds-upload",
                                  onclick="selectDS('upload')",
                                  div(class="ds-pill-icon", tags$i(class="fas fa-upload")),
                                  div(class="ds-pill-lbl","Upload CSV")
                              ),
                              # WHO GHO tile
                              div(class="ds-pill", id="ds-who",
                                  onclick="selectDS('who')",
                                  div(class="ds-pill-icon", tags$i(class="fas fa-globe")),
                                  div(class="ds-pill-lbl","WHO GHO API")
                              ),
                              # DHIS2 tile
                              div(class="ds-pill", id="ds-dhis2",
                                  onclick="selectDS('dhis2')",
                                  div(class="ds-pill-icon", tags$i(class="fas fa-database")),
                                  div(class="ds-pill-lbl","DHIS2 / KHIS")
                              )
                          ),
                          # Hidden input to track selection
                          tags$input(type="hidden", id="ds_choice", value="demo")
                      )
                  ),
                  
                  # ── STAGE 3: LOAD DATA ─────────────────────────────────────────
                  div(id="stage3", class="stage locked",
                      div(class="stage-hd",
                          div(class="stage-num","3"),
                          div(class="stage-title","Load Data"),
                          tags$i(class="fas fa-lock stage-lock", id="lock3")
                      ),
                      div(class="stage-body",
                          uiOutput("stage3_ui")
                      )
                  ),
                  
                  # ── STAGE 4: PARAMETERS + RUN ─────────────────────────────────
                  div(id="stage4", class="stage locked",
                      div(class="stage-hd",
                          div(class="stage-num","4"),
                          div(class="stage-title","Analyse"),
                          tags$i(class="fas fa-lock stage-lock", id="lock4")
                      ),
                      div(class="stage-body",
                          
                          div(class="fg",
                              div(class="fl",
                                  "m₀  mass parameter",
                                  span(id="v-m0","0.10",class="fv")),
                              sliderInput("mass_param",NULL,0.02,0.25,0.10,0.01,
                                          width="100%",ticks=FALSE)),
                          div(class="fg",
                              div(class="fl",
                                  "α  void sensitivity",
                                  span(id="v-al","0.25",class="fv")),
                              sliderInput("alpha_param",NULL,0.05,0.50,0.25,0.01,
                                          width="100%",ticks=FALSE)),
                          div(class="fg",
                              div(class="fl",
                                  "Min deficit threshold (O/E <)",
                                  span(id="v-thr","0.75",class="fv")),
                              sliderInput("oe_threshold",NULL,0.20,0.90,0.75,0.05,
                                          width="100%",ticks=FALSE)),
                          
                          div(style="margin-bottom:8px;",
                              tags$button(class="btn-run",
                                          onclick="Shiny.setInputValue('run_analysis',Math.random())",
                                          tags$i(class="fas fa-magnifying-glass-chart"),
                                          "Detect Surveillance Gaps")
                          ),
                          
                          # Temporal analysis button (enabled when history present)
                          uiOutput("temporal_run_ui"),
                          
                          # Export
                          div(class="btn-2",
                              downloadButton("dl_report",
                                             tagList(tags$i(class="fas fa-file-medical")," Brief"),
                                             class="btn-sec"),
                              downloadButton("dl_geojson",
                                             tagList(tags$i(class="fas fa-map")," GeoJSON"),
                                             class="btn-sec")
                          ),
                          downloadButton("dl_table",
                                         tagList(tags$i(class="fas fa-table")," Completeness CSV"),
                                         class="btn-sec"),
                          downloadButton("dl_temporal",
                                         tagList(tags$i(class="fas fa-wave-square")," Temporal Report"),
                                         class="btn-sec")
                      )
                  ),
                  
                  # Validation section (always accessible once data loaded)
                  uiOutput("validation_section_ui")
                  
              ),
              
              # Status bar
              div(id="sbar",
                  div(id="sdot",class="sdot ready"),
                  tags$span(id="stxt","Step 1 — Select disease and reporting period")
              )
          ),
          
          # ── ALERTS PANEL ──────────────────────────────────────────────────────
          div(id="pr", class="tp", uiOutput("alerts_ui")),
          
          # ── TEMPORAL ANALYSIS PANEL — NEW v2.1 ─────────────────────────────
          div(id="pt", class="tp",
              div(style="flex:1;overflow-y:auto;padding:16px;background:var(--ink);
                   scrollbar-width:thin;scrollbar-color:var(--edge) transparent;",
                  uiOutput("temporal_ui")
              )
          ),
          
          # ── GUIDE PANEL ───────────────────────────────────────────────────────
          div(id="pg", class="tp",
              div(style="flex:1;overflow-y:auto;padding:22px;width:100%;background:var(--ink);scrollbar-width:thin;",
                  div(class="gi",
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-bullseye"),"What This Tool Does"),
                          div(class="callout",
                              tags$strong("One sentence: "),
                              "Takes your DHIS2 case count table, computes expected cases from population,",
                              " maps geographic clusters of silence, and classifies each as",
                              " STRUCTURAL (permanent barrier) or STOCHASTIC (random noise)."
                          ),
                          tags$p("A surveillance void is not just a missing number. Sub-counties that",
                                 " never appear in DHIS2 may harbour the highest true caseloads.",
                                 " This tool makes those silences visible, locatable, and actionable.")
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-divide"),"Observed vs Expected Ratio (O/E)"),
                          tags$p("For each admin unit i and period t, expected cases come from the",
                                 " reference disease incidence rate multiplied by population:"),
                          div(class="fb",
                              div(class="fb-t","O/E Formula"),
                              tags$p("Expected(i,t) = Population(i) x ReferenceRate / PeriodDivisor"),
                              tags$p("O/E(i,t) = ReportedCases(i,t) / Expected(i,t)"),
                              tags$p("Period divisors: Annual=1, Quarterly=4, Monthly=12, Weekly=52."),
                              tags$p("O/E = 1.00 means perfect reporting. O/E = 0.15 means only",
                                     " 15% of expected cases are visible — 85% are silent.")
                          ),
                          div(class="fb",
                              div(class="fb-t","Completeness Thresholds"),
                              tags$p(tags$span(class="cb-critical","CRITICAL"), " — O/E < 0.20: severe under-reporting, likely structural barrier."),
                              tags$p(tags$span(class="cb-moderate","MODERATE"), " — O/E 0.20-0.50: significant gap, needs investigation."),
                              tags$p(tags$span(class="cb-mild","MILD"), " — O/E 0.50-0.75: below threshold, monitor closely."),
                              tags$p(tags$span(class="cb-adequate","ADEQUATE"), " — O/E >= 0.75: acceptable completeness.")
                          )
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-hexagon-nodes"),"Topological Void Detection (DTM)"),
                          tags$p("The tool finds contiguous geographic clusters of silence using the",
                                 " Distance-to-Measure function from Topological Data Analysis."),
                          div(class="fb",
                              div(class="fb-t","How DTM Works"),
                              tags$p("1. Each deficit unit is placed in UTM coordinate space,",
                                     " weighted by deficit rate."),
                              tags$p("2. A regular grid is cast over the convex hull of the study region."),
                              tags$p("3. At each grid point, DTM measures the average distance to the",
                                     " k = ceiling(m0 x n) nearest deficit-weighted points."),
                              tags$p("4. Grid points above threshold tau are labelled void cells.",
                                     " Connected cells merge into void polygons."),
                              tags$p("5. tau = max(Q(1-alpha, DTM), 0.85 x kneedle_elbow) balances",
                                     " sensitivity with noise rejection.")
                          ),
                          div(class="fb",
                              div(class="fb-t","Parameters"),
                              tags$p(tags$strong("m0 (0.02-0.25): "),
                                     "Controls neighbourhood size. Lower = finer resolution, more sensitive.",
                                     " Higher = smoother, less noise."),
                              tags$p(tags$strong("alpha (0.05-0.50): "),
                                     "Fraction of grid points treated as void.",
                                     " alpha=0.25 means top 25% of DTM values are candidates.")
                          )
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-wave-square"),"Temporal Void Classification"),
                          div(class="callout",
                              tags$strong("Why this matters: "),
                              "O/E = 0.10 this month could be a data entry failure that self-corrects.",
                              " The same unit at O/E = 0.10 for 8 consecutive months is a structural",
                              " barrier requiring field intervention. The response is completely different."
                          ),
                          div(class="fb",
                              div(class="fb-t","Fano Factor (Primary Classifier)"),
                              tags$p("Fano = Var(O/E) / Mean(O/E) across all periods."),
                              tags$p("For pure Poisson counting, Fano = 1. A STRUCTURAL void has consistently",
                                     " low O/E with small variance => Fano < 1 (sub-Poisson, regular silence)."),
                              tags$p("A STOCHASTIC dip has high variance around an adequate mean",
                                     " => Fano > 1 (super-Poisson, noisy but recoverable).")
                          ),
                          div(class="fb",
                              div(class="fb-t","2-State Hidden Markov Model"),
                              tags$p("States: S=0 (Silent) and S=1 (Reporting)."),
                              tags$p("Emission: Gaussian N(mu_k, sigma_k) per state.",
                                     " Transition matrix A estimated via Baum-Welch EM."),
                              tags$p("Viterbi decoding gives the most-likely state sequence.",
                                     " p_structural = fraction of periods in state 0.")
                          ),
                          div(class="fb",
                              div(class="fb-t","Decision Rule"),
                              tags$p(tags$span(class="void-structural","STRUCTURAL"),
                                     ": p_structural >= 0.60 — persistent silence, address root cause."),
                              tags$p(tags$span(class="void-intermittent","INTERMITTENT"),
                                     ": 0.35-0.60 — partial or seasonal suppression."),
                              tags$p(tags$span(class="void-stochastic","STOCHASTIC"),
                                     ": p_structural < 0.35 — random noise, low priority."),
                              tags$p("Use the Temporal Report download (sidebar) to export a full",
                                     " per-unit classification table as a printable HTML/PDF document.")
                          )
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-magnifying-glass"),"Causal Classification"),
                          tags$p("For each spatial void the tool assigns a probable cause from covariate data:"),
                          div(class="fb",
                              div(class="fb-t","Cause Hierarchy"),
                              tags$p(tags$span(class="cause-BORDER","BORDER"),
                                     ": near international border AND O/E < 0.25."),
                              tags$p(tags$span(class="cause-ACCESS","ACCESS"),
                                     ": road_index < 0.35 — geographic isolation."),
                              tags$p(tags$span(class="cause-INFRASTRUCTURE","INFRASTRUCTURE"),
                                     ": facility density < 0.5 per 100 km2."),
                              tags$p(tags$span(class="cause-SYSTEM","SYSTEM"),
                                     ": facilities present but cases far below expected — DHIS2 pipeline failure."),
                              tags$p(tags$span(class="cause-UNKNOWN","UNKNOWN"),
                                     ": covariates unavailable; silence confirmed but cause unclassified.")
                          )
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-database"),"Real Data Sources"),
                          tags$p("All three sources export CSV that this tool accepts after simple column renaming:"),
                          div(class="fb",
                              div(class="fb-t","WHO GHO API"),
                              tags$p("Country-level annual aggregates. Click the link in Stage 3 to",
                                     " download CSV directly. Rename: SpatialDim->admin_unit,",
                                     " NumericValue->reported_cases. Add a population column.")
                          ),
                          div(class="fb",
                              div(class="fb-t","DHIS2 Demo Server"),
                              tags$p("Login: admin / district at play.dhis2.org/40.6.1.",
                                     " Apps -> Data Visualizer -> Pivot Table -> Download CSV.",
                                     " Rename: Data->admin_unit, Period->period, Value->reported_cases.")
                          ),
                          div(class="fb",
                              div(class="fb-t","Kenya KHIS (hiskenya.org)"),
                              tags$p("Real national HMIS. Free registration required.",
                                     " Apps -> Data Visualizer -> Sub-county -> Download CSV.",
                                     " Sub-county names match this tool geography for Nyanza region.")
                          )
                      ),
                      
                      div(class="gs",
                          tags$h2(tags$i(class="fas fa-file-contract"),"Citation"),
                          div(class="fb",
                              div(class="fb-t","How to cite"),
                              tags$p(WM_CITATION),
                              tags$a(href=WM_URL, target="_blank",
                                     style="color:var(--amber);font-size:10.5px;",
                                     tags$i(class="fas fa-external-link-alt",style="margin-right:4px;"),
                                     paste0("doi:", WM_DOI))
                          )
                      )
                  )
              )
          )
      ),
      
      # FABs
      tags$button(id="fabrun",
                  onclick="Shiny.setInputValue('run_analysis',Math.random())",
                  tags$i(class="fas fa-magnifying-glass-chart"),"Detect Gaps"),
      tags$button(id="fabresults",
                  onclick="switchTab('pr')",
                  tags$i(class="fas fa-triangle-exclamation"),"View Alerts"),
      div(id="mobov",onclick="toggleSB()")
  ),
  
  tags$script(HTML("
    /* ── Tab switching ── */
    function switchTab(t) {
      document.querySelectorAll('.nb').forEach(function(x){x.classList.remove('on');});
      document.querySelectorAll('.tp').forEach(function(x){x.classList.remove('on');});
      var b = document.querySelector('.nb[data-tab=\"'+t+'\"]');
      if(b) b.classList.add('on');
      var p = document.getElementById(t);
      if(p) p.classList.add('on');
      if(t==='pm'){
        setTimeout(function(){
          document.querySelectorAll('.leaflet-container').forEach(function(m){
            if(m._leaflet_id){
              try{window.L&&L.map&&Object.values(L.map).forEach(function(mm){
                if(mm.invalidateSize)mm.invalidateSize();})}catch(e){}
            }
          });
        },80);
      }
    }

    /* ── Stage progression ── */
    function setStage(n, state) {
      var el = document.getElementById('stage'+n);
      if(!el) return;
      el.classList.remove('locked','unlocked','complete');
      el.classList.add(state);
      var lk = el.querySelector('.stage-lock');
      if(lk){
        lk.className = 'fas stage-lock ' +
          (state==='locked' ? 'fa-lock' : state==='unlocked' ? 'fa-lock-open' : 'fa-check-circle');
        if(state==='complete') lk.style.color='var(--green)';
        else if(state==='unlocked') lk.style.color='var(--amber)';
        else lk.style.color='';
      }
    }

    /* Called from Shiny: unlock stage 2 once disease+period chosen */
    Shiny.addCustomMessageHandler('unlock_stage', function(m) {
      setStage(m.stage, m.state);
    });

    /* ── Data source pill selection ── */
    function selectDS(src) {
      ['demo','upload','who','dhis2'].forEach(function(s){
        document.getElementById('ds-'+s).classList.remove('active');
      });
      document.getElementById('ds-'+src).classList.add('active');
      document.getElementById('ds_choice').value = src;
      Shiny.setInputValue('ds_choice', src, {priority:'event'});
    }

    /* ── Sidebar toggle ── */
    function openSB(){
      document.getElementById('sb').classList.add('open');
      document.body.classList.add('sb-open');
      if(window.innerWidth<769){
        document.getElementById('mobov').classList.add('open');
        document.body.style.overflow='hidden';
      }
    }
    function closeSB(){
      document.getElementById('sb').classList.remove('open');
      document.body.classList.remove('sb-open');
      document.getElementById('mobov').classList.remove('open');
      document.body.style.overflow='';
    }
    function toggleSB(e){
      if(e){e.preventDefault();e.stopPropagation();}
      if(document.getElementById('sb').classList.contains('open')) closeSB();
      else openSB();
    }

    /* ── Accordion ── */
    function tC(h){
      var b=h.nextElementSibling; var i=h.querySelector('.scv');
      if(!b) return;
      var hidden=b.style.display==='none'||b.style.display==='';
      b.style.display=hidden?'block':'none';
      if(i){if(hidden)i.classList.add('open');else i.classList.remove('open');}
    }

    document.addEventListener('DOMContentLoaded',function(){
      /* Open sidebar by default */
      openSB();
      /* Delegation on #nav: one listener that survives all Shiny re-renders */
      var nav=document.getElementById('nav');
      if(nav) nav.addEventListener('click',function(e){
        var b=e.target.closest('.nb');
        if(!b) return;
        e.preventDefault(); e.stopPropagation();
        switchTab(b.getAttribute('data-tab'));
      });
      var ov=document.getElementById('mobov');
      if(ov){
        ov.addEventListener('click',closeSB);
        ov.addEventListener('touchend',function(e){e.preventDefault();closeSB();});
      }
    });

    /* ── Shiny message handlers ── */
    Shiny.addCustomMessageHandler('ss',function(m){
      var el=document.getElementById('stxt');
      var dot=document.getElementById('sdot');
      if(el)  el.textContent =m.t;
      if(dot) dot.className  ='sdot '+(m.s||'ready');
    });
    Shiny.addCustomMessageHandler('sm',function(m){
      if(m.crit!==undefined){var e=document.getElementById('s-crit'); if(e)e.textContent=m.crit;}
      if(m.mod !==undefined){var e=document.getElementById('s-mod');  if(e)e.textContent=m.mod;}
      if(m.voids!==undefined){var e=document.getElementById('s-voids');if(e)e.textContent=m.voids;}
    });
    Shiny.addCustomMessageHandler('sv',function(m){
      var e=document.getElementById(m.i); if(e)e.textContent=m.v;
    });
    Shiny.addCustomMessageHandler('goto_alerts',function(m){switchTab('pr');});
    Shiny.addCustomMessageHandler('goto_temporal',function(m){
      if(window.innerWidth<769) closeSB();
      switchTab('pt');
    });
    Shiny.addCustomMessageHandler('reset_done',function(m){
      ['s-crit','s-mod','s-voids'].forEach(function(id){
        var e=document.getElementById(id);if(e)e.textContent='—';
      });
      setStage(2,'locked');setStage(3,'locked');setStage(4,'locked');
      selectDS('demo');
      switchTab('pm');
    });
  "))
)


# =============================================================================
# SERVER
# =============================================================================
server <- function(input, output, session) {
  options(shiny.maxRequestSize = 20 * 1024^2)
  
  v <- reactiveValues(
    df          = NULL,    # current period data frame
    history     = list(),  # list of prior-period data frames (for temporal)
    results     = NULL,    # spatial analysis results
    temporal    = NULL,    # temporal classification results
    selftest    = NULL,
    disease     = "malaria",
    period      = "monthly",
    stage       = 1L       # current progressive input stage
  )
  
  # Helpers
  ss  <- function(t, s="ready")
    session$sendCustomMessage("ss", list(t=t, s=s))
  sm  <- function(crit=NULL, mod=NULL, voids=NULL)
    session$sendCustomMessage("sm", list(
      crit  = if(!is.null(crit))  as.character(crit)  else NULL,
      mod   = if(!is.null(mod))   as.character(mod)   else NULL,
      voids = if(!is.null(voids)) as.character(voids) else NULL))
  sv  <- function(id, val)
    session$sendCustomMessage("sv", list(i=id, v=as.character(val)))
  unlock <- function(stage, state="unlocked")
    session$sendCustomMessage("unlock_stage", list(stage=stage, state=state))
  
  # ── Stage 1 complete: unlock stage 2 ───────────────────────────────────
  observe({
    req(input$sel_disease, input$sel_period)
    isolate({
      if (v$stage < 2L) {
        v$stage <- 2L
        unlock(2, "unlocked")
        ss("Step 2 — Choose your data source", "ready")
      }
    })
  })
  
  # ── CSV parser ─────────────────────────────────────────────────────────
  .parse_csv <- function(txt) {
    tryCatch({
      # Strip comment lines beginning with #
      lines <- strsplit(txt, "\n")[[1]]
      lines <- lines[!grepl("^\\s*#", lines)]
      txt2  <- paste(lines, collapse="\n")
      df    <- read.csv(text=txt2, stringsAsFactors=FALSE,
                        na.strings=c("","NA","NULL"), nrows=50000)
      names(df) <- trimws(tolower(make.names(names(df))))
      # Sanitise column names (security: prevent injection via headers)
      names(df) <- gsub("[^a-z0-9_]", "_", names(df))
      needed <- c("admin_unit","population","reported_cases")
      miss   <- setdiff(needed, names(df))
      if (length(miss) > 0) stop(paste("Missing columns:", paste(miss, collapse=", ")))
      if (!"period" %in% names(df)) df$period <- "uploaded"
      df$population     <- suppressWarnings(as.numeric(df$population))
      df$reported_cases <- suppressWarnings(as.numeric(df$reported_cases))
      # Trim admin_unit whitespace and normalise case artefacts
      df$admin_unit     <- trimws(df$admin_unit)
      # Remove duplicates (DHIS2 export artefact)
      df <- df[!duplicated(df[, c("period","admin_unit")]), ]
      df <- df[complete.cases(df[, c("population","reported_cases")]), ]
      df <- df[df$population > 0, ]
      if (nrow(df) == 0) stop("No valid rows after cleaning")
      for (col in c("lat","long","facility_count","road_index","area_km2","reference_rate")) {
        if (col %in% names(df)) df[[col]] <- suppressWarnings(as.numeric(df[[col]]))
        else df[[col]] <- NA_real_
      }
      # Sanitise character columns (XSS prevention)
      df[] <- lapply(df, function(x) {
        if (is.character(x)) gsub("[<>\"'`]", "", x) else x
      })
      df
    }, error=function(e){ ss(conditionMessage(e), "error"); NULL })
  }
  
  # ── Enrich with disease rates ──────────────────────────────────────────
  .enrich <- function(df, disease, period_type) {
    dis  <- .DISEASE_REF[[disease]]
    pdiv <- dis$period_div[[period_type]]
    rm   <- if (disease %in% c("tb","meningitis")) 1/100 else 1
    if (disease == "malaria") {
      m <- match(toupper(trimws(df$admin_unit)), toupper(.KENYA_RATES$admin_unit))
      df$ref_rate <- ifelse(!is.na(m), .KENYA_RATES$malaria_rate_k[m], dis$rate_per_k)
      for (col in c("lat","long","facility_count","road_index","area_km2")) {
        if (all(is.na(df[[col]]))) {
          vals <- .KENYA_RATES[[col]]
          if (!is.null(vals)) df[[col]] <- ifelse(!is.na(m), vals[m], NA_real_)
        }
      }
      if (!("county" %in% names(df)) || all(is.na(df$county))) {
        df$county <- ifelse(!is.na(m), .KENYA_RATES$county[m], NA_character_)
      }
    } else {
      df$ref_rate <- ifelse(!is.na(df$reference_rate), df$reference_rate, dis$rate_per_k)
    }
    df$expected <- df$population * df$ref_rate * rm / pdiv
    df <- .compute_completeness(df, disease)
    df
  }
  
  # ── Data source selector → update stage 3 ─────────────────────────────
  observeEvent(input$ds_choice, {
    req(v$stage >= 2L)
    unlock(3, "unlocked")
    if (v$stage < 3L) {
      v$stage <- 3L
      ss("Step 3 — Load your data", "ready")
    }
  })
  
  # ── Stage 3 UI (dynamic per data source choice) ────────────────────────
  output$stage3_ui <- renderUI({
    dis  <- if (!is.null(input$sel_disease)) input$sel_disease else "malaria"
    per  <- if (!is.null(input$sel_period))  input$sel_period  else "monthly"
    src  <- if (!is.null(input$ds_choice))   input$ds_choice   else "demo"
    sources <- .real_data_sources(dis)
    
    if (src == "demo") {
      tagList(
        div(style=paste0(
          "background:#f59e0b12;border:1px solid var(--amber-m);",
          "border-radius:var(--r);padding:8px;margin-bottom:8px;",
          "font-size:9.5px;color:var(--amber);line-height:1.7;"),
          tags$i(class="fas fa-flask",style="margin-right:5px;"),
          tags$strong("SIMULATED DEMO — "),
          .DISEASE_REF[[dis]]$label, " · ", per,
          tags$br(),
          span(style="color:var(--muted);",
               "44 Nyanza sub-counties. Expected = real population × WHO/MAP rate. ",
               "Reported = synthetic. Silent zones epidemiologically motivated.")),
        div(class="tr-row",
            div(style="font-size:10px;color:var(--cyan);",
                tags$i(class="fas fa-flask",style="margin-right:4px;"),
                "Load simulated demo"),
            tags$input(type="checkbox",class="form-check-input",
                       id="use_demo",checked=NA)
        ),
        tags$hr(style="border-color:var(--edge);margin:8px 0;"),
        div(style="font-size:9px;color:var(--muted);margin-bottom:5px;",
            "Also download a multi-period noisy CSV (mimics DHIS2 export):"),
        div(class="btn-2",
            downloadButton("dl_sample",
                           tagList(tags$i(class="fas fa-table-list")," Clean CSV"),
                           class="btn-sec", style="margin-bottom:0;"),
            downloadButton("dl_noisy",
                           tagList(tags$i(class="fas fa-bug")," Noisy CSV"),
                           class="btn-sec", style="margin-bottom:0;")
        )
      )
      
    } else if (src == "upload") {
      tagList(
        div(style=paste0(
          "background:var(--ink);border:1px solid var(--edge);",
          "border-radius:var(--r);padding:8px;margin-bottom:8px;"),
          div(style="font-size:9px;color:var(--amber);margin-bottom:5px;",
              tags$i(class="fas fa-table",style="margin-right:4px;"),
              "REQUIRED CSV FORMAT"),
          div(style="font-family:var(--mono);font-size:9px;color:var(--muted);line-height:2;",
              div(style="color:var(--amber);","period,admin_unit,population,reported_cases"),
              div("2024-01,Kisumu Central,409000,310"),
              div("2024-01,Mbita,77000,8"),
              div(style="color:var(--muted);margin-top:4px;font-size:8.5px;",
                  "Optional: lat, long, facility_count, road_index, area_km2")
          )
        ),
        tags$label(class="upload-btn",
                   tags$i(class="fas fa-upload"),
                   tags$span(id="upload-lbl","Upload case count CSV…"),
                   tags$input(type="file",id="data_upload",accept=".csv",style="display:none;",
                              onchange=paste0(
                                "var f=this.files[0];if(f){",
                                "document.getElementById('upload-lbl').textContent=f.name;",
                                "var r=new FileReader();",
                                "r.onload=function(e){Shiny.setInputValue('upload_data',",
                                "{name:f.name,content:e.target.result},{priority:'event'});};",
                                "r.readAsText(f);}"
                              )
                   )
        ),
        div(style="font-size:9px;color:var(--muted);margin-top:4px;",
            tags$i(class="fas fa-shield-halved",style="margin-right:3px;"),
            "Max 20 MB · 50,000 rows · comment lines (#) stripped automatically")
      )
      
    } else if (src == "who") {
      s <- sources$who_gho
      tagList(
        div(class="ds-info",
            div(style="font-weight:600;color:var(--text);margin-bottom:5px;",
                tags$i(class="fas fa-globe",style="color:var(--cyan);margin-right:5px;"),
                s$label, " — ", s$format_note),
            tags$a(href=s$url, target="_blank",
                   style="color:var(--cyan);font-size:9.5px;word-break:break-all;",
                   tags$i(class="fas fa-external-link-alt",style="margin-right:3px;"),
                   "Open API URL ↗"),
            tags$br(), tags$br(),
            div(style="white-space:pre-wrap;font-size:9px;color:var(--muted);",
                s$instructions)
        ),
        tags$label(class="upload-btn",
                   style="border-color:var(--cyan);",
                   tags$i(class="fas fa-upload"),
                   tags$span(id="upload-lbl2","Paste/upload downloaded WHO CSV…"),
                   tags$input(type="file",id="data_upload",accept=".csv",style="display:none;",
                              onchange=paste0(
                                "var f=this.files[0];if(f){",
                                "document.getElementById('upload-lbl2').textContent=f.name;",
                                "var r=new FileReader();",
                                "r.onload=function(e){Shiny.setInputValue('upload_data',",
                                "{name:f.name,content:e.target.result},{priority:'event'});};",
                                "r.readAsText(f);}"
                              )
                   )
        )
      )
      
    } else {  # dhis2 / khis
      s_dhis2 <- sources$dhis2_play
      s_khis  <- sources$khis_kenya
      tagList(
        div(class="ds-info",
            div(style="font-weight:600;color:var(--text);margin-bottom:4px;",
                tags$i(class="fas fa-database",style="color:var(--purple);margin-right:5px;"),
                "DHIS2 Demo Server (play.dhis2.org)"),
            div(style="font-size:9px;color:var(--muted);margin-bottom:4px;",
                "Login: ", tags$code("admin"), " / ", tags$code("district1")),
            tags$a(href=s_dhis2$url, target="_blank",
                   style="color:var(--purple);font-size:9px;",
                   tags$i(class="fas fa-external-link-alt",style="margin-right:3px;"),
                   "Open analytics URL ↗"),
            tags$br(), tags$br(),
            div(style="font-weight:600;color:var(--text);margin-bottom:4px;",
                tags$i(class="fas fa-flag",style="color:var(--green);margin-right:5px;"),
                "Kenya KHIS (hiskenya.org) — Sub-county level"),
            tags$a(href=s_khis$url, target="_blank",
                   style="color:var(--green);font-size:9px;",
                   tags$i(class="fas fa-external-link-alt",style="margin-right:3px;"),
                   "Open KHIS ↗"),
            div(style="white-space:pre-wrap;font-size:9px;color:var(--muted);margin-top:6px;",
                "Column mapping after export:\n",
                tags$code("OrganisationUnit"), " → admin_unit  |  ",
                tags$code("Period"), " → period  |  ",
                tags$code("Value"), " → reported_cases")
        ),
        tags$label(class="upload-btn",
                   style="border-color:var(--purple);",
                   tags$i(class="fas fa-upload"),
                   tags$span(id="upload-lbl3","Upload DHIS2/KHIS export CSV…"),
                   tags$input(type="file",id="data_upload",accept=".csv",style="display:none;",
                              onchange=paste0(
                                "var f=this.files[0];if(f){",
                                "document.getElementById('upload-lbl3').textContent=f.name;",
                                "var r=new FileReader();",
                                "r.onload=function(e){Shiny.setInputValue('upload_data',",
                                "{name:f.name,content:e.target.result},{priority:'event'});};",
                                "r.readAsText(f);}"
                              )
                   )
        )
      )
    }
  })
  
  # ── Demo toggle ────────────────────────────────────────────────────────
  observeEvent(input$use_demo, {
    if (isTRUE(input$use_demo)) {
      dis <- if (!is.null(input$sel_disease)) input$sel_disease else "malaria"
      per <- if (!is.null(input$sel_period))  input$sel_period  else "monthly"
      demo_df <- .build_demo(dis, per)
      v$df <- demo_df
      .advance_to_stage4(demo_df)
    } else {
      v$df <- NULL; v$results <- NULL
      sm(crit="—",mod="—",voids="—")
      unlock(4, "locked")
      ss("Demo cleared — upload your CSV or choose another source","ready")
      leafletProxy("map_main") %>%
        clearGroup("Completeness") %>% clearGroup("Voids") %>% clearGroup("Rings")
    }
  })
  
  # ── CSV upload ──────────────────────────────────────────────────────────
  observeEvent(input$upload_data, {
    req(input$upload_data)
    updateCheckboxInput(session, "use_demo", value=FALSE)
    df <- .parse_csv(input$upload_data$content)
    if (is.null(df)) return()
    dis <- if (!is.null(input$sel_disease)) input$sel_disease else "malaria"
    per <- if (!is.null(input$sel_period))  input$sel_period  else "monthly"
    df  <- .enrich(df, dis, per)
    v$df <- df; v$results <- NULL
    .advance_to_stage4(df)
  })
  
  # Helper: advance to stage 4 after data loaded
  .advance_to_stage4 <- function(df) {
    dis     <- if (!is.null(input$sel_disease)) input$sel_disease else "malaria"
    n_crit  <- sum(df$completeness == "Critical",  na.rm=TRUE)
    n_mod   <- sum(df$completeness == "Moderate",  na.rm=TRUE)
    n_coord <- sum(!is.na(df$lat) & !is.na(df$long))
    sm(crit=n_crit, mod=n_mod, voids="—")
    unlock(3, "complete")
    if (n_coord >= 5) {
      unlock(4, "unlocked")
      v$stage <- 4L
      ss(sprintf("Data loaded — %d units · %d critical · ready to analyse",
                 nrow(df), n_crit), "ready")
      .paint_completeness(df)
    } else {
      ss(paste0("Loaded ", nrow(df), " units but only ", n_coord,
                " have coordinates. Add lat/long to enable map analysis."), "error")
    }
  }
  
  # ── Disease or period change → re-enrich ──────────────────────────────
  observeEvent(list(input$sel_disease, input$sel_period), {
    req(input$sel_disease, input$sel_period)
    dis <- input$sel_disease; per <- input$sel_period
    if (isTRUE(isolate(input$use_demo))) {
      demo_df <- .build_demo(dis, per)
      v$df <- demo_df; v$results <- NULL
      n_crit <- sum(demo_df$completeness == "Critical", na.rm=TRUE)
      n_mod  <- sum(demo_df$completeness == "Moderate", na.rm=TRUE)
      sm(crit=n_crit, mod=n_mod, voids="—")
      ss(sprintf("Demo updated — %s, %s | %d critical | %d moderate",
                 .DISEASE_REF[[dis]]$label, per, n_crit, n_mod), "ready")
      .paint_completeness(demo_df)
    } else if (!is.null(isolate(v$df))) {
      df_new <- .enrich(isolate(v$df), dis, per)
      v$df <- df_new; v$results <- NULL
      n_crit <- sum(df_new$completeness == "Critical", na.rm=TRUE)
      n_mod  <- sum(df_new$completeness == "Moderate", na.rm=TRUE)
      sm(crit=n_crit, mod=n_mod, voids="—")
      ss(sprintf("Recalculated — %s %s | %d critical | %d moderate",
                 .DISEASE_REF[[dis]]$label, per, n_crit, n_mod), "ready")
      .paint_completeness(df_new)
    }
  }, ignoreInit=TRUE)
  
  # ── Reset ──────────────────────────────────────────────────────────────
  observeEvent(input$reset_app, {
    v$df <- NULL; v$results <- NULL; v$history <- list()
    v$temporal <- NULL; v$selftest <- NULL; v$stage <- 1L
    sm(crit="—",mod="—",voids="—")
    ss("Reset — Step 1: select disease and period","ready")
    leafletProxy("map_main") %>%
      clearGroup("Completeness") %>% clearGroup("Voids") %>% clearGroup("Rings")
    session$sendCustomMessage("reset_done", list())
  })
  
  # ── Sample CSV downloads ───────────────────────────────────────────────
  output$dl_sample <- downloadHandler(
    filename = function() "sample_surveillance.csv",
    content  = function(file) writeLines(.sample_csv(), file))
  
  output$dl_noisy <- downloadHandler(
    filename = function() paste0("noisy_dhis2_",
                                 if(!is.null(input$sel_disease)) input$sel_disease else "malaria", ".csv"),
    content  = function(file) {
      dis <- if (!is.null(input$sel_disease)) input$sel_disease else "malaria"
      writeLines(.generate_noisy_csv(dis, 6), file)
    })
  
  observeEvent(input$mass_param,   sv("v-m0",  sprintf("%.2f", input$mass_param)))
  observeEvent(input$alpha_param,  sv("v-al",  sprintf("%.2f", input$alpha_param)))
  observeEvent(input$oe_threshold, sv("v-thr", sprintf("%.2f", input$oe_threshold)))
  
  # ── Map init ───────────────────────────────────────────────────────────
  output$map_main <- renderLeaflet({
    leaflet(options=leafletOptions(zoomControl=TRUE, attributionControl=FALSE)) %>%
      addProviderTiles(providers$CartoDB.DarkMatter) %>%
      setView(34.55, -0.45, 8) %>%
      addLayersControl(
        overlayGroups = c("Completeness","Voids","Rings"),
        options = layersControlOptions(collapsed=FALSE, position="bottomleft"))
  })
  
  .oe_color <- function(oe) {
    ifelse(oe < 0.20,"#f87171",ifelse(oe<0.50,"#f59e0b",ifelse(oe<0.75,"#22d3ee","#4ade80")))
  }
  .oe_label <- function(oe) {
    ifelse(oe<0.20,"Critical",ifelse(oe<0.50,"Moderate",ifelse(oe<0.75,"Mild","Adequate")))
  }
  
  .paint_completeness <- function(df) {
    df_valid <- df[!is.na(df$lat) & !is.na(df$long), ]
    if (nrow(df_valid) == 0) return()
    leafletProxy("map_main") %>%
      clearGroup("Completeness") %>%
      addCircleMarkers(
        data=df_valid, ~long, ~lat,
        radius      = ~pmin(pmax(sqrt(deficit+1)*0.9,5),20),
        color       = ~.oe_color(oe_ratio),
        stroke      = TRUE, weight=1.5, fillOpacity=0.75,
        fillColor   = ~.oe_color(oe_ratio),
        group       = "Completeness",
        popup       = ~paste0(
          "<div style='font-family:monospace;background:#0b1220;color:#c8d8e8;",
          "padding:10px;border-radius:5px;min-width:180px;font-size:11px;'>",
          "<b style='color:",.oe_color(oe_ratio),";font-size:13px;'>",admin_unit,"</b><br>",
          "<span style='color:#5a7fa0;'>County: </span>",
          ifelse(is.na(county),"—",county),"<br>",
          "<b>O/E ratio: </b>",sprintf("%.3f",oe_ratio),
          " <span style='color:",.oe_color(oe_ratio),";'>(",.oe_label(oe_ratio),")</span><br>",
          "<b>Expected: </b>",round(expected)," cases<br>",
          "<b>Reported: </b>",reported_cases," cases<br>",
          "<b>Deficit: </b>",round(deficit)," cases<br>",
          "<b>Population: </b>",formatC(population,format="d",big.mark=","),
          "<br><small style='color:#3a5570;'>",WM_AUTHOR," · doi:",WM_DOI,"</small></div>")
      ) %>%
      fitBounds(min(df_valid$long)-.08, min(df_valid$lat)-.08,
                max(df_valid$long)+.08, max(df_valid$lat)+.08)
  }
  
  # ── MAIN SPATIAL ANALYSIS ──────────────────────────────────────────────
  observeEvent(input$run_analysis, {
    df <- v$df
    if (is.null(df)) { ss("No data loaded yet","error"); return() }
    df_d <- df[!is.na(df$lat) & !is.na(df$long), ]
    if (nrow(df_d) < 5) { ss("Need ≥5 units with lat/long","error"); return() }
    ss("Running spatial analysis…","working")
    tryCatch({
      withProgress(message="Analysis",value=0,{
        incProgress(.15, detail="Completeness surface…")
        n_crit <- sum(df$completeness=="Critical",na.rm=TRUE)
        n_mod  <- sum(df$completeness=="Moderate",na.rm=TRUE)
        
        incProgress(.35, detail="DTM void detection…")
        void_res <- .dtm_voids(df_d, m0=input$mass_param, alpha=input$alpha_param)
        
        incProgress(.65, detail="Causal classification…")
        causes <- list()
        if (!is.null(void_res)) {
          vs <- void_res$voids
          for (i in seq_len(nrow(vs))) {
            idx <- which(df_d$admin_unit %in% strsplit(vs$admin_units[i],", ")[[1]])
            causes[[i]] <- .classify_cause(
              mean(df_d$road_index[idx],na.rm=TRUE),
              mean(df_d$facility_count[idx],na.rm=TRUE),
              mean(df_d$area_km2[idx],na.rm=TRUE),
              any(df_d$admin_unit[idx] %in% c("Kuria East","Kuria West","Nyatike","Migori Town")),
              if(is.na(vs$mean_oe[i])) 0.5 else vs$mean_oe[i])
          }
        }
        
        incProgress(.85, detail="Spatial stability…")
        stability <- tryCatch({
          m0v <- input$mass_param
          counts <- sapply(c(m0v*.6, m0v, m0v*1.4), function(m) {
            r2 <- tryCatch(.dtm_voids(df_d, m0=m, alpha=input$alpha_param),
                           error=function(e) NULL)
            if (is.null(r2)) 0L else nrow(r2$voids)
          })
          counts[is.na(counts)] <- 0L
          list(counts=counts, stable=diff(range(counts)) <= 2)
        }, error=function(e) list(counts=c(0L,0L,0L), stable=TRUE))
        
        incProgress(1)
        n_voids <- if(!is.null(void_res)) nrow(void_res$voids) else 0
        sm(crit=n_crit, mod=n_mod, voids=n_voids)
        
        v$results <- list(
          df=df, void_res=void_res, causes=causes, stability=stability,
          n_crit=n_crit, n_mod=n_mod, n_voids=n_voids,
          disease=input$sel_disease, period=input$sel_period,
          timestamp=.stamp(), dis_label=.DISEASE_REF[[input$sel_disease]]$label)
        
        ss(sprintf("%d critical | %d moderate | %d void%s",
                   n_crit, n_mod, n_voids, if(n_voids==1)""else"s"),
           if(n_crit>0)"error" else if(n_mod>0)"working" else "success")
        unlock(4,"complete")
        
        if (!is.null(void_res)) {
          vs <- void_res$voids
          leafletProxy("map_main") %>%
            clearGroup("Voids") %>% clearGroup("Rings") %>%
            addPolygons(data=vs, color="#f87171", weight=1.8,
                        fillColor="#f87171", fillOpacity=0.18, group="Voids",
                        popup=~paste0(
                          "<div style='font-family:monospace;background:#0b1220;color:#c8d8e8;",
                          "padding:10px;border-radius:5px;min-width:200px;font-size:11px;'>",
                          "<b style='color:#f87171;'>◉ VOID #",void_id,"</b><br>",
                          "Admin units: <b>",admin_units,"</b><br>",
                          "Mean O/E: <b>",mean_oe,"</b><br>",
                          "Deficit: <b>",total_deficit," cases</b><br>",
                          "Population: <b>",formatC(total_pop,format="d",big.mark=","),"</b>",
                          "</div>"))
          for (i in seq_len(nrow(vs))) {
            if (!is.na(vs$ring_radius_km[i])) {
              ctr <- sf::st_sfc(sf::st_point(c(vs$ring_lon[i],vs$ring_lat[i])),crs=4326)
              ep2 <- .utm_epsg(vs$ring_lon[i],vs$ring_lat[i])
              ring_sf <- sf::st_transform(
                sf::st_buffer(sf::st_transform(ctr,ep2), vs$ring_radius_km[i]*1000), 4326)
              leafletProxy("map_main") %>%
                addPolylines(data=ring_sf, color="#f87171", weight=1.5, opacity=0.6,
                             dashArray="5,4", group="Rings",
                             popup=sprintf("Response perimeter — r = %s km", vs$ring_radius_km[i]))
            }
          }
        }
        session$sendCustomMessage("goto_alerts", list())
      })
    }, error=function(e) ss(paste("Error:", conditionMessage(e)),"error"))
  })
  
  # ── TEMPORAL ANALYSIS (Stochastic vs Structural) ── NEW v2.1 ──────────
  
  # Button to add demo multi-period history
  output$temporal_run_ui <- renderUI({
    n_hist <- length(v$history)
    tagList(
      if (n_hist > 0)
        div(style="font-size:9px;color:var(--green);margin-bottom:5px;display:flex;align-items:center;gap:5px;padding:4px 6px;background:rgba(74,222,128,.07);border-radius:4px;",
            tags$i(class="fas fa-circle-check"),
            sprintf("%d + 1 periods ready for temporal analysis", n_hist)),
      div(style="margin-bottom:6px;",
          tags$button(
            class="btn-run",
            style="width:100%;font-size:11px;",
            onclick="Shiny.setInputValue('run_temporal_auto',Math.random(),{priority:'event'})",
            tags$i(class="fas fa-wave-square"),
            if (n_hist == 0) " Run Temporal Analysis"
            else " Run Temporal Analysis"
          )
      ),
      if (n_hist == 0)
        div(style="font-size:8px;color:var(--muted);margin-bottom:5px;line-height:1.5;",
            tags$i(class="fas fa-info-circle",style="margin-right:3px;color:var(--amber);"),
            "No history? Demo 6-period data loads automatically."),
      tags$details(
        tags$summary(style="font-size:8.5px;color:var(--muted);cursor:pointer;margin-bottom:4px;",
                     tags$i(class="fas fa-chevron-right",style="font-size:7px;margin-right:3px;"),
                     "Upload your own historical CSVs"),
        div(style="padding-top:6px;",
            tags$label(class="upload-btn",
                       style="border-color:var(--edge);font-size:9px;",
                       tags$i(class="fas fa-clock-rotate-left"),
                       tags$span(id="hist-lbl","Add historical period CSV…"),
                       tags$input(type="file",id="hist_upload",accept=".csv",style="display:none;",
                                  onchange=paste0(
                                    "var f=this.files[0];if(f){",
                                    "document.getElementById('hist-lbl').textContent=f.name;",
                                    "var r=new FileReader();r.onload=function(e){",
                                    "Shiny.setInputValue('hist_data',{name:f.name,content:e.target.result},",
                                    "{priority:'event'});};r.readAsText(f);}"
                                  ))
            )
        )
      )
    )
  })
  
  # helper: load 6-period demo data into v$df and v$history
  .load_demo <- function(dis, per) {
    hist      <- .build_demo_temporal(dis, 6)
    v$df      <- .enrich(hist[[1]], dis, per)
    v$history <- lapply(hist[-1], function(h) .enrich(h, dis, per))
    unlock(3,"complete"); unlock(4,"unlocked"); v$stage <- 4L
    .paint_completeness(v$df)
    sm(crit=sum(v$df$completeness=="Critical",na.rm=TRUE),
       mod =sum(v$df$completeness=="Moderate",na.rm=TRUE), voids="—")
  }
  
  # One-click temporal: auto-loads demo if no history, then classifies
  observeEvent(input$run_temporal_auto, {
    dis <- if(!is.null(input$sel_disease)) input$sel_disease else "malaria"
    per <- if(!is.null(input$sel_period))  input$sel_period  else "monthly"
    if (length(v$history) == 0) {
      ss("Loading demo data…","working")
      .load_demo(dis, per)
    }
    all_dfs <- Filter(Negate(is.null), c(list(v$df), v$history))
    if (length(all_dfs) < 2) { ss("Need ≥2 periods","error"); return() }
    ss("Running temporal classification…","working")
    tryCatch({
      withProgress(message="Temporal Analysis",value=0,{
        threshold <- .DISEASE_REF[[dis]]$critical
        all_units <- unique(unlist(lapply(all_dfs, function(d) d$admin_unit)))
        results   <- lapply(seq_along(all_units), function(ui) {
          au   <- all_units[ui]
          oe_v <- sapply(all_dfs, function(d) {
            r <- d$oe_ratio[d$admin_unit == au]
            if(length(r)==0||all(is.na(r))) NA_real_ else r[1]
          })
          incProgress(0.9/length(all_units))
          c(list(admin_unit=au, oe_series=oe_v),
            .classify_void_temporality(oe_v, threshold))
        })
        incProgress(1)
        v$temporal <- list(results=results, n_periods=length(all_dfs),
                           disease=dis, threshold=threshold, timestamp=.stamp())
        n_s <- sum(sapply(results, function(r) r$label=="STRUCTURAL"))
        n_r <- sum(sapply(results, function(r) r$label=="STOCHASTIC"))
        ss(sprintf("Temporal: %d structural | %d stochastic | %d intermittent",
                   n_s, n_r,
                   sum(sapply(results, function(r) r$label=="INTERMITTENT"))), "success")
        session$sendCustomMessage("goto_temporal", list())
      })
    }, error=function(e) ss(paste("Temporal error:", conditionMessage(e)),"error"))
  })
  
  # Legacy observer (kept for back-compat)
  observeEvent(input$load_temporal_demo, {
    dis <- if(!is.null(input$sel_disease)) input$sel_disease else "malaria"
    per <- if(!is.null(input$sel_period))  input$sel_period  else "monthly"
    .load_demo(dis, per)
    ss(sprintf("Demo loaded — %s", .DISEASE_REF[[dis]]$label),"ready")
  })
  
  # Historical period upload
  observeEvent(input$hist_data, {
    req(input$hist_data)
    df <- .parse_csv(input$hist_data$content)
    if (!is.null(df)) {
      dis <- if(!is.null(input$sel_disease)) input$sel_disease else "malaria"
      per <- if(!is.null(input$sel_period))  input$sel_period  else "monthly"
      df  <- .enrich(df, dis, per)
      df$period_label <- input$hist_data$name
      v$history <- c(v$history, list(df))
      ss(sprintf("Period %d added: %d units", length(v$history), nrow(df)),"ready")
    }
  })
  
  # Run temporal classifier
  observeEvent(input$run_temporal, {
    all_dfs <- c(list(v$df), v$history)
    all_dfs <- Filter(Negate(is.null), all_dfs)
    if (length(all_dfs) < 2) {
      ss("Need ≥2 periods for temporal analysis","error"); return()
    }
    ss("Running stochastic vs structural classification…","working")
    tryCatch({
      withProgress(message="Temporal Analysis",value=0,{
        incProgress(.1)
        dis       <- if(!is.null(input$sel_disease)) input$sel_disease else "malaria"
        threshold <- .DISEASE_REF[[dis]]$critical
        # Collect all admin units across all periods
        all_units <- unique(unlist(lapply(all_dfs, function(d) d$admin_unit)))
        n_units   <- length(all_units)
        results   <- lapply(seq_along(all_units), function(ui) {
          au   <- all_units[ui]
          oe_v <- sapply(all_dfs, function(d) {
            r <- d$oe_ratio[d$admin_unit == au]
            if(length(r)==0||all(is.na(r))) NA_real_ else r[1]
          })
          incProgress(0.8/n_units)
          c(list(admin_unit=au, oe_series=oe_v),
            .classify_void_temporality(oe_v, threshold))
        })
        incProgress(1)
        v$temporal <- list(
          results   = results,
          n_periods = length(all_dfs),
          disease   = dis,
          threshold = threshold,
          timestamp = .stamp()
        )
        n_struct <- sum(sapply(results, function(r) r$label=="STRUCTURAL"))
        n_stoch  <- sum(sapply(results, function(r) r$label=="STOCHASTIC"))
        ss(sprintf("Temporal: %d structural | %d stochastic | %d intermittent",
                   n_struct, n_stoch,
                   sum(sapply(results, function(r) r$label=="INTERMITTENT"))), "success")
        session$sendCustomMessage("goto_temporal", list())
      })
    }, error=function(e) ss(paste("Temporal error:", conditionMessage(e)),"error"))
  })
  
  # ── TEMPORAL UI ────────────────────────────────────────────────────────
  output$temporal_ui <- renderUI({
    tmp <- v$temporal
    if (is.null(tmp)) {
      return(div(
        style="margin:60px auto;text-align:center;max-width:380px;",
        div(style="font-size:36px;margin-bottom:12px;color:var(--edge2);","〰"),
        div(style="font-family:var(--sans);font-size:14px;color:var(--text);",
            "No temporal data"),
        div(style="font-size:11px;color:var(--muted);margin-top:6px;",
            "Load a multi-period demo or upload historical period CSVs,",
            " then click 'Run Stochastic/Structural Analysis'")
      ))
    }
    
    results   <- tmp$results
    dis_label <- .DISEASE_REF[[tmp$disease]]$label
    
    # Summary KPIs
    n_struct  <- sum(sapply(results, function(r) r$label=="STRUCTURAL"))
    n_interm  <- sum(sapply(results, function(r) r$label=="INTERMITTENT"))
    n_stoch   <- sum(sapply(results, function(r) r$label=="STOCHASTIC"))
    n_single  <- sum(sapply(results, function(r) r$label=="SINGLE_PERIOD"))
    
    # Sort: structural first, then intermittent, then stochastic
    label_ord <- c(STRUCTURAL=1,INTERMITTENT=2,STOCHASTIC=3,
                   SINGLE_PERIOD=4,INSUFFICIENT_DATA=5)
    results_sorted <- results[order(sapply(results, function(r)
      label_ord[r$label] %||% 5))]
    
    div(
      # Header
      div(class="rb",
          div(class="rb-title",
              tags$i(class="fas fa-wave-square"),
              sprintf("Temporal Void Classification — %s (%d periods)",
                      dis_label, tmp$n_periods)),
          div(style="display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-bottom:8px;",
              div(class="met r",
                  div(class="mel","Structural"),
                  div(class="mev",n_struct)),
              div(class="met a",
                  div(class="mel","Intermittent"),
                  div(class="mev",n_interm)),
              div(class="met c",
                  div(class="mel","Stochastic"),
                  div(class="mev",n_stoch)),
              div(class="met",
                  div(class="mel","Total units"),
                  div(class="mev",length(results)))
          ),
          div(style="font-size:9.5px;color:var(--muted);margin-bottom:6px;",
              tags$strong(style="color:var(--red);","STRUCTURAL "),
              "— persistent geographic/system barrier. Requires intervention, not just monitoring. | ",
              tags$strong(style="color:var(--amber);","INTERMITTENT "),
              "— recurring but not constant; seasonal or staffing-driven. | ",
              tags$strong(style="color:var(--cyan);","STOCHASTIC "),
              "— random fluctuation; no structural barrier evident."),
          div(style="font-size:9px;color:var(--muted);",
              "Method: Fano factor (primary) + 2-state HMM Viterbi path (confidence). ",
              "Generated: ", tmp$timestamp)
      ),
      
      # Per-unit temporal cards
      div(class="rb",
          div(class="rb-title",
              tags$i(class="fas fa-list-check"),
              "Admin Unit Classification"),
          tagList(lapply(results_sorted, function(r) {
            if (r$label %in% c("SINGLE_PERIOD","INSUFFICIENT_DATA")) return(NULL)
            lbl_cls <- switch(r$label,
                              STRUCTURAL   = "void-structural",
                              INTERMITTENT = "void-intermittent",
                              STOCHASTIC   = "void-stochastic",
                              "void-single")
            p_struct <- if(!is.na(r$p_structural)) r$p_structural else 0
            p_stoch  <- if(!is.na(r$p_stochastic)) r$p_stochastic else 0
            # Sparkline cells for period-by-period state
            spark_cells <- if (!is.null(r$state_seq) && length(r$state_seq)>0) {
              tagList(lapply(r$state_seq, function(s) {
                col <- if(s==0)"#f87171" else "#4ade80"
                ht  <- if(s==0) 80 else 30
                div(class="spark-cell",
                    div(class="spark-bar",
                        style=sprintf("height:%d%%;background:%s;",ht,col)))
              }))
            } else NULL
            
            div(style=paste0(
              "background:var(--ink);border:1px solid var(--edge);",
              "border-left:3px solid ",
              switch(r$label,STRUCTURAL="var(--red)",INTERMITTENT="var(--amber)","var(--cyan)"),
              ";border-radius:var(--r);padding:9px;margin-bottom:6px;"),
              div(style="display:flex;align-items:center;gap:7px;margin-bottom:6px;flex-wrap:wrap;",
                  span(style="font-family:var(--sans);font-size:11px;font-weight:600;color:var(--text);",
                       r$admin_unit),
                  span(class=paste("tag", r$badge_class), r$label),
                  if (!is.na(r$n_critical))
                    span(style="font-size:9px;color:var(--muted);",
                         sprintf("%d/%d periods critical", r$n_critical, r$n_total))
              ),
              # HMM probability bar
              div(style="margin-bottom:5px;",
                  div(style="font-size:8.5px;color:var(--muted);margin-bottom:2px;",
                      sprintf("HMM structural probability: %.0f%% | Fano factor: %s | CV: %s",
                              p_struct*100,
                              if(!is.na(r$fano)) sprintf("%.2f",r$fano) else "—",
                              if(!is.na(r$cv))   sprintf("%.2f",r$cv)   else "—")),
                  div(class="hmm-bar",
                      div(class=paste("hmm-fill",
                                      if(r$label=="STRUCTURAL")"structural" else "stochastic"),
                          style=sprintf("width:%.0f%%",p_struct*100))
                  )
              ),
              # Period sparkline
              if (!is.null(spark_cells)) {
                div(
                  div(style="font-size:8.5px;color:var(--muted);margin-bottom:3px;",
                      "Period-by-period state (red=silent, green=reporting):"),
                  div(class="period-sparkline", spark_cells),
                  if (!is.null(r$oe_series)) {
                    div(style="font-size:8px;color:var(--muted);margin-top:2px;",
                        paste("O/E:", paste(sprintf("%.2f",
                                                    r$oe_series[!is.na(r$oe_series)]), collapse=" · ")))
                  }
                )
              },
              # Interpretation
              div(style="font-size:10px;color:var(--mid);line-height:1.65;margin-top:5px;",
                  r$interpretation)
            )
          }))
      ),
      
      # Summary table
      div(class="rb",
          div(class="rb-title",
              tags$i(class="fas fa-table"),
              "Classification Summary Table"),
          div(style="overflow-x:auto;",
              tags$table(class="vt",
                         tags$thead(tags$tr(
                           tags$th("Admin Unit"),
                           tags$th("Classification"),
                           tags$th("p_struct"),
                           tags$th("Fano"),
                           tags$th("CV"),
                           tags$th("Critical / Total"))),
                         tags$tbody(lapply(results_sorted, function(r) {
                           if (r$label=="INSUFFICIENT_DATA") return(NULL)
                           badge_fn <- switch(r$label,
                                              STRUCTURAL   = function(x) tags$span(class="tag tr2", x),
                                              INTERMITTENT = function(x) tags$span(class="tag ta", x),
                                              STOCHASTIC   = function(x) tags$span(class="tag tc", x),
                                              function(x) tags$span(class="tag tm", x))
                           tags$tr(
                             tags$td(r$admin_unit),
                             tags$td(badge_fn(r$label)),
                             tags$td(if(!is.na(r$p_structural)) sprintf("%.2f",r$p_structural) else "—"),
                             tags$td(if(!is.na(r$fano)) sprintf("%.2f",r$fano) else "—"),
                             tags$td(if(!is.na(r$cv)) sprintf("%.2f",r$cv) else "—"),
                             tags$td(if(!is.na(r$n_critical))
                               sprintf("%d / %d", r$n_critical, r$n_total) else "—")
                           )
                         }))
              )
          )
      ),
      
      # Watermark
      div(class="wm-footer",
          div(style="display:flex;justify-content:space-between;flex-wrap:wrap;gap:5px;",
              div(tags$strong(style="color:var(--text);",WM_AUTHOR), "  ·  ", WM_TOOL),
              div("doi: ", tags$a(href=WM_URL,target="_blank",WM_DOI))
          ),
          div(style="margin-top:3px;color:var(--muted);",
              "Temporal analysis — ", tmp$timestamp)
      )
    )
  })
  
  # ── Validation section ─────────────────────────────────────────────────
  output$validation_section_ui <- renderUI({
    if (is.null(v$df)) return(NULL)
    div(class="sc",
        div(class="sch", onclick="tC(this)",
            div(class="sct", tags$i(class="fas fa-vials"), "Validation"),
            tags$i(class="fas fa-chevron-down scv")),
        div(class="scb", style="display:none;",
            div(style=paste0("border:1px solid var(--cyan);border-radius:var(--r);",
                             "padding:9px;background:var(--cyan-d);"),
                div(style="font-size:10px;color:var(--cyan);font-weight:600;margin-bottom:5px;",
                    tags$i(class="fas fa-flask-conical",style="margin-right:5px;"),
                    "ALGORITHM SELF-TEST"),
                div(style="font-size:9.5px;color:var(--mid);margin-bottom:7px;line-height:1.6;",
                    "Plants a known silent zone and measures detection accuracy (F1 score)."),
                tags$button(class="btn-sec",
                            style="border-color:var(--cyan);color:var(--cyan);",
                            onclick="Shiny.setInputValue('run_selftest',Math.random())",
                            tags$i(class="fas fa-flask-conical"),"Run Self-Test"),
                uiOutput("selftest_ui")
            )
        )
    )
  })
  
  # ── Self-test ──────────────────────────────────────────────────────────
  observeEvent(input$run_selftest, {
    ss("Self-test running…","working")
    tryCatch({
      withProgress(message="Self-Test",value=0,{
        incProgress(.1)
        set.seed(888)
        df_t        <- .build_demo("malaria","monthly")
        true_units  <- c("Mbita","Suba North","Suba South","Rarieda",
                         "Kuria East","Kuria West","Nyatike")
        df_valid    <- df_t[!is.na(df_t$lat)&!is.na(df_t$long),]
        incProgress(.4)
        res_t <- .dtm_voids(df_valid,m0=0.10,alpha=0.25)
        incProgress(.8)
        detected <- if(!is.null(res_t))
          unique(trimws(unlist(strsplit(
            paste(res_t$voids$admin_units,collapse=", "),", "))))
        else character(0)
        detected <- detected[detected!=""]
        tp  <- sum(true_units %in% detected)
        fp  <- sum(!detected %in% true_units)
        fn  <- sum(!true_units %in% detected)
        pre <- if(tp+fp>0) round(tp/(tp+fp),3) else 0
        rec <- if(tp+fn>0) round(tp/(tp+fn),3) else 0
        f1  <- if(pre+rec>0) round(2*pre*rec/(pre+rec),3) else 0
        g   <- if(f1>=.80)"Excellent" else if(f1>=.60)"Good" else
          if(f1>=.40)"Fair" else "Poor"
        incProgress(1)
        v$selftest <- list(tp=tp,fp=fp,fn=fn,precision=pre,
                           recall=rec,f1=f1,grade=g,
                           true_units=true_units,detected_units=detected)
        ss(sprintf("Self-test: F1=%.3f (%s) — %d/%d true voids found",
                   f1,g,tp,length(true_units)),
           if(f1>=.60)"success" else "error")
      })
    },error=function(e) ss(paste("Self-test error:",conditionMessage(e)),"error"))
  })
  
  output$selftest_ui <- renderUI({
    st <- v$selftest; if(is.null(st)) return(NULL)
    gc <- if(st$grade=="Excellent")"tg" else if(st$grade=="Good")"tc" else
      if(st$grade=="Fair")"ta" else "tr2"
    div(style="margin-top:8px;background:var(--paper);border:1px solid var(--edge);
               border-radius:var(--r);padding:8px;",
        div(style="display:flex;align-items:center;gap:8px;margin-bottom:6px;",
            span(class=paste("tag",gc), st$grade),
            span(style="font-size:12px;color:var(--text);font-weight:600;",
                 sprintf("F1 = %.3f", st$f1))),
        div(style="display:grid;grid-template-columns:repeat(3,1fr);gap:4px;",
            div(div(style="font-size:8px;color:var(--muted);","Precision"),
                div(style="font-size:12px;", sprintf("%.3f",st$precision))),
            div(div(style="font-size:8px;color:var(--muted);","Recall"),
                div(style="font-size:12px;", sprintf("%.3f",st$recall))),
            div(div(style="font-size:8px;color:var(--muted);","TP/(TP+FN)"),
                div(style="font-size:12px;", sprintf("%d/%d",st$tp,st$tp+st$fn)))
        ),
        div(style="font-size:9px;color:var(--muted);margin-top:6px;",
            sprintf("True silent zones: %s", paste(st$true_units, collapse=", ")))
    )
  })
  
  # ── Data status ────────────────────────────────────────────────────────
  output$data_status_ui <- renderUI({
    df  <- v$df; if(is.null(df)) return(NULL)
    dis <- if(!is.null(input$sel_disease)) input$sel_disease else "malaria"
    n_crit <- sum(df$completeness=="Critical",na.rm=TRUE)
    n_mod  <- sum(df$completeness=="Moderate",na.rm=TRUE)
    n_ok   <- sum(df$completeness=="Adequate",na.rm=TRUE)
    n_na   <- sum(is.na(df$lat)|is.na(df$long))
    div(
      div(style="display:flex;flex-wrap:wrap;gap:3px;margin-bottom:4px;",
          span(class="tag tr2", sprintf("Critical: %d",n_crit)),
          span(class="tag ta",  sprintf("Moderate: %d",n_mod)),
          span(class="tag tg",  sprintf("Adequate: %d",n_ok)),
          if(n_na>0) span(class="tag tm", sprintf("No coords: %d",n_na))),
      div(style="font-size:9px;color:var(--muted);",
          sprintf("%d admin units · ref: %s", nrow(df), .DISEASE_REF[[dis]]$label)))
  })
  
  # ── ALERTS UI ────────────────────────────────────────────────────────
  output$alerts_ui <- renderUI({
    res <- v$results
    if (is.null(res)) {
      return(div(
        style="margin:60px auto;text-align:center;max-width:380px;",
        div(style="font-size:36px;margin-bottom:12px;color:var(--edge2);","◎"),
        div(style="font-family:var(--sans);font-size:14px;color:var(--text);",
            "No analysis yet"),
        div(style="font-size:11px;color:var(--muted);margin-top:6px;",
            "Complete steps 1–3, then click Detect Surveillance Gaps")
      ))
    }
    df       <- res$df
    dis      <- .DISEASE_REF[[res$disease]]
    df_sorted <- df[order(df$oe_ratio), ]
    action_units <- df_sorted[!is.na(df_sorted$oe_ratio) &
                                df_sorted$oe_ratio < dis$moderate, ]
    
    # Incorporate temporal labels if available
    temp_map <- NULL
    if (!is.null(v$temporal)) {
      temp_map <- setNames(
        lapply(v$temporal$results, function(r) r$label),
        sapply(v$temporal$results, function(r) r$admin_unit))
    }
    
    alert_cards <- lapply(seq_len(min(nrow(action_units), 15)), function(i) {
      r   <- action_units[i, ]
      cls <- if(r$oe_ratio < dis$critical)"critical"else"moderate"
      col <- if(r$oe_ratio < dis$critical)"var(--red)"else"var(--amber)"
      cause_obj <- .classify_cause(r$road_index, r$facility_count, r$area_km2,
                                   r$admin_unit %in% c("Kuria East","Kuria West","Nyatike","Migori Town"),
                                   r$oe_ratio)
      # Temporal label badge
      temp_badge <- if (!is.null(temp_map) && r$admin_unit %in% names(temp_map)) {
        tl <- temp_map[[r$admin_unit]]
        tc <- switch(tl, STRUCTURAL="tr2", INTERMITTENT="ta", STOCHASTIC="tc", "tm")
        tags$span(class=paste("tag",tc), style="font-size:8px;", tl)
      } else NULL
      
      div(class=paste("alert-card",cls),
          div(class="ac-head",
              tags$i(class=paste("fas",cause_obj$icon), style=paste0("color:",col,";")),
              span(r$admin_unit, style=paste0("color:",col,";")),
              span(style=paste0("background:",col,"1a;color:",col,";border:1px solid ",col,
                                "44;border-radius:3px;padding:1px 6px;font-size:9px;font-family:var(--mono);"),
                   sprintf("O/E = %.2f", r$oe_ratio)),
              span(class=paste0("cause-",cause_obj$cause),
                   style="font-size:9px;", cause_obj$label),
              temp_badge
          ),
          div(class="ac-body",
              sprintf("Expected %s · Reported %s · Deficit %s (%s%%)",
                      formatC(round(r$expected),format="d",big.mark=","),
                      formatC(r$reported_cases, format="d",big.mark=","),
                      formatC(round(r$deficit),  format="d",big.mark=","),
                      round(r$deficit_pct)),
              if(!is.na(r$county)) paste0(" · County: ", r$county)
          ),
          div(class="ac-action",
              tags$i(class="fas fa-arrow-right"),
              tags$strong("Action: "), cause_obj$action
          )
      )
    })
    
    table_rows <- lapply(seq_len(nrow(df_sorted)), function(i) {
      r   <- df_sorted[i, ]
      cls <- tolower(as.character(r$completeness))
      badge_fn <- switch(cls,
                         critical = function(x) tags$span(class="cb-critical",x),
                         moderate = function(x) tags$span(class="cb-moderate",x),
                         mild     = function(x) tags$span(class="cb-mild",x),
                         function(x) tags$span(class="cb-adequate",x))
      temp_lbl <- if(!is.null(temp_map) && r$admin_unit %in% names(temp_map)) {
        tl <- temp_map[[r$admin_unit]]
        tc <- switch(tl,STRUCTURAL="tr2",INTERMITTENT="ta",STOCHASTIC="tc","tm")
        tags$span(class=paste("tag",tc),style="font-size:8px;",tl)
      } else tags$span(style="color:var(--muted);font-size:9px;","—")
      tags$tr(
        class = if(cls=="critical")"crit"else NULL,
        tags$td(r$admin_unit),
        tags$td(if(!is.na(r$county))r$county else "—"),
        tags$td(badge_fn(sprintf("%.2f",r$oe_ratio))),
        tags$td(formatC(round(r$expected),format="d",big.mark=",")),
        tags$td(formatC(r$reported_cases, format="d",big.mark=",")),
        tags$td(style="color:var(--red);",
                formatC(round(r$deficit),format="d",big.mark=",")),
        tags$td(temp_lbl)
      )
    })
    
    div(
      div(class="rb",
          div(class="rb-title",
              tags$i(class="fas fa-satellite-dish"),
              sprintf("Completeness — %s (%s)", res$dis_label, res$period)),
          div(style="display:grid;grid-template-columns:repeat(4,1fr);gap:5px;margin-bottom:8px;",
              div(class="met r", div(class="mel","Critical"), div(class="mev",res$n_crit)),
              div(class="met a", div(class="mel","Moderate"), div(class="mev",res$n_mod)),
              div(class="met",   div(class="mel","Total"),    div(class="mev",nrow(df))),
              div(class="met c", div(class="mel","Voids"),    div(class="mev",res$n_voids))),
          div(style="font-size:9.5px;color:var(--muted);",
              sprintf("Reference: %s · Run: %s", dis$source, res$timestamp))
      ),
      
      if (length(action_units) > 0)
        div(class="rb",
            div(class="rb-title",
                tags$i(class="fas fa-triangle-exclamation",style="color:var(--red);"),
                sprintf("%d Unit%s Requiring Attention",
                        nrow(action_units), if(nrow(action_units)>1)"s"else"")),
            tagList(alert_cards)
        ),
      
      if (!is.null(res$void_res)) {
        vs <- res$void_res$voids
        div(class="rb",
            div(class="rb-title",
                tags$i(class="fas fa-draw-polygon"),
                sprintf("%d Spatial Void%s",nrow(vs),if(nrow(vs)>1)"s"else"")),
            div(style="overflow-x:auto;",
                tags$table(class="vt",
                           tags$thead(tags$tr(
                             tags$th("Void"),tags$th("Admin Units"),tags$th("Mean O/E"),
                             tags$th("Deficit"),tags$th("Population"),tags$th("Ring r"))),
                           tags$tbody(lapply(seq_len(nrow(vs)), function(i) {
                             r   <- vs[i,]
                             tags$tr(
                               tags$td(paste0("#",r$void_id)),
                               tags$td(style="max-width:140px;word-wrap:break-word;",r$admin_units),
                               tags$td(style="color:var(--red);",sprintf("%.2f",r$mean_oe)),
                               tags$td(formatC(r$total_deficit,format="d",big.mark=",")),
                               tags$td(formatC(r$total_pop,format="d",big.mark=",")),
                               tags$td(ifelse(is.na(r$ring_radius_km),"—",
                                              paste0(r$ring_radius_km," km")))
                             )
                           }))
                )
            ),
            if (!is.null(res$stability))
              div(style="margin-top:8px;font-size:10px;color:var(--muted);",
                  tags$i(class="fas fa-layer-group",style="margin-right:5px;"),
                  sprintf("Stability: %s [%s voids across m₀ sensitivity range]",
                          if(res$stability$stable)"stable"else"variable",
                          paste(res$stability$counts,collapse=" / ")))
        )
      },
      
      div(class="rb",
          div(class="rb-title",
              tags$i(class="fas fa-table"),"Full Completeness Table"),
          div(style="overflow-x:auto;",
              tags$table(class="vt",
                         tags$thead(tags$tr(
                           tags$th("Admin Unit"),tags$th("County"),
                           tags$th("O/E"),tags$th("Expected"),
                           tags$th("Reported"),tags$th("Deficit"),tags$th("Temporal"))),
                         tags$tbody(table_rows)))
      ),
      
      div(class="wm-footer",
          div(style="display:flex;justify-content:space-between;flex-wrap:wrap;gap:5px;",
              div(tags$strong(style="color:var(--text);",WM_AUTHOR),"  ·  ",WM_TOOL),
              div("doi: ",tags$a(href=WM_URL,target="_blank",WM_DOI))),
          div(style="margin-top:3px;color:var(--muted);",
              "Generated: ",res$timestamp,"  ·  All outputs watermarked.")
      )
    )
  })
  
  # ── EXPORTS ─────────────────────────────────────────────────────────────
  output$dl_report <- downloadHandler(
    filename = function() paste0("alert_brief_",format(Sys.time(),"%Y%m%d_%H%M%S"),".html"),
    content  = function(file) {
      res <- v$results
      ts  <- if(!is.null(res)) res$timestamp else .stamp()
      df  <- if(!is.null(res)) res$df else data.frame()
      dis <- if(!is.null(res)) .DISEASE_REF[[res$disease]] else .DISEASE_REF[["malaria"]]
      df_sorted     <- if(nrow(df)>0) df[order(df$oe_ratio),] else df
      critical_rows <- if(nrow(df)>0)
        df_sorted[!is.na(df_sorted$oe_ratio)&df_sorted$oe_ratio<dis$critical,]
      else data.frame()
      html <- paste0(
        "<!DOCTYPE html><html><head><meta charset='UTF-8'>",
        "<title>",WM_TOOL," — Alert Brief</title>",
        "<style>body{font-family:monospace;background:#06080e;color:#c8d8e8;",
        "padding:28px;max-width:900px;margin:0 auto;line-height:1.6}",
        "h1{color:#f59e0b}h2{color:#5a7fa0;border-bottom:1px solid #172437;",
        "padding-bottom:4px}",
        ".wm{background:#0f1a2a;border-left:4px solid #f59e0b;",
        "border-radius:4px;padding:12px 16px;margin-bottom:20px}",
        ".wm strong{color:#c8d8e8}.wm a{color:#f59e0b}",
        "table{border-collapse:collapse;width:100%}",
        "th{font-size:9px;color:#3a5570;padding:6px;border-bottom:1px solid #172437;text-align:left}",
        "td{font-size:10.5px;padding:6px;border-bottom:1px solid #172437;color:#5a7fa0}",
        ".crit td{background:#f8717108}</style></head><body>",
        "<h1>Surveillance Alert Brief</h1>",
        "<p style='color:#3a5570;font-size:11px;'>",WM_TOOL,"  ·  ",ts,"</p>",
        "<div class='wm'><strong>",WM_TOOL,"</strong><br>",
        "Author: <strong>",WM_AUTHOR,"</strong><br>",
        "DOI: <a href='",WM_URL,"'>",WM_DOI,"</a><br>",
        "Citation: ",WM_CITATION,"</div>",
        if(!is.null(res)) paste0(
          "<h2>Summary</h2>",
          "<p>Disease: <strong>",res$dis_label,"</strong>  ·  ",
          "Admin units: <strong>",nrow(df),"</strong>  ·  ",
          "Critical: <strong>",res$n_crit,"</strong>  ·  ",
          "Voids: <strong>",res$n_voids,"</strong></p>",
          "<h2>Completeness Table</h2>",
          "<table><tr><th>Admin Unit</th><th>County</th>",
          "<th>O/E</th><th>Expected</th><th>Reported</th><th>Deficit</th></tr>",
          paste(sapply(seq_len(nrow(df_sorted)), function(i) {
            r  <- df_sorted[i,]
            cl <- if(!is.na(r$oe_ratio)&&r$oe_ratio<dis$critical)"crit"else""
            paste0("<tr class='",cl,"'><td>",r$admin_unit,"</td><td>",
                   ifelse(is.na(r$county),"—",r$county),"</td><td>",
                   sprintf("%.3f",r$oe_ratio),"</td><td>",round(r$expected),"</td><td>",
                   r$reported_cases,"</td><td>",round(r$deficit),"</td></tr>")
          }),collapse=""),
          "</table>") else "<p>No results.</p>",
        "<div style='margin-top:20px;font-size:10px;color:#3a5570;",
        "border-top:2px solid #f59e0b;padding-top:8px;'>",
        WM_AUTHOR,"  ·  ",WM_TOOL,"  ·  ",ts,"</div>",
        "</body></html>")
      writeLines(html, file)
    })
  
  output$dl_geojson <- downloadHandler(
    filename = function() paste0("voids_",format(Sys.time(),"%Y%m%d_%H%M%S"),".geojson"),
    content  = function(file) {
      req(v$results$void_res)
      vs <- v$results$void_res$voids
      vs$author <- WM_AUTHOR; vs$doi <- WM_DOI
      vs$tool   <- WM_TOOL;   vs$generated <- v$results$timestamp
      vs$disease <- v$results$dis_label
      vs2 <- vs[, !sapply(vs, is.list), drop=FALSE]
      sf::st_write(vs2, file, driver="GeoJSON", quiet=TRUE)
    })
  
  output$dl_table <- downloadHandler(
    filename = function() paste0("completeness_",format(Sys.time(),"%Y%m%d_%H%M%S"),".csv"),
    content  = function(file) {
      req(v$results)
      df  <- v$results$df
      # Merge temporal labels if available
      if (!is.null(v$temporal)) {
        tlabels <- setNames(
          sapply(v$temporal$results, function(r) r$label),
          sapply(v$temporal$results, function(r) r$admin_unit))
        df$temporal_class <- tlabels[df$admin_unit]
      }
      con <- file(file, "w")
      writeLines(c(
        paste0("# ",WM_TOOL),
        paste0("# Author: ",WM_AUTHOR),
        paste0("# DOI: ",WM_DOI),
        paste0("# Generated: ",v$results$timestamp),
        paste0("# Disease: ",v$results$dis_label),
        paste0("# Citation: ",WM_CITATION),
        "#"), con); close(con)
      cols <- intersect(c("period","admin_unit","county","population",
                          "reported_cases","expected","oe_ratio","deficit","deficit_rate",
                          "completeness","temporal_class","lat","long"), names(df))
      write.csv(df[, cols], file, row.names=FALSE, append=TRUE)
    })
  
  # Temporal classification HTML report (open in browser -> File -> Print -> Save as PDF)
  output$dl_temporal <- downloadHandler(
    filename = function()
      paste0("temporal_voids_", format(Sys.time(),"%Y%m%d_%H%M%S"), ".html"),
    content = function(file) {
      req(v$temporal)
      res       <- v$temporal$results
      dis_label <- if (!is.null(v$results)) v$results$dis_label else "Unknown"
      rows <- paste(sapply(res, function(r) {
        col <- switch(r$label,
                      STRUCTURAL   = "#f87171",
                      INTERMITTENT = "#f59e0b",
                      STOCHASTIC   = "#22d3ee", "#5a7fa0")
        paste0("<tr>",
               "<td>",r$admin_unit,"</td>",
               "<td style=\"color:",col,";font-weight:700\">",r$label,"</td>",
               "<td>",round(r$p_structural,3),"</td>",
               "<td>",round(r$fano,3),"</td>",
               "<td>",r$n_critical," / ",r$n_periods,"</td>",
               "<td>",round(r$mean_oe,3),"</td></tr>")
      }), collapse="")
      html <- paste0(
        "<!DOCTYPE html><html lang='en'>",
        "<head><meta charset='UTF-8'>",
        "<meta name='viewport' content='width=device-width,initial-scale=1'>",
        "<title>Temporal Void Report</title>",
        "<style>",
        "body{margin:0;padding:32px 40px;background:#06080e;color:#c8d8e8;",
        "font-family:'Courier New',monospace}",
        "h1{font-size:20px;color:#f59e0b;margin:0 0 4px}",
        "h2{font-size:12px;color:#5a7fa0;font-weight:400;margin:0 0 20px}",
        ".intro{font-size:11px;color:#5a7fa0;line-height:1.8;padding:12px 16px;",
        "background:#0f1a2a;border-left:3px solid #f59e0b;",
        "border-radius:4px;margin-bottom:22px}",
        "table{border-collapse:collapse;width:100%;font-size:11px}",
        "th{padding:8px 10px;text-align:left;color:#3a5570;font-size:9px;",
        "text-transform:uppercase;letter-spacing:.5px;",
        "border-bottom:2px solid #1e3050;background:#0f1a2a}",
        "td{padding:7px 10px;border-bottom:1px solid #172437;color:#5a7fa0}",
        "tr:nth-child(even){background:#0a1018}",
        ".foot{margin-top:24px;font-size:9px;color:#3a5570;",
        "border-top:1px solid #172437;padding-top:10px;line-height:1.7}",
        "@media print{body{background:#fff;color:#000;padding:20px}",
        "h1{color:#b45309} h2{color:#555}",
        "th{background:#f3f4f6;color:#374151;border-color:#d1d5db}",
        "td{color:#374151;border-color:#e5e7eb}",
        "tr:nth-child(even){background:#f9fafb}",
        ".intro{background:#fffbeb;border-color:#f59e0b;color:#374151}",
        ".foot{color:#6b7280;border-color:#d1d5db}}",
        "</style></head><body>",
        "<h1>Temporal Void Classification Report</h1>",
        "<h2>Disease: ",dis_label,
        " | Generated: ",format(Sys.time(),"%d %B %Y %H:%M"),
        " | ",WM_TOOL,"</h2>",
        "<div class='intro'>",
        "<strong>Purpose:</strong> Each admin unit classified by how its silence ",
        "behaves over time. ",
        "<strong style='color:#dc2626'>STRUCTURAL</strong> (p&ge;0.60) = persistent ",
        "barrier needing field action. ",
        "<strong style='color:#d97706'>INTERMITTENT</strong> (0.35&ndash;0.60) = ",
        "partial or seasonal suppression. ",
        "<strong style='color:#0891b2'>STOCHASTIC</strong> (p&lt;0.35) = random noise.",
        "<br><strong>To save as PDF:</strong> File &rarr; Print &rarr; Save as PDF.",
        "</div>",
        "<table><thead><tr>",
        "<th>Admin Unit</th><th>Classification</th>",
        "<th>P(Structural)</th><th>Fano</th>",
        "<th>Critical/Periods</th><th>Mean O/E</th>",
        "</tr></thead><tbody>",rows,"</tbody></table>",
        "<div class='foot'>",WM_TOOL,
        " | Author: ",WM_AUTHOR,
        " | DOI: ",WM_DOI,
        "<br>Citation: ",WM_CITATION,
        "</div></body></html>"
      )
      writeLines(html, file, useBytes=FALSE)
    }
  )
  
  outputOptions(output, "alerts_ui",    suspendWhenHidden=FALSE)
  outputOptions(output, "temporal_ui",  suspendWhenHidden=FALSE)
  outputOptions(output, "temporal_run_ui", suspendWhenHidden=FALSE)
}

# Null coalescing operator (base R ≥ 4.4 has this but for safety)
`%||%` <- function(a, b) if (!is.null(a)) a else b

shinyApp(ui, server)