# Headline numbers and tables shown on the pages (from the analysis outputs).
# Needs src/setup/data.R and src/helpers/stats.R.

# overview
n_study <- sum(tabs$countries$total)
n_england <- tabs$countries$total[tabs$countries$country == "England"]
reg <- tabs$regions
ratio_ns <- max(reg$per_10k_births) / min(reg$per_10k_births)
dist_main <- tabs$rr |> filter(model == "TTWA: main (M2)", term == "dist10")
dist_pct <- (1 - dist_main$RR) * 100
ov_sr <- st_drop_geometry(units$ttwa) |> select(unit, name) |>
  left_join(compute_sr("ttwa", players, YEARS), by = "unit") |> filter(E >= 5)
ov_top <- ov_sr |> arrange(desc(SR_EB)) |> head(5)
ov_bottom <- ov_sr |> arrange(SR_EB) |> head(5)

# why page
y_club_young <- tabs$academy |> filter(model == "A1 club distance", term == "club10")
y_acad <- tabs$academy |> filter(model == "A2 academy distance", term == "acad10")
y_nw <- tabs$region_fx |> filter(term == "North West")
y_m1_imd <- tabs$rr |> filter(model == "TTWA: no region (M1)", term == "imd10")
y_m2_imd <- tabs$rr |> filter(model == "TTWA: main (M2)", term == "imd10")
y_m2_urb <- tabs$rr |> filter(model == "TTWA: main (M2)", term == "urban10")
ROBUST_LABELS <- c("TTWA: main (M2)" = "Main model", "TTWA: no region (M1)" = "Without region effects",
                   "TTWA: certain" = "Certain evidence only", "TTWA: premier" = "Premier League players only",
                   "TTWA: cohort_75_89" = "Born 1975–1989", "TTWA: cohort_90_05" = "Born 1990–2005",
                   "TTWA: no_ambiguous" = "Excluding ambiguous dates", "TTWA: pop_baseline" = "Total-population baseline",
                   "TTWA: excl. 5 largest cities" = "Excluding the 5 largest cities", "LAD: main (M2)" = "Local authorities instead")

# patterns page
p_n_sig <- sum(reg$p_value < 0.05)
p_moran <- tabs$global |> filter(level == "ttwa", weights == "queen")
p_dclf <- tabs$ltests |> filter(pattern == "players", test == "DCLF", r_range_km == "0-60")
p_gi <- st_drop_geometry(units$ttwa) |> filter(Gi_p < 0.05)
p_hot <- p_gi |> filter(Gi_z > 0) |> arrange(desc(Gi_z))
p_cold <- p_gi |> filter(Gi_z < 0) |> arrange(Gi_z)

# world page
UK_OTHER <- c("Scotland", "Wales", "Northern Ireland")
w_all <- tabs$countries |> filter(!country %in% c("(unknown)", "England")) |>
  mutate(group = case_when(country %in% UK_OTHER ~ "Scotland, Wales & N. Ireland",
                           is.na(continent) ~ "Other", TRUE ~ continent),
         subregion = ifelse(country %in% UK_OTHER, "United Kingdom", coalesce(subregion, "")))
w_n_countries <- nrow(w_all)
w_outside <- sum(w_all$total)
w_top <- w_all |> slice_max(total, n = 1)
w_head <- w_all |> filter(total >= 10, !is.na(per_million)) |> slice_max(per_million, n = 1)
w_change <- w_all |> mutate(change = `1990–2005` - `1975–1989`)
w_risers <- w_change |> slice_max(change, n = 5, with_ties = FALSE)
w_fallers <- w_change |> slice_min(change, n = 5, with_ties = FALSE)
W_GROUPS <- c("Europe", "Scotland, Wales & N. Ireland", "Africa", "South America", "North America", "Asia", "Oceania")

lab_terms <- c(dist10 = "Distance to nearest club (+10 km)", imd10 = "Deprivation (+10 IMD points)",
               urban10 = "Urban share (+10 pp)")
