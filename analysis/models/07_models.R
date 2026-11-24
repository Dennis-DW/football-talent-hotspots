# Step 7 (RQ3): what explains where players come from?
#
# Main unit: 155 TTWAs (LADs as a robustness check). Outcome: observed players O,
# offset log(E) (expected from male births), so coefficients are rate ratios (RR) of
# player production relative to births.
#
#   M0  O ~ offset(log E)                                  (overdispersion baseline)
#   M1  + IMD (per 10 points) + urban share (per 10 pp) + distance to club (per 10 km)
#   M2  M1 + region fixed effects (region holding most of the TTWA's population)
#   Negative binomial (MASS::glm.nb). Multicollinearity: VIF of the covariates.
#   Residual spatial autocorrelation: Moran's I of M2 Pearson residuals (queen, 999 perm).
#   Spatial models on log(EB-smoothed SR) (proposal 6.8d): OLS, robust LM tests
#   (spdep::lm.RStests), spatial error (errorsarlm) and lag (lagsarlm) models.
# Robustness (M2): variants certain / premier / cohort_75_89 / cohort_90_05 /
#   no_ambiguous / pop_baseline; excluding the 5 largest-city TTWAs; LAD level.
#
# Outputs: data/processed/step7_*.csv, docs/reports/figures/step7_*.png
# Usage (inside the app container): Rscript analysis/models/07_models.R

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(MASS, exclude = "select")
  library(spdep)
  library(spatialreg)
})
set.seed(20261118)
latest <- function(pattern, dir) tail(sort(list.files(dir, pattern, full.names = TRUE)), 1)

# --- data --------------------------------------------------------------------------
lsoa <- read_csv("data/processed/lsoa21_england.csv", show_col_types = FALSE)
regions <- read_csv(latest("^lad21_rgn21_lookup_.*csv$", "data/raw/ons"), show_col_types = FALSE) |>
  transmute(lad21cd = LAD21CD, region = RGN21NM)
ttwa_region <- lsoa |> inner_join(regions, by = "lad21cd") |>
  group_by(ttwa, region) |> summarise(pop = sum(pop2022), .groups = "drop_last") |>
  mutate(share = pop / sum(pop)) |> slice_max(pop, n = 1, with_ties = FALSE) |> ungroup() |>
  transmute(unit = ttwa, region, region_share = share)

ttwa <- read_sf("data/processed/ttwa11_england.gpkg") |> rename(unit = ttwa_id, name = ttwa_nm)
cov_t <- read_csv("data/processed/ttwa_covariates.csv", show_col_types = FALSE) |>
  rename(unit = ttwa_id) |> select(unit, imd_score, urban_share, dist_club_km)
eb_t <- read_csv("data/processed/step6_ttwa_queen.csv", show_col_types = FALSE) |> select(unit, SR_EB)
counts_t <- read_csv("data/processed/counts_ttwa.csv", show_col_types = FALSE)

prep <- function(cnt, cov, reg) {
  cnt |> inner_join(cov, by = "unit") |> inner_join(reg, by = "unit") |>
    mutate(imd10 = imd_score / 10, urban10 = urban_share * 10, dist10 = dist_club_km / 10,
           region = relevel(factor(region), ref = "West Midlands"))
}
d_main <- prep(counts_t |> filter(variant == "main"), cov_t, ttwa_region)
d_main <- ttwa |> select(unit, name) |> inner_join(d_main, by = "unit") |>
  left_join(eb_t, by = "unit")
stopifnot(nrow(d_main) == 155)

f1 <- O ~ imd10 + urban10 + dist10 + offset(log(E))
f2 <- update(f1, . ~ . + region)
rr_table <- function(m, label) {
  co <- summary(m)$coefficients
  keep <- rownames(co) %in% c("imd10", "urban10", "dist10")
  ci <- suppressMessages(confint.default(m))[keep, , drop = FALSE]
  tibble(model = label, term = rownames(co)[keep], RR = exp(co[keep, 1]),
         lo = exp(ci[, 1]), hi = exp(ci[, 2]), p = co[keep, 4])
}

# --- 1. negative binomial models -------------------------------------------------------
m0 <- glm.nb(O ~ 1 + offset(log(E)), data = d_main)
m1 <- glm.nb(f1, data = d_main)
m2 <- glm.nb(f2, data = d_main)
m2_pois <- glm(f2, family = poisson, data = d_main)
disp_pois <- sum(residuals(m2_pois, type = "pearson")^2) / m2_pois$df.residual
fit_tab <- tibble(model = c("M0 baseline", "M1 covariates", "M2 covariates + region"),
                  AIC = c(AIC(m0), AIC(m1), AIC(m2)),
                  logLik = c(logLik(m0), logLik(m1), logLik(m2)),
                  theta = c(m0$theta, m1$theta, m2$theta))
lr_region <- anova(m1, m2)

# multicollinearity (VIF from regressing each covariate on the others, incl. region)
X <- model.matrix(~ imd10 + urban10 + dist10 + region, data = d_main)[, -1]
vif <- sapply(c("imd10", "urban10", "dist10"), function(v) {
  1 / (1 - summary(lm(X[, v] ~ X[, colnames(X) != v]))$r.squared)
})

# --- 2. residual spatial autocorrelation --------------------------------------------------
poly_nb <- function(x) {
  nb <- poly2nb(x, queen = TRUE)
  cent <- st_coordinates(st_point_on_surface(st_geometry(x)))
  for (i in which(card(nb) == 0)) {
    dd <- sqrt((cent[, 1] - cent[i, 1])^2 + (cent[, 2] - cent[i, 2])^2); dd[i] <- Inf
    j <- which.min(dd)
    nb[[i]] <- j
    nb[[j]] <- sort(unique(c(nb[[j]][nb[[j]] > 0], i)))
  }
  nb
}
lw <- nb2listw(suppressWarnings(poly_nb(d_main)), style = "W")
mor_m1 <- moran.mc(residuals(m1, type = "pearson"), lw, nsim = 999)
mor_m2 <- moran.mc(residuals(m2, type = "pearson"), lw, nsim = 999)

# --- 3. spatial models on log EB-smoothed SR -----------------------------------------------
d_main$y <- log(d_main$SR_EB)
fs <- y ~ imd10 + urban10 + dist10 + region
ols <- lm(fs, data = d_main)
lmt <- lm.RStests(ols, lw, test = c("RSerr", "RSlag", "adjRSerr", "adjRSlag"))
sem <- errorsarlm(fs, data = d_main, listw = lw)
slm <- lagsarlm(fs, data = d_main, listw = lw)
lm_tab <- tibble(test = names(lmt), statistic = sapply(lmt, function(t) unname(t$statistic)),
                 p = sapply(lmt, function(t) unname(t$p.value)))
sp_coef <- function(m, label) {
  co <- summary(m)$Coef
  keep <- rownames(co) %in% c("imd10", "urban10", "dist10")
  tibble(model = label, term = rownames(co)[keep], estimate = co[keep, 1],
         se = co[keep, 2], p = co[keep, 4], ratio = exp(co[keep, 1]))
}
sp_tab <- bind_rows(sp_coef(sem, "Spatial error"), sp_coef(slm, "Spatial lag"),
                    tibble(model = "OLS", term = c("imd10", "urban10", "dist10"),
                           estimate = coef(ols)[c("imd10", "urban10", "dist10")],
                           se = summary(ols)$coefficients[c("imd10", "urban10", "dist10"), 2],
                           p = summary(ols)$coefficients[c("imd10", "urban10", "dist10"), 4]) |>
                      mutate(ratio = exp(estimate)))
sp_fit <- tibble(model = c("OLS", "Spatial error", "Spatial lag"),
                 AIC = c(AIC(ols), AIC(sem), AIC(slm)),
                 spatial_param = c(NA, sem$lambda, slm$rho),
                 spatial_param_p = c(NA, summary(sem)$LR1$p.value, summary(slm)$LR1$p.value))

# --- 4. robustness ---------------------------------------------------------------------------
rob <- list(rr_table(m1, "TTWA: no region (M1)"), rr_table(m2, "TTWA: main (M2)"))
for (v in c("certain", "premier", "cohort_75_89", "cohort_90_05", "no_ambiguous", "pop_baseline")) {
  dv <- prep(counts_t |> filter(variant == v), cov_t, ttwa_region)
  rob[[length(rob) + 1]] <- rr_table(glm.nb(f2, data = dv), paste("TTWA:", v))
}
big <- c("London", "Birmingham", "Manchester", "Liverpool", "Leeds")
rob[[length(rob) + 1]] <- rr_table(glm.nb(f2, data = filter(d_main, !name %in% big)),
                                   "TTWA: excl. 5 largest cities")
cov_l <- read_csv("data/processed/lad21_covariates.csv", show_col_types = FALSE) |>
  rename(unit = lad21cd) |> select(unit, imd_score, urban_share, dist_club_km)
d_lad <- prep(read_csv("data/processed/counts_lad21.csv", show_col_types = FALSE) |> filter(variant == "main"),
              cov_l, regions |> rename(unit = lad21cd) |> mutate(region_share = 1))
rob[[length(rob) + 1]] <- rr_table(glm.nb(f2, data = d_lad), "LAD: main (M2)")
rob <- bind_rows(rob)

# --- outputs ----------------------------------------------------------------------------------
write_csv(rob, "data/processed/step7_rate_ratios.csv")
write_csv(fit_tab, "data/processed/step7_model_fit.csv")
write_csv(sp_tab, "data/processed/step7_spatial_coefficients.csv")
write_csv(bind_rows(sp_fit |> mutate(across(everything(), as.character)),
                    lm_tab |> transmute(model = test, AIC = NA, spatial_param = as.character(statistic),
                                        spatial_param_p = as.character(p))),
          "data/processed/step7_spatial_fit.csv")
reg_fx <- tibble(term = names(coef(m2)), RR = exp(coef(m2))) |> filter(grepl("^region", term)) |>
  mutate(term = sub("^region", "", term))
write_csv(reg_fx, "data/processed/step7_region_effects.csv")
write_csv(tibble(
  measure = c("poisson_dispersion_m2", "lr_region_chisq", "lr_region_df", "lr_region_p",
              "vif_imd10", "vif_urban10", "vif_dist10",
              "resid_moran_m1", "resid_moran_m1_p", "resid_moran_m2", "resid_moran_m2_p",
              "sem_lambda", "sem_lambda_p", "slm_rho", "slm_rho_p", "n_ttwa", "region_share_median"),
  value = c(disp_pois, lr_region$`LR stat.`[2], lr_region$`   df`[2], lr_region$`Pr(Chi)`[2],
            vif[["imd10"]], vif[["urban10"]], vif[["dist10"]],
            unname(mor_m1$statistic), mor_m1$p.value, unname(mor_m2$statistic), mor_m2$p.value,
            sem$lambda, summary(sem)$LR1$p.value, slm$rho, summary(slm)$LR1$p.value,
            nrow(d_main), median(d_main$region_share))),
  "data/processed/step7_diagnostics.csv")
write_csv(st_drop_geometry(d_main) |> select(unit, name, region, region_share, O, E, SR_EB,
                                              imd_score, urban_share, dist_club_km),
          "data/processed/step7_model_data_ttwa.csv")

labs_t <- c(imd10 = "Deprivation (IMD, +10 points)", urban10 = "Urban share (+10 percentage points)",
            dist10 = "Distance to nearest club (+10 km)")
pf <- rob |> mutate(term = labs_t[term], model = factor(model, rev(unique(model)))) |>
  ggplot(aes(RR, model)) +
  geom_vline(xintercept = 1, linetype = 2, colour = "grey50") +
  geom_errorbar(aes(xmin = lo, xmax = hi), width = 0.2, orientation = "y", colour = "grey40") +
  geom_point(aes(colour = model == "TTWA: main (M2)"), size = 2) +
  scale_colour_manual(values = c(`TRUE` = "#b2182b", `FALSE` = "grey20"), guide = "none") +
  facet_wrap(~term, scales = "free_x") + scale_x_log10() +
  labs(x = "Rate ratio (95% CI), log scale", y = NULL,
       title = "What predicts player production? Negative binomial models, offset = expected from births",
       subtitle = "Main model in red (TTWA, with region fixed effects). Below 1 = fewer players than births predict.") +
  theme_minimal(base_size = 9)
ggsave("docs/reports/figures/step7_rate_ratios.png", pf, width = 11, height = 5.5, dpi = 150, bg = "white")

# --- summary ------------------------------------------------------------------------------------
cat(sprintf("TTWAs: %d | region assigned by majority population (median share %.0f%%)\n",
            nrow(d_main), 100 * median(d_main$region_share)))
cat(sprintf("Poisson dispersion (M2): %.2f\n", disp_pois))
cat("\nModel fit:\n"); print(fit_tab |> mutate(across(where(is.numeric), ~ round(.x, 2))))
cat(sprintf("LR test region effects (M1 vs M2): chi2 = %.1f, df = %d, p = %.2g\n",
            lr_region$`LR stat.`[2], lr_region$`   df`[2], lr_region$`Pr(Chi)`[2]))
cat("VIF:", paste(names(vif), round(vif, 2), collapse = ", "), "\n")
cat("\nRate ratios (M1 = no region, M2 = with region):\n")
print(rob |> filter(model %in% c("TTWA: no region (M1)", "TTWA: main (M2)")) |>
        mutate(across(c(RR, lo, hi), ~ round(.x, 3)), p = signif(p, 2)))
cat("\nRegion effects (RR vs West Midlands, M2):\n"); print(reg_fx |> mutate(RR = round(RR, 2)))
cat(sprintf("\nResidual Moran's I: M1 %.3f (p %.3f) | M2 %.3f (p %.3f)\n",
            mor_m1$statistic, mor_m1$p.value, mor_m2$statistic, mor_m2$p.value))
cat("\nLM tests (OLS on log EB-SR):\n"); print(lm_tab |> mutate(statistic = round(statistic, 2), p = signif(p, 2)))
cat("\nSpatial models:\n"); print(sp_fit |> mutate(across(where(is.numeric), ~ round(.x, 3))))
print(sp_tab |> mutate(across(c(estimate, se, ratio), ~ round(.x, 3)), p = signif(p, 2)))
cat("\nRobustness (M2, rate ratios):\n")
print(rob |> select(model, term, RR, p) |> mutate(RR = round(RR, 3), p = signif(p, 2)) |>
        pivot_wider(names_from = term, values_from = c(RR, p)), width = 200)
