# Data prepared by analysis/dashboard/09_app_data.R, and constants used across pages.

units <- readRDS("data/units.rds")
births <- readRDS("data/births_unit_year.rds")
players <- readRDS("data/players.rds")
tabs <- readRDS("data/tables.rds")
world <- readRDS("data/world.rds")
rr_rast <- rast("data/relative_risk.tif")

YEARS <- range(players$birth_year)
LEVELS <- c("Travel to Work Areas" = "ttwa", "Local authorities" = "lad21", "20 km hexagons" = "hex20")
LEVEL_NOUN <- c(ttwa = "Travel to Work Areas", lad21 = "local authorities", hex20 = "hexagons")
MEASURES <- c("Smoothed" = "SR_EB", "Raw" = "SR", "Hotspots" = "gi")
POSITIONS <- c("GK" = "Goalkeeper", "DF" = "Defender", "MF" = "Midfielder", "FW" = "Forward")
GI_COLS <- c("Hotspot (FDR q<0.05)" = "#b2182b", "Hotspot (q<0.10)" = "#ef8a62",
             "Hot, exploratory (p<0.05)" = "#fddbc7", "Not significant" = "#eef0f2",
             "Cold, exploratory (p<0.05)" = "#d1e5f0", "Coldspot (q<0.10)" = "#67a9cf",
             "Coldspot (FDR q<0.05)" = "#2166ac")
GI_TAG <- c("Hotspot (FDR q<0.05)" = "hot2", "Hotspot (q<0.10)" = "hot1", "Hot, exploratory (p<0.05)" = "hot0",
            "Not significant" = "none", "Cold, exploratory (p<0.05)" = "cold0", "Coldspot (q<0.10)" = "cold1",
            "Coldspot (FDR q<0.05)" = "cold2")
GI_SHORT <- c("Hotspot (FDR q<0.05)" = "Hotspot", "Hotspot (q<0.10)" = "Hotspot (weak)",
              "Hot, exploratory (p<0.05)" = "Hot (exploratory)", "Not significant" = "—",
              "Cold, exploratory (p<0.05)" = "Cold (exploratory)", "Coldspot (q<0.10)" = "Coldspot (weak)",
              "Coldspot (FDR q<0.05)" = "Coldspot")
SR_COLS <- c("#2166ac", "#67a9cf", "#f7f7f7", "#ef8a62", "#b2182b")
MIN_PLAYERS <- 300
