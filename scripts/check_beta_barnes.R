# Check: recompute the beta of Valencia with the code of Barnes et al. (2026)
# and compare them with the published values used in scripts/00_delta_barnes.R.
#
# Barnes et al. regress, for each summer month m, the monthly mean temperature
# of the city on smoothed global mean surface temperature G:
#   T(y, m) = alpha_m + beta_m * G_y + e
# on ERA5-Land (1950-2025), E-OBS (1920-2025) and 36 CMIP6 models (each on its
# own smoothed global temperature), with a 1,000-draw bootstrap over whole
# years. The datasets are combined with the synthesis of the rwwa package
# (Otto et al. 2024); the paper uses the unweighted mean of observations and
# models (row "Unweighted").
#
# This script repeats sections of the notebook betas-and-counterfactuals.ipynb
# (Zenodo, doi:10.5281/zenodo.22228326) restricted to Valencia (ES003C), and
# reports the largest difference with the published beta. It is a check only:
# nothing it computes is used by the other scripts.
#
# It downloads about 105 MB from Zenodo into data/barnes2026/ (ignored by git)
# and takes a few minutes. Run from the repository root.

city   <- "ES003C"
months <- c("06", "07", "08")
nboot  <- 1000
folder <- file.path("data", "barnes2026")
url    <- "https://zenodo.org/records/22228327/files/"

# MD5 published on the Zenodo record
zenodo_files <- c(
  "gmst.txt"                     = "de311aa0427c7073e66a244aecb0980a",
  "beta-pars_full-synthesis.rds" = "9095483384dd77b4a7b8275a970623ee",
  "t2m-monthly_era5-land.csv"    = "25a84e82bf89508409facf5b6b1f0acc",
  "t2m-monthly_eobs.csv"         = "58a86a2141ae1111c2d684971a37bdd1",
  "cmip6.zip"                    = "c329a311a0900bc4e65622e9646c4793")

options(timeout = 900)
for (f in names(zenodo_files)) {
  path <- file.path(folder, f)
  if (!file.exists(path)) download.file(paste0(url, f, "?download=1"), path, mode = "wb", quiet = TRUE)
  if (unname(tools::md5sum(path)) != zenodo_files[[f]]) stop(f, ": MD5 differs from Zenodo")
}

gmst <- read.table(file.path(folder, "gmst.txt"), comment.char = "#", col.names = c("year", "gmst"))
published <- readRDS(file.path(folder, "beta-pars_full-synthesis.rds"))[city, , "Unweighted", ]

# ---------------------------------------------------------------------------
# Regression and bootstrap (notebook, restricted to one city). The notebook
# fits all 854 cities in one lm(); with several responses, lm() drops a month
# as soon as one city has a missing value. The same months are set to NA here.
# ---------------------------------------------------------------------------
beta_pars <- function(mdl) {
  co <- coef(mdl)
  co["gmst"] + c("06" = 0, "07" = unname(co["gmst:month07"]), "08" = unname(co["gmst:month08"]))
}

bootstrap_pars <- function(frmla, df, nsamp) {
  t(replicate(nsamp, {
    ysamp <- sample(unique(df$year), replace = TRUE)
    boot_df <- merge(data.frame(year = ysamp), df)
    beta_pars(lm(frmla, data = boot_df))
  }))
}

fit <- function(df) {
  frmla <- T ~ gmst * month
  est <- beta_pars(lm(frmla, data = df))
  set.seed(42)                                   # as in the notebook
  boot <- bootstrap_pars(frmla, df, nboot)
  data.frame(month = months, est = est,
             lower = apply(boot, 2, quantile, 0.025),
             upper = apply(boot, 2, quantile, 0.975))
}

# ---------------------------------------------------------------------------
# Synthesis functions of the rwwa package (C. Barnes,
# github.com/WorldWeatherAttribution/rwwa, R/synthesis.R, CC BY-NC 4.0).
# Calculations unchanged; output simplified.
# ---------------------------------------------------------------------------
getsynmean <- function(data, sig_mod = 0) {
  w = 1/(((data$upper - data$lower)/(2*1.96))^2 + sig_mod^2)
  w1 = sum(w)
  s1 <- sum(w*data$est) / w1
  sig_lower = sqrt(sum(w * (((data$est - data$lower)/1.96)^2 + sig_mod^2)) / w1)
  sig_upper = sqrt(sum(w * (((data$est - data$upper)/1.96)^2 + sig_mod^2)) / w1)
  return(setNames(s1 + c(0, -1.96*sig_lower, +1.96*sig_upper), c("est", "lower", "upper")))
}

getsynchi2 <- function(data, sig_mod = 0) {
  s1 <- getsynmean(data, sig_mod)["est"]
  chi2 <- sum(apply(data[,c("est", "lower", "upper")], 1, function(x) {
    if(x["est"] > s1) {
      (x["est"] - s1)^2 / (((x["est"] - x["lower"])/1.96)^2 + sig_mod^2)
    } else {
      (x["est"] - s1)^2 / (((x["est"] - x["upper"])/1.96)^2 + sig_mod^2)
    }
  }))
  return(chi2)
}

synthesis_abs <- function(obs_in, models_in) {
  nobs = nrow(obs_in)
  obs <- apply(obs_in[,c("est", "lower", "upper"),drop = F], 2, mean)
  if(nobs == 1) { sig_obs = 0 } else {
    s2 = sum((obs_in$est - obs[1])^2)
    sig_obs = sqrt(s2/(nobs-1))
  }
  obs[2] <- obs[1] - sqrt( (obs[1] - obs[2])**2 + (1.96*sig_obs)**2 )
  obs[3] <- obs[1] + sqrt( (obs[1] - obs[3])**2 + (1.96*sig_obs)**2 )

  chi2 <- getsynchi2(models_in, sig_mod = 0)
  mdof <- nrow(models_in)-1
  if ( chi2/mdof > 1 ) {
    sig_mod <- optim(0, function(x) {(getsynchi2(models_in, sig_mod = x) - (nrow(models_in)-1))^2},
                     method = "Brent", lower = 0, upper = 5)$par
  } else {
    sig_mod <- 0
  }
  models <- getsynmean(models_in, sig_mod = sig_mod)

  umean <- (obs["est"] +  models["est"]) / 2
  l_wb <- umean - sqrt(((obs["est"]-obs["lower"])^2 + (models["est"]-models["lower"])^2)/2)
  u_wb <- umean + sqrt(((obs["est"]-obs["upper"])^2 + (models["est"]-models["upper"])^2)/2)
  setNames(c(umean, l_wb, u_wb), c("est", "lower", "upper"))
}

# ---------------------------------------------------------------------------
# Observations (notebook cells 7-8)
# ---------------------------------------------------------------------------
gmst_obs <- gmst
gmst_obs$gmst <- gmst_obs$gmst - gmst_obs$gmst[gmst_obs$year == 2025]   # shift only, beta unchanged

read_obs <- function(file) {
  df <- read.csv(file.path(folder, file), check.names = FALSE)
  names(df)[1] <- "X"
  complete <- complete.cases(df[, -1])
  df <- data.frame(year = substr(df$X, 1, 4), month = as.factor(substr(df$X, 6, 7)),
                   T = ifelse(complete, df[[city]], NA))
  merge(gmst_obs, df)
}
obs_fits <- list("E-Obs"     = fit(read_obs("t2m-monthly_eobs.csv")),
                 "ERA5-Land" = fit(read_obs("t2m-monthly_era5-land.csv")))

# ---------------------------------------------------------------------------
# CMIP6 models (notebook cells 10-11)
# ---------------------------------------------------------------------------
cmip6_dir <- file.path(folder, "cmip6")
if (!dir.exists(cmip6_dir)) unzip(file.path(folder, "cmip6.zip"), exdir = cmip6_dir)
cmip6_files <- list.files(cmip6_dir, pattern = "t2m-monthly_cmip6", full.names = TRUE, recursive = TRUE)

mod_fits <- list()
for (fnm in cmip6_files) {
  model <- gsub(".+cmip6_|.csv", "", basename(fnm))
  lines <- readLines(fnm)
  dates <- gsub('"', "", strsplit(lines[1], ",")[[1]][-1])
  fields <- strsplit(lines[-1], ",")
  cities <- gsub('"', "", sapply(fields, `[`, 1))
  mat <- suppressWarnings(t(sapply(fields, function(x) as.numeric(x[-1]))))
  complete <- colSums(is.na(mat)) == 0
  values <- ifelse(complete, mat[cities == city, ], NA)
  df <- data.frame(year = substr(dates, 1, 4), month = substr(dates, 6, 7), T = values)
  gsat <- read.table(file.path(dirname(fnm), paste0("gsat_", model, ".dat")), col.names = c("year", "gmst"))
  mod_fits[[model]] <- fit(merge(gsat, df))
}
cat(length(mod_fits), "CMIP6 models (36 in the paper)\n")

# ---------------------------------------------------------------------------
# Synthesis by month (notebook cell 15) and comparison
# ---------------------------------------------------------------------------
recomputed <- t(sapply(months, function(m) {
  row <- function(f) f[f$month == m, c("est", "lower", "upper")]
  synthesis_abs(do.call(rbind, lapply(obs_fits, row)), do.call(rbind, lapply(mod_fits, row)))
}))

cat("\nBeta of Valencia, row 'Unweighted' (degC per degC of global warming)\n")
print(cbind(round(recomputed, 4), published = round(published[, "est"], 4)))
gap <- max(abs(recomputed - published))
cat(sprintf("Largest difference with the published values: %.1e %s\n", gap,
            ifelse(gap < 1e-6, "(identical)", "(DIFFERENT: check the downloaded files)")))
