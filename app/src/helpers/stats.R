# Player filters, observed / expected counts and formatting of numbers and effects.

fmt_int <- function(x) format(round(x), big.mark = ",", trim = TRUE)
clamp_log2 <- function(x) pmin(pmax(log2(x), -2), 2)

filter_players <- function(p, years, league, evidence, positions) {
  p <- p[p$birth_year >= years[1] & p$birth_year <= years[2], ]
  if (identical(league, "pl")) p <- p[p$premier_league, ]
  if (identical(evidence, "certain")) p <- p[p$certain, ]
  if (length(positions)) p <- p[!is.na(p$position) & p$position %in% positions, ]
  p
}

# Observed / expected / SR for any player subset (proposal section 6.4), plus Empirical
# Bayes smoothing (global method of moments, Marshall 1991).
compute_sr <- function(level, p, years) {
  if (level != "ttwa") p <- p[p$fine, ]
  b <- births[births$level == level & births$birth_year >= years[1] & births$birth_year <= years[2], ]
  n_y <- table(factor(p$birth_year, levels = years[1]:years[2]))
  B_y <- tapply(b$b, b$birth_year, sum)
  rate <- as.numeric(n_y[names(B_y)]) / B_y
  b$e <- b$b * rate[as.character(b$birth_year)]
  E <- tapply(b$e, b$unit, sum)
  O <- table(factor(p[[level]], levels = names(E)))
  d <- data.frame(unit = names(E), E = as.numeric(E), O = as.numeric(O[names(E)]))
  d$SR <- ifelse(d$E > 0, d$O / d$E, NA)
  m <- if (sum(d$E) > 0) sum(d$O) / sum(d$E) else 1
  s2 <- sum(d$E * (d$SR - m)^2, na.rm = TRUE) / sum(d$E)
  phi <- max(s2 - m / mean(d$E), 0)
  C <- phi / (phi + m / d$E)
  d$SR_EB <- m + C * (d$SR - m)
  d
}

effect_words <- function(term, RR) {
  unit <- c(dist10 = "per 10 km", imd10 = "per 10 IMD points", urban10 = "per 10 pp urban",
            club10 = "per 10 km", acad10 = "per 10 km")[term]
  sprintf("%+.0f%% %s", (RR - 1) * 100, unit)
}
sig_tag <- function(p) if (p < 0.05) tag_span("yes", "Yes") else tag_span("no", "No")
pct_txt <- function(rr) { v <- round((rr - 1) * 100); if (v == 0) "0%" else sprintf("%+d%%", v) }
