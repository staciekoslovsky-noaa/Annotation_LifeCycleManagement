# Match bounding boxes between datasets

# Create functions -----------------------------------------------
# Function to install packages needed
install_pkg <- function(x)
{
  if (!require(x,character.only = TRUE))
  {
    install.packages(x,dep=TRUE)
    if(!require(x,character.only = TRUE)) stop("Package not found")
  }
}

# Install libraries ----------------------------------------------

install_pkg("RPostgreSQL")
install_pkg("tidyverse")

# Connect to DB
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

# Process data --------------------------------------------------
# Get original and processed detections from DB
original <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_jobss.tbl_detections_original_rgb") %>%
  rename(o_detection = detection,
         o_left = bound_left,
         o_bottom = bound_bottom,
         o_right = bound_right,
         o_top = bound_top, 
         o_score = score,
         o_detection_type = detection_type) %>%
  select(image_name, o_detection, o_left, o_bottom, o_right, o_top, o_score, o_detection_type) %>%
  mutate(o_average_x = (o_left + o_right)/2,
         o_average_y = (o_top + o_bottom)/2)

processed <- RPostgreSQL::dbGetQuery(con, "SELECT * FROM surv_jobss.tbl_detections_processed_rgb") %>% # WHERE detection_type <> \'false_positive\'
  rename(p_detection = detection,
         p_left = bound_left,
         p_bottom = bound_bottom,
         p_right = bound_right,
         p_top = bound_top, 
         p_detection_type = detection_type) %>%
  select(image_name, p_detection, p_left, p_bottom, p_right, p_top, p_detection_type) %>%
  mutate(p_average_x = (p_left + p_right)/2,
         p_average_y = (p_top + p_bottom)/2)

# Merge datasets together
data <- original %>%
  full_join(processed, by = "image_name") %>%
  select(image_name, o_detection, p_detection, o_left, o_right, p_left, p_right, o_top, o_bottom, p_top, p_bottom, o_score, o_detection_type, p_detection_type) %>%
  mutate(intersect_LR = ifelse(p_right < o_left | p_left > o_right, "no", "yes"),
         intersect_TB = ifelse(p_top > o_bottom | p_bottom < o_top, "no", "yes"))

intersecting <- data %>%
  filter(intersect_LR == "yes" & intersect_TB == "yes")

missing_o <- original %>%
  filter(!o_detection %in% (intersecting$o_detection))

missing_p <- processed %>%
  filter(!p_detection %in% (intersecting$p_detection))

