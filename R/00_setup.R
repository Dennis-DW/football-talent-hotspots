# Record the exact versions of the R packages this project uses in renv.lock.
#
# Packages are installed in the Docker image (see .devcontainer/Dockerfile), so this
# script does not install anything: it reads DESCRIPTION and snapshots the versions
# found in the container's library. Outside Docker, run renv::restore() to rebuild
# the same library.
#
# Usage (inside the app container):  Rscript R/00_setup.R

lock <- renv::snapshot(
  project  = ".",
  library  = .libPaths(),
  lockfile = "renv.lock",
  type     = "explicit",
  prompt   = FALSE
)

pkgs <- names(lock$Packages)
cat(sprintf("renv.lock written: %d packages recorded (R %s)\n",
            length(pkgs), lock$R$Version))
key <- c("sf", "terra", "spatstat", "spdep", "spatialreg", "engsoccerdata")
for (p in key) cat(sprintf("  %-14s %s\n", p, lock$Packages[[p]]$Version))
