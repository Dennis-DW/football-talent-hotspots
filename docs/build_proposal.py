"""Build the England Talent Hotspots technical research proposal as a PDF."""
import sys
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import cm
from reportlab.lib import colors
from reportlab.lib.styles import ParagraphStyle
from reportlab.lib.enums import TA_CENTER, TA_JUSTIFY
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.lib.fonts import addMapping
from reportlab.platypus import (BaseDocTemplate, PageTemplate, Frame, Paragraph, Spacer,
                                PageBreak, Table, TableStyle, KeepTogether, Preformatted)
from reportlab.platypus.tableofcontents import TableOfContents

OUT = sys.argv[1]
FD = "/usr/share/fonts/truetype/dejavu/"
pdfmetrics.registerFont(TTFont("Serif", FD + "DejaVuSerif.ttf"))
pdfmetrics.registerFont(TTFont("Serif-B", FD + "DejaVuSerif-Bold.ttf"))
pdfmetrics.registerFont(TTFont("Serif-I", FD + "DejaVuSerif-Italic.ttf"))
pdfmetrics.registerFont(TTFont("Serif-BI", FD + "DejaVuSerif-BoldItalic.ttf"))
pdfmetrics.registerFont(TTFont("Sans", FD + "DejaVuSans.ttf"))
pdfmetrics.registerFont(TTFont("Sans-B", FD + "DejaVuSans-Bold.ttf"))
pdfmetrics.registerFont(TTFont("Sans-I", FD + "DejaVuSans-Oblique.ttf"))
pdfmetrics.registerFont(TTFont("Sans-BI", FD + "DejaVuSans-BoldOblique.ttf"))
pdfmetrics.registerFont(TTFont("Mono", FD + "DejaVuSansMono.ttf"))
addMapping("Serif", 0, 0, "Serif"); addMapping("Serif", 1, 0, "Serif-B")
addMapping("Serif", 0, 1, "Serif-I"); addMapping("Serif", 1, 1, "Serif-BI")
addMapping("Sans", 0, 0, "Sans"); addMapping("Sans", 1, 0, "Sans-B")
addMapping("Sans", 0, 1, "Sans-I"); addMapping("Sans", 1, 1, "Sans-BI")

NAVY = colors.HexColor("#1F3A5F")
LIGHT = colors.HexColor("#E8EEF5")
GRID = colors.HexColor("#9AA9BC")

body = ParagraphStyle("body", fontName="Serif", fontSize=10, leading=14.5,
                      alignment=TA_JUSTIFY, spaceAfter=6)
bullet = ParagraphStyle("bullet", parent=body, leftIndent=16, bulletIndent=5, spaceAfter=3)
h1 = ParagraphStyle("h1", fontName="Sans-B", fontSize=14, leading=18, textColor=NAVY,
                    spaceBefore=14, spaceAfter=8, keepWithNext=1)
h2 = ParagraphStyle("h2", fontName="Sans-B", fontSize=11.5, leading=15, textColor=NAVY,
                    spaceBefore=10, spaceAfter=5, keepWithNext=1)
cell = ParagraphStyle("cell", fontName="Serif", fontSize=8.6, leading=11.2)
cellb = ParagraphStyle("cellb", parent=cell, fontName="Sans-B", textColor=colors.white)
caption = ParagraphStyle("cap", fontName="Sans-I", fontSize=8.5, leading=11,
                         textColor=colors.HexColor("#444444"), spaceBefore=3, spaceAfter=10,
                         alignment=TA_CENTER)
eq = ParagraphStyle("eq", parent=body, alignment=TA_CENTER, fontName="Serif-I",
                    spaceBefore=4, spaceAfter=8)
ref = ParagraphStyle("ref", parent=body, leftIndent=18, firstLineIndent=-18, alignment=0,
                     fontSize=9.3, leading=13)
mono = ParagraphStyle("mono", fontName="Mono", fontSize=7.8, leading=10.2,
                      backColor=colors.HexColor("#F4F6F8"), borderPadding=6,
                      leftIndent=6, rightIndent=6, spaceBefore=4, spaceAfter=10)


class Doc(BaseDocTemplate):
    def __init__(self, fn, **kw):
        super().__init__(fn, pagesize=A4, leftMargin=2.3 * cm, rightMargin=2.3 * cm,
                         topMargin=2.2 * cm, bottomMargin=2.2 * cm,
                         title="England Talent Hotspots: Technical Research Proposal",
                         author="Dennis Wambua", subject="Spatial analysis of professional footballer birthplaces",
                         **kw)
        f = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f")
        self.addPageTemplates([PageTemplate("cover", [f], onPage=lambda c, d: None),
                               PageTemplate("main", [f], onPage=self.decorate)])
        self._n = 0

    def decorate(self, c, d):
        c.saveState()
        c.setFont("Sans", 8); c.setFillColor(colors.HexColor("#666666"))
        c.drawString(self.leftMargin, A4[1] - 1.4 * cm,
                     "England Football Talent Hotspots — Technical Research Proposal")
        c.drawRightString(A4[0] - self.rightMargin, A4[1] - 1.4 * cm, "Version 2.1 · November 2026")
        c.setStrokeColor(GRID); c.setLineWidth(0.4)
        c.line(self.leftMargin, A4[1] - 1.55 * cm, A4[0] - self.rightMargin, A4[1] - 1.55 * cm)
        c.drawCentredString(A4[0] / 2, 1.2 * cm, f"Page {d.page - 1}")
        c.restoreState()

    def afterFlowable(self, fl):
        if isinstance(fl, Paragraph) and fl.style.name in ("h1", "h2"):
            lvl = 0 if fl.style.name == "h1" else 1
            text = fl.getPlainText()
            key = "k%x" % (hash(text) & 0xffffffff)
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=lvl, closed=lvl > 0)
            self.notify("TOCEntry", (lvl, text, self.page - 1, key))


S = []
P = lambda t, s=body: S.append(Paragraph(t, s))
H1 = lambda t: S.append(Paragraph(t, h1))
H2 = lambda t: S.append(Paragraph(t, h2))


def B(items):
    for t in items:
        S.append(Paragraph(t, bullet, bulletText="•"))
    S.append(Spacer(1, 4))


def T(rows, widths, cap=None, zebra=True):
    data = [[Paragraph(str(x), cellb) for x in rows[0]]] + \
           [[Paragraph(str(x), cell) for x in r] for r in rows[1:]]
    tw = sum(widths)
    t = Table(data, colWidths=[w / tw * (A4[0] - 4.6 * cm) for w in widths], repeatRows=1)
    st = [("BACKGROUND", (0, 0), (-1, 0), NAVY),
          ("GRID", (0, 0), (-1, -1), 0.4, GRID),
          ("VALIGN", (0, 0), (-1, -1), "TOP"),
          ("TOPPADDING", (0, 0), (-1, -1), 3.5), ("BOTTOMPADDING", (0, 0), (-1, -1), 3.5),
          ("LEFTPADDING", (0, 0), (-1, -1), 4.5), ("RIGHTPADDING", (0, 0), (-1, -1), 4.5)]
    if zebra:
        for i in range(2, len(data), 2):
            st.append(("BACKGROUND", (0, i), (-1, i), LIGHT))
    t.setStyle(TableStyle(st))
    S.append(t)
    if cap:
        S.append(Paragraph(cap, caption))
    else:
        S.append(Spacer(1, 8))


# ---------------------------------------------------------------- Cover
S.append(Spacer(1, 4.0 * cm))
S.append(Paragraph("TECHNICAL RESEARCH PROPOSAL", ParagraphStyle(
    "k", fontName="Sans-B", fontSize=10, textColor=colors.HexColor("#5A6F8C"),
    alignment=TA_CENTER, spaceAfter=18)))
S.append(Paragraph("Where Do England's Premier League and Championship Footballers Come From?",
                   ParagraphStyle("t", fontName="Sans-B", fontSize=21, leading=27, textColor=NAVY,
                                  alignment=TA_CENTER, spaceAfter=10)))
S.append(Paragraph("Detecting Birthplace Hotspots Across English Local Areas Beyond Population Density, "
                   "and Their Social and Spatial Correlates", ParagraphStyle(
    "st", fontName="Serif-I", fontSize=13, leading=19, alignment=TA_CENTER,
    textColor=colors.HexColor("#333333"), spaceAfter=36)))
cov = Table([[Paragraph("<b>Study population</b>", cell), Paragraph("Players with Premier League or Championship careers, born 1975–2005", cell)],
             [Paragraph("<b>Main analysis</b>", cell), Paragraph("English-born players, analysed across English local areas", cell)],
             [Paragraph("<b>Discipline</b>", cell), Paragraph("Spatial statistics · Sports geography · Spatial epidemiology methods", cell)],
             [Paragraph("<b>Prepared by</b>", cell), Paragraph("Dennis Wambua", cell)],
             [Paragraph("<b>Version / date</b>", cell), Paragraph("2.1 · 2 November 2026", cell)],
             [Paragraph("<b>Status</b>", cell), Paragraph("Proposal for review", cell)]],
            colWidths=[4 * cm, 9.5 * cm])
cov.setStyle(TableStyle([("LINEBELOW", (0, 0), (-1, -1), 0.4, GRID),
                         ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5)]))
S.append(cov)
S.append(Spacer(1, 3.0 * cm))
S.append(Paragraph("All data sources used in this study are openly available at no cost. "
                   "Results are intended for academic and non-commercial use.",
                   ParagraphStyle("n", parent=caption, fontSize=8)))

from reportlab.platypus.doctemplate import NextPageTemplate
S.append(NextPageTemplate("main"))
S.append(PageBreak())

# ---------------------------------------------------------------- Abstract
S.append(Paragraph("Abstract", ParagraphStyle("ah", parent=h1, spaceBefore=0)))
P("English football invests heavily in finding young talent, yet it is unclear whether the players who reach the "
  "Premier League and Championship come from across England in proportion to population, or whether certain "
  "towns and districts produce far more than their size would suggest. This proposal sets out a reproducible, "
  "fully open-data study of players born between 1975 and 2005 who played in the top two English divisions. "
  "The main analysis focuses on English-born players and tests whether their birthplaces are spatially clustered "
  "<i>beyond</i> population, locates statistically significant hotspots and coldspots across local authority "
  "districts and regular grids, and evaluates whether deprivation, urbanisation "
  "and proximity to professional clubs and academies help explain the pattern. Player records come from Wikidata; "
  "division membership by season comes from the engsoccerdata archive, extended to the present season; expected "
  "counts are derived from Office for National Statistics live births by local authority in each player's birth "
  "year. The analysis combines "
  "inhomogeneous point-pattern statistics, Empirical-Bayes-adjusted Moran's I, Getis-Ord Gi* and LISA hotspot "
  "detection, and negative-binomial and spatial regression models. A secondary, descriptive analysis maps the "
  "countries that supply foreign-born players to the two leagues. Outputs comprise a cleaned open dataset, hotspot "
  "maps, a methods-and-results report and an interactive R Shiny dashboard.")
P("<b>Keywords:</b> Premier League, EFL Championship, talent identification, birthplace effect, spatial point "
  "patterns, hotspot analysis, Getis-Ord Gi*, spatial regression, deprivation, Wikidata")

S.append(PageBreak())
S.append(Paragraph("Table of Contents", ParagraphStyle("toch", parent=h1, spaceBefore=0)))
toc = TableOfContents()
toc.levelStyles = [ParagraphStyle("t0", fontName="Sans-B", fontSize=9.5, leading=11, leftIndent=0, spaceBefore=0, spaceAfter=0),
                   ParagraphStyle("t1", fontName="Serif", fontSize=9, leading=10.5, leftIndent=14, spaceBefore=0, spaceAfter=0)]
S.append(toc)
S.append(PageBreak())

# ---------------------------------------------------------------- 1 Introduction
H1("1. Introduction")
H2("1.1 Background")
P("The Premier League and the EFL Championship are the top two tiers of English football and among the most "
  "closely followed competitions in the world. Clubs in both divisions run youth academies, and since 2012 the "
  "Elite Player Performance Plan (EPPP) has graded those academies into categories that shape where young players "
  "are recruited and trained. Despite this investment, there is little systematic, population-adjusted evidence "
  "on <i>where in England</i> top-flight and second-tier players are born.")
P("Research on the \"birthplace effect\" shows that, in several sports, the size and type of community in which "
  "an athlete is born is associated with the likelihood of reaching elite level (Côté et al., 2006; MacDonald "
  "et al., 2009). Most of that work relies on broad city-size categories rather than formal spatial statistics. "
  "England offers ideal conditions for a more rigorous test: its players are well documented in open databases "
  "such as Wikidata (Vrandečić &amp; Krötzsch, 2014), and the Office for National Statistics (ONS) publishes "
  "detailed, openly licensed population, boundary and deprivation data for small areas.")
H2("1.2 Problem Statement")
P("Maps of where English footballers are born largely reproduce maps of where people live: large cities "
  "naturally produce more players. Without an explicit population baseline it is impossible to say whether an "
  "apparent \"talent hotbed\" is genuinely exceptional or simply populous. Standard mapping and regression also "
  "ignore spatial dependence, which can make hotspot claims misleading. In addition, roughly two-thirds of "
  "Premier League players are born abroad, so a study that pools all players would measure clubs' international "
  "recruitment rather than domestic talent production. There is currently no open, reproducible, multi-scale "
  "analysis that tests whether English-born Premier League and Championship players are concentrated in "
  "particular areas beyond what population predicts.")

# ---------------------------------------------------------------- 2 Literature
H1("2. Literature Review")
H2("2.1 Birthplace Effects in Sport")
P("Côté, MacDonald, Baker and Abernethy (2006) showed that athletes from mid-sized communities were "
  "over-represented among professional players in several North American sports, introducing the term "
  "\"birthplace effect.\" MacDonald et al. (2009) reported a similar place-of-birth influence in American "
  "football. These studies establish that place matters, but they use population-size categories rather than "
  "continuous spatial methods and have not examined English football at small-area level.")
H2("2.2 Spatial Methods for Clustering and Hotspots")
P("Ripley's K-function (Ripley, 1977) is the standard tool for detecting clustering in point patterns; its "
  "inhomogeneous extension (Baddeley et al., 2000) tests clustering against a varying background intensity such "
  "as population. For area-level rates, global Moran's I measures overall spatial autocorrelation, and the "
  "Empirical-Bayes index of Assunção and Reis (1999) corrects it for unequal population sizes. Local hotspots are "
  "identified with the Getis-Ord G<sub>i</sub>* statistic (Getis &amp; Ord, 1992) and Local Indicators of Spatial "
  "Association (Anselin, 1995). Many simultaneous local tests are controlled with the false discovery rate "
  "(Benjamini &amp; Hochberg, 1995).")
H2("2.3 Spatial Regression and Scale")
P("When model residuals are spatially autocorrelated, spatial lag and spatial error models (Anselin, 1988) or "
  "Bayesian BYM2 models for counts (Riebler et al., 2016) give valid inference. Results from aggregated data can "
  "change with the choice of boundaries — the Modifiable Areal Unit Problem (Openshaw, 1984) — so analysis at "
  "several scales is required.")
H2("2.4 Research Gap")
P("No published study, to our knowledge, combines (i) a complete list of Premier League and Championship players "
  "born over three decades, (ii) a birth-year-matched official population baseline, (iii) small-area analysis "
  "across England, and (iv) formal point-pattern, hotspot and spatial-regression methods, together with "
  "deprivation and club-proximity covariates. This proposal addresses that gap.")

# ---------------------------------------------------------------- 3 Aims
H1("3. Aim, Objectives, Research Questions and Hypotheses")
H2("3.1 Aim")
P("To determine whether, where and why English-born Premier League and Championship footballers are concentrated "
  "in particular areas of England beyond what population predicts.")
H2("3.2 Specific Objectives")
B(["<b>O1.</b> Build a clean, geocoded dataset of Premier League and Championship players born 1975–2005, with each player's divisions and seasons.",
   "<b>O2.</b> Derive birth-year-matched expected player counts from ONS live-births data for several spatial units in England.",
   "<b>O3.</b> Test for clustering of English-born players' birthplaces beyond population using inhomogeneous point-pattern statistics.",
   "<b>O4.</b> Identify and map significant hotspots and coldspots across English local areas at several scales.",
   "<b>O5.</b> Estimate associations between hotspot intensity and deprivation, urbanisation and proximity to professional clubs and academies.",
   "<b>O6.</b> Describe the countries supplying foreign-born players to the two leagues.",
   "<b>O7.</b> Publish an open, reproducible code base, dataset and interactive dashboard."])
H2("3.3 Research Questions")
T([["Code", "Research question", "Objective(s)"],
   ["RQ1", "Are the birthplaces of English-born Premier League and Championship players more clustered than population alone would predict?", "O1–O3"],
   ["RQ2", "Where in England are the statistically significant hotspots and coldspots of player production?", "O4"],
   ["RQ3", "Is hotspot intensity associated with deprivation, urbanisation or proximity to professional clubs and academies, after controlling for population?", "O5"],
   ["RQ4 (desc.)", "Which countries and regions supply foreign-born players to the two leagues, and how has this changed across birth cohorts?", "O6"]],
  [1.9, 8.3, 2], "Table 1. Research questions mapped to objectives.")
H2("3.4 Hypotheses")
T([["Hypothesis", "Statement", "Test"],
   ["H0 (null)", "English-born players' births are distributed in proportion to population; every area produces players at its expected rate.", "Inhomogeneous K/L envelopes; EB Moran's I"],
   ["H1", "Some areas of England produce significantly more (hotspots) or fewer (coldspots) players than population predicts.", "Gi*, LISA with FDR correction"],
   ["H2", "Hotspot intensity is associated with deprivation, urbanisation and proximity to professional clubs and academies.", "NB / spatial regression coefficients"]],
  [2.0, 6.8, 3.4], "Table 2. Hypotheses and statistical tests. RQ4 is descriptive and has no formal hypothesis.")

# ---------------------------------------------------------------- 4 Significance
H1("4. Significance of the Study")
B(["<b>Scientific:</b> provides the first population-adjusted, multi-scale test of the birthplace effect for English top-two-division football, using methods from spatial epidemiology.",
   "<b>Practical:</b> shows clubs, academies, the Premier League, the EFL and the Football Association which areas over- and under-produce players relative to population, informing scouting coverage and grassroots investment.",
   "<b>Social:</b> tests whether deprivation helps or hinders the route to professional football, a question of interest to local authorities and community sport.",
   "<b>Methodological:</b> demonstrates a reusable open-data pipeline (Wikidata + ONS + spatial statistics) applicable to other sports and countries.",
   "<b>Open science:</b> all data, code and results are released for reuse and verification."])

# ---------------------------------------------------------------- 5 Scope
H1("5. Scope and Delimitations")
T([["Dimension", "Included", "Excluded"],
   ["Players", "Men who played for a club during a season in which it was in the Premier League or Championship", "Players whose highest level was League One or below; women's football (possible future study)"],
   ["Birth cohort", "Born 1 Jan 1975 – 31 Dec 2005", "Earlier births (outside the Premier League era); later births (careers incomplete)"],
   ["Seasons", "1992/93 to 2025/26 for the Premier League; matching seasons for the second tier (First Division to 2004, Championship from 2004/05)", "Seasons before 1992/93"],
   ["Main analysis", "English-born players, analysed across England", "Scotland, Wales and Northern Ireland (different statistics and deprivation indices)"],
   ["Secondary analysis", "Foreign-born and other UK-born players, by country of birth (descriptive)", "Hotspot inference outside England"],
   ["Variables", "Birthplace, birth year, position, divisions and seasons, population, deprivation, urbanisation, distance to clubs and academies", "Match physical metrics, wages, transfer fees, ethnicity"]],
  [1.8, 5.4, 5], "Table 3. Scope of the study.")
P("<b>Operational definitions.</b> A <i>study player</i> is a Wikidata item with occupation \"association football "
  "player\" (P106 = Q937857), sex male (P21 = Q6581097), and a club membership (P54) whose start and end dates "
  "overlap a season in which that club was in the Premier League or the second tier, as recorded in the "
  "engsoccerdata archive. Where Wikidata records matches played for a membership (P1350), a value of at least one "
  "is required. The <i>Premier League subset</i> comprises players with at least one such membership in a "
  "Premier League season. <i>English-born</i> means the birthplace coordinates fall inside England.")

# ---------------------------------------------------------------- 6 Methodology
H1("6. Methodology")
H2("6.1 Research Design")
P("The study is a quantitative, observational, cross-sectional spatial analysis. It follows the logic of "
  "disease-mapping studies in spatial epidemiology: observed counts of an outcome (players born in an area) are "
  "compared with counts expected from the population of that area, and departures from expectation are tested "
  "for spatial structure and explained with covariates.")
H2("6.2 Data Sources")
T([["Dataset", "Provider", "Resolution / period", "Use", "Licence"],
   ["Player records (birthplace, coordinates, birth date, clubs and dates, position)", "Wikidata SPARQL endpoint", "Point; births 1975–2005", "Main outcome data", "CC0"],
   ["Club division by season", "engsoccerdata (R package, Curley); later seasons from published league tables and Wikidata season items", "Season; package to 2015/16, compiled 2016/17–2025/26", "Which clubs were in each tier each season", "Open source / CC0"],
   ["Live births by area of usual residence (male births where available)", "ONS (via Nomis and ONS birth statistics)", "Local authority; annual", "Expected counts (primary baseline)", "Open Government Licence v3.0"],
   ["Population estimates and censuses", "ONS (via Nomis)", "Local authority; 1981 onward; Censuses 1981, 1991, 2001", "Fallback baseline; sensitivity analysis", "Open Government Licence v3.0"],
   ["Boundaries: local authority districts, MSOAs, LSOAs", "ONS Open Geography Portal", "Vector", "Aggregation units", "Open Government Licence v3.0"],
   ["English Indices of Deprivation", "MHCLG", "LSOA", "Deprivation covariate", "Open Government Licence v3.0"],
   ["Rural-Urban Classification", "ONS", "LSOA / local authority", "Urbanisation covariate", "Open Government Licence v3.0"],
   ["Population grid", "GHS-POP (EU JRC)", "1 km; 1975–2005", "Intensity surface for point-pattern analysis", "CC BY 4.0"],
   ["Club grounds and academies", "Wikidata (home venue P115 → P625); published EPPP category lists (2012 onward)", "Point; by season", "Distance covariates", "CC0 / public information"],
   ["Country populations (secondary analysis)", "UN World Population Prospects", "Country; annual", "Players per million by country", "CC BY 3.0 IGO"]],
  [3.2, 2.6, 2.5, 2.3, 1.8], "Table 4. Data sources. All are free to access.")
H2("6.3 Baseline: Births by Area and Year")
P("The baseline for expected counts is the number of <b>live births</b> in each area in each birth year — male "
  "births where ONS publishes them by sex — rather than total population. Births measure the pool of children "
  "from which each cohort of players came; total population is distorted in areas with many students or retirees, "
  "which would otherwise appear as false coldspots.")
P("Where local-authority births are not available on current boundaries for a given year (most likely for the "
  "earliest birth years), the baseline falls back to ONS mid-year population estimates, using 1981 estimates for "
  "players born 1975–1980, apportioned to current boundaries using the 1 km GHS-POP grid where necessary. Every "
  "fallback is recorded, and a sensitivity analysis repeats the main results with the total-population baseline.")
H2("6.4 Outcome Measure")
P("For each spatial unit <i>i</i>, the expected count is the sum over birth years <i>y</i> of the unit's "
  "births multiplied by England's player rate per birth in that year:")
S.append(Paragraph("E<sub>i</sub> = Σ<sub>y</sub> B<sub>i,y</sub> × ( N<sub>y</sub> / B<sub>England,y</sub> )", eq))
P("where B<sub>i,y</sub> is the number of births in unit <i>i</i> in year <i>y</i> and N<sub>y</sub> is the number "
  "of English-born study players born in year <i>y</i>. The <b>Standardised "
  "Ratio</b> is SR<sub>i</sub> = O<sub>i</sub> / E<sub>i</sub>, where O<sub>i</sub> is the observed count. SR = 1 "
  "indicates production equal to expectation; SR = 2 indicates twice the expected number.")
H2("6.5 Spatial Units")
T([["Unit", "Approximate number in England", "Role"],
   ["Local authority districts (current boundaries)", "≈ 300", "Main unit for hotspot analysis and regression"],
   ["Middle-layer super output areas (MSOAs)", "≈ 6,800", "Optional extension: fine-scale sensitivity analysis, only if time allows"],
   ["Regular hexagon grid, 10 km and 20 km", "≈ 1,500 and ≈ 400", "Boundary-free robustness check"],
   ["Regions (ITL1)", "9", "Summary reporting"]],
  [4.6, 3, 4.4], "Table 5. Spatial units of analysis.")
H2("6.6 Data Processing Pipeline")
S.append(KeepTogether([Preformatted(
"""  Wikidata SPARQL (players, clubs, dates)     engsoccerdata (club tier by season)
                 │                                       │
                 └──────────► Season-level eligibility ◄─┘
                                       │
                                       ▼
          Clean & validate ──► Geocoding fallback (missing coordinates only)
                                       │
              ┌────────────────────────┴───────────────────────┐
              ▼                                                 ▼
   English-born (main analysis)                 Foreign / other UK-born (descriptive)
              │
              ▼
   ONS population · IMD · Rural-Urban · club & academy distances
              │
              ▼
   PostgreSQL + PostGIS  (storage, spatial joins, GiST indexes)
              │
              ▼
   R: point patterns ► aggregation ► hotspots ► regression ► robustness
              │
              ▼
   R Shiny + Leaflet dashboard""", mono),
    Paragraph("Figure 1. Data processing and analysis pipeline.", caption)]))
P("<b>Cleaning rules.</b>")
B(["Retain records with birth dates between 1975-01-01 and 2005-12-31.",
   "Retain players with at least one club membership overlapping a Premier League or second-tier season.",
   "Deduplicate on Wikidata QID.",
   "Discard coordinates falling in the sea or outside the recorded birth country.",
   "Exclude records resolved only to country level from the spatial analyses (retained for the descriptive analysis).",
   "Write every excluded record and its reason to an exclusion log."])
P("<b>Season assignment rule.</b> Wikidata club dates are often recorded to the year only. To avoid case-by-case "
  "judgements, the following rule is fixed before any data are inspected:")
B(["A year-only <b>start</b> date <i>Y</i> is assigned to the season beginning in August of <i>Y</i> (e.g., 2004 → 2004/05).",
   "A year-only <b>end</b> date <i>Y</i> is assigned to the season ending in May of <i>Y</i> (e.g., 2004 → 2003/04).",
   "A membership that starts and ends in the same year is assigned to the season ending in that year if the start is year-only, otherwise to the season containing the full date.",
   "Full dates are assigned to the season that contains them; dates in June or July belong to the following season.",
   "Any membership whose eligibility depends on a year-only date in a season when the club changed division (promotion or relegation) is flagged as <i>ambiguous</i>. Main results include ambiguous cases; a sensitivity run excludes them."])
P("<b>Validation of league eligibility.</b> A random sample of 200 players is checked manually against "
  "published season squad lists to estimate the false-inclusion and false-exclusion rates of the Wikidata-based "
  "definition, including the error rate of the season assignment rule for ambiguous cases.")
P("<b>Geocoding fallback.</b> Only for birthplaces lacking coordinates, a Python routine (geopy / Nominatim, "
  "rate-limited to one request per second) queries town, then county, then country, and records the resolution "
  "level achieved.")
H2("6.7 Coordinate Reference Systems")
T([["Operation", "CRS / method", "Rationale"],
   ["Storage", "EPSG:4326 (WGS 84)", "Universal interchange standard"],
   ["Distances, densities, grids, areas", "EPSG:27700 (British National Grid, metres)", "Official projection for Great Britain; accurate distances and areas"],
   ["Web display", "EPSG:3857 (Web Mercator)", "Display only — never used for measurement"]],
  [3, 4.4, 4.6], "Table 6. Coordinate reference systems.")
P("All geometry columns carry GiST indexes. Because many players share an identical town-centre coordinate, "
  "points are jittered by up to ±500 m for point-pattern analysis only; aggregated analyses use original "
  "coordinates.")

H2("6.8 Analytical Methods")
P("<b>(a) Exploratory analysis.</b> Players per 100,000 population by region and local authority; kernel density "
  "surfaces of player births and of population; and a relative-risk surface (player density ÷ population "
  "density) estimated with <i>spatstat::relrisk</i>.")
P("<b>(b) RQ1 — clustering beyond population.</b> The inhomogeneous K and L functions "
  "(<i>spatstat::Kinhom</i>) are estimated within the England boundary, using the population surface as the "
  "background intensity. Global envelopes from 999 Monte Carlo simulations of births distributed in proportion to "
  "population form the null model; an observed curve above the envelope indicates clustering beyond population.")
P("<b>(c) RQ2 — hotspot location.</b> Standardised Ratios are Empirical-Bayes smoothed to stabilise estimates in "
  "small-population units. Global autocorrelation is measured with the EB Moran's I (<i>spdep::EBImoran.mc</i>, "
  "999 permutations). Local hotspots and coldspots are identified with Getis-Ord G<sub>i</sub>* "
  "(<i>spdep::localG_perm</i>) and Local Moran's I (LISA), classifying units as High-High, Low-Low, High-Low or "
  "Low-High. P-values are adjusted with the Benjamini-Hochberg false discovery rate (q = 0.05).")
T([["Spatial unit", "Neighbour definition", "Robustness alternative"],
   ["Local authorities / MSOAs", "Queen contiguity (row-standardised); islands such as the Isle of Wight linked to nearest neighbour", "Inverse distance, 30 km cut-off"],
   ["10 km / 20 km hexagons", "k-nearest neighbours, k = 6", "k = 4 and k = 8"]],
  [3.2, 5, 3.8], "Table 7. Spatial weights specifications.")
P("<b>(d) RQ3 — explanatory modelling.</b> A negative binomial model is fitted with the expected count as an "
  "offset, so that coefficients describe departures from births-based expectation:")
S.append(Paragraph("O<sub>i</sub> ~ NegBin(μ<sub>i</sub>)", eq))
S.append(Paragraph("log μ<sub>i</sub> = log E<sub>i</sub> + β<sub>1</sub>IMD<sub>i</sub> + β<sub>2</sub>Urban<sub>i</sub> + "
                   "β<sub>3</sub>DistClub<sub>i</sub> + γ<sub>r</sub>", eq))
P("where IMD<sub>i</sub> is the population-weighted deprivation score, Urban<sub>i</sub> the urban share, "
  "DistClub<sub>i</sub> the cohort-weighted distance to the nearest professional (Football League or Premier League) "
  "club <i>at the time each cohort was aged 12</i>, and γ<sub>r</sub> region fixed effects. Every professional club ran "
  "youth development throughout the study period, so this measure applies to all cohorts.")
P("<b>Academy-era sub-model.</b> Category 1 academies exist only since the Elite Player Performance Plan began in "
  "2012, so distance to the nearest Category 1 academy (DistAcademy<sub>i</sub>) is <i>not</i> used for the whole "
  "cohort. It is added in a separate model restricted to players born 1996–2005, who were aged 16 or under when "
  "EPPP began and could therefore have been developed within it. Comparing DistClub in the two cohorts shows "
  "whether proximity mattered differently before and after EPPP.")
P("Residuals are tested for "
  "spatial autocorrelation with Moran's I. If significant, robust Lagrange Multiplier tests "
  "(<i>spdep::lm.RStests</i>) guide the choice between a Spatial Error Model (<i>spatialreg::errorsarlm</i>) and "
  "a Spatial Lag Model (<i>spatialreg::lagsarlm</i>) fitted to log EB-smoothed SR. As an optional extension, only "
  "if time allows, a BYM2 Poisson model (R-INLA) is fitted as a count-based alternative. Results are reported as rate ratios with 95% confidence (or credible) "
  "intervals, the spatial parameters ρ or λ, and AIC / log-likelihood model comparison.")
P("<b>(e) RQ4 — foreign-born supply (descriptive).</b> Counts of foreign-born and other UK-born players by "
  "country of birth, players per million national population, and changes between the 1975–1989 and 1990–2005 "
  "birth cohorts, shown as choropleth and flow maps. No hotspot inference is made, because these players are a "
  "selected subset of each country's footballers.")

H2("6.9 Robustness and Sensitivity Analyses")
T([["Check", "Purpose"],
   ["Multiple scales: local authority, 10 km and 20 km hexagons (MSOA optional)", "Assess sensitivity to the Modifiable Areal Unit Problem"],
   ["Cohort split: 1975–1989 vs 1990–2005", "Test stability of hotspots across generations and before / after EPPP"],
   ["Premier League subset vs all study players", "Test whether hotspots differ by level reached"],
   ["Truncate cohort at 2002", "Check bias from incompletely recorded youngest players"],
   ["Exclude the largest cities (London, Birmingham, Manchester, Liverpool, Leeds)", "Check that hotspots are not simply big-city effects"],
   ["Alternative neighbour definitions (Table 7)", "Test sensitivity to spatial weights"],
   ["Total-population baseline instead of births", "Check the effect of the births baseline"],
   ["Exclude ambiguous season assignments", "Check the effect of year-only Wikidata dates"]],
  [6, 6], "Table 8. Robustness checks.")

H2("6.10 Validation and Quality Assurance")
B(["<b>Coordinate integrity:</b> unit tests confirm that round-trip transformations between EPSG:4326 and EPSG:27700 return points within 1 m.",
   "<b>Data checks:</b> all English-born points fall inside England; local authority births sum to the published England total within 1%; all birth years lie in 1975–2005.",
   "<b>League eligibility check:</b> the 200-player manual validation sample (Section 6.6).",
   "<b>Null-model test:</b> players simulated purely in proportion to population must yield no significant hotspots after FDR correction, showing that the pipeline does not generate false positives.",
   "<b>Code review</b> of the analysis scripts before results are finalised."])

# ---------------------------------------------------------------- 7 Tech
H1("7. Technical Architecture and Tools")
T([["Component", "Technology", "Function"],
   ["Development environment", "GitHub Codespaces (dev container)", "Reproducible cloud workspace with GDAL, GEOS and PROJ"],
   ["Analysis", "R: sf, terra, spatstat, spdep, spatialreg, MASS, engsoccerdata, tidyverse (INLA optional)", "Spatial processing, statistics and modelling"],
   ["Data acquisition", "Python: requests, SPARQLWrapper, geopy, pandas", "Wikidata extraction and geocoding fallback"],
   ["Database", "PostgreSQL 16 + PostGIS 3 (Docker service)", "Spatial storage, joins and indexing"],
   ["Visualisation", "R Shiny + Leaflet", "Interactive dashboard"],
   ["Version control", "Git / GitHub", "Code history and collaboration"],
   ["Deployment", "shinyapps.io (free tier)", "Public dashboard hosting"]],
  [2.8, 4.8, 4.6], "Table 9. Technology stack (all open source or free tier).")
P("<b>Dashboard design.</b> (1) England hotspot map with Gi* classes, switchable between local authority, MSOA "
  "and hexagon scales, with player popups; (2) density explorer comparing player density, population density and "
  "relative risk; (3) drivers panel showing model coefficients and SR-versus-deprivation and distance plots; "
  "(4) world map of foreign-born supply; (5) filters for league (Premier League / Championship / both), birth "
  "cohort, position and region.")

# ---------------------------------------------------------------- 8 Data mgmt
H1("8. Data Management and Reproducibility")
B(["<b>Versioned raw data:</b> each Wikidata extraction is stored as a dated Parquet snapshot so results can be reproduced after Wikidata changes.",
   "<b>Environment locking:</b> R packages pinned with renv; Python packages pinned in requirements.txt; database defined in docker-compose.",
   "<b>Determinism:</b> fixed random seeds for all permutation tests, simulations and jittering.",
   "<b>Directory structure:</b> data/raw, data/processed, R/, python/, sql/, app/, docs/, tests/.",
   "<b>Documentation:</b> data dictionary (Appendix A), exclusion log, eligibility validation report, and a README describing how to rerun the full pipeline.",
   "<b>Sharing:</b> code under an MIT licence; derived aggregated data under CC BY 4.0 with attribution to all upstream sources, including the Open Government Licence statement for ONS and MHCLG data."])

# ---------------------------------------------------------------- 9 Ethics
H1("9. Ethical and Legal Considerations")
B(["<b>Nature of data:</b> only publicly available information about public figures (name, birth date, birthplace, clubs) is used. No sensitive personal data — such as ethnicity, health or religion — is collected.",
   "<b>Data protection:</b> processing follows the data-minimisation and purpose-limitation principles of the UK GDPR and Data Protection Act 2018. The research purpose is non-commercial and statistical.",
   "<b>Publication of results:</b> findings are reported for aggregated spatial units. The dashboard shows only fields already public on Wikidata.",
   "<b>Licensing compliance:</b> all upstream licences are respected and credited.",
   "<b>Interpretation:</b> results describe area-level patterns and must not be used to make claims about individuals or to stereotype towns or communities, particularly when discussing deprivation."])

# ---------------------------------------------------------------- 10 Limits
H1("10. Limitations and Risk Management")
T([["Risk / limitation", "Likelihood", "Impact", "Mitigation"],
   ["Wikidata club dates incomplete or year-only", "High", "High", "Pre-defined season assignment rule; ambiguity flag; 200-player validation; sensitivity run"],
   ["Club membership does not guarantee an appearance", "Medium", "Medium", "Use matches-played qualifier where present; validation sample"],
   ["engsoccerdata ends at 2015/16 (≈10 seasons missing)", "Certain", "Medium", "Compile 2016/17–2025/26 club-tier table in Week 1 from league tables and Wikidata; cross-check"],
   ["Local-authority births unavailable for earliest years", "Medium", "Medium", "Fallback to population estimates; record fallbacks; sensitivity analysis"],
   ["Academy variable anachronistic for pre-EPPP cohorts", "Certain", "Medium", "Academy distance used only for players born 1996–2005"],
   ["Timeline overrun (≈135 hours)", "Medium", "High", "BYM2 and MSOA analysis designated optional extensions"],
   ["Birthplace recorded as hospital town, not home town", "High", "Medium", "Local authority and coarser scales; stated as limitation"],
   ["Birthplace differs from where a player grew up", "Medium", "Medium", "Coarser-scale analyses; stated as limitation"],
   ["Deprivation measured today, not at birth", "High", "Medium", "Sensitivity analysis with older deprivation releases; stated as limitation"],
   ["Youngest cohort (2003–05) incompletely recorded", "Medium", "Medium", "Cohort split; sensitivity run truncated at 2002"],
   ["Unstable rates in small-population areas", "High", "Medium", "Empirical Bayes smoothing; minimum-births thresholds"],
   ["Spatial autocorrelation in residuals", "High", "High", "Spatial error / lag models; BYM2 if time allows"],
   ["Modifiable Areal Unit Problem", "High", "Medium", "Multi-scale analysis (Table 8)"],
   ["Ecological fallacy", "Medium", "Medium", "Area-level interpretation only"]],
  [3.6, 1.7, 1.3, 4.6], "Table 10. Risk register.")

# ---------------------------------------------------------------- 11 Work plan
H1("11. Work Plan and Timeline")
weeks = ["W1", "W2", "W3", "W4", "W5", "W6"]
tasks = [("Environment set-up; club-tier table to 2025/26; Wikidata extraction; season rule; data-quality report", [1]),
         ("ONS births and population, boundaries, IMD, urbanisation; club and academy locations; aggregation", [2]),
         ("Exploratory analysis; KDE; inhomogeneous K (RQ1)", [3]),
         ("EB Moran's I; Gi*; LISA hotspots (RQ2)", [4]),
         ("Regression models; robustness checks (RQ3); foreign-born summary (RQ4)", [5]),
         ("Dashboard; documentation; final report; deployment", [6]),
         ("Validation and testing (continuous)", [1, 2, 3, 4, 5, 6])]
gdata = [[Paragraph("Activity", cellb)] + [Paragraph(w, cellb) for w in weeks]]
for t, ws in tasks:
    gdata.append([Paragraph(t, cell)] + ["" for _ in weeks])
g = Table(gdata, colWidths=[8.6 * cm] + [(A4[0] - 4.6 * cm - 8.6 * cm) / 6] * 6)
gst = [("BACKGROUND", (0, 0), (-1, 0), NAVY), ("GRID", (0, 0), (-1, -1), 0.4, GRID),
       ("VALIGN", (0, 0), (-1, -1), "MIDDLE"), ("ALIGN", (1, 0), (-1, 0), "CENTER")]
for r, (_, ws) in enumerate(tasks, start=1):
    for w in ws:
        gst.append(("BACKGROUND", (w, r), (w, r), colors.HexColor("#4A7BB7") if len(ws) == 1
                    else colors.HexColor("#B9CCE4")))
g.setStyle(TableStyle(gst))
S.append(g)
S.append(Paragraph("Figure 2. Gantt chart of the six-week work plan.", caption))
T([["Milestone", "Week", "Deliverable"],
   ["M1", "1", "Clean player dataset with league-season eligibility and data-quality report"],
   ["M2", "2", "Enriched, aggregated analysis-ready database"],
   ["M3", "4", "Clustering and hotspot results (RQ1, RQ2)"],
   ["M4", "5", "Model results, robustness report and foreign-born summary (RQ3, RQ4)"],
   ["M5", "6", "Final report, public dashboard and code release"]],
  [1.5, 1.2, 9.3], "Table 11. Milestones and deliverables.")

# ---------------------------------------------------------------- 12 Budget
H1("12. Budget and Resources")
T([["Item", "Source", "Cost"],
   ["Player data", "Wikidata", "Free"],
   ["League history", "engsoccerdata", "Free"],
   ["Births, population, boundaries, deprivation, urbanisation", "ONS; MHCLG (Open Government Licence)", "Free"],
   ["Population grid and country populations", "EU JRC GHSL; UN World Population Prospects", "Free"],
   ["Software", "R, Python, PostgreSQL/PostGIS, Shiny (open source)", "Free"],
   ["Compute", "GitHub Codespaces personal free allowance", "Free"],
   ["Hosting", "shinyapps.io free tier", "Free"],
   ["<b>Total</b>", "", "<b>0</b>"]],
  [4, 6, 2], "Table 12. Budget. The project can be completed at no direct cost.")
P("<b>Human resources:</b> one researcher, approximately 20–25 hours per week for six weeks (about 135 hours). "
  "<b>Scope control:</b> the core analysis uses local authorities and hexagon grids with spatial error / lag models; "
  "the MSOA-level analysis and the BYM2 (R-INLA) model are optional extensions undertaken only if the core is "
  "complete. "
  "<b>Contingency:</b> if free compute is insufficient for the 999-simulation envelopes, exploratory runs use 199 "
  "simulations and the full 999 are run only for final results.")

# ---------------------------------------------------------------- 13 Outcomes
H1("13. Expected Outcomes and Dissemination")
B(["A cleaned, documented open dataset of Premier League and Championship players born 1975–2005, with birthplaces, divisions and seasons.",
   "Formal evidence on whether English-born players' birthplaces cluster beyond population (RQ1).",
   "Multi-scale maps of statistically significant talent hotspots and coldspots across England (RQ2).",
   "Estimates of how deprivation, urbanisation and proximity to clubs and academies relate to player production (RQ3).",
   "A descriptive map of the countries supplying foreign-born players to the two leagues (RQ4).",
   "A public, interactive R Shiny dashboard and an open GitHub repository.",
   "A methods-and-results report suitable for submission to a sports-science or geography journal, and a portfolio case study."])

# ---------------------------------------------------------------- References
H1("References")
refs = [
 "Anselin, L. (1988). <i>Spatial econometrics: Methods and models</i>. Kluwer Academic.",
 "Anselin, L. (1995). Local indicators of spatial association—LISA. <i>Geographical Analysis, 27</i>(2), 93–115.",
 "Assunção, R. M., &amp; Reis, E. A. (1999). A new proposal to adjust Moran's I for population density. <i>Statistics in Medicine, 18</i>(16), 2147–2162.",
 "Baddeley, A. J., Møller, J., &amp; Waagepetersen, R. (2000). Non- and semi-parametric estimation of interaction in inhomogeneous point patterns. <i>Statistica Neerlandica, 54</i>(3), 329–350.",
 "Benjamini, Y., &amp; Hochberg, Y. (1995). Controlling the false discovery rate: A practical and powerful approach to multiple testing. <i>Journal of the Royal Statistical Society: Series B, 57</i>(1), 289–300.",
 "Côté, J., MacDonald, D. J., Baker, J., &amp; Abernethy, B. (2006). When \"where\" is more important than \"when\": Birthplace and birthdate effects on the achievement of sporting expertise. <i>Journal of Sports Sciences, 24</i>(10), 1065–1073.",
 "Curley, J. P. (2016). <i>engsoccerdata: English soccer data 1871–2016</i> [R package]. https://github.com/jalapic/engsoccerdata",
 "European Commission, Joint Research Centre. (2023). <i>GHS-POP R2023A — GHS population grid multitemporal (1975–2030)</i> [Data set]. European Commission.",
 "Getis, A., &amp; Ord, J. K. (1992). The analysis of spatial association by use of distance statistics. <i>Geographical Analysis, 24</i>(3), 189–206.",
 "MacDonald, D. J., Cheung, M., Côté, J., &amp; Abernethy, B. (2009). Place but not date of birth influences the development and emergence of athletic talent in American football. <i>Journal of Applied Sport Psychology, 21</i>(1), 80–90.",
 "Ministry of Housing, Communities &amp; Local Government. (2019). <i>The English Indices of Deprivation 2019</i> [Data set]. UK Government.",
 "Office for National Statistics. (n.d.). <i>Births in England and Wales: Births by area of usual residence of mother</i> [Data set]. ONS.",
 "Office for National Statistics. (n.d.). <i>Population estimates for local authorities in England and Wales</i> [Data set]. Nomis.",
 "Openshaw, S. (1984). <i>The modifiable areal unit problem</i> (Concepts and Techniques in Modern Geography No. 38). Geo Books.",
 "Riebler, A., Sørbye, S. H., Simpson, D., &amp; Rue, H. (2016). An intuitive Bayesian spatial model for disease mapping that accounts for scaling. <i>Statistical Methods in Medical Research, 25</i>(4), 1145–1165.",
 "Ripley, B. D. (1977). Modelling spatial patterns. <i>Journal of the Royal Statistical Society: Series B, 39</i>(2), 172–212.",
 "Vrandečić, D., &amp; Krötzsch, M. (2014). Wikidata: A free collaborative knowledgebase. <i>Communications of the ACM, 57</i>(10), 78–85.",
]
for r in refs:
    S.append(Paragraph(r, ref))

# ---------------------------------------------------------------- Appendices
S.append(PageBreak())
H1("Appendix A. Data Dictionary")
T([["Variable", "Type", "Source", "Description"],
   ["player_qid", "text", "Wikidata", "Unique Wikidata identifier (e.g., Q12345)"],
   ["birth_date", "date", "Wikidata P569", "Date of birth (1975-01-01 to 2005-12-31)"],
   ["birth_place_qid", "text", "Wikidata P19", "Identifier of place of birth"],
   ["geom", "geometry(Point, 4326)", "Wikidata P625 / geocoder", "Birthplace coordinates"],
   ["geo_level", "text", "Pipeline", "Resolution: town / county / country"],
   ["birth_country", "text", "Spatial join", "Country of birth; England flag for main analysis"],
   ["position", "text", "Wikidata P413", "Main playing position"],
   ["club_qid, start, end", "text, date, date", "Wikidata P54 + qualifiers", "Club membership periods"],
   ["season, tier", "text, integer", "engsoccerdata + compiled 2016/17–2025/26", "Club's division in each season"],
   ["season_ambiguous", "boolean", "Derived", "Eligibility depends on a year-only date in a promotion / relegation season"],
   ["births_iy, baseline_type", "integer, text", "ONS", "Births in area i, year y; 'births' or 'population' fallback"],
   ["max_tier", "integer", "Derived", "1 = Premier League, 2 = second tier"],
   ["lad_code, msoa_code", "text", "ONS spatial join", "Local authority and MSOA of birth"],
   ["imd_score", "numeric", "MHCLG", "Population-weighted deprivation score"],
   ["urban_share", "numeric", "ONS Rural-Urban", "Share of population in urban areas"],
   ["dist_club_km, dist_academy_km", "numeric", "Derived (EPSG:27700)", "Distance to nearest professional club (all cohorts) and Category 1 academy (born 1996–2005 only)"],
   ["O_i, E_i, SR_i", "numeric", "Derived (per unit)", "Observed, expected and standardised ratio"]],
  [3, 2.4, 2.8, 4.2], "Table A1. Core variables.")

_q = Preformatted(
"""SELECT ?player ?birthDate ?place ?coord ?club ?start ?end ?apps WHERE {
  ?player wdt:P106 wd:Q937857 ;         # association football player
          wdt:P21  wd:Q6581097 ;        # male
          wdt:P569 ?birthDate ;
          wdt:P19  ?place ;
          p:P54    ?m .                 # club membership statement
  ?m ps:P54 ?club .
  OPTIONAL { ?m pq:P580  ?start . }     # start time
  OPTIONAL { ?m pq:P582  ?end . }       # end time
  OPTIONAL { ?m pq:P1350 ?apps . }      # matches played
  VALUES ?club { wd:Q9617 wd:Q50602 }   # batch of clubs, e.g. Arsenal, Man City
  OPTIONAL { ?place wdt:P625 ?coord . }
  FILTER (YEAR(?birthDate) >= 1975 && YEAR(?birthDate) <= 2005)
}""", mono)
S.append(KeepTogether([Paragraph("Appendix B. Example Wikidata Query", h1), _q, Paragraph("Queries are run in batches of clubs (every club that has been in the top two divisions since 1992/93, listed "
  "from engsoccerdata) to stay within the endpoint's 60-second limit. Membership periods are then matched to "
  "seasons in which each club was in tier 1 or 2. Results are merged and deduplicated on player QID.", body)]))

H1("Appendix C. Glossary")
T([["Term", "Meaning"],
   ["Standardised Ratio (SR)", "Observed players ÷ players expected from births in the area"],
   ["EPPP", "Elite Player Performance Plan: the Premier League's academy system, introduced in 2012"],
   ["Local authority district", "The main tier of local government areas used by ONS"],
   ["MSOA", "Middle-layer Super Output Area: ONS statistical area of about 5,000–15,000 residents"],
   ["IMD", "Index of Multiple Deprivation: the official measure of relative deprivation in England"],
   ["Inhomogeneous K/L function", "Measures clustering of points relative to a varying background intensity"],
   ["Empirical Bayes smoothing", "Shrinks unstable rates in small populations towards an overall mean"],
   ["Moran's I", "Global measure of whether similar values are located near each other"],
   ["Getis-Ord G<sub>i</sub>*", "Local statistic identifying significant clusters of high (hot) or low (cold) values"],
   ["LISA", "Local Indicators of Spatial Association; classifies units as High-High, Low-Low or outliers"],
   ["Spatial lag / error model", "Regression models that account for spatial dependence in outcomes or residuals"],
   ["BYM2", "Bayesian spatial model for area counts with structured and unstructured random effects"],
   ["MAUP", "Modifiable Areal Unit Problem: results changing with the choice of spatial units"],
   ["FDR", "False Discovery Rate correction for many simultaneous tests"]],
  [3.6, 8.4], "Table C1. Glossary of technical terms.")

doc = Doc(OUT)
doc.multiBuild(S)
print("written", OUT)
