# Reusable UI building blocks: inputs, tags, bars, KPI cards and lists.

# Segmented button groups (Bootstrap btn-check) that behave as Shiny radio / checkbox inputs
seg_group <- function(id, label, choices, selected = NULL, type = c("radio", "checkbox")) {
  type <- match.arg(type)
  opts <- lapply(seq_along(choices), function(i) {
    oid <- paste0(id, "_", i)
    tagList(
      tags$input(type = type, class = "btn-check", name = id, id = oid, value = choices[[i]],
                 autocomplete = "off", checked = if (choices[[i]] %in% selected) NA),
      tags$label(class = "btn btn-outline-primary", `for` = oid, names(choices)[i])
    )
  })
  div(id = id, class = paste("seg", if (type == "radio") "shiny-input-radiogroup" else "shiny-input-checkboxgroup"),
      if (!is.null(label)) span(class = "seg-label", label),
      div(class = "btn-group btn-group-sm", role = "group", opts))
}
info <- function(text) tooltip(bs_icon("info-circle", class = "text-muted"), text, placement = "left")
tag_span <- function(class, text) span(class = paste("tag", paste0("tag-", class)), text)
with_tooltip <- function(label, tip) tags$span(title = tip, style = "text-decoration: underline dotted; cursor: help;", label)

sr_bar <- function(value) {
  if (is.na(value)) return("—")
  v <- clamp_log2(value) / 2               # -1 .. 1
  col <- if (value >= 1) "#d6604d" else "#4393c3"
  left <- if (v >= 0) 50 else 50 + 50 * v
  width <- 50 * abs(v)
  div(class = "bar-cell",
      div(class = "bar-track", div(class = "bar-mid"),
          div(class = "bar-fill", style = sprintf("left:%.1f%%;width:%.1f%%;background:%s", left, width, col))),
      span(class = "bar-num", sprintf("%.2f", value)))
}
plain_bar <- function(value, max, colour = "#5b7fa6", digits = 1) {
  if (is.na(value)) return("—")
  div(class = "bar-cell",
      div(class = "bar-track", div(class = "bar-fill", style = sprintf("left:0;width:%.1f%%;background:%s", 100 * min(value / max, 1), colour))),
      span(class = "bar-num", formatC(value, format = "f", digits = digits)))
}

glance_rows <- function(d, colour) {
  tags$ul(class = "glance-list", lapply(seq_len(nrow(d)), function(i) tags$li(
    span(class = "rk", i), span(d$name[i]),
    plain_bar(d$SR_EB[i], 2.5, colour, digits = 2))))
}
kpi <- function(icon, colour, value, label, sub) {
  div(class = "kpi", div(class = paste("ico", paste0("ico-", colour)), bs_icon(icon)),
      div(div(class = "v", value), div(class = "l", label), div(class = "s", sub)))
}
finding <- function(icon, colour, title, text, link_id, link_label) {
  div(class = "finding", div(class = paste("ico", paste0("ico-", colour)), bs_icon(icon)),
      h6(title), p(text), actionLink(link_id, paste(link_label, "→")))
}

short_region <- function(x) sub("Yorkshire and The Humber", "Yorkshire & Humber", x, fixed = TRUE)
HEADER_STYLE <- list(fontSize = ".74rem", textTransform = "uppercase", letterSpacing = ".03em",
                     color = "var(--bs-secondary-color)")
pct_bar <- function(label, value_txt, pct, note) {
  div(class = "pbar",
      div(class = "pbar-head", span(label), strong(value_txt)),
      div(class = "bar-track", div(class = "bar-fill", style = sprintf("left:0;width:%.0f%%;background:#5b7fa6", pct))),
      div(class = "pbar-note", note))
}

verdict <- function(icon, title, tag_class, tag_text, text) {
  div(class = "verdict", div(class = "verdict-head", bs_icon(icon), strong(title), tag_span(tag_class, tag_text)), p(text))
}

cluster_rows <- function(d) {
  tags$ul(class = "glance-list cluster-list", lapply(seq_len(nrow(d)), function(i) tags$li(
    span(class = "rk", i), span(d$name[i]),
    span(class = "note", sprintf("z = %+.1f", d$Gi_z[i])),
    tag_span(GI_TAG[[d$gi_class[i]]], if (d$Gi_q[i] < 0.10) "weak (q < 0.10)" else "exploratory"))))
}

change_rows <- function(d, up) {
  tags$ul(class = "glance-list change-list", lapply(seq_len(nrow(d)), function(i) tags$li(
    span(class = "rk", i), span(d$country[i]),
    span(class = if (up) "up" else "down", sprintf("%s %d", if (up) "▲" else "▼", abs(d$change[i])),
         span(class = "note", sprintf(" (%d → %d)", d$`1975–1989`[i], d$`1990–2005`[i]))))))
}
