# ==============================================================================
# trisk_power_demo.R
# Compatibility wrapper for the shared sector-aware TRISK runner.
#
# Prerequisite:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_prepare_inputs.R
#
# Run from project root:
#   "C:\Program Files\R\R-4.5.2\bin\Rscript.exe" scripts/trisk_power_demo.R
# ==============================================================================

source(file.path(getwd(), "scripts", "trisk_sector_demo.R"), local = FALSE)
