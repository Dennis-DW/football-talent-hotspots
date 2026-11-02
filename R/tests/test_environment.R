# Environment checks for Step 1.
# Usage (inside the app container):  Rscript R/tests/test_environment.R

library(testthat)

test_that("core R packages load", {
  pkgs <- c("sf", "terra", "spatstat", "spdep", "spatialreg", "MASS",
            "DBI", "RPostgres", "arrow", "engsoccerdata", "shiny", "leaflet")
  for (p in pkgs) expect_true(requireNamespace(p, quietly = TRUE), info = p)
})

test_that("lm.RStests exists in the installed spdep", {
  expect_true("lm.RStests" %in% getNamespaceExports("spdep"))
})

test_that("points round-trip EPSG:4326 -> 27700 -> 4326 within 1 m", {
  # Wembley, Old Trafford, St James' Park, Home Park (Plymouth), Carrow Road (Norwich)
  pts <- sf::st_sfc(
    sf::st_point(c(-0.2795, 51.5560)),
    sf::st_point(c(-2.2913, 53.4631)),
    sf::st_point(c(-1.6217, 54.9756)),
    sf::st_point(c(-4.1508, 50.3881)),
    sf::st_point(c( 1.3091, 52.6221)),
    crs = 4326
  )
  back <- sf::st_transform(sf::st_transform(pts, 27700), 4326)
  err_m <- as.numeric(sf::st_distance(pts, back, by_element = TRUE))
  expect_true(all(err_m < 1), info = paste(round(err_m, 4), collapse = ", "))
})

test_that("British National Grid distances are sensible", {
  # Wembley to Old Trafford is roughly 260 km in a straight line
  pts <- sf::st_sfc(sf::st_point(c(-0.2795, 51.5560)),
                    sf::st_point(c(-2.2913, 53.4631)), crs = 4326)
  d_bng <- as.numeric(sf::st_distance(sf::st_transform(pts, 27700))[1, 2]) / 1000
  d_geo <- as.numeric(sf::st_distance(pts)[1, 2]) / 1000
  expect_gt(d_bng, 240); expect_lt(d_bng, 280)
  expect_lt(abs(d_bng - d_geo), 1)  # BNG and geodesic agree to within 1 km
})

test_that("PostGIS answers from R", {
  con <- DBI::dbConnect(
    RPostgres::Postgres(),
    host = Sys.getenv("POSTGRES_HOST", "db"),
    port = as.integer(Sys.getenv("POSTGRES_PORT", "5432")),
    dbname = Sys.getenv("POSTGRES_DB"),
    user = Sys.getenv("POSTGRES_USER"),
    password = Sys.getenv("POSTGRES_PASSWORD")
  )
  on.exit(DBI::dbDisconnect(con))
  v <- DBI::dbGetQuery(con, "SELECT PostGIS_Version() AS v")$v
  expect_match(v, "^3\\.")
  expect_true("talent" %in% DBI::dbGetQuery(con, "SELECT schema_name FROM information_schema.schemata")$schema_name)
})
