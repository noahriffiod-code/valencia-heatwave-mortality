# Parameters and file paths for the mortality analysis. Sourced by the
# scripts in scripts/. Paths are relative to the repository root.

data_path   <- function(...) file.path("data", ...)
output_path <- function(f) file.path("output", f)
dir.create("output", showWarnings = FALSE)

params <- list()

# ---------------------------------------------------------------------------
# 1. Exposure-response functions (Masselot et al. 2023)
# ---------------------------------------------------------------------------
# Files of Zenodo doi:10.5281/zenodo.10288665 (v2.0.0, CC BY 4.0), unchanged:
# coefs.csv, vcov.csv, tmean_distribution.csv, metadata.csv. era5_ES003C.csv
# is the ES003C subset of era5series.csv (additional_data.zip, same record).
# Valencia is the Urban Audit city ES003C.
params$city <- "ES003C"

# Model specification, from 00_Packages_Parameters.R of
# github.com/PierreMasselot/Paper--2023--LancetPH--EUcityTRM
params$varper    <- c(10, 75, 90)     # knots of the quadratic B-spline (percentiles)
params$maxlag    <- 21                # lag 0-21, cumulative effect
params$mmprange  <- c(25, 99)         # MMT searched between P25 and P99
params$agebreaks <- c(20, 45, 65, 75, 85)
params$agelabs   <- c("20-44", "45-64", "65-74", "75-84", "85+")

# ---------------------------------------------------------------------------
# 2. Temperature
# ---------------------------------------------------------------------------
# Daily mean temperature, ERA5-Land (Munoz-Sabater et al. 2021) through the
# Open-Meteo archive API, calibrated on the ES003C series of Masselot et al.
# by scripts/01_prepare_temperature.R.
params$file_temp_raw  <- data_path("era5land_openmeteo_raw.csv")
params$file_temp      <- data_path("era5land_valencia_calibrated.csv")
params$temp_start     <- as.Date("1990-01-01")
params$temp_end       <- as.Date("2026-09-30")

# Reference temperature for the "excess over normal" indicator: mean of
# 2016-2025 within +/- 7 days of the same calendar day (our choice).
params$normal_years  <- 2016:2025
params$normal_window <- 15

# ---------------------------------------------------------------------------
# 3. Heatwaves and attributable warming
# ---------------------------------------------------------------------------
# Official 2026 heatwaves for mainland Spain and the Balearic Islands (AEMET,
# note of 9 September 2026). Wave 4 (2-7 September) is provisional in that
# note and is excluded, as in the other sections of the paper.
params$waves <- read.csv(data_path("heatwaves_aemet_2026.csv"))
params$waves <- params$waves[params$waves$status != "provisional", ]
params$waves$start <- as.Date(params$waves$start)
params$waves$end   <- as.Date(params$waves$end)

# Attributable warming of mean daily temperature by month, Barnes et al.
# (2026), city ES003C, row "Unweighted" of the synthesis:
# delta = beta x W_2026. Available for June, July and August only.
params$delta <- read.csv(data_path("delta_barnes_2026_valencia.csv"))

# ---------------------------------------------------------------------------
# 4. Deaths and population
# ---------------------------------------------------------------------------
# Daily deaths by age group, province of Valencia, MoMo (Instituto de Salud
# Carlos III). MoMo groups ages 15-44; the 20-44 share is applied in
# scripts/02_mortality.R.
params$files_momo <- c("20-44" = "momo_valencia_province_15-44.csv",
                       "45-64" = "momo_valencia_province_45-64.csv",
                       "65-74" = "momo_valencia_province_65-74.csv",
                       "75-84" = "momo_valencia_province_75-84.csv",
                       "85+"   = "momo_valencia_province_85plus.csv")

# Population of the city on 1 January 2026, provisional municipal register
# (Ajuntament de Valencia, 9 May 2026), and of the province on 1 April 2026
# (INE, Estadistica Continua de Poblacion)
params$pop_city     <- 858178
params$pop_province <- 2815786

# ---------------------------------------------------------------------------
# 5. Uncertainty
# ---------------------------------------------------------------------------
params$nsim <- 1000
params$seed <- 2026

# ---------------------------------------------------------------------------
# 6. Monetary values (EUR)
# ---------------------------------------------------------------------------
# Value of a statistical life for Spain: Direccion General de Trafico and
# Universidad de Murcia, report dated 2023 (published March 2024); the price
# year is not stated, taken as 2023.
params$vsl_spain <- 1.9e6
# Risk-context factor of 1.8 (Dekker et al. 2011), sensitivity only.
params$vsl_factor <- 1.8
# European VSL and VOLY used by Huang et al. (2023), 2021 euros; the VOLY
# comes from Desaigues et al. (2011), range 29,000-116,000.
params$vsl_europe <- 3.91e6
params$voly       <- 46000
params$voly_high  <- 116000
