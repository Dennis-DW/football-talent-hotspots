# Step 6 (RQ2): where are the hotspots and coldspots?
#
# For each unit level (TTWA = main; LAD 2021 and 20 km hexagons = comparison):
#   1. Empirical Bayes smoothing of SR (spdep::EBest, Poisson, global shrinkage).
#   2. Spatial weights: polygons — queen contiguity, units without a neighbour (islands)
#      linked to their nearest unit; hexagons — 6 nearest neighbours (symmetrised).
#      Alternative (robustness): 6 nearest neighbours for polygons; 4 and 8 for hexagons.
#   3. Global EB Moran's I (Assuncao & Reis), 999 permutations.
#   4. Local Getis-Ord Gi* on the EB-smoothed SR (binary weights incl. self), 9,999
#      conditional permutations; LISA (local Moran's I, row-standardised), 9,999 permutations.
#      Benjamini–Hochberg FDR across units; significant at q < 0.05.
#
# Outputs: data/processed/step6_{level}_{weights}.csv   per-unit results
#          data/processed/step6_global.csv              global EB Moran's I
#          docs/reports/figures/step6_*.png             maps
# Usage (inside the app container): Rscript analysis/models/06_hotspots.R [nsim_global] [nsim_local]
#        (defaults 999 and 9999)

suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(tidyr)
  library(ggplot2)
  library(spdep)
})
args <- commandArgs(trailingOnly = TRUE)
NSIM <- if (length(args)) as.integer(args[1]) else 999L        # global EB Moran's I
# Local tests need finer p-values: with FDR over ~155–440 units the strongest unit must
# reach p < 0.05 / n_units (~0.0003), impossible with 999 permutations (minimum p = 0.001).
NSIM_LOCAL <- if (length(args) > 1) as.integer(args[2]) else 9999L
Q <- 0.05
set.seed(20261118)

lad <- read_sf("data/processed/lad21_england.gpkg") |> rename(unit = lad21cd, name = lad21nm)
ttwa <- read_sf("data/processed/ttwa11_england.gpkg") |> rename(unit = ttwa_id, name = ttwa_nm)
hex20 <- read_sf("data/processed/hex20_england.gpkg") |> rename(unit = hex_id) |> mutate(name = unit)

counts <- function(level) {
  read_csv(sprintf("data/processed/counts_%s.csv", level), show_col_types = FALSE) |>
    filter(variant == "main") |> select(unit, O, E, births)
}

# --- neighbours --------------------------------------------------------------------
poly_nb <- function(x) {
  nb <- poly2nb(x, queen = TRUE)
  iso <- which(card(nb) == 0)
  if (length(iso)) {
    cent <- st_coordinates(st_point_on_surface(st_geometry(x)))
    for (i in iso) {
      d <- sqrt((cent[, 1] - cent[i, 1])^2 + (cent[, 2] - cent[i, 2])^2)
      d[i] <- Inf
      j <- which.min(d)
      nb[[i]] <- sort(unique(c(nb[[i]][nb[[i]] > 0], j)))
      nb[[j]] <- sort(unique(c(nb[[j]][nb[[j]] > 0], i)))
    }
  }
  attr(nb, "linked_islands") <- x$name[iso]
  nb
}
knn_nb <- function(x, k) {
  cent <- st_coordinates(st_point_on_surface(st_geometry(x)))
  make.sym.nb(knn2nb(knearneigh(cent, k = k)))
}

# --- analysis for one level / weights -------------------------------------------------
analyse <- function(geo, level, nb, wname) {
  d <- geo |> left_join(counts(level), by = "unit")
  stopifnot(!anyNA(d$E), all(d$E > 0))
  eb <- EBest(d$O, d$E, family = "poisson")
  d$SR <- d$O / d$E
  d$SR_EB <- eb$estmm

  moran <- EBImoran.mc(d$O, d$E, nb2listw(nb, style = "W"), nsim = NSIM)

  lw_g <- nb2listw(include.self(nb), style = "B")
  g <- localG_perm(d$SR_EB, lw_g, nsim = NSIM_LOCAL, iseed = 20261118)
  gi <- attr(g, "internals")
  d$Gi_z <- as.numeric(g)
  d$Gi_p <- gi[, "Pr(z != E(Gi)) Sim"]
  d$Gi_q <- p.adjust(d$Gi_p, "BH")
  # sensitivity: normal-theory p-values (assume Gi* is approximately normal)
  d$Gi_p_norm <- 2 * pnorm(-abs(d$Gi_z))
  d$Gi_q_norm <- p.adjust(d$Gi_p_norm, "BH")

  lm <- localmoran_perm(d$SR_EB, nb2listw(nb, style = "W"), nsim = NSIM_LOCAL, iseed = 20261118)
  d$LISA_I <- lm[, "Ii"]
  d$LISA_p <- lm[, "Pr(z != E(Ii)) Sim"]
  d$LISA_q <- p.adjust(d$LISA_p, "BH")
  quad <- as.character(attr(lm, "quadr")$mean)

  d <- d |> mutate(
    # evidence tiers (permutation p-values; FDR = Benjamini–Hochberg across units)
    gi_class = case_when(
      Gi_q < Q & Gi_z > 0 ~ "Hotspot (FDR q<0.05)",
      Gi_q < 0.10 & Gi_z > 0 ~ "Hotspot (q<0.10)",
      Gi_p < Q & Gi_z > 0 ~ "Hot, exploratory (p<0.05)",
      Gi_q < Q & Gi_z < 0 ~ "Coldspot (FDR q<0.05)",
      Gi_q < 0.10 & Gi_z < 0 ~ "Coldspot (q<0.10)",
      Gi_p < Q & Gi_z < 0 ~ "Cold, exploratory (p<0.05)",
      TRUE ~ "Not significant"),
    lisa_class = ifelse(LISA_q < Q, quad, "Not significant"),
    level = level, weights = wname)
  write_csv(st_drop_geometry(d), sprintf("data/processed/step6_%s_%s.csv", level, wname))
  list(d = d, moran = moran, level = level, weights = wname,
       islands = attr(nb, "linked_islands"))
}

runs <- list(
  analyse(ttwa, "ttwa", poly_nb(ttwa), "queen"),
  analyse(ttwa, "ttwa", knn_nb(ttwa, 6), "knn6"),
  analyse(lad, "lad21", poly_nb(lad), "queen"),
  analyse(lad, "lad21", knn_nb(lad, 6), "knn6"),
  analyse(hex20, "hex20", knn_nb(hex20, 6), "knn6"),
  analyse(hex20, "hex20", knn_nb(hex20, 4), "knn4"),
  analyse(hex20, "hex20", knn_nb(hex20, 8), "knn8")
)

glob <- bind_rows(lapply(runs, function(r) tibble(
  level = r$level, weights = r$weights, units = nrow(r$d),
  EB_Moran_I = unname(r$moran$statistic), p_value = r$moran$p.value,
  hot_fdr05 = sum(r$d$Gi_q < Q & r$d$Gi_z > 0), cold_fdr05 = sum(r$d$Gi_q < Q & r$d$Gi_z < 0),
  hot_fdr10 = sum(r$d$Gi_q < 0.10 & r$d$Gi_z > 0), cold_fdr10 = sum(r$d$Gi_q < 0.10 & r$d$Gi_z < 0),
  hot_p05 = sum(r$d$Gi_p < Q & r$d$Gi_z > 0), cold_p05 = sum(r$d$Gi_p < Q & r$d$Gi_z < 0),
  hot_norm_fdr05 = sum(r$d$Gi_q_norm < Q & r$d$Gi_z > 0), cold_norm_fdr05 = sum(r$d$Gi_q_norm < Q & r$d$Gi_z < 0),
  lisa_HH = sum(r$d$lisa_class == "High-High"), lisa_LL = sum(r$d$lisa_class == "Low-Low"),
  lisa_HL = sum(r$d$lisa_class == "High-Low"), lisa_LH = sum(r$d$lisa_class == "Low-High"))))
write_csv(glob, "data/processed/step6_global.csv")

# --- maps --------------------------------------------------------------------------------
gi_cols <- c("Hotspot (FDR q<0.05)" = "#b2182b", "Hotspot (q<0.10)" = "#ef8a62",
             "Hot, exploratory (p<0.05)" = "#fddbc7", "Not significant" = "#f7f7f7",
             "Cold, exploratory (p<0.05)" = "#d1e5f0", "Coldspot (q<0.10)" = "#67a9cf",
             "Coldspot (FDR q<0.05)" = "#2166ac")
lisa_cols <- c("High-High" = "#b2182b", "Low-Low" = "#2166ac", "High-Low" = "#f4a582",
               "Low-High" = "#92c5de", "Not significant" = "#f0f0f0")
map_gi <- function(r, file, title) {
  p <- ggplot(r$d) + geom_sf(aes(fill = factor(gi_class, names(gi_cols))), colour = "grey55", linewidth = 0.08) +
    scale_fill_manual(values = gi_cols, drop = FALSE, name = "Getis-Ord Gi*\n(permutation p;\nFDR = Benjamini–Hochberg)") +
    labs(title = title, subtitle = sprintf("EB-smoothed SR, %s weights, %d permutations; global EB Moran's I = %.3f (p = %.3f)",
                                           r$weights, NSIM_LOCAL, r$moran$statistic, r$moran$p.value)) +
    theme_void(base_size = 10)
  ggsave(file, p, width = 7, height = 8, dpi = 150, bg = "white")
}
map_gi(runs[[1]], "docs/reports/figures/step6_gi_ttwa.png", "Hotspots and coldspots: Travel to Work Areas")
map_gi(runs[[3]], "docs/reports/figures/step6_gi_lad21.png", "Hotspots and coldspots: local authorities")
map_gi(runs[[5]], "docs/reports/figures/step6_gi_hex20.png", "Hotspots and coldspots: 20 km hexagons")
p_lisa <- ggplot(runs[[1]]$d) +
  geom_sf(aes(fill = factor(lisa_class, names(lisa_cols))), colour = "grey55", linewidth = 0.08) +
  scale_fill_manual(values = lisa_cols, drop = FALSE, name = "LISA cluster\n(FDR q < 0.05)") +
  labs(title = "Local Moran's I (LISA): Travel to Work Areas",
       subtitle = sprintf("EB-smoothed SR, queen contiguity, %d permutations", NSIM_LOCAL)) +
  theme_void(base_size = 10)
ggsave("docs/reports/figures/step6_lisa_ttwa.png", p_lisa, width = 7, height = 8, dpi = 150, bg = "white")
p_eb <- ggplot(runs[[1]]$d) +
  geom_sf(aes(fill = SR_EB), colour = "grey55", linewidth = 0.08) +
  scale_fill_gradient2(trans = "log2", low = "#2166ac", mid = "#f7f7f7", high = "#b2182b", midpoint = 0,
                       name = "SR (EB)") +
  labs(title = "Empirical Bayes-smoothed SR: Travel to Work Areas") + theme_void(base_size = 10)
ggsave("docs/reports/figures/step6_sr_eb_ttwa.png", p_eb, width = 7, height = 8, dpi = 150, bg = "white")

# --- summary ---------------------------------------------------------------------------------
cat("Islands linked to nearest unit:", paste(unique(unlist(lapply(runs, `[[`, "islands"))), collapse = ", "), "\n\n")
cat("Global EB Moran's I and counts of significant units (FDR q < 0.05):\n")
print(glob |> mutate(EB_Moran_I = round(EB_Moran_I, 3), p_value = signif(p_value, 2)), width = 200)
main <- runs[[1]]$d |> st_drop_geometry()
show <- function(x) x |> transmute(name, O, E = round(E, 1), SR = round(SR, 2), SR_EB = round(SR_EB, 2),
                                   Gi_z = round(Gi_z, 2), Gi_q = signif(Gi_q, 2), lisa_class)
cat("\nTTWA hot (Gi*, queen, permutation p < 0.05):\n")
print(show(main |> filter(Gi_p < Q, Gi_z > 0) |> arrange(desc(Gi_z))) |> mutate(q_norm = signif(main$Gi_q_norm[match(name, main$name)], 2)), n = 50)
cat("\nTTWA cold (Gi*, queen, permutation p < 0.05):\n")
print(show(main |> filter(Gi_p < Q, Gi_z < 0) |> arrange(Gi_z)) |> mutate(q_norm = signif(main$Gi_q_norm[match(name, main$name)], 2)), n = 50)
alt <- runs[[2]]$d |> st_drop_geometry()
sig <- function(x) ifelse(x$Gi_p < Q, sign(x$Gi_z), 0)
cat(sprintf("\nTTWA agreement queen vs knn6 (hot / cold / neither at p<0.05): %.0f%%; Gi* z correlation %.2f\n",
            100 * mean(sig(main) == sig(alt)), cor(main$Gi_z, alt$Gi_z)))
cat("TTWA LISA outliers (High-Low / Low-High):\n")
print(show(main |> filter(lisa_class %in% c("High-Low", "Low-High"))))
