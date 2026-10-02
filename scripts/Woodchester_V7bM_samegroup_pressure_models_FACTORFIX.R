# =============================================================================
# TEMPORARY FACTOR-LEVEL FIX FOR SAME-GROUP PRESSURE MODEL
#
# The original pressure script used factor(outcome_quarter) and
# factor(period_start) inside each paired history. In the first smoke/full runs,
# all pressure-adjusted models failed with:
#   contrasts can be applied only to factors with 2 or more levels
#
# This wrapper keeps the scientific model unchanged but forces stable factor
# levels across every paired history before evaluating the original script.
# Once the corrected model has been validated, this temporary wrapper can be
# folded into the main script and archived.
# =============================================================================

src <- "scripts/Woodchester_V7bM_samegroup_pressure_models.R"
if(!file.exists(src)) stop("Missing source script: ",src)

x <- readLines(src,warn=FALSE)
txt <- paste(x,collapse="\n")

txt <- sub(
  "quarter=factor\\(outcome_quarter\\),\\n      period=factor\\(period_start\\)",
  paste0(
    "quarter=factor(outcome_quarter,levels=1:4),\\n",
    "      period=factor(period_start,levels=sort(unique(5L*((pidx$pressure_year+1L)%/%5L))))"
  ),
  txt
)

if(identical(txt,paste(x,collapse="\n")))
  stop("Factor-level patch did not find the expected code block.")

message("Applying stable quarter/period factor levels, then running same-group pressure model.")
eval(parse(text=txt),envir=.GlobalEnv)
