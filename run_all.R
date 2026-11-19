# Reproduces all results of the mortality analysis. Open the .Rproj file (or
# set the working directory to the repository root) and run this file.
# Outputs are written to output/.
#
# Packages: dlnm (>= 2.2.0), MASS; jsonlite only if the ERA5-Land series has
# to be downloaded again.

source("scripts/00_delta_barnes.R")
source("scripts/01_prepare_temperature.R")
source("scripts/02_mortality.R")
