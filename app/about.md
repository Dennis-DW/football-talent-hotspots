## About this dashboard

**Where do England's Premier League and Championship footballers come from?**
A spatial analysis of the birthplaces of men born 1975–2005 who made at least one league appearance in the Premier League or the second tier (First Division / Championship), 1992/93–2025/26.
Author: **Dennis Wambua** · Code and full reports: the project repository (`docs/reports/`).

### Main findings
1. **A north-west vs. south/south-east gradient.** London and the North West produce about **2.4×** as many players per birth as the South West. The Merseyside–Lancashire–Greater Manchester belt is the strongest cluster.
2. **Proximity to a professional club matters.** Each extra 10 km from the nearest league club at age 12 means about **14% fewer** players than births predict, and more so for players born since 1990. Proximity to an elite (Category 1) academy does not.
3. **Deprivation and urbanisation do not explain the pattern** once region is taken into account.
4. **About half of the players were born outside England.** Ireland, Scotland, Wales and Iceland supply the most per head.

### How to read the maps
- **SR (standardised ratio)** = players born in an area ÷ players expected from the number of boys born there (1975–2005). SR 1 = as expected; 2 = twice as many; 0.5 = half.
- **Smoothed SR** pulls small, noisy areas toward the national average (Empirical Bayes), so areas with few births do not look extreme by chance.
- **Gi\* hotspots** mark groups of neighbouring areas that are together unusually high or low (Getis-Ord Gi\*, 9,999 permutations, Benjamini–Hochberg false discovery rate).
- **Travel to Work Areas** are the main unit: birthplaces are often recorded as the maternity-hospital town, and TTWAs contain both the town and its catchment.

### Important limitations
- Player data come from Wikidata and Wikipedia (community-edited); eligibility was validated on a 200-player sample.
- A birthplace is where a player was born, not necessarily where he grew up.
- Births are estimated from ONS counts of boys aged under one; deprivation is measured in 2025.
- Results describe areas, not individuals, and should not be used to stereotype places or communities.
- The foreign-born map shows recruitment by English clubs, not talent production in each country.

### Data sources and licences
- **Players, clubs, birthplaces:** Wikidata (CC0); league appearances from English Wikipedia (CC BY-SA 4.0).
- **League tables:** engsoccerdata (J. Curley) and Wikipedia.
- **Births, population, boundaries, Rural-Urban Classification:** Office for National Statistics. Contains public sector information licensed under the Open Government Licence v3.0. Contains OS data © Crown copyright and database right.
- **English Indices of Deprivation 2025:** Ministry of Housing, Communities & Local Government (Open Government Licence v3.0).
- **Country populations:** World Bank World Development Indicators (CC BY 4.0).
- **World boundaries:** Natural Earth (public domain). Background maps: Esri Light Gray Canvas (© Esri, HERE, Garmin, © OpenStreetMap contributors) and © OpenStreetMap contributors.
