# 05c_county_shapes.R: simplified NC county outlines for the tool's need map.
# CACHES ONLY: reads the qualifier's cached tigris county file, no outside call.
# Run from Finalists/src/:   Rscript R/05c_county_shapes.R
# Output: data/processed/county_shapes.csv  (fips, county, path)  path = SVG path in a 0..SVG_W box.
# Source file: QualifierChallenge/data/cache/api/nc_counties_tigris.rds (US Census TIGER via tigris).

here::i_am("src/R/05c_county_shapes.R")
source(here::here("src", "R", "00_config.R"))
suppressMessages(library(sf))

SRC_FILE     <- here::here("..", "QualifierChallenge", "data", "cache", "api", "nc_counties_tigris.rds")
OUT_FILE     <- file.path(DIR_PROCESSED, "county_shapes.csv")
NC_CRS       <- 32119    # NC state plane, meters
SIMPLIFY_M   <- 700      # outline simplification tolerance, meters (display only)
SVG_W        <- 1000     # width of the drawing box

x <- readRDS(SRC_FILE) |> st_transform(NC_CRS)
x <- x[order(x$GEOID), ]
x <- st_simplify(x, dTolerance = SIMPLIFY_M, preserveTopology = TRUE)
bb <- st_bbox(x)
k  <- SVG_W / (bb["xmax"] - bb["xmin"])

ring_path <- function(m) {
  px <- (m[, 1] - bb["xmin"]) * k
  py <- (bb["ymax"] - m[, 2]) * k
  paste0("M", paste(sprintf("%.0f %.0f", px, py), collapse = "L"), "Z")
}
geom_path <- function(g) {
  polys <- if (inherits(g, "MULTIPOLYGON")) unclass(g) else list(unclass(g))
  paste(unlist(lapply(polys, function(p) vapply(p, ring_path, ""))), collapse = "")
}
out <- data.frame(fips = x$GEOID, county = sub(" County$", "", x$NAMELSAD),
                  path = vapply(st_geometry(x), geom_path, ""), stringsAsFactors = FALSE)
stopifnot(nrow(out) == 100, !anyNA(out$path))
write.csv(out, OUT_FILE, row.names = FALSE)
message("Wrote ", OUT_FILE, ": ", nrow(out), " counties, box ", SVG_W, " x ", round((bb["ymax"] - bb["ymin"]) * k))
