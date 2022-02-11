# JoBSS: Randomly select seals for species identification
# Actually occurred at flight #25 and 35.58% due to high bird numbers in some of the early flights

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

# Run code -------------------------------------------------------
# Extract data from DB ------------------------------------------------------------------
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

process <- RPostgreSQL::dbGetQuery(con, "SELECT detection, image_name, frame_number, bound_left, bound_bottom, bound_right, bound_top,
                                   score, length, detection_type, type_score, detection_id, p.processing_completed_by FROM surv_jobss.tbl_detections_processed_rgb r
                                   LEFT JOIN annotations.tbl_detector_meta m
                                   ON m.rgb_processed_csv = r.detection_file
                                   LEFT JOIN annotations.tbl_detector_processing p
                                   ON m.id = p.detector_meta_id
                                   WHERE detection_type LIKE \'%seal%\'
                                   AND processing_step_lku = 7
                                   AND random_order >=1 and random_order <= 25")

# Create random selections of seals------------------------------------------------------
set.seed(465396)
rand_select <- sample(1:nrow(process), 300)
process$rand_select <- ifelse(row.names(process) %in% rand_select, "Select", "")
process <- process %>%
  filter(rand_select == "Select")

write.csv(process, "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\JoBSS_Quartile1Review_RandomSelection.csv", row.names = FALSE, quote = FALSE)

process$detection_type <- ""

random_clc <- process %>%
  subset(processing_completed_by != 'CLC') %>%
  arrange(image_name) %>%
  rowid_to_column(var = "id") %>%
  mutate(detection = id - 1) %>%
  group_by(image_name) %>%
  mutate(frame_number = cur_group_id()-1) %>%
  ungroup() %>%
  select(detection, image_name, frame_number, bound_left, bound_bottom, bound_right, bound_top, score, length, detection_type, type_score)

random_smw <- process %>%
  subset(processing_completed_by != 'SMW') %>%
  arrange(image_name) %>%
  rowid_to_column(var = "id") %>%
  mutate(detection = id - 1) %>%
  group_by(image_name) %>%
  mutate(frame_number = cur_group_id()-1) %>%
  ungroup() %>%
  select(detection, image_name, frame_number, bound_left, bound_bottom, bound_right, bound_top, score, length, detection_type, type_score)

random_gmb <- process %>%
  subset(processing_completed_by != 'GMB') %>%
  arrange(image_name) %>%
  rowid_to_column(var = "id") %>%
  mutate(detection = id - 1) %>%
  group_by(image_name) %>%
  mutate(frame_number = cur_group_id()-1) %>%
  ungroup() %>%
  select(detection, image_name, frame_number, bound_left, bound_bottom, bound_right, bound_top, score, length, detection_type, type_score)

# Export random selections of seals -----------------------------------------------------
write.csv(random_clc, "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\JoBSS_Quartile1Review_SpeciesID_CLC.csv", row.names = FALSE, quote = FALSE, col.names = FALSE)
write.csv(random_smw, "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\JoBSS_Quartile1Review_SpeciesID_SMW.csv", row.names = FALSE, quote = FALSE, col.names = FALSE)
write.csv(random_gmb, "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\JoBSS_Quartile1Review_SpeciesID_GMB.csv", row.names = FALSE, quote = FALSE, col.names = FALSE)

write.table(unique(random_clc$image_name), "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\Images\\_JoBSS_Quartile1Review_SpeciesID_CLC_images.txt", row.names = FALSE, quote = FALSE, col.names = FALSE)
write.table(unique(random_smw$image_name), "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\Images\\_JoBSS_Quartile1Review_SpeciesID_SMW_images.txt", row.names = FALSE, quote = FALSE, col.names = FALSE)
write.table(unique(random_gmb$image_name), "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\Images\\_JoBSS_Quartile1Review_SpeciesID_GMB_images.txt", row.names = FALSE, quote = FALSE, col.names = FALSE)

# Copy images to server for processing --------------------------------------------------
color_images <- RPostgreSQL::dbGetQuery(con, "SELECT image_name, image_dir FROM surv_jobss.tbl_images WHERE image_type = \'rgb_image\'")
color_images$rand_select <- ifelse(color_images$image_name %in% process$image_name, "Select", "")
color_images <- color_images %>%
  filter(rand_select == "Select")

color <- paste(color_images$image_dir, color_images$image_name, sep = "/")

file.copy(color, "J:\\SpeciesMisclassification\\JoBSS\\Quartile1\\Images")

# Disconnect for database and delete unnecessary variables ------------------------------
dbDisconnect(con)
rm(con)