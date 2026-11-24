# Dashboard tests: every output renders for several filter combinations, and the live
# observed/expected calculation matches Step 4 (sum O = sum E; top TTWA = Liverpool).
# Usage (inside the app container, from the repository root): Rscript analysis/tests/test_app.R

suppressMessages({
  library(shiny)
  library(testthat)
})
app_dir <- normalizePath("app")
outs <- c("ov_map", "map", "map_title", "me_kpis", "filter_summary", "area_panel", "rank_table",
          "why_main", "regfx", "scatter", "robust_plot", "model_tbl",
          "region_tbl", "scale_tbl", "rrmap", "lplot", "tests_tbl", "wmap", "wcont", "wtable")

old <- setwd(app_dir)
on.exit(setwd(old))
testServer(shinyAppDir("."), {
  renders <- function() for (o in outs) expect_no_error(output[[o]], message = o)

  test_that("default view renders and matches Step 4", {
    session$setInputs(level = "ttwa", measure = "SR_EB", years = c(1975, 2005), league = "all",
                      evidence = "all", positions = NULL, show_players = FALSE, opacity = 0.8,
                      wmeasure = "per_million", wcohort = "total", wcontinent = "all",
                      rank_filter = "all", rank_region = "all")
    session$elapse(500)  # birth-year slider is debounced
    renders()
    d <- sr()
    expect_equal(nrow(d), 155)
    expect_equal(sum(d$O), 3017)
    expect_equal(sum(d$E), sum(d$O), tolerance = 1e-6)
    expect_equal(d$name[which.max(d$SR_EB)], "Liverpool")
    expect_equal(ranked()$name[1], "Liverpool")
  })

  test_that("selecting an area fills the profile", {
    session$setInputs(map_shape_click = list(id = ranked()$unit[1]))
    expect_equal(selected(), ranked()$unit[1])
    expect_no_error(output$area_panel)
    session$setInputs(rank_filter = "above")
    expect_true(all(ranked_view()$SR_EB > 1))
    session$setInputs(rank_filter = "all", rank_region = "North West")
    expect_true(all(ranked_view()$region == "North West"))
    session$setInputs(rank_region = "all")
  })

  test_that("filtered views render and keep sum O = sum E", {
    session$setInputs(level = "lad21", measure = "gi", league = "pl", years = c(1990, 2005),
                      positions = "Forward", show_players = TRUE)
    session$elapse(500)
    renders()
    d <- sr()
    expect_equal(sum(d$E), sum(d$O), tolerance = 1e-6)
    expect_lt(nrow(sel()), 3017)
    session$setInputs(level = "hex20", measure = "SR", evidence = "certain", wmeasure = "total", wcohort = "1990–2005", wcontinent = "Africa")
    session$elapse(500)
    renders()
    expect_true(all(wtab()$group == "Africa"))
    expect_false("England" %in% wtab()$country)
  })
})
