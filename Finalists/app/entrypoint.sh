#!/bin/sh
# MODE=job: daily refresh (job.R scores from cache, checks, stamps "data as of", ships payload.json;
# dry run unless JOB_DRY_RUN=0). Otherwise: serve the Shiny app directly (no shiny-server), so env vars reach R.
# APP_DIR defaults to /srv/app (the image); set it to Finalists/app to run the job on a laptop.
APP_DIR="${APP_DIR:-/srv/app}"
cd "$APP_DIR" || exit 1
if [ "${MODE:-app}" = "job" ]; then
  exec Rscript job.R
fi
exec R -q -e "shiny::runApp('$APP_DIR', host = '0.0.0.0', port = 3838)"
