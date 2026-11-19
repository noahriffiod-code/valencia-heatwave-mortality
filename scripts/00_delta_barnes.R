# Warming attributable to climate change in Valencia, summer 2026 (delta).
#
# delta_m = beta_m x W_2026, with
#   beta_m  regression coefficient of the monthly mean temperature of the city
#           on smoothed global mean surface temperature (Barnes et al. 2026,
#           city ES003C, June to August, row "Unweighted" of the synthesis);
#   W_2026  = G_2026 - (G_2025 - 1.3): global warming of 2026 relative to the
#           pre-industrial climate, where G is the smoothed GISTEMP series used
#           by Barnes et al. and 2025 is 1.3 degC above pre-industrial
#           (Barnes et al. 2026, after Thorne et al.).
# The bounds use the lower and upper bounds of beta.
#
# Inputs, unmodified, from Barnes et al. (2026), doi:10.5281/zenodo.22228326:
#   data/barnes2026/beta-pars_full-synthesis.rds
#   data/barnes2026/gmst.txt
# Output: data/delta_barnes_2026_valencia.csv (read by script 02 and by the
# outdoor-work, tourism and electricity repositories).
# Run from the repository root.

beta <- readRDS("data/barnes2026/beta-pars_full-synthesis.rds")["ES003C", , "Unweighted", ]

gmst <- read.table("data/barnes2026/gmst.txt", comment.char = "#", col.names = c("year", "gmst"))
g <- function(y) gmst$gmst[gmst$year == y][1]   # the first rows are annual values
W_2026 <- round(g(2026) - (g(2025) - 1.3), 6)

delta <- data.frame(month = as.integer(rownames(beta)),
                    beta = beta[, "est"], beta_low = beta[, "lower"], beta_high = beta[, "upper"],
                    W_2026 = W_2026,
                    delta = beta[, "est"] * W_2026, delta_low = beta[, "lower"] * W_2026,
                    delta_high = beta[, "upper"] * W_2026,
                    source = "Barnes et al. (2026), Zenodo doi:10.5281/zenodo.22228326, city ES003C, row 'Unweighted'")

cat(sprintf("G_2025 = %.6f, G_2026 = %.6f, W_2026 = %.6f degC\n", g(2025), g(2026), W_2026))
print(delta[, c("month", "beta", "delta", "delta_low", "delta_high")], digits = 4, row.names = FALSE)
write.csv(delta, "data/delta_barnes_2026_valencia.csv", row.names = FALSE)
