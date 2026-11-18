# Heat-related deaths during the 2026 AEMET heatwaves in the city of Valencia,
# the part attributable to climate change, and its cost.
#
# Exposure-response functions: Masselot et al. (2023), city ES003C, five age
# groups, cumulative effect over lags 0-21. Attributable deaths: attrdl()
# (Gasparrini and Leone 2014) with these reduced coefficients, which implies
# the forward perspective: the heat of day t is attributed the deaths of days
# t to t+21. Climate change: difference between the factual world and a world
# where mean temperature is lowered by the monthly attributable warming of
# Barnes et al. (2026), with the same deaths in both worlds (Vicedo-Cabrera et
# al. 2021, MainAnalysis.R; Barnes et al. 2026).
#
# Two series of baseline deaths:
#   A. constant daily deaths by age (Eurostat rates in metadata.csv), as in
#      Masselot et al. (2023) and Barnes et al. (2026);
#   B. observed daily deaths of the province (MoMo) scaled to the city.
#
# Three indicators:
#   heat     deaths attributable to temperatures above the MMT;
#   normal   heat deaths minus those with the 2016-2025 normal temperature;
#   cc       heat deaths minus those without climate change.
#
# Results are printed and written to output/.

library(dlnm)
library(splines)
library(MASS)
source("R/parameters.R")
source("R/attrdl.R")

agelabs <- params$agelabs
nage    <- length(agelabs)
maxlag  <- params$maxlag

# ---------------------------------------------------------------------------
# 1. Exposure-response functions for ES003C
# ---------------------------------------------------------------------------
read_city <- function(f) {
  d <- read.csv(data_path("masselot2023", f), check.names = FALSE)
  d[d$URAU_CODE == params$city, ]
}
coefs <- read_city("coefs.csv")
vcovs <- read_city("vcov.csv")
meta  <- read_city("metadata.csv")
tdist <- unlist(read_city("tmean_distribution.csv")[-1])
per   <- as.numeric(sub("%", "", names(tdist)))

coef_age <- lapply(agelabs, function(a) unlist(coefs[coefs$agegroup == a, paste0("b", 1:5)]))
# vcov.csv stores the lower triangle by column (v11, v21, ..., v55)
vcov_age <- lapply(agelabs, function(a) {
  v <- matrix(0, 5, 5)
  v[lower.tri(v, diag = TRUE)] <- unlist(vcovs[vcovs$agegroup == a, -(1:2)])
  v + t(v) - diag(diag(v))
})
names(coef_age) <- names(vcov_age) <- agelabs

# Quadratic B-spline with knots at P10, P75, P90 and boundary knots at the
# range of the 1990-2019 series (09_ResultsCityAge.R, daily attributable
# deaths).
knots  <- tdist[match(params$varper, per)]
argvar <- list(fun = "bs", degree = 2, knots = knots, Boundary.knots = range(tdist))

# MMT: minimum of the curve on the percentile grid 0.1-99.9, restricted to
# P25-P99. As in 09_ResultsCityAge.R, the basis of this search is built on
# the grid itself, without imposed boundary knots.
inner    <- per > 0 & per < 100
grid     <- tdist[inner]
in_range <- per[inner] >= params$mmprange[1] & per[inner] <= params$mmprange[2]
b_grid   <- onebasis(grid, fun = "bs", degree = 2, knots = knots)
find_mmt <- function(coef) unname(grid[in_range][which.min((b_grid %*% coef)[in_range])])
mmt <- sapply(coef_age, find_mmt)

# ---------------------------------------------------------------------------
# 2. Temperature in the three worlds
# ---------------------------------------------------------------------------
# Calculation window: first day of the first wave to 21 days after the last
# one, so that every heatwave day has its full forward window of deaths.
waves <- params$waves
wave_id <- paste0("V", waves$wave)

temp <- read.csv(params$file_temp)
temp$date <- as.Date(temp$date)

win <- data.frame(date = seq(min(waves$start), max(waves$end) + maxlag, by = "day"))
win$tmean <- temp$tmean[match(win$date, temp$date)]
if (anyNA(win$tmean)) stop("missing temperature in ", params$file_temp)

win$wave <- NA_character_
for (i in seq_len(nrow(waves)))
  win$wave[win$date >= waves$start[i] & win$date <= waves$end[i]] <- wave_id[i]
hw   <- which(!is.na(win$wave))                 # heatwave days
hw_v <- factor(win$wave[hw], levels = wave_id)

t_obs <- win$tmean

# Without climate change: T - delta of the month. No delta is published for
# September: it is set to 0 there and the climate change result is not
# reported for waves with such days.
k <- match(as.numeric(format(win$date, "%m")), params$delta$month)
has_delta <- !is.na(k)
delta_c  <- ifelse(has_delta, params$delta$delta[k], 0)
delta_sd <- ifelse(has_delta, (params$delta$delta_high[k] - params$delta$delta_low[k]) / (2 * 1.96), 0)
t_nocc   <- t_obs - delta_c
cc_ok    <- tapply(has_delta[hw], hw_v, all)

# Normal: mean of the same calendar window in 2016-2025
doy <- function(d) as.numeric(format(d, "%j"))
ref <- temp[format(temp$date, "%Y") %in% params$normal_years, ]
t_normal <- sapply(win$date, function(d) {
  gap <- abs(doy(ref$date) - doy(d))
  mean(ref$tmean[pmin(gap, 365 - gap) <= (params$normal_window - 1) / 2])
})

# Cross-basis with the specification of Masselot et al. With reduced
# coefficients attrdl() only uses its temperature basis and its lag range.
cb <- suppressWarnings(crossbasis(t_obs, lag = maxlag, argvar = argvar,
                                  arglag = list(fun = "ns", knots = logknots(maxlag, 3))))

# ---------------------------------------------------------------------------
# 3. Deaths
# ---------------------------------------------------------------------------
share_city <- params$pop_city / params$pop_province

# Population shares and death rates by 5-year age band (metadata.csv)
by5 <- function(prefix) {
  v <- grep(paste0("^", prefix, "[0-9]{4}$"), names(meta), value = TRUE)
  data.frame(start = as.numeric(substr(v, nchar(prefix) + 1, nchar(prefix) + 2)), value = unlist(meta[v]))
}
bands <- merge(by5("prop_"), by5("deathrate_"), by = "start", suffixes = c("_prop", "_rate"))
bands$deaths <- bands$value_prop / 100 * bands$value_rate * params$pop_city
age_group <- function(x) cut(x, c(params$agebreaks, 100), right = FALSE, labels = agelabs)

# A. Constant daily deaths by age group
adult <- bands$start >= 20
deaths_base <- tapply(bands$deaths[adult], age_group(bands$start[adult]), sum) / 365.25
deaths_A <- matrix(deaths_base, nrow(win), nage, byrow = TRUE, dimnames = list(NULL, agelabs))

# B. MoMo deaths of the province times the population share of the city.
# MoMo starts its group at 15: the 20-44 share of 15-44 deaths is taken from
# the same rates.
read_momo <- function(f) {
  m <- read.csv(data_path("momo", f), sep = ";")
  data.frame(date = as.Date(m$fecha, "%d/%m/%Y"), observed = m$defunciones_observadas,
             excess = m$exceso_todas_causas, temperature = m$atribuibles_temperatura)
}
momo <- lapply(params$files_momo, read_momo)
share_20_44 <- with(bands, sum(deaths[start >= 20 & start < 45]) / sum(deaths[start >= 15 & start < 45]))
deaths_B <- sapply(agelabs, function(a) momo[[a]]$observed[match(win$date, momo[[a]]$date)] * share_city)
deaths_B[, "20-44"] <- deaths_B[, "20-44"] * share_20_44
if (anyNA(deaths_B)) stop("missing MoMo deaths in the calculation window")

# Years of life lost: remaining life expectancy at the mean age at death of
# each group (Masselot et al. 2023; Huang et al. 2023). 85+: 85 + e(85).
ages <- 20:99
rate_by_age <- bands$value_rate[findInterval(ages, bands$start)]
age_death <- tapply(seq_along(ages), age_group(ages), function(i) weighted.mean(ages[i], rate_by_age[i]))
age_death["85+"] <- 85 + meta$lifexp_85
le_vars <- grep("^lifexp_[0-9]{2}$", names(meta), value = TRUE)
years_left <- approx(as.numeric(sub("lifexp_", "", le_vars)), unlist(meta[le_vars]), xout = age_death, rule = 2)$y
years_left[agelabs == "85+"] <- meta$lifexp_85
names(years_left) <- agelabs

# ---------------------------------------------------------------------------
# 4. Attributable deaths
# ---------------------------------------------------------------------------
# Daily forward attributable deaths on heatwave days, temperatures above the
# MMT only (range); one column per age group.
heat_deaths <- function(t, deaths, coef, mmt)
  sapply(agelabs, function(a) suppressWarnings(
    attrdl(t, cb, deaths[, a], coef = coef[[a]], vcov = vcov_age[[a]], model.link = "log",
           type = "an", dir = "forw", tot = FALSE, cen = mmt[a], range = c(mmt[a], 100))[hw]))

indicators <- function(deaths, coef, mmt, t_cf) {
  heat <- heat_deaths(t_obs, deaths, coef, mmt)
  list(heat   = heat,
       normal = heat - heat_deaths(t_normal, deaths, coef, mmt),
       cc     = heat - heat_deaths(t_cf, deaths, coef, mmt))
}

# Totals by wave, in deaths or in years of life lost. The climate change
# total only covers waves with a delta.
by_wave <- function(res, unit = c("deaths", "yll")) {
  unit <- match.arg(unit)
  w <- if (unit == "yll") years_left else rep(1, nage)
  unlist(lapply(names(res), function(ind) {
    v <- tapply(drop(res[[ind]] %*% w), hw_v, sum)
    if (ind == "cc") v[!cc_ok] <- NA
    setNames(c(v, Total = sum(v, na.rm = TRUE)), paste(ind, c(wave_id, "Total"), sep = "|"))
  }))
}

methods <- list(A = deaths_A, B = deaths_B)
central <- lapply(methods, indicators, coef = coef_age, mmt = mmt, t_cf = t_nocc)

# 95% intervals: in each draw, new coefficients for every age group (hence
# new MMTs, as in Barnes et al. 2026) and a new delta drawn from a normal
# distribution matching its 95% interval, common to all months and waves.
set.seed(params$seed)
draws <- replicate(params$nsim, {
  coef_s <- lapply(agelabs, function(a) mvrnorm(1, coef_age[[a]], vcov_age[[a]]))
  names(coef_s) <- agelabs
  mmt_s  <- sapply(coef_s, find_mmt)
  t_cf_s <- t_obs - (delta_c + rnorm(1) * delta_sd)
  sapply(methods, function(d) by_wave(indicators(d, coef_s, mmt_s, t_cf_s)))
}, simplify = "array")

# ---------------------------------------------------------------------------
# 5. Results
# ---------------------------------------------------------------------------
ind_names <- c(heat = "heat-related deaths", normal = "excess over normal temperature",
               cc = "attributable to climate change")
rows <- c(wave_id, "Total")

results <- do.call(rbind, lapply(names(methods), function(m) {
  est <- by_wave(central[[m]], "deaths")
  yll <- by_wave(central[[m]], "yll")
  ci  <- t(apply(draws[, m, ], 1, quantile, c(0.025, 0.975), na.rm = TRUE))
  ci[is.na(est), ] <- NA
  key <- strsplit(names(est), "|", fixed = TRUE)
  data.frame(method = m, indicator = sapply(key, `[`, 1), wave = sapply(key, `[`, 2),
             deaths = est, low = ci[, 1], high = ci[, 2], yll = yll, row.names = NULL)
}))

r <- results[results$indicator != "heat", ]
costs <- with(r, data.frame(method, indicator, wave,
                            vsl_spain      = deaths * params$vsl_spain,
                            vsl_spain_low  = low * params$vsl_spain,
                            vsl_spain_high = high * params$vsl_spain,
                            vsl_spain_x1.8 = deaths * params$vsl_spain * params$vsl_factor,
                            vsl_europe     = deaths * params$vsl_europe,
                            voly           = yll * params$voly,
                            voly_high      = yll * params$voly_high))
costs[, -(1:3)] <- costs[, -(1:3)] / 1e6

summary_waves <- data.frame(
  wave = wave_id, start = waves$start, end = waves$end, days = as.numeric(table(hw_v)), status = waves$status,
  deaths_until = waves$end + maxlag,
  t_obs    = round(tapply(t_obs[hw], hw_v, mean), 1),
  t_max    = round(tapply(t_obs[hw], hw_v, max), 1),
  t_normal = round(tapply(t_normal[hw], hw_v, mean), 1),
  t_nocc   = ifelse(cc_ok, round(tapply(t_nocc[hw], hw_v, mean), 1), NA),
  delta    = ifelse(cc_ok, round(tapply(delta_c[hw], hw_v, mean), 2), NA), row.names = NULL)

by_age <- rbind(baseline_deaths_per_day_A = deaths_base,
                momo_deaths_per_day_B     = colMeans(deaths_B[hw, ]),
                mmt                       = mmt,
                years_left                = years_left,
                cc_deaths_A = colSums(central$A$cc[hw_v %in% wave_id[cc_ok], ]),
                cc_deaths_B = colSums(central$B$cc[hw_v %in% wave_id[cc_ok], ]))

daily <- data.frame(wave = hw_v, date = win$date[hw], t_obs = round(t_obs[hw], 1),
                    t_normal = round(t_normal[hw], 1),
                    t_nocc = ifelse(has_delta[hw], round(t_nocc[hw], 1), NA),
                    momo_deaths_city = round(rowSums(deaths_B[hw, ]), 1),
                    cc_A = ifelse(has_delta[hw], round(rowSums(central$A$cc), 2), NA),
                    cc_B = ifelse(has_delta[hw], round(rowSums(central$B$cc), 2), NA))

# Sensitivity to the equal-deaths convention: if deaths in the world without
# climate change are scaled by RR(T_nocc) / RR(T), the climate change result
# becomes the convention times RR(T_nocc), day by day and age by age.
rr_nocc <- sapply(agelabs, function(a) {
  b  <- suppressWarnings(do.call(onebasis, c(list(x = pmax(t_nocc[hw], mmt[a])), argvar)))
  b0 <- suppressWarnings(do.call(onebasis, c(list(x = mmt[a]), argvar)))
  exp(drop(sweep(b, 2, drop(b0)) %*% coef_age[[a]]))
})
keep <- hw_v %in% wave_id[cc_ok]
scaling <- t(sapply(names(methods), function(m) {
  conv   <- sum(central[[m]]$cc[keep, ])
  scaled <- sum((central[[m]]$cc * rr_nocc)[keep, ])
  c(convention = conv, scaled = scaled, change_pct = 100 * (scaled / conv - 1))
}))
heat_share <- 100 * sum(central$B$heat) / sum(deaths_B)

write.csv(summary_waves, output_path("waves.csv"), row.names = FALSE)
write.csv(results, output_path("deaths_by_wave.csv"), row.names = FALSE)
write.csv(costs, output_path("costs_by_wave_million_eur.csv"), row.names = FALSE)
write.csv(round(by_age, 3), output_path("by_age.csv"))
write.csv(daily, output_path("daily_heatwave_days.csv"), row.names = FALSE)
write.csv(scaling, output_path("sensitivity_equal_deaths.csv"))

cat("\nCity of Valencia,", params$pop_city, "inhabitants, ages 20+\n\n")
print(summary_waves, row.names = FALSE)
cat("\nDays above the 1990-2019 maximum (", max(tdist), "degC):", sum(t_obs[hw] > max(tdist)), "\n")
cat("MMT by age (degC):", paste(agelabs, round(mmt, 1), collapse = " | "), "\n")
for (m in names(methods)) for (ind in names(ind_names)) {
  cat("\n", m, ": ", ind_names[ind], "\n", sep = "")
  r <- results[results$method == m & results$indicator == ind, c("wave", "deaths", "low", "high", "yll")]
  print(format(r, digits = 1, nsmall = 1), row.names = FALSE)
}
cat("\nCost, million EUR\n")
print(format(costs, digits = 1, nsmall = 1), row.names = FALSE)
cat("\nBy age\n")
print(round(by_age, 2))
cat("\nMoMo, city, all ages\n")
print(format(momo_tab, digits = 1, nsmall = 1), row.names = FALSE)
cat("\nScaled deaths in the world without climate change (waves with a delta)\n")
print(round(scaling, 1))
cat(sprintf("Heat-related deaths, all waves (B): %.1f%% of deaths from %s to %s\n",
            heat_share, format(min(win$date), "%d/%m"), format(max(win$date), "%d/%m")))

# ---------------------------------------------------------------------------
# 6. Figure: exposure-response functions and heatwave temperatures
# ---------------------------------------------------------------------------
xs <- seq(min(tdist), max(tdist), by = 0.1)
rr <- sapply(agelabs, function(a)
  crosspred(do.call(onebasis, c(list(x = xs), argvar)), coef = coef_age[[a]], vcov = vcov_age[[a]],
            model.link = "log", cen = mmt[a], at = xs)$allRRfit)
png(output_path("exposure_response.png"), width = 2000, height = 1400, res = 250)
matplot(xs, rr, type = "l", lty = 1, lwd = 2, col = 1:nage, log = "y",
        xlab = "Daily mean temperature (degC)", ylab = "Relative risk, lag 0-21",
        main = "Valencia (ES003C), Masselot et al. 2023")
abline(h = 1, lty = 3)
abline(v = mmt, col = 1:nage, lty = 2)
legend("topleft", agelabs, col = 1:nage, lwd = 2, bty = "n")
rug(t_obs[hw], col = "firebrick", lwd = 2)
rug(t_nocc[hw][has_delta[hw]], col = "steelblue", lwd = 2)
invisible(dev.off())
