# Deploy the dashboard (app/) to shinyapps.io.
#
# 1. Create a free account at https://www.shinyapps.io and open Account → Tokens → Show.
# 2. Put the three values in .env (never committed):
#      SHINYAPPS_ACCOUNT=your-account-name
#      SHINYAPPS_TOKEN=...
#      SHINYAPPS_SECRET=...
# 3. Restart the containers so .env is reloaded (docker compose up -d), then run
#      docker compose exec app Rscript R/10_deploy.R
#
# The app bundle is small (~2 MB of data in app/data). Rebuild the data first with
# Rscript R/09_app_data.R if the analysis has changed.

account <- Sys.getenv("SHINYAPPS_ACCOUNT")
token <- Sys.getenv("SHINYAPPS_TOKEN")
secret <- Sys.getenv("SHINYAPPS_SECRET")
if (!nzchar(account) || !nzchar(token) || !nzchar(secret)) {
  stop("Set SHINYAPPS_ACCOUNT, SHINYAPPS_TOKEN and SHINYAPPS_SECRET in .env (see the header of this script).")
}
rsconnect::setAccountInfo(name = account, token = token, secret = secret)
rsconnect::deployApp(
  appDir = "app",
  appName = "football-talent-hotspots",
  appTitle = "Football Talent Hotspots",
  appFiles = c("app.R", "about.md", list.files("app/data", full.names = FALSE) |> (\(f) file.path("data", f))()),
  forceUpdate = TRUE
)
