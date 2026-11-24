# Heat-related mortality during the 2026 heatwaves in Valencia attributable to climate change

Code and data for the mortality section of *Attributing the economic cost of the summer 2026 heat waves in València to climate change*, N. Riffiod, A.G. Fernández-Garza, D. Ávila-Velásquez, E. Gielen and M. Pulido-Velazquez (2026).

The analysis estimates, for the city of Valencia (858,178 inhabitants, ages
20 and over), the deaths attributable to heat during the three official AEMET
heatwaves of summer 2026 (20-27 June, 2-24 July, 28 July-20 August),
the part of these deaths attributable to climate change, and their cost.

- **Exposure-response functions**: Masselot et al. (2023), city ES003C, five
  age groups, cumulative effect over lags 0-21 days.
- **Attributable deaths**: `attrdl()` of Gasparrini and Leone (2014). With
  the reduced (cumulative) coefficients published by Masselot et al., the
  function only allows the forward perspective: the heat of day *t* is
  attributed a share of the deaths of days *t* to *t*+21,
  AN<sub>t</sub> = (1 - 1/RR(T<sub>t</sub>)) x mean(D<sub>t</sub>, ..., D<sub>t+21</sub>),
  with RR centred on the minimum mortality temperature (MMT) and set to 1
  below it.
- **Climate change**: heat deaths in the factual world minus heat deaths in
  a world where daily mean temperature is lowered by the attributable
  warming of Barnes et al. (2026) for the month, with the same deaths in both
  worlds (Vicedo-Cabrera et al. 2021; Barnes et al. 2026).
- **Deaths**: (A) constant daily deaths by age from the Eurostat rates in
  the Masselot et al. files, as in Barnes et al. (2026); (B) observed daily
  deaths of the province from MoMo, scaled to the city by population.
- **Cost**: value of a statistical life for Spain and for Europe, and value
  of a life year applied to years of life lost.

## Main results (method B, ages 20+, deaths)

| Wave | Dates | Heat-related [95% CI] | Attributable to climate change [95% CI] |
|---|---|---:|---:|
| 1 | 20-27 Jun | 12.6 [10.6-14.6] | 10.7 [7.8-12.7] |
| 2 | 2-24 Jul | 69.5 [60.8-77.3] | 48.0 [31.1-60.3] |
| 3 | 28 Jul-20 Aug | 76.8 [67.4-85.1] | 52.1 [35.8-64.2] |
| Total | | 158.8 [139.3-176.5] | 110.8 [75.3-136.8] |

Climate change: 1,230 years of life lost; 210.6 million EUR
[143.0-259.8] with the Spanish VSL. Method A: 124.9 deaths [84.3-154.2],
237.3 million EUR. These are the values of the paper (Tables 5, 6 and 12,
Figures 1 and 2). Full tables are written to `output/`.

## Running the code

Requirements: R and the packages `dlnm` and `MASS`. The results above were
obtained with R 4.4.3, dlnm 2.4.10 and MASS 7.3-66. The 95% intervals come
from 1,000 random draws (`set.seed(2026)`); another version of R or of its
linear algebra library can change them in the last decimal. Open `valencia_heatwave_mortality.Rproj` (or set the working
directory to the repository root) and run

```r
source("run_all.R")
```

`scripts/00_delta_barnes.R` computes the attributable warming from the
files of Barnes et al. (2026), which the four repositories share;
`scripts/check_beta_barnes.R` (not run by `run_all.R`, about 105 MB
downloaded from Zenodo) recomputes these beta with the regression, bootstrap
and synthesis code of the authors and checks that they equal the published
values; `scripts/01_prepare_temperature.R` builds the temperature series;
`scripts/02_mortality.R` computes deaths and costs and draws Figures 1
and 2 of the paper (about 1 minute with 1,000 draws). Nothing is downloaded unless
`data/era5land_openmeteo_raw.csv` is deleted, in which case the series is
retrieved again from Open-Meteo (requires `jsonlite`).

## Repository structure

```
run_all.R                          runs scripts 00 to 02
R/parameters.R                     parameters, file paths and sources
R/attrdl.R                         Gasparrini and Leone (2014), unmodified
R/fhempel_main.R                   Hempel et al. (2013) calibration, by A. Gasparrini, unmodified
scripts/00_delta_barnes.R          attributable warming (delta) from the files of Barnes et al.
scripts/check_beta_barnes.R        check: recomputes the beta of Valencia with the code of Barnes et al.
scripts/01_prepare_temperature.R   ERA5-Land series on the scale of the curves
scripts/02_mortality.R             attributable deaths, climate change, costs, Figures 1-2
data/                              inputs (see below)
output/                            results (created by the scripts)
```

## Data

| File | Content | Source |
|---|---|---|
| `masselot2023/coefs.csv`, `vcov.csv`, `tmean_distribution.csv`, `metadata.csv` | Spline coefficients and covariance by city and age, temperature percentiles 1990-2019, city metadata (population structure, death rates, life expectancy) | Masselot and Gasparrini (2023), Zenodo [doi:10.5281/zenodo.10288665](https://doi.org/10.5281/zenodo.10288665), v2.0.0, unchanged (MD5 identical to the record) |
| `masselot2023/era5_ES003C.csv` | Daily mean temperature 1990-2019, ERA5-Land aggregated over ES003C | Rows `URAU_CODE == "ES003C"` of `era5series.csv` in `additional_data.zip`, same record |
| `era5land_openmeteo_raw.csv` | Daily mean temperature 1990-2026, ERA5-Land at the coordinates of ES003C in `metadata.csv`, local time | Open-Meteo archive API (Zippenfenig 2023), `models=era5_land`, `timezone=Europe/Madrid`, retrieved 9 November 2026 |
| `era5land_valencia_calibrated.csv` | Same, calibrated on `era5_ES003C.csv` | `scripts/01_prepare_temperature.R` |
| `momo/momo_valencia_province_*.csv` | Daily deaths, province of Valencia, by age group, to 30 September 2026 (only observed deaths are used; the files are kept as downloaded) | MoMo, Instituto de Salud Carlos III ([momo.isciii.es](https://momo.isciii.es/panel_momo/)), daily data from 1 June 2015 to 30 September 2026; methodology in León-Gómez et al. (2022) |
| `heatwaves_aemet_2026.csv` | Dates of the 2026 heatwaves | AEMET, note of 9 September 2026, [link](https://www.aemet.es/es/noticias/2026/09/olas_de_calor_2026) |
| `delta_barnes_2026_valencia.csv` | Attributable warming of mean temperature by month, 95% interval | Computed by `scripts/00_delta_barnes.R` from the two files below: city ES003C, row "Unweighted"; delta = beta x W<sub>2026</sub>, W<sub>2026</sub> = G<sub>2026</sub> - (G<sub>2025</sub> - 1.3) = 1.319167 degC |
| `barnes2026/beta-pars_full-synthesis.rds` | Regression coefficients of monthly city temperature on smoothed GMST, 854 cities, June-August, with 95% bounds | Barnes et al. (2026), [doi:10.5281/zenodo.22228326](https://doi.org/10.5281/zenodo.22228326), unmodified (MD5 9095483384dd77b4a7b8275a970623ee) |
| `barnes2026/gmst.txt` | Smoothed GISTEMP global mean surface temperature used by Barnes et al. | Same record, unmodified (MD5 de311aa0427c7073e66a244aecb0980a) |

Population of the city on 1 January 2026 (provisional municipal register,
Ajuntament de València, 9 May 2026) and of the province on 1 April 2026 (INE,
Estadística Continua de Población). Monetary values: see `R/parameters.R` (Abellán Perpiñán et al. 2023;
Dekker et al. 2011; Huang et al. 2023; Desaigues et al. 2011).

### Data sources and licences

- **Masselot and Gasparrini (2023)** and **Barnes et al. (2026)**: CC BY 4.0.
- **ERA5-Land**: Contains modified Copernicus Climate Change Service
  information 2026. Neither the European Commission nor ECMWF is responsible
  for any use that may be made of the Copernicus information or data it
  contains. Weather data by [Open-Meteo.com](https://open-meteo.com/),
  licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
- **MoMo**: Instituto de Salud Carlos III, Centro Nacional de Epidemiología.
  File names changed; content unchanged.
- **AEMET**: © AEMET. Information prepared using, among others, data from
  the Agencia Estatal de Meteorología ([nota legal](https://www.aemet.es/es/nota_legal));
  AEMET does not endorse this work.
- `R/attrdl.R` © Antonio Gasparrini, from
  [github.com/gasparrini/2014_gasparrini_BMCmrm_Rcodedata](https://github.com/gasparrini/2014_gasparrini_BMCmrm_Rcodedata).
  `R/fhempel_main.R` by Antonio Gasparrini, GNU GPL v3, from
  [github.com/anavica/mcc_ccattr_NCC](https://github.com/anavica/mcc_ccattr_NCC).

## Main assumptions

1. **Curves.** Masselot et al. curves for ES003C (Urban Audit city, about
   1.4 million inhabitants in `metadata.csv`), applied to the deaths of the
   municipality: the relative risk is assumed the same in both. The curves
   come from MCC data for Valencia combined with a second-stage model over
   854 cities; no adaptation after the study period is considered.
2. **Temperature scale.** The spline knots (9.30, 22.77, 25.72 degC) and the
   MMT are defined on the ES003C ERA5-Land series. The 2026 series is an
   ERA5-Land extraction from Open-Meteo calibrated month by month on that
   series over 1990-2019 (Hempel et al. 2013, as in Vicedo-Cabrera et al.
   2021). The calibration preserves the trend after 2019.
3. **Forward perspective only.** Imposed by `attrdl()` with reduced
   coefficients; the lag-specific effects are not published.
4. **Deaths.** (A) constant daily deaths: city population times the
   provincial age structure and death rates in `metadata.csv`, divided by
   365.25. (B) MoMo deaths of the province times the city share of the
   population (30.5%), assuming the same day-to-day variation in the city
   and the province. MoMo groups 15-44: the 20-44 share of deaths in that
   group is taken from the same rates. Ages under 20 are not counted, as in
   Masselot et al.
5. **Heat.** Only days above the MMT of each age group count. The MMT is the
   minimum of the curve between the 25th and 99th percentiles (Masselot et
   al.) and is recomputed in each draw (Barnes et al.).
6. **Same deaths in both worlds.** This is the convention of Vicedo-Cabrera
   et al. (2021) and Barnes et al. (2026). Scaling the deaths of the world
   without climate change by RR(T without CC)/RR(T) multiplies the result by
   RR(T without CC); the script reports this sensitivity (+7.5%).
7. **Attributable warming.** One delta per month (June, July, August),
   identical for all days and ages. Uncertainty: normal distribution
   matched to its 95% interval, one draw per simulation common to all months
   and waves. Coefficients are drawn independently by age group from their
   covariance matrices (1,000 draws).
8. **Normal temperature** (Figure 1 only): mean of 2016-2025 within
   +/- 7 days of the same date. It is not used in any result.
9. **Mortality displacement.** Part of it is inside the 21-day window and
   it is not corrected further. Armstrong et al. (2017) find that most
   heat-related deaths in daily time-series analyses are brought forward by
   at least one year. Years of life lost assume the life expectancy of the
   age group and are probably overstated for frail people.
10. **Years of life lost**: remaining life expectancy at the mean age at
    death of each group (Masselot et al. 2023; Huang et al. 2023).
    Monetary values are in euros of different years (Spanish VSL about 2023,
    European values 2021) and are not converted to 2026 euros.
11. **Heatwaves.** Official AEMET waves for mainland Spain and the Balearic
    Islands (at least 10% of reference stations above the 95th percentile of
    July-August Tmax 1971-2000 for at least 3 consecutive days). Wave 4
    (2-7 September) is provisional in the AEMET note and is excluded, as in
    the other sections of the paper. Days between waves are not counted.
12. **Close waves.** Forward windows overlap (wave 1 to 18 July, wave 2 to
    14 August). There is no double counting: each heat day receives
    AF<sub>t</sub>/22 of the deaths of each of the 22 following days, which
    is the calculation of `attrdl()` on the whole series restricted to
    heatwave days.
13. **Months.** Barnes et al. publish the attributable warming for June to
    August, the months of the three waves retained.

## License

Code: MIT (see `LICENSE`), except `R/attrdl.R` and `R/fhempel_main.R`
(see above). Data files remain under the terms of their providers.

## Citation

See `CITATION.cff`.

## References

Abellán Perpiñán, J. M., Martínez Pérez, J. E., Méndez Martínez, I., Pinto
Prades, J. L., Sánchez Martínez, F. I. (2023). *Actualización del valor
monetario de una vida estadística en España*. Universidad de Murcia for the
Dirección General de Tráfico, published 12 March 2024.
https://www.dgt.es/export/sites/web-DGT/.galleries/downloads/conoce_la_dgt/que-hacemos/conocimiento-e-investigacion/Actualizacion-del-valor-monetario-de-una-vida-estadistica-en-Espana.pdf

AEMET (2026). España registra 61 días bajo ola de calor en 2026, más que en
ningún otro año. Agencia Estatal de Meteorología, 9 September 2026.
https://www.aemet.es/es/noticias/2026/09/olas_de_calor_2026

Armstrong, B., Bell, M. L., de Sousa Zanotti Stagliorio Coelho, M., Guo,
Y.-L. L., Guo, Y., Goodman, P., et al. (2017). Longer-term impact of high and low temperature on mortality: an
international study to clarify length of mortality displacement.
*Environmental Health Perspectives*, 125(10), 107009.
https://doi.org/10.1289/EHP1756

Barnes, C., Masselot, P., Xi, D., Clarke, B., Rayner, A., Chen, X., Wang, R.,
Raju, E., Theokritoff, E., Mistry, M., Gasparrini, A., Otto, F.,
Vicedo-Cabrera, A. M., Konstantinoudis, G. (2026). Heat-related urban
mortality attributable to human-induced climate change in Europe from 2000
to 2025. *Nature Health*. https://doi.org/10.1038/s44360-026-00209-8. Data
and code: https://doi.org/10.5281/zenodo.22228326

Dekker, T., Brouwer, R., Hofkes, M., Moeltner, K. (2011). The effect of risk
context on the value of a statistical life: a Bayesian meta-model.
*Environmental and Resource Economics*, 49(4), 597-624.
https://doi.org/10.1007/s10640-011-9456-z

Desaigues, B., Ami, D., Bartczak, A., Braun-Kohlová, M., Chilton, S.,
Czajkowski, M., et al. (2011). Economic valuation of
air pollution mortality: a 9-country contingent valuation survey of value
of a life year (VOLY). *Ecological Indicators*, 11(3), 902-910.
https://doi.org/10.1016/j.ecolind.2010.12.006

Gasparrini, A., Leone, M. (2014). Attributable risk from distributed lag
models. *BMC Medical Research Methodology*, 14, 55.
https://doi.org/10.1186/1471-2288-14-55

Hempel, S., Frieler, K., Warszawski, L., Schewe, J., Piontek, F. (2013). A
trend-preserving bias correction - the ISI-MIP approach. *Earth System
Dynamics*, 4(2), 219-236. https://doi.org/10.5194/esd-4-219-2013

Huang, W. T. K., Masselot, P., Bou-Zeid, E., Fatichi, S., Paschalis, A.,
Sun, T., Gasparrini, A., Manoli, G. (2023). Economic
valuation of temperature-related mortality attributed to urban heat
islands in European cities. *Nature Communications*, 14, 7438.
https://doi.org/10.1038/s41467-023-43135-z

León-Gómez, I., Delgado Sanz, C., Larrauri, A. (2022). Implementación de un
nuevo modelo MoMo, para la estimación de excesos de mortalidad por todas las
causas y atribuibles a temperatura. *Boletín Epidemiológico Semanal*, 30(6),
67-82. http://hdl.handle.net/20.500.12105/15506

Masselot, P., Mistry, M., Vanoli, J., et al. (2023). Excess mortality
attributed to heat and cold: a health impact assessment study in 854 cities
in Europe. *The Lancet Planetary Health*, 7(4), e271-e281.
https://doi.org/10.1016/S2542-5196(23)00023-2. Code:
https://github.com/PierreMasselot/Paper--2023--LancetPH--EUcityTRM

Masselot, P., Gasparrini, A. (2023). Temperature-related mortality
exposure-response functions for 854 cities in Europe (v2.0.0). Zenodo.
https://doi.org/10.5281/zenodo.10288665

Muñoz-Sabater, J., Dutra, E., Agustí-Panareda, A., et al. (2021). ERA5-Land:
a state-of-the-art global reanalysis dataset for land applications. *Earth
System Science Data*, 13(9), 4349-4383. https://doi.org/10.5194/essd-13-4349-2021

Vicedo-Cabrera, A. M., Scovronick, N., Sera, F., et al. (2021). The burden of
heat-related mortality attributable to recent human-induced climate change.
*Nature Climate Change*, 11, 492-500. https://doi.org/10.1038/s41558-021-01058-x.
Code: https://github.com/anavica/mcc_ccattr_NCC

Zippenfenig, P. (2023). Open-Meteo.com Weather API. Zenodo.
https://doi.org/10.5281/zenodo.7970649
