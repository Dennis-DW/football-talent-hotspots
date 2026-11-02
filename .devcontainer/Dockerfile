# R 4.5.1 with GDAL, GEOS, PROJ, sf, terra, spdep and friends preinstalled.
# Rocker's versioned images install CRAN packages from a dated Posit Package Manager
# snapshot, so package versions are fixed for a given image tag.
FROM rocker/geospatial:4.5.1

# System tools: PostgreSQL client and Python
RUN apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client python3-venv python3-pip \
 && rm -rf /var/lib/apt/lists/*

# Additional R packages (already-installed ones are skipped)
RUN install2.r --error --skipinstalled -n -1 \
      spatstat spdep spatialreg MASS tidyverse DBI RPostgres arrow \
      testthat shiny leaflet renv remotes here \
 && Rscript -e 'remotes::install_github("jalapic/engsoccerdata@872c5c354161ace8408f3091b758c6af4cccca94", upgrade = "never")' \
 && rm -rf /tmp/downloaded_packages

# Python in an isolated virtual environment
COPY requirements.txt /tmp/requirements.txt
RUN python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir --upgrade pip \
 && /opt/venv/bin/pip install --no-cache-dir -r /tmp/requirements.txt
ENV PATH="/opt/venv/bin:${PATH}"
