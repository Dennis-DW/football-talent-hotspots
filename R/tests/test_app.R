# Dashboard tests: every output renders for several filter combinations, and the live
# observed/expected calculation matches Step 4 (sum O = sum E; top TTWA = Liverpool).
# Usage (inside the app container): Rscript R/tests/test_app.R

suppressMessages({
  library(shiny)
  library(testthat)
})
app_dir <- normalizePath("app")  # run from the repository root, like the other scripts
outs <- c("map", "top_units", "pmap", "player_count", "rrmap", "lplot", "ltests", "regions",
          "forest", "regfx", "scatter", "academy", "wmap", "wtable", "gi_note")

old <- setwd(app_dir)
on.exit(setwd(old))
testServer(shinyAppDir("."), {
  renders <- function() for (o in outs) expect_no_error(output[[o]], message = o)

  test_that("default view renders and matches Step 4", {
    session$setInputs(level = "ttwa", measure = "SR_EB", years = c(1975, 2005), premier = FALSE,
                      certain = FALSE, positions = "All", years_p = c(1975, 2005), premier_p = FALSE,
                      wmeasure = "per_million", wcohort = "total")
    renders()
    d <- sr()
    expect_equal(nrow(d), 155)
    expect_equal(sum(d$O), 3017)
    expect_equal(sum(d$E), sum(d$O), tolerance = 1e-6)
    expect_equal(d$name[which.max(d$SR_EB)], "Liverpool")
  })

  test_that("filtered views render and keep sum O = sum E", {
    session$setInputs(level = "lad21", measure = "gi", premier = TRUE, years = c(1990, 2005), positions = "Forward")
    renders()
    d <- sr()
    expect_equal(sum(d$E), sum(d$O), tolerance = 1e-6)
    session$setInputs(level = "hex20", measure = "SR", certain = TRUE, wmeasure = "total", wcohort = "1990–2005")
    renders()
  })
})
