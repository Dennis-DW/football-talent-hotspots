# Step 5 (RQ1): are birthplaces clustered beyond what births alone would predict?
#
# Data:  English-born study players with a town-level birthplace (2,919), jittered by up to
#        ±500 m (fixed seed) because many share one town-centre coordinate.
# Null:  births (male, 1975–2005) as the background intensity. LAD births are shared out to
#        LSOA centroids by population; the intensity surface is a kernel smooth of those
#        weighted points (sigma = 2 km), scaled so that it integrates to the number of
#        players: lambda(u) = n * f_births(u).
# Test:  inhomogeneous L-function (spatstat::Linhom, border correction), compared with a
#        global envelope from 999 patterns of n points drawn from lambda (rpoint). Global
#        MAD and DCLF tests over r in [0, 60] km and r in [20, 60] km (border correction
#        leaves too few points beyond ~60 km in a country as narrow as England); the short range is
#        affected by shared town-centre coordinates and by the hospital effect.
# Null test: a fake player pattern drawn from lambda must give no significant clustering.
# Also:  players per 10,000 male births by region; kernel maps of players, births and their
#        ratio (relative risk, sigma = 15 km).
#
# Outputs: data/processed/step5_*.csv, docs/reports/figures/step5_*.png
# Usage (inside the app container): Rscript analysis/models/05_clustering.R [nsim]   (default 999)

options(warn = 1)
suppressPackageStartupMessages({
  library(sf)
  library(dplyr)
  library(readr)
  library(ggplot2)
  library(spatstat)
})
args <- commandArgs(trailingOnly = TRUE)
NSIM <- if (length(args)) as.integer(args[1]) else 999L
NSIM_NULL <- 199L
set.seed(20261118)
dir.create("docs/reports/figures", showWarnings = FALSE, recursive = TRUE)
latest <- function(pattern, dir) tail(sort(list.files(dir, pattern, full.names = TRUE)), 1)

# --- data ------------------------------------------------------------------------
lad <- read_sf("data/processed/lad21_england.gpkg")
lsoa <- read_csv("data/processed/lsoa21_england.csv", show_col_types = FALSE)
births <- read_csv("data/processed/births_lad_year.csv", show_col_types = FALSE)
players <- read_csv("data/processed/player_units.csv", show_col_types = FALSE)
regions <- read_csv(latest("^lad21_rgn21_lookup_.*csv$", "data/raw/ons"), show_col_types = FALSE) |>
  select(lad21cd = LAD21CD, region = RGN21NM)

# --- 1. regional overview ------------------------------------------------------------
# Town-level players by their LAD's region; "London" birthplaces go to London.
reg_births <- births |> inner_join(regions, by = "lad21cd") |>
  group_by(region) |> summarise(births = sum(births_male), .groups = "drop")
reg_players <- players |>
  left_join(regions, by = "lad21cd") |>
  mutate(region = ifelse(fine, region, "London")) |>
  count(region, name = "players")
reg <- reg_births |> left_join(reg_players, by = "region") |>
  mutate(players = coalesce(players, 0L),
         per_10k_births = 1e4 * players / births,
         E = births * sum(players) / sum(births), SR = players / E,
         p_value = mapply(function(o, e) poisson.test(o, e)$p.value, players, E)) |>
  arrange(desc(SR))
write_csv(reg, "data/processed/step5_regions.csv")

# --- 2. window, points, background intensity --------------------------------------------
eng <- st_union(lad) |> st_simplify(dTolerance = 500)
W <- as.owin(st_geometry(eng))
W <- rescale(W, 1000, "km")

fine <- players |> filter(fine)
pts <- st_as_sf(fine, coords = c("lon", "lat"), crs = 4326) |> st_transform(27700)
xy <- st_coordinates(pts) / 1000
X <- ppp(xy[, 1], xy[, 2], window = W, check = FALSE)
X <- rjitter(X, radius = 0.5, retry = TRUE)        # ±0.5 km
X <- X[W]                                          # drop the odd point jittered outside
Window(X) <- W
n <- npoints(X)

lsoa_b <- lsoa |>
  group_by(lad21cd) |> mutate(w = pop2022 / sum(pop2022)) |> ungroup() |>
  inner_join(births |> group_by(lad21cd) |> summarise(B = sum(births_male)), by = "lad21cd") |>
  mutate(b = B * w)
Bp <- ppp(lsoa_b$bng_e / 1000, lsoa_b$bng_n / 1000, window = W, check = FALSE)
inside <- inside.owin(Bp$x, Bp$y, W)
Bp <- Bp[inside]
bw <- lsoa_b$b[inside]
f_births <- density(Bp, sigma = 2, weights = bw / sum(bw), eps = 1, positive = TRUE)
lambda <- eval.im(pmax(f_births, 1e-12) * n)

# --- 3. inhomogeneous L-function with global envelope -------------------------------------
R_MAX <- 60
r <- seq(0, R_MAX, by = 1)
sim_expr <- expression(rpoint(n, lambda, win = W))
t0 <- Sys.time()
# nrank = 5% of (nsim + 1) gives a 95% global envelope (default nrank = 1 would be 99.9%)
env <- envelope(X, Linhom, nsim = NSIM, simulate = sim_expr, r = r,
                funargs = list(lambda = lambda, correction = "border"),
                global = TRUE, nrank = max(1, round(0.05 * (NSIM + 1))), savefuns = TRUE, verbose = FALSE)
mad_all <- mad.test(env)
dclf_all <- dclf.test(env)
mad_far <- mad.test(env, rinterval = c(20, R_MAX))
dclf_far <- dclf.test(env, rinterval = c(20, R_MAX))
elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "mins")), 1)

envdf <- as.data.frame(env) |> transmute(r_km = r, L_obs = obs, L_ref = mmean, lo, hi)
write_csv(envdf, "data/processed/step5_linhom_envelope.csv")

p_env <- ggplot(envdf, aes(r_km)) +
  geom_ribbon(aes(ymin = lo - r_km, ymax = hi - r_km), fill = "grey80") +
  geom_hline(yintercept = 0, linetype = 2, colour = "grey40") +
  geom_line(aes(y = L_obs - r_km), colour = "#b2182b", linewidth = 0.8) +
  geom_vline(xintercept = 20, linetype = 3) +
  labs(x = "distance r (km)", y = "L(r) − r  (km)",
       title = "Inhomogeneous L-function: player birthplaces vs. births",
       subtitle = sprintf("Grey: 95%% global envelope from %d simulations of births-only placement; red: observed (n = %d)",
                          NSIM, n),
       caption = "Above the band = clustered beyond births. Left of the dotted line (20 km) is affected by shared town-centre\ncoordinates and the hospital effect.") +
  theme_minimal(base_size = 10)
ggsave("docs/reports/figures/step5_linhom_envelope.png", p_env, width = 8, height = 5, dpi = 150, bg = "white")

# --- 4. null test: births-only fake players ---------------------------------------------
X0 <- rpoint(n, lambda, win = W)
env0 <- envelope(X0, Linhom, nsim = NSIM_NULL, simulate = sim_expr, r = r,
                 funargs = list(lambda = lambda, correction = "border"),
                 global = TRUE, nrank = max(1, round(0.05 * (NSIM_NULL + 1))), savefuns = TRUE, verbose = FALSE)
null_all <- mad.test(env0)
null_far <- mad.test(env0, rinterval = c(20, R_MAX))

# --- 5. kernel density maps and relative risk ------------------------------------------
S <- 15
f_pl <- density(X, sigma = S, eps = 2, positive = TRUE)
f_pl <- f_pl / integral(f_pl)
f_b15 <- density(Bp, sigma = S, weights = bw / sum(bw), eps = 2, positive = TRUE)
f_b15 <- f_b15 / integral(f_b15)
rr <- eval.im(f_pl / pmax(f_b15, 1e-12))
to_df <- function(im, name) {
  d <- as.data.frame(im)
  d$layer <- name
  d
}
kd <- bind_rows(to_df(f_pl, "Players"), to_df(f_b15, "Male births"))
p_kde <- ggplot(kd, aes(x, y, fill = value)) +
  geom_tile() + facet_wrap(~layer) + coord_equal() +
  scale_fill_viridis_c(option = "magma", trans = "sqrt", name = "density") +
  labs(title = sprintf("Kernel density (sigma = %d km), each scaled to integrate to 1", S)) +
  theme_void(base_size = 10)
ggsave("docs/reports/figures/step5_kde_players_births.png", p_kde, width = 9, height = 6, dpi = 150, bg = "white")
rrd <- as.data.frame(rr)
p_rr <- ggplot(rrd, aes(x, y, fill = pmin(pmax(value, 0.25), 4))) +
  geom_tile() + coord_equal() +
  scale_fill_gradient2(trans = "log2", low = "#2166ac", mid = "#f7f7f7", high = "#b2182b",
                       midpoint = 0, breaks = c(0.25, 0.5, 1, 2, 4),
                       labels = c("≤0.25", "0.5", "1", "2", "≥4"), name = "relative\nrisk") +
  labs(title = "Relative risk: player density ÷ births density (sigma = 15 km)",
       subtitle = "Above 1: more players than births predict. Exploratory — no significance test.") +
  theme_void(base_size = 10)
ggsave("docs/reports/figures/step5_relative_risk.png", p_rr, width = 7, height = 8, dpi = 150, bg = "white")

# --- 6. summary ------------------------------------------------------------------------
tests <- tibble(
  pattern = c("players", "players", "players", "players", "null (births-only)", "null (births-only)"),
  test = c("MAD", "DCLF", "MAD", "DCLF", "MAD", "MAD"),
  r_range_km = c("0-60", "0-60", "20-60", "20-60", "0-60", "20-60"),
  statistic = sapply(list(mad_all, dclf_all, mad_far, dclf_far, null_all, null_far),
                     function(t) unname(t$statistic[[1]])),
  p_value = c(mad_all$p.value, dclf_all$p.value, mad_far$p.value, dclf_far$p.value,
              null_all$p.value, null_far$p.value),
  nsim = c(rep(NSIM, 4), rep(NSIM_NULL, 2))
)
write_csv(tests, "data/processed/step5_tests.csv")
above <- envdf |> filter(L_obs > hi)
cat(sprintf("Points: %d players | window %.0f km2 | envelope: %d sims in %.1f min\n",
            n, area(W), NSIM, elapsed))
cat("Regions (players per 10,000 male births, SR, Poisson p):\n")
print(reg |> mutate(across(c(per_10k_births, SR), ~ round(.x, 2)),
                    p_value = signif(p_value, 2)) |> select(-E), n = 20)
cat("\nGlobal tests:\n"); print(tests |> mutate(statistic = signif(statistic, 3)))
cat(sprintf("NaN values in observed L: %d | in envelope: %d\n", sum(!is.finite(envdf$L_obs)), sum(!is.finite(envdf$hi))))
cat(sprintf("\nObserved L above the envelope for r in: %s km\n",
            if (nrow(above)) paste(range(above$r_km), collapse = "-") else "none"))
cat("L(r) - r at selected distances (observed | envelope):\n")
print(envdf |> filter(r_km %in% c(2, 5, 10, 20, 30, 40, 50, 60)) |>
        transmute(r_km, obs = round(L_obs - r_km, 2), lo = round(lo - r_km, 2), hi = round(hi - r_km, 2)))
