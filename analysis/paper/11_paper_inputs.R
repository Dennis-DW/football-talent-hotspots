# Generate the inputs of the research paper (paper/) from the cached analysis outputs.
#
#   paper/generated/numbers.tex   every number quoted in the text, as LaTeX macros
#   paper/generated/commit.tex    code version (git commit, with a note if the tree is dirty)
#   paper/generated/tables/*.tex  booktabs tables
#   paper/figures/*.pdf           vector figures
#
# Reads only files in data/processed, data/manual and data/raw (nothing is refitted), so the
# paper always matches the analysis. Do not edit the generated files by hand.
# Usage (inside the app container, from the repository root): Rscript analysis/paper/11_paper_inputs.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(tidyr)
  library(readr)
  library(arrow)
  library(ggplot2)
})
sf_use_s2(FALSE)
PROC <- "data/processed"
OUT_G <- "paper/generated"
OUT_T <- "paper/generated/tables"
OUT_F <- "paper/figures"
dir.create(OUT_T, recursive = TRUE, showWarnings = FALSE)
dir.create(OUT_F, recursive = TRUE, showWarnings = FALSE)
latest <- function(pattern, dir) tail(sort(list.files(dir, pattern, full.names = TRUE)), 1)
rd <- function(f) read_csv(file.path(PROC, f), show_col_types = FALSE)

# --- formatting helpers ---------------------------------------------------------------
num <- function(x, d = 0) {
  s <- formatC(round(x, d), format = "f", digits = d, big.mark = ",")
  gsub(",", "\\\\,", s)                       # thin space as thousands separator
}
pct <- function(x, d = 1) num(100 * x, d)
pv <- function(p) if (p < 0.001) "$<$0.001" else formatC(p, format = "f", digits = if (p < 0.01) 3 else 2)
rrpct <- function(rr) { v <- round((rr - 1) * 100); if (v == 0) "0" else sprintf("%+d", v) }
tex_esc <- function(x) gsub("&", "\\\\&", gsub("%", "\\\\%", gsub("_", "\\\\_", x)))
macros <- character(0)
M <- function(name, value) macros[[name]] <<- sprintf("\\newcommand{\\%s}{%s}", name, value)

write_table <- function(file, header, rows, align, note = NULL) {
  lines <- c(sprintf("\\begin{tabular}{%s}", align), "\\toprule", paste(header, collapse = " & "), "\\\\", "\\midrule")
  for (r in rows) lines <- c(lines, paste0(paste(r, collapse = " & "), " \\\\"))
  lines <- c(lines, "\\bottomrule", "\\end{tabular}")
  writeLines(lines, file.path(OUT_T, file))
}
theme_paper <- function(base = 10) {
  theme_minimal(base_size = base, base_family = "sans") +
    theme(panel.grid.minor = element_blank(), plot.title.position = "plot",
          axis.title = element_text(colour = "grey30"), legend.position = "bottom")
}
OUT_W <- "site/figures"   # PNG copies for the project page (site/)
dir.create(OUT_W, recursive = TRUE, showWarnings = FALSE)
save_fig <- function(p, file, w, h) {
  ggsave(file.path(OUT_F, file), p, width = w, height = h, device = cairo_pdf)
  ggsave(file.path(OUT_W, sub("\\.pdf$", ".png", file)), p, width = w, height = h, dpi = 200, bg = "white")
}
NAVY <- "#1A3A5C"

# ======================================================================================
# 1. Data and study population (Step 2)
# ======================================================================================
tiers <- rd("club_season_tier.csv")
mem <- read_parquet(latest("^wikidata_memberships_.*parquet$", "data/raw"))
raw_players <- read_parquet(latest("^wikidata_players_.*parquet$", "data/raw"))
pe <- read_parquet(file.path(PROC, "players_eligible.parquet"))
excl <- rd("exclusion_log.csv")
pu <- rd("player_units.csv")
val <- read_csv("data/manual/validation_sample_claude.csv", show_col_types = FALSE)

M("nClubsTopTwo", n_distinct(tiers$club_qid[tiers$season >= 1992 & tiers$tier <= 2]))
M("nClubsAll", n_distinct(tiers$club_qid))
M("nSeasonTables", 32)
M("nMemberships", num(nrow(mem)))
M("nFetched", num(n_distinct(raw_players$player_qid)))
yo <- function(x) { v <- suppressWarnings(as.numeric(x)) <= 9; !is.na(v) & v }
M("shareYearOnly", pct(mean(yo(mem$startPrec) | yo(mem$endPrec)), 0))
M("nStudy", num(nrow(pe)))
M("nCertain", num(sum(pe$status == "certain")))
M("nProbable", num(sum(pe$status == "probable")))
M("shareProbable", pct(mean(pe$status == "probable"), 0))
M("nPremier", num(sum(pe$premier_league)))
M("nPremierCertain", num(sum(pe$premier_league_certain)))
M("nAmbiguous", num(sum(pe$season_ambiguous)))
M("nEnglish", num(sum(pe$english_born)))
M("shareEnglish", pct(mean(pe$english_born), 1))
M("nMapped", num(nrow(pu)))
M("nTown", num(sum(pu$fine)))
M("nLondonOnly", num(sum(!pu$fine)))
M("nEngCountryLevel", num(sum(pe$english_born & pe$geo_level == "country")))
M("nEngAdminLevel", num(sum(pe$english_born & pe$geo_level == "admin")))
M("shareCoords", pct(mean(!is.na(pe$lon)), 1))
M("nExclBirth", num(sum(excl$reason == "born outside 1975–2005")))
M("nExclWomen", num(sum(excl$reason == "not male (women's football)")))
M("nExclSex", num(sum(excl$reason == "sex not recorded")))
M("nExclEvidence", num(sum(excl$reason == "no evidence of a tier 1–2 league appearance")))

inc <- val[val$group == "included" & val$check_played_t12 %in% c("yes", "no"), ]
exc <- val[val$group == "excluded" & val$check_played_t12 %in% c("yes", "no"), ]
plv <- val[val$group == "included" & val$check_correct_pl %in% c("yes", "no"), ]
M("valFI", sum(inc$check_played_t12 == "no")); M("valFIn", nrow(inc)); M("valFIpct", pct(mean(inc$check_played_t12 == "no")))
M("valFE", sum(exc$check_played_t12 == "yes")); M("valFEn", nrow(exc)); M("valFEpct", pct(mean(exc$check_played_t12 == "yes")))
M("valPL", sum(plv$check_correct_pl == "no")); M("valPLn", nrow(plv)); M("valPLpct", pct(mean(plv$check_correct_pl == "no")))
M("valUnknown", sum(val$check_played_t12 == "unknown"))

write_table("flow.tex", c("Step", "Players"), list(
  c("Footballers with a membership at one of the clubs, born 1970 or later (Wikidata)", num(n_distinct(raw_players$player_qid))),
  c("\\quad excluded: born outside 1975--2005", num(sum(excl$reason == "born outside 1975–2005"))),
  c("\\quad excluded: not recorded as male", num(sum(excl$reason %in% c("not male (women's football)", "sex not recorded")))),
  c("\\quad excluded: no evidence of a tier 1--2 league appearance", num(sum(excl$reason == "no evidence of a tier 1–2 league appearance"))),
  c("\\textbf{Study players}", sprintf("\\textbf{%s}", num(nrow(pe)))),
  c("\\quad certain / probable appearance evidence", sprintf("%s / %s", num(sum(pe$status == "certain")), num(sum(pe$status == "probable")))),
  c("\\quad with at least one Premier League appearance", num(sum(pe$premier_league))),
  c("\\textbf{Born in England}", sprintf("\\textbf{%s}", num(sum(pe$english_born)))),
  c("\\quad placed on the map (town-level birthplace / ``London'' only)", sprintf("%s (%s / %s)", num(nrow(pu)), num(sum(pu$fine)), num(sum(!pu$fine)))),
  c("\\quad not placeable (birthplace only ``England'' or a county)", num(sum(pe$english_born) - nrow(pu)))
), "lr")

write_table("validation.tex", c("Measure", "Errors", "Checked", "Rate"), list(
  c("False inclusion (included, no tier 1--2 league appearance)", sum(inc$check_played_t12 == "no"), nrow(inc), paste0(pct(mean(inc$check_played_t12 == "no")), "\\%")),
  c("False exclusion (excluded, but played at tier 1--2)", sum(exc$check_played_t12 == "yes"), nrow(exc), paste0(pct(mean(exc$check_played_t12 == "yes")), "\\%")),
  c("Premier League flag wrong", sum(plv$check_correct_pl == "no"), nrow(plv), paste0(pct(mean(plv$check_correct_pl == "no")), "\\%")),
  c("Undecidable (club changed division during the spell, or no article)", sum(val$check_played_t12 == "unknown"), nrow(val), "")
), "lrrr")

# ======================================================================================
# 2. Areas and births (Steps 3–4)
# ======================================================================================
births <- rd("births_lad_year.csv")
lsoa <- rd("lsoa21_england.csv")
covl <- rd("lad21_covariates.csv")
covt <- rd("ttwa_covariates.csv")
cnt_t <- rd("counts_ttwa.csv"); cnt_l <- rd("counts_lad21.csv"); cnt_h <- rd("counts_hex20.csv"); cnt_h10 <- rd("counts_hex10.csv")
bt <- births |> group_by(birth_year) |> summarise(b = sum(births_male))
M("birthsTotal", num(sum(births$births_male) / 1e6, 2))
M("birthsLow", num(min(bt$b))); M("birthsHigh", num(max(bt$b)))
M("birthsLowYear", bt$birth_year[which.min(bt$b)]); M("birthsHighYear", bt$birth_year[which.max(bt$b)])
M("nLAD", nrow(covl)); M("nTTWA", nrow(covt)); M("nLSOA", num(nrow(lsoa)))
M("nHexTwenty", n_distinct(cnt_h$unit)); M("nHexTen", num(n_distinct(cnt_h10$unit)))
mt <- cnt_t |> filter(variant == "main"); ml <- cnt_l |> filter(variant == "main")
mh <- cnt_h |> filter(variant == "main"); mh10 <- cnt_h10 |> filter(variant == "main")
M("medETTWA", num(median(mt$E), 1)); M("medELAD", num(median(ml$E), 1)); M("medEHex", num(median(mh$E), 1))
M("zeroHexTen", pct(mean(mh10$O == 0), 0)); M("smallTTWA", sum(mt$E < 5))
corv <- cor(covt[, c("imd_score", "urban_share", "dist_club_km")])
M("corUrbanDist", num(corv["urban_share", "dist_club_km"], 2))
M("distMedTTWA", num(median(covt$dist_club_km), 1))

# hospital effect example: Oxfordshire
oxf <- ml |> left_join(covl |> select(unit = lad21cd, lad21nm), by = "unit") |>
  filter(lad21nm %in% c("Oxford", "Cherwell", "South Oxfordshire", "Vale of White Horse", "West Oxfordshire"))
M("oxfSR", num(oxf$SR[oxf$lad21nm == "Oxford"], 2))
M("oxfNbLo", num(min(oxf$SR[oxf$lad21nm != "Oxford"]), 2)); M("oxfNbHi", num(max(oxf$SR[oxf$lad21nm != "Oxford"]), 2))
M("oxfAll", num(sum(oxf$O) / sum(oxf$E), 2))
west <- ml |> left_join(covl |> select(unit = lad21cd, lad21nm), by = "unit") |> filter(lad21nm == "Westminster")
M("nLondonPoint", 98)

# ======================================================================================
# 3. RQ1: regions and L-function (Step 5)
# ======================================================================================
reg <- rd("step5_regions.csv")
# poisson.test(x, T = E) gives the CI of the rate ratio O/E directly
reg <- reg |> rowwise() |> mutate(lo = poisson.test(players, E)$conf.int[1], hi = poisson.test(players, E)$conf.int[2]) |> ungroup()
eng_rate <- sum(reg$players) / sum(reg$births) * 1e4
M("engRate", num(eng_rate, 2))
M("londonRate", num(reg$per_10k_births[reg$region == "London"], 2)); M("nwRate", num(reg$per_10k_births[reg$region == "North West"], 2))
M("swRate", num(reg$per_10k_births[reg$region == "South West"], 2)); M("seRate", num(reg$per_10k_births[reg$region == "South East"], 2))
M("regionRatio", num(max(reg$per_10k_births) / min(reg$per_10k_births), 1))
M("nRegionsSig", sum(reg$p_value < 0.05))
write_table("regions.tex", c("Region", "Male births", "Players", "Expected", "Per 10\\,000", "SR (95\\% CI)", "$p$"),
  lapply(seq_len(nrow(reg)), function(i) with(reg[i, ], c(region, num(births), num(players), num(E, 1), num(per_10k_births, 2),
    sprintf("%s (%s--%s)", num(SR, 2), num(lo, 2), num(hi, 2)), pv(p_value)))) |>
    append(list(c("\\textbf{England}", num(sum(reg$births)), num(sum(reg$players)), num(sum(reg$E), 1), num(eng_rate, 2), "1.00", ""))),
  "lrrrrrr")
p_reg <- ggplot(reg, aes(SR, reorder(region, SR))) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.25, orientation = "y", colour = "grey40") +
  geom_point(aes(colour = SR > 1), size = 2.6) +
  scale_colour_manual(values = c(`TRUE` = "#b2182b", `FALSE` = "#2166ac"), guide = "none") +
  labs(x = "Standardised ratio: players / expected from male births (exact 95% CI)", y = NULL) + theme_paper()
save_fig(p_reg, "fig_regions.pdf", 6.2, 3.1)

lt <- rd("step5_tests.csv")
gp <- function(pt, ts, r) lt$p_value[lt$pattern == pt & lt$test == ts & lt$r_range_km == r]
M("lMADall", pv(gp("players", "MAD", "0-60"))); M("lDCLFall", pv(gp("players", "DCLF", "0-60")))
M("lMADfar", pv(gp("players", "MAD", "20-60"))); M("lDCLFfar", pv(gp("players", "DCLF", "20-60")))
M("lNullAll", pv(gp("null (births-only)", "MAD", "0-60"))); M("lNullFar", pv(gp("null (births-only)", "MAD", "20-60")))
env <- rd("step5_linhom_envelope.csv")
M("lExcess", num(median(env$L_obs - env$r_km), 0))
write_table("ltests.tex", c("Pattern", "Test", "Distances (km)", "Simulations", "$p$"),
  lapply(seq_len(nrow(lt)), function(i) with(lt[i, ], c(ifelse(pattern == "players", "Players", "Births-only (null check)"),
                                                     test, gsub("-", "--", r_range_km), nsim, pv(p_value)))), "llrrr")
p_l <- ggplot(env, aes(r_km)) + geom_ribbon(aes(ymin = lo - r_km, ymax = hi - r_km), fill = "grey85") +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey45") +
  geom_line(aes(y = L_obs - r_km), colour = "#b2182b", linewidth = 0.9) +
  geom_vline(xintercept = 20, linetype = 3, colour = "grey50") +
  labs(x = "Distance r (km)", y = expression(L[inhom](r) - r ~ "(km)")) + theme_paper()
save_fig(p_l, "fig_lfunction.pdf", 6, 2.8)

# ======================================================================================
# 4. RQ2: hotspots (Step 6)
# ======================================================================================
gl <- rd("step6_global.csv")
g1 <- gl |> filter(level == "ttwa", weights == "queen")
M("moranTTWA", num(g1$EB_Moran_I, 2)); M("moranTTWAp", pv(g1$p_value))
M("moranTTWAknn", num(gl$EB_Moran_I[gl$level == "ttwa" & gl$weights == "knn6"], 2))
M("moranLADlo", num(min(gl$EB_Moran_I[gl$level == "lad21"]), 2)); M("moranLADhi", num(max(gl$EB_Moran_I[gl$level == "lad21"]), 2))
lvl <- c(ttwa = "TTWA", lad21 = "Local authorities", hex20 = "20 km hexagons")
wts <- c(queen = "shared border", knn6 = "6 nearest", knn4 = "4 nearest", knn8 = "8 nearest")
write_table("moran.tex", c("Areas", "Neighbours", "$n$", "EB Moran's $I$", "$p$", "Hot / cold ($p<0.05$)", "Hot / cold (FDR $q<0.10$)"),
  lapply(seq_len(nrow(gl)), function(i) with(gl[i, ], c(lvl[[level]], wts[[weights]], units, num(EB_Moran_I, 3), pv(p_value),
    sprintf("%d / %d", hot_p05, cold_p05), sprintf("%d / %d", hot_fdr10, cold_fdr10)))), "llrrrrr")
gt <- rd("step6_ttwa_queen.csv")
hot <- gt |> filter(Gi_p < 0.05, Gi_z > 0) |> arrange(desc(Gi_z)); cold <- gt |> filter(Gi_p < 0.05, Gi_z < 0) |> arrange(Gi_z)
M("nHot", nrow(hot)); M("nCold", nrow(cold)); M("nHotNorm", sum(gt$Gi_q_norm < 0.05 & gt$Gi_z > 0))
M("giTopName", hot$name[1]); M("giTopZ", num(hot$Gi_z[1], 2)); M("giTopQ", num(hot$Gi_q[1], 3))
M("liverpoolSR", num(gt$SR_EB[gt$name == "Liverpool"], 2)); M("liverpoolRaw", num(gt$SR[gt$name == "Liverpool"], 2))
M("liverpoolO", gt$O[gt$name == "Liverpool"]); M("liverpoolE", num(gt$E[gt$name == "Liverpool"], 1))
M("ebMin", num(min(gt$SR_EB), 2)); M("ebMax", num(max(gt$SR_EB), 2))
M("hotNormList", tex_esc(paste(gt$name[gt$Gi_q_norm < 0.05 & gt$Gi_z > 0][order(-gt$Gi_z[gt$Gi_q_norm < 0.05 & gt$Gi_z > 0])], collapse = ", ")))
nr <- max(nrow(hot), nrow(cold))
gi_rows <- lapply(seq_len(nr), function(i) c(
  if (i <= nrow(hot)) c(tex_esc(hot$name[i]), num(hot$Gi_z[i], 2), num(hot$Gi_p[i], 4), num(hot$Gi_q[i], 2)) else rep("", 4),
  if (i <= nrow(cold)) c(tex_esc(cold$name[i]), num(cold$Gi_z[i], 2), num(cold$Gi_p[i], 4), num(cold$Gi_q[i], 2)) else rep("", 4)))
write_table("gi.tex", c("Hot cluster", "$z$", "$p$", "$q$", "Cold cluster", "$z$", "$p$", "$q$"), gi_rows, "lrrrlrrr")
ebt <- gt |> arrange(desc(SR_EB)) |> filter(E >= 5)
top_rows <- lapply(1:8, function(i) c(tex_esc(ebt$name[i]), ebt$O[i], num(ebt$E[i], 1), num(ebt$SR_EB[i], 2),
                                       tex_esc(rev(ebt$name)[i]), rev(ebt$O)[i], num(rev(ebt$E)[i], 1), num(rev(ebt$SR_EB)[i], 2)))
write_table("toparea.tex", c("Highest", "$O$", "$E$", "SR$_{EB}$", "Lowest", "$O$", "$E$", "SR$_{EB}$"), top_rows, "lrrrlrrr")

# maps
lad <- read_sf(file.path(PROC, "lad21_england.gpkg")); ttwa <- read_sf(file.path(PROC, "ttwa11_england.gpkg"))
pal_sr <- scale_fill_gradient2(trans = "log2", low = "#2166ac", mid = "#f7f7f7", high = "#b2182b", midpoint = 0,
                               limits = c(0.25, 4), oob = scales::squish, breaks = c(0.25, 0.5, 1, 2, 4),
                               labels = c("0.25", "0.5", "1", "2", "4"), name = "SR")
both <- bind_rows(lad |> left_join(ml, by = c("lad21cd" = "unit")) |> transmute(panel = "(a) Local authorities, raw SR", SR = pmax(SR, 0.25)),
                  ttwa |> left_join(mt, by = c("ttwa_id" = "unit")) |> transmute(panel = "(b) Travel to Work Areas, raw SR", SR = pmax(SR, 0.25)))
p_h <- ggplot(both) + geom_sf(aes(fill = SR), colour = "white", linewidth = 0.04) + pal_sr + facet_wrap(~panel) +
  theme_void(base_size = 9) + theme(legend.position = "right", strip.text = element_text(face = "bold", hjust = 0))
save_fig(p_h, "fig_hospital.pdf", 6.5, 3.6)
tm <- ttwa |> left_join(gt, by = c("ttwa_id" = "unit"))
gi_cols <- c("Hotspot (q<0.10)" = "#b2182b", "Hot, exploratory (p<0.05)" = "#f4a582", "Not significant" = "#f2f2f2",
             "Cold, exploratory (p<0.05)" = "#92c5de", "Coldspot (q<0.10)" = "#2166ac")
p_eb <- ggplot(tm) + geom_sf(aes(fill = SR_EB), colour = "white", linewidth = 0.05) +
  scale_fill_gradient2(trans = "log2", low = "#2166ac", mid = "#f7f7f7", high = "#b2182b", midpoint = 0, name = "SR (EB)") +
  labs(subtitle = "(a) Empirical Bayes-smoothed SR") + theme_void(base_size = 9) + theme(legend.position = "bottom")
p_gi <- ggplot(tm) + geom_sf(aes(fill = factor(gi_class, names(gi_cols))), colour = "grey70", linewidth = 0.05) +
  scale_fill_manual(values = gi_cols, drop = FALSE, name = NULL) + guides(fill = guide_legend(ncol = 2)) +
  labs(subtitle = "(b) Getis-Ord Gi* (permutation p, FDR q)") + theme_void(base_size = 9) +
  theme(legend.position = "bottom", legend.text = element_text(size = 7))
save_fig(p_eb, "fig_ttwa_sr.pdf", 3.2, 4.2); save_fig(p_gi, "fig_ttwa_gi.pdf", 3.2, 4.2)

# ======================================================================================
# 5. RQ3: models (Step 7)
# ======================================================================================
rr <- rd("step7_rate_ratios.csv"); fit <- rd("step7_model_fit.csv"); dg <- rd("step7_diagnostics.csv")
rfx <- rd("step7_region_effects.csv"); spc <- rd("step7_spatial_coefficients.csv"); spf <- rd("step7_spatial_fit.csv")
D <- function(m) dg$value[dg$measure == m]
g <- function(model, term, col) rr[[col]][rr$model == model & rr$term == term]
mm <- "TTWA: main (M2)"; m1 <- "TTWA: no region (M1)"
M("distRR", num(g(mm, "dist10", "RR"), 3)); M("distLo", num(g(mm, "dist10", "lo"), 2)); M("distHi", num(g(mm, "dist10", "hi"), 2))
M("distP", pv(g(mm, "dist10", "p"))); M("distPct", num((1 - g(mm, "dist10", "RR")) * 100, 0))
M("distPctLo", num((1 - g(mm, "dist10", "hi")) * 100, 0)); M("distPctHi", num((1 - g(mm, "dist10", "lo")) * 100, 0))
M("imdRRmOne", num(g(m1, "imd10", "RR"), 2)); M("imdPmOne", pv(g(m1, "imd10", "p")))
M("imdRR", num(g(mm, "imd10", "RR"), 2)); M("imdP", pv(g(mm, "imd10", "p")))
M("urbRR", num(g(mm, "urban10", "RR"), 2)); M("urbP", pv(g(mm, "urban10", "p")))
M("distRRmOne", num(g(m1, "dist10", "RR"), 2))
M("dispersion", num(D("poisson_dispersion_m2"), 2)); M("lrChi", num(D("lr_region_chisq"), 1)); M("lrDf", D("lr_region_df")); M("lrP", pv(D("lr_region_p")))
M("vifMax", num(max(D("vif_imd10"), D("vif_urban10"), D("vif_dist10")), 2))
M("resMoranOne", num(D("resid_moran_m1"), 2)); M("resMoranOneP", pv(D("resid_moran_m1_p")))
M("resMoranTwo", num(D("resid_moran_m2"), 2)); M("resMoranTwoP", pv(D("resid_moran_m2_p")))
M("semLambda", num(D("sem_lambda"), 2)); M("semP", pv(D("sem_lambda_p"))); M("slmRho", num(D("slm_rho"), 2)); M("slmP", pv(D("slm_rho_p")))
lm_rows <- spf |> filter(model %in% c("RSerr", "RSlag", "adjRSerr", "adjRSlag"))
M("lmPmin", pv(min(as.numeric(lm_rows$spatial_param_p))))
M("spatialDistP", sprintf("%s--%s", pv(min(spc$p[spc$term == "dist10"])), pv(max(spc$p[spc$term == "dist10"]))))
M("nwRR", num(rfx$RR[rfx$term == "North West"], 2)); M("neRR", num(rfx$RR[rfx$term == "North East"], 2))
M("seRR", num(rfx$RR[rfx$term == "South East"], 2)); M("swRR", num(rfx$RR[rfx$term == "South West"], 2))
rfx_sorted <- rfx |> arrange(desc(RR))
write_table("regionfx.tex", c("Region", "Rate ratio"),
  c(lapply(seq_len(nrow(rfx_sorted)), function(i) c(rfx_sorted$term[i], num(rfx_sorted$RR[i], 2))),
    list(c("West Midlands (reference)", "1.00"))), "lr")
M("aicZero", num(fit$AIC[1], 0)); M("aicOne", num(fit$AIC[2], 0)); M("aicTwo", num(fit$AIC[3], 0))
lab <- c(dist10 = "Distance to nearest club (+10 km)", imd10 = "Deprivation (+10 IMD points)", urban10 = "Urban share (+10 pp)")
mrow <- function(model) lapply(names(lab), function(t) c(lab[[t]],
  sprintf("%s (%s--%s)", num(g(model, t, "RR"), 3), num(g(model, t, "lo"), 2), num(g(model, t, "hi"), 2)), pv(g(model, t, "p"))))
r1 <- mrow(m1); r2 <- mrow(mm)
write_table("models.tex", c("", "M1: rate ratio (95\\% CI)", "$p$", "M2: rate ratio (95\\% CI)", "$p$"),
  c(lapply(1:3, function(i) c(r1[[i]][1], r1[[i]][2], r1[[i]][3], r2[[i]][2], r2[[i]][3])),
    list(c("Region fixed effects", "no", "", "yes", ""),
         c("AIC", num(fit$AIC[2], 1), "", num(fit$AIC[3], 1), ""),
         c("$\\theta$ (negative binomial)", num(fit$theta[2], 1), "", num(fit$theta[3], 1), ""),
         c("Residual Moran's $I$ ($p$)", sprintf("%s (%s)", num(D("resid_moran_m1"), 3), pv(D("resid_moran_m1_p"))), "",
           sprintf("%s (%s)", num(D("resid_moran_m2"), 3), pv(D("resid_moran_m2_p"))), ""))), "lrrrr")
vlab <- c("TTWA: main (M2)" = "Main model (M2)", "TTWA: no region (M1)" = "Without region effects (M1)",
          "TTWA: certain" = "Certain evidence only", "TTWA: premier" = "Premier League players only",
          "TTWA: cohort_75_89" = "Born 1975--1989", "TTWA: cohort_90_05" = "Born 1990--2005",
          "TTWA: no_ambiguous" = "Excluding season-ambiguous players", "TTWA: pop_baseline" = "Total-population baseline",
          "TTWA: excl. 5 largest cities" = "Excluding the five largest-city TTWAs", "LAD: main (M2)" = "Local authorities instead of TTWAs")
cell <- function(model, t) sprintf("%s (%s)", num(g(model, t, "RR"), 2), pv(g(model, t, "p")))
write_table("robust.tex", c("Variant", "Club distance", "Deprivation", "Urban share"),
  lapply(names(vlab), function(m) c(vlab[[m]], cell(m, "dist10"), cell(m, "imd10"), cell(m, "urban10"))), "lrrr")
for (m in list(c("TTWA: cohort_75_89", "Old"), c("TTWA: cohort_90_05", "Young"), c("LAD: main (M2)", "LAD"),
               c("TTWA: premier", "Premier"), c("TTWA: certain", "Certain"), c("TTWA: pop_baseline", "Pop"),
               c("TTWA: excl. 5 largest cities", "NoCities"))) {
  M(paste0("distRR", m[2]), num(g(m[1], "dist10", "RR"), 2)); M(paste0("distP", m[2]), pv(g(m[1], "dist10", "p")))
}
M("nRobustSig", sum(rr$term == "dist10" & rr$p < 0.05)); M("nRobust", sum(rr$term == "dist10"))
robd <- rr |> filter(term == "dist10") |> mutate(label = factor(gsub("--", "–", vlab[model]), rev(gsub("--", "–", vlab))))
p_rb <- ggplot(robd, aes(RR, label)) + geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.25, orientation = "y", colour = "grey40") +
  geom_point(aes(colour = model == mm, shape = p < 0.05), size = 2.4) +
  scale_colour_manual(values = c(`TRUE` = "#b2182b", `FALSE` = NAVY), guide = "none") +
  scale_shape_manual(values = c(`TRUE` = 16, `FALSE` = 1), labels = c(`TRUE` = "p < 0.05", `FALSE` = "p ≥ 0.05"), name = NULL) +
  labs(x = "Rate ratio per extra 10 km to the nearest club (95% CI)", y = NULL) + theme_paper()
save_fig(p_rb, "fig_robustness.pdf", 6.2, 3.3)
eff <- rr |> filter(model %in% c(m1, mm)) |>
  mutate(term = factor(gsub("pp", "pp", lab[term]), rev(lab)), model = ifelse(model == mm, "M2: with region effects", "M1: without region effects"))
p_ef <- ggplot(eff, aes(RR, term, colour = model)) + geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, orientation = "y", position = position_dodge(0.5)) +
  geom_point(size = 2.4, position = position_dodge(0.5)) +
  scale_colour_manual(values = c("M1: without region effects" = "grey60", "M2: with region effects" = NAVY), name = NULL) +
  labs(x = "Rate ratio (95% CI)", y = NULL) + theme_paper()
save_fig(p_ef, "fig_models.pdf", 6.2, 2.6)

ac <- rd("step7b_academy_rate_ratios.csv"); ad <- rd("step7b_academy_data.csv"); acad <- read_csv("data/manual/category1_academies.csv", show_col_types = FALSE)
ga <- function(model, term, col) ac[[col]][ac$model == model & ac$term == term]
M("nAcadPlayers", sum(ad$O)); M("nAcadClubs", n_distinct(acad$club_qid))
M("acadPerSeasonLo", min(table(acad$season))); M("acadPerSeasonHi", max(table(acad$season)))
M("clubYoungRR", num(ga("A1 club distance", "club10", "RR"), 3)); M("clubYoungP", pv(ga("A1 club distance", "club10", "p")))
M("clubYoungLo", num(ga("A1 club distance", "club10", "lo"), 2)); M("clubYoungHi", num(ga("A1 club distance", "club10", "hi"), 2))
M("clubYoungPct", num((1 - ga("A1 club distance", "club10", "RR")) * 100, 0))
M("acadRR", num(ga("A2 academy distance", "acad10", "RR"), 3)); M("acadP", pv(ga("A2 academy distance", "acad10", "p")))
M("bothClubRR", num(ga("A3 both", "club10", "RR"), 2)); M("bothAcadRR", num(ga("A3 both", "acad10", "RR"), 2)); M("bothAcadP", pv(ga("A3 both", "acad10", "p")))
M("acadDistMed", num(median(ad$dist_academy), 0)); M("clubDistMedYoung", num(median(ad$dist_club), 1))
M("acadCor", num(cor(ad$dist_club, ad$dist_academy), 2))
afit <- rd("step7b_academy_fit.csv")
write_table("academy.tex", c("Model", "Any club (+10 km)", "$p$", "Category 1 academy (+10 km)", "$p$", "AIC"),
  list(c("A1: club distance", sprintf("%s (%s--%s)", num(ga("A1 club distance", "club10", "RR"), 3), num(ga("A1 club distance", "club10", "lo"), 2), num(ga("A1 club distance", "club10", "hi"), 2)), pv(ga("A1 club distance", "club10", "p")), "", "", num(afit$AIC[1], 1)),
       c("A2: academy distance", "", "", sprintf("%s (%s--%s)", num(ga("A2 academy distance", "acad10", "RR"), 3), num(ga("A2 academy distance", "acad10", "lo"), 2), num(ga("A2 academy distance", "acad10", "hi"), 2)), pv(ga("A2 academy distance", "acad10", "p")), num(afit$AIC[2], 1)),
       c("A3: both", sprintf("%s (%s--%s)", num(ga("A3 both", "club10", "RR"), 3), num(ga("A3 both", "club10", "lo"), 2), num(ga("A3 both", "club10", "hi"), 2)), pv(ga("A3 both", "club10", "p")),
         sprintf("%s (%s--%s)", num(ga("A3 both", "acad10", "RR"), 3), num(ga("A3 both", "acad10", "lo"), 2), num(ga("A3 both", "acad10", "hi"), 2)), pv(ga("A3 both", "acad10", "p")), num(afit$AIC[3], 1))), "lrrrrr")

# ======================================================================================
# 6. RQ4: foreign-born (Step 7)
# ======================================================================================
ct <- rd("step8_rq4_countries.csv") |> filter(country != "(unknown)")
uk3 <- c("Scotland", "Wales", "Northern Ireland")
out_eng <- ct |> filter(country != "England")
M("nCountries", nrow(out_eng)); M("nOutsideEngland", num(sum(out_eng$total))); M("shareOutsideEngland", pct(sum(out_eng$total) / nrow(pe), 0))
M("nOutsideUK", num(sum(out_eng$total[!out_eng$country %in% uk3]))); M("shareOutsideUK", pct(sum(out_eng$total[!out_eng$country %in% uk3]) / nrow(pe), 1))
M("nOtherUK", num(sum(out_eng$total[out_eng$country %in% uk3]))); M("shareOtherUK", pct(sum(out_eng$total[out_eng$country %in% uk3]) / nrow(pe), 1))
M("scotOld", ct$`1975–1989`[ct$country == "Scotland"]); M("scotNew", ct$`1990–2005`[ct$country == "Scotland"])
M("engShareOld", pct(ct$`1975–1989`[ct$country == "England"] / sum(ct$`1975–1989`), 1)); M("engShareNew", pct(ct$`1990–2005`[ct$country == "England"] / sum(ct$`1990–2005`), 1))
hd <- ct |> filter(total >= 10, !is.na(per_million)) |> arrange(desc(per_million))
M("topHeadName", hd$country[1]); M("topHeadRate", num(hd$per_million[1], 0))
top15 <- out_eng |> arrange(desc(total)) |> head(15)
write_table("countries.tex", c("Country", "Born 1975--89", "Born 1990--2005", "Total", "Per million"),
  lapply(seq_len(nrow(top15)), function(i) with(top15[i, ], c(country, `1975–1989`, `1990–2005`, total,
                                                             if (is.na(per_million)) "--" else num(per_million, 1)))), "lrrrr")
cont <- rd("step8_rq4_continents.csv")
cs <- function(co, ch) pct(cont$share[cont$cohort == co & cont$continent == ch], 1)
M("eurOld", cs("1975–1989", "Europe")); M("eurNew", cs("1990–2005", "Europe"))
M("afrOld", cs("1975–1989", "Africa")); M("afrNew", cs("1990–2005", "Africa"))
M("samOld", cs("1975–1989", "South America")); M("samNew", cs("1990–2005", "South America"))
units_w <- read_sf("/vsizip/data/raw/naturalearth/ne_10m_admin_0_map_units.zip") |>
  transmute(country = ifelse(GEOUNIT %in% c("England", uk3), GEOUNIT, ADMIN))
wm <- units_w |> left_join(out_eng |> select(country, per_million), by = "country")
p_w <- ggplot(wm) + geom_sf(aes(fill = per_million), colour = "grey70", linewidth = 0.03) +
  scale_fill_viridis_c(option = "plasma", trans = "log10", na.value = "grey92", name = "Players per\nmillion people") +
  coord_sf(crs = "+proj=robin", datum = NA) + theme_void(base_size = 9) + theme(legend.position = "right")
save_fig(p_w, "fig_world.pdf", 6.5, 3.2)

# ======================================================================================
# 7. Software, seeds, commit
# ======================================================================================
M("seed", "20261118"); M("nPerm", "9\\,999"); M("nSim", 999)
M("Rversion", paste(R.version$major, R.version$minor, sep = "."))
for (pk in c("sf", "spatstat", "spdep", "spatialreg", "MASS")) M(paste0("ver", gsub("[^A-Za-z]", "", pk)), as.character(packageVersion(pk)))
M("snapshotDate", sub("^.*_(\\d{4}-\\d{2}-\\d{2})\\.parquet$", "\\1", latest("^wikidata_players_.*parquet$", "data/raw")))

writeLines(c("% Generated by analysis/paper/11_paper_inputs.R from cached outputs. Do not edit.", unname(unlist(macros))),
           file.path(OUT_G, "numbers.tex"))
commit <- tryCatch(system("git -c safe.directory='*' rev-parse --short HEAD", intern = TRUE), error = function(e) "unknown",
                   warning = function(w) "unknown")
dirty <- tryCatch(length(system("git -c safe.directory='*' status --porcelain", intern = TRUE)) > 0, error = function(e) TRUE)
writeLines(sprintf("\\newcommand{\\commitHash}{%s%s}", commit[1], if (dirty) " with uncommitted changes" else ""),
           file.path(OUT_G, "commit.tex"))
cat(sprintf("Wrote %d macros, %d tables, %d figures. Commit: %s%s\n", length(macros),
            length(list.files(OUT_T)), length(list.files(OUT_F, "pdf$")), commit[1], if (dirty) " (dirty)" else ""))
