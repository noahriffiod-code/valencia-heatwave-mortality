# Daily mean temperature for Valencia, 1990-2026, on the scale of the
# exposure-response functions of Masselot et al. (2023).
#
# The spline knots and the MMT of the curves are expressed in degrees of the
# ERA5-Land series that Masselot et al. aggregated over the ES003C area for
# 1990-2019. That series stops in 2019, so a 2026 series has to come from
# another extraction of ERA5-Land (here the Open-Meteo archive API at the
# coordinates of ES003C in metadata.csv) and be put back on the same scale.
#
# Calibration: ISIMIP method (Hempel et al. 2013), fhempel_main() by A.
# Gasparrini, used for the same purpose by Vicedo-Cabrera et al. (2021,
# github.com/anavica/mcc_ccattr_NCC, MainAnalysis.R). For each calendar month
# an additive term (difference of monthly means) and a multiplicative term
# (ratio of daily variability around the monthly mean) are estimated on the
# common days 1990-2019 and applied to the whole Open-Meteo series. Monthly
# means of each year are only shifted, so the warming after 2019 is kept.
#
# The download is skipped when data/era5land_openmeteo_raw.csv exists.

source("R/parameters.R")
source("R/fhempel_main.R")

masselot <- read.csv(data_path("masselot2023", "era5_ES003C.csv"))
masselot <- data.frame(date = as.Date(masselot$date), tmean = masselot$era5landtmean)

if (!file.exists(params$file_temp_raw)) {
  meta <- read.csv(data_path("masselot2023", "metadata.csv"))
  meta <- meta[meta$URAU_CODE == params$city, ]
  url <- paste0("https://archive-api.open-meteo.com/v1/archive",
                "?latitude=", meta$lat, "&longitude=", meta$lon,
                "&start_date=", params$temp_start, "&end_date=", params$temp_end,
                "&daily=temperature_2m_mean&models=era5_land&timezone=Europe%2FMadrid")
  om <- jsonlite::fromJSON(url)$daily
  write.csv(data.frame(date = om$time, tmean = om$temperature_2m_mean),
            params$file_temp_raw, row.names = FALSE)
}
raw <- read.csv(params$file_temp_raw)
raw <- data.frame(date = as.Date(raw$date), tmean = raw$tmean)

calibrated <- fhempel_main(obs = masselot, mod = raw, output = "series")
correction <- fhempel_main(obs = masselot, mod = raw, output = "correction")[[1]]

out <- data.frame(date = raw$date, tmean_raw = raw$tmean, tmean = round(calibrated$tmean, 2))
write.csv(out, params$file_temp, row.names = FALSE)

# Checks: after calibration the mean difference should be zero and the
# correlation close to one on 1990-2019.
common <- merge(masselot, out, by = "date", suffixes = c("_masselot", ""))
cat("\nCalibration by month (add: degC, mult: ratio of daily variability)\n")
print(round(correction, 2))
cat(sprintf("Common days: %d | mean difference before: %.2f degC, after: %.2f degC | correlation: %.3f\n",
            nrow(common), mean(common$tmean_raw - common$tmean_masselot),
            mean(common$tmean - common$tmean_masselot), cor(common$tmean, common$tmean_masselot)))
