# Figures 1 to 4 of the paper, drawn from the result files of the four
# repositories. Run from the repository root, after scripts 00 to 02.
#
# Figures 1 and 2 use only output/ of this repository.
# Figures 3 and 4 also use the outputs of the three other repositories,
# cloned next to this one and run first:
#   ../valencia-heatwave-tourism/output/tourism_total_by_wave.csv
#   ../valencia-heatwave-outdoor/output/labour_productivity_results.csv
#   ../valencia-heatwave-electricity/output/electricity_by_wave.csv
# If one is missing, Figures 3 and 4 are skipped with a message.
#
# Base R graphics only. PNG, 300 dpi.

source("R/parameters.R")   # monetary values used in the labels of Figure 4
out <- function(f) file.path("output", f)

daily  <- read.csv(out("daily_heatwave_days.csv"))
daily$date <- as.Date(daily$date)
waves  <- read.csv(out("waves.csv"))
waves$start <- as.Date(waves$start); waves$end <- as.Date(waves$end)
by_age <- read.csv(out("by_age.csv"), row.names = 1, check.names = FALSE)
costs  <- read.csv(out("costs_by_wave_million_eur.csv"))
deaths <- read.csv(out("deaths_by_wave.csv"))

ink <- "#222222"; mut <- "#555B66"; gry <- "#8C96A3"; grid_col <- "#E3E7EC"
red <- "#D73027"; blu <- "#4575B4"
col_channel <- c(Mortality = "#A50026", Tourism = "#D73027",
                 "Outdoor work" = "#F46D43", "Residential electricity" = "#FDAE61")

day_label <- function(d) paste(as.integer(format(d, "%d")), month.abb[as.integer(format(d, "%m"))])
wave_dates <- function(i) {
  s <- waves$start[i]; e <- waves$end[i]
  if (format(s, "%m") == format(e, "%m"))
    paste0(as.integer(format(s, "%d")), "-", day_label(e))
  else paste0(day_label(s), "-", day_label(e))
}
open_png <- function(f, w, h) {
  png(out(f), width = w, height = h, units = "in", res = 300, pointsize = 9)
  par(family = "sans", col.axis = mut, col.lab = mut, fg = gry, las = 1, mgp = c(2.4, 0.6, 0), tcl = -0.3)
}
hgrid <- function(at) abline(h = at, col = grid_col, lwd = 0.8)


# Figure 1: daily mean temperature on heatwave days ------------------------
# Observed, normal 2016-2025 (+/- 7 days) and without climate change (T - delta).

open_png("figure1_temperatures.png", 7.4, 3.0)
ndays <- as.numeric(table(factor(daily$wave, levels = waves$wave)))
layout(matrix(c(seq_along(ndays), rep(length(ndays) + 1, length(ndays))), 2, byrow = TRUE),
       widths = pmax(ndays, 12), heights = c(1, 0.14))
ylim <- c(22, 34)
for (i in seq_len(nrow(waves))) {
  d <- daily[daily$wave == waves$wave[i], ]
  par(mar = c(2.6, if (i == 1) 4 else 0.6, 1.8, 0.4))
  plot(d$date, d$t_obs, type = "n", ylim = ylim, axes = FALSE, xlab = "", ylab = "",
       xlim = range(d$date) + c(-0.55, 0.55))
  hgrid(seq(22, 34, 2))
  lines(d$date, d$t_normal, col = gry, lwd = 1.6)
  lines(d$date, d$t_obs, col = ink, lwd = 1.8, type = "o", pch = 16, cex = 0.7)
  lines(d$date, d$t_nocc, col = blu, lwd = 1.8, type = "o", pch = 16, cex = 0.7)
  ticks <- d$date[as.integer(format(d$date, "%d")) %% 5 == 0]
  axis(1, at = d$date, labels = FALSE, tcl = -0.15, col = gry)
  axis(1, at = ticks, labels = day_label(ticks), col = gry, cex.axis = 0.95)
  if (i == 1) {
    axis(2, at = seq(22, 34, 2), col = gry, cex.axis = 0.95)
    mtext("Daily mean temperature (\u00b0C)", side = 2, line = 2.4, col = mut, las = 0)
  }
  mtext(paste("Heat wave", i), side = 3, line = 0.4, adj = 0, font = 2, col = ink)
}
par(mar = c(0, 0, 0, 0)); plot.new()
legend("center", c("Observed", "Normal 2016-2025 (\u00b17 days)", "Without climate change (T \u2212 \u03b4)"),
       col = c(ink, gry, blu), lwd = c(1.8, 1.6, 1.8), pch = c(16, NA, 16), pt.cex = 0.8,
       horiz = TRUE, bty = "n", text.col = ink, seg.len = 2.2)
invisible(dev.off())


# Figure 2: deaths attributable to climate change (method B) ---------------
# (a) per heatwave day, (b) by age group over the three waves.

open_png("figure2_deaths.png", 7.4, 3.0)
layout(matrix(1:2, 1), widths = c(1.55, 1))
par(mar = c(3.2, 4.2, 1.8, 0.8))
span <- seq(min(waves$start), max(waves$end), by = "day")
plot(range(span) + c(-0.6, 0.6), c(0, 4.4), type = "n", axes = FALSE, xlab = "", ylab = "",
     xaxs = "i", yaxs = "i")
for (i in seq_len(nrow(waves))) {
  rect(waves$start[i] - 0.5, 0, waves$end[i] + 0.5, 4.4, col = "#F3F5F8", border = NA)
  text(waves$start[i] + (waves$end[i] - waves$start[i]) / 2, 4.15, paste("Wave", i), col = mut)
}
hgrid(1:4)
rect(daily$date - 0.425, 0, daily$date + 0.425, daily$cc_B, col = red, border = NA)
ticks <- span[as.integer(format(span, "%d")) %% 10 == 0]
axis(1, at = ticks, labels = day_label(ticks), col = gry)
axis(2, at = 0:4, col = gry)
mtext("Deaths attributable to climate change per day", side = 2, line = 2.2, col = mut, las = 0, cex = 0.95)
mtext("a", side = 3, line = 0.4, adj = 0, font = 2, col = ink)

par(mar = c(3.2, 4.2, 1.8, 0.4))
v <- unlist(by_age["cc_deaths_B", ])
ages <- sub("85+", "\u226585", names(v), fixed = TRUE)
b <- barplot(v, names.arg = ages, col = red, border = NA, ylim = c(0, 62), axes = FALSE,
             space = 0.6, col.axis = mut)
hgrid(seq(10, 60, 10))
barplot(v, col = red, border = NA, axes = FALSE, names.arg = FALSE, space = 0.6, add = TRUE)
axis(2, at = seq(0, 60, 10), col = gry)
text(b, v + 2.5, sprintf("%.1f", v), col = ink)
mtext("Age group (years)", side = 1, line = 2.1, col = mut)
mtext("Deaths attributable to climate change", side = 2, line = 2.4, col = mut, las = 0)
mtext("b", side = 3, line = 0.4, adj = 0, font = 2, col = ink)
invisible(dev.off())
cat("Figures 1 and 2 written to output/\n")


# Figures 3 and 4: the four channels ---------------------------------------

f_tour <- "../valencia-heatwave-tourism/output/tourism_total_by_wave.csv"
f_out  <- "../valencia-heatwave-outdoor/output/labour_productivity_results.csv"
f_ele  <- "../valencia-heatwave-electricity/output/electricity_by_wave.csv"
missing <- !file.exists(c(f_tour, f_out, f_ele))
if (any(missing)) {
  cat("Figures 3 and 4 skipped; run the other repositories first. Missing:",
      paste(c(f_tour, f_out, f_ele)[missing], collapse = ", "), "\n")
} else {
  wv <- c("V1", "V2", "V3")
  mort <- costs[costs$method == "B" & costs$indicator == "cc", ]
  tour <- read.csv(f_tour)
  outd <- read.csv(f_out)
  outd <- outd[outd$scenario == "Central", ]
  elec <- read.csv(f_ele)

  # Million EUR attributable to climate change, by wave (rows) and channel
  tab <- cbind(
    Mortality                 = mort$vsl_spain[match(wv, mort$wave)],
    Tourism                   = tour$total[match(1:3, tour$wave)] / 1e6,
    "Outdoor work"            = tapply(outd$climate_meur, outd$period, sum)[paste("Wave", 1:3)],
    "Residential electricity" = elec$cost_eur[match(1:3, elec$wave)] / 1e6)
  rownames(tab) <- wv
  total_wave <- rowSums(tab)
  cat("\nCost attributable to climate change by wave and channel (million EUR)\n")
  print(round(cbind(tab, Total = total_wave), 2))
  cat("Total:", round(sum(tab), 1), "\n")

  # Figure 3: cost by channel and wave
  open_png("figure3_cost_by_wave.png", 6.4, 3.5)
  par(mar = c(4.2, 4.2, 0.8, 0.4))
  ytop <- ceiling(max(tab) * 1.2 / 20) * 20
  b <- barplot(t(tab), beside = TRUE, col = col_channel, border = NA, ylim = c(0, ytop),
               axes = FALSE, names.arg = rep("", 3), space = c(0, 0.9))
  hgrid(seq(20, ytop, 20))
  barplot(t(tab), beside = TRUE, col = col_channel, border = NA, axes = FALSE,
          names.arg = rep("", 3), space = c(0, 0.9), add = TRUE)
  axis(2, at = seq(0, ytop, 20), col = gry)
  lab <- ifelse(t(tab) < 1, sprintf("%.2f", t(tab)), sprintf("%.1f", t(tab)))
  text(b, t(tab) + 1.5, lab, srt = 90, adj = c(0, 0.5), cex = 0.85, col = ink)
  centers <- colMeans(b)
  mtext(paste0("Wave ", 1:3, " \u00b7 ", sapply(1:3, wave_dates)), side = 1, at = centers, line = 0.6, col = mut)
  mtext(sprintf("Total \u20ac%.1f M", total_wave), side = 1, at = centers, line = 1.6, col = mut)
  mtext("Attributable cost (\u20ac million of 2026)", side = 2, line = 2.4, col = mut, las = 0)
  legend("topleft", colnames(tab), fill = col_channel, border = NA, bty = "n", text.col = ink)
  invisible(dev.off())

  # Figure 4: total under four valuations of mortality
  tot <- mort[mort$wave == "Total", ]
  other <- sum(tab[, -1])
  yll <- deaths$yll[deaths$method == "B" & deaths$indicator == "cc" & deaths$wave == "Total"]
  m <- c(tot$voly, tot$vsl_spain, tot$vsl_spain_x1.8, tot$vsl_europe)
  eur_m <- function(x) sprintf("\u20ac%.2f M", x / 1e6)
  labs <- c(sprintf("Value of a life year\n\u20ac%s \u00d7 %s years",
                    format(round(params$voly), big.mark = ","), format(round(yll), big.mark = ",")),
            paste0("Spanish VSL\n", eur_m(params$vsl_spain), " (central)"),
            sprintf("Spanish VSL\n\u00d7 %s", params$vsl_factor),
            paste0("European VSL\n", eur_m(params$vsl_europe)))
  open_png("figure4_valuation.png", 6.4, 3.4)
  par(mar = c(3.6, 4.4, 0.8, 0.4))
  h <- rbind(m, other)
  ytop <- ceiling(max(m + other) * 1.15 / 100) * 100
  b <- barplot(h, col = c(col_channel[1], col_channel[3]), border = NA, ylim = c(0, ytop),
               axes = FALSE, names.arg = rep("", 4), space = 0.8)
  hgrid(seq(100, ytop, 100))
  barplot(h, col = c(col_channel[1], col_channel[3]), border = NA, axes = FALSE,
          names.arg = rep("", 4), space = 0.8, add = TRUE)
  axis(2, at = seq(0, ytop, 100), col = gry)
  text(b, m + other + 14, sprintf("\u20ac%.1f M", m + other), font = 2, col = ink, cex = 1.05)
  mtext(labs, side = 1, at = b, line = 1.6, col = mut, padj = 0)
  mtext("Total attributable cost (\u20ac million of 2026)", side = 2, line = 2.6, col = mut, las = 0)
  legend("topleft", c("Mortality", "Tourism, outdoor work and electricity"),
         fill = c(col_channel[1], col_channel[3]), border = NA, bty = "n", text.col = ink)
  invisible(dev.off())
  cat("Figures 3 and 4 written to output/\n")
}
