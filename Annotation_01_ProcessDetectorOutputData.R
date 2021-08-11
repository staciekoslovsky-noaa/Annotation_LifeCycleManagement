# Process detector output data (original detections) to DB
# S. Hardy, 10 August 2021

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set up working environment
"%notin%" <- Negate("%in%")


con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              #port = Sys.getenv("pep_port"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

wd <- "O:/Data/Annotations"
setwd(wd)

# Prepare list of directories with original data
dir <- list.dirs(wd, full.names = TRUE, recursive = FALSE) 
dir <- data.frame(network_path = dir, stringsAsFactors = FALSE)
dir <- dir %>%
  mutate(path = basename(network_path)) %>%
  subset(path != "_Database") %>%
  subset(path != "_ImportLogs") %>%
  subset(path != "_TEMPLATE_project_YYYYMMDD_datasetDescription") %>%
  subset(!grepl("X$", path)) %>%
  mutate(project_schema = ifelse(grep("jobss", path) == TRUE, "surv_jobss", "TO BE WRITTEN"))

for (i in 1:nrow(dir)){
  detection_files <- # get list of detection files...could be in root or in specific subfolder
    # Combine IR and RGB files to get list of files by processing run
    # Process files without _X at end
      # Create new record in tbl_detector_meta - and indicate ready to review
      # Import original data to DB (will be different code for each project)
      # Add steps to tbl_detector_processing based on project
      # Import image lists
      # Create flight_cameraView folder in 02... folder and copy files there. Add _Processed to end of file name
      # Update import log
    # Process _X files
      # Add record to tbl_detector_meta and indicate it will not be processed
      # Archive files
      # Update import log
  
}

# When done, move all files to Archive_DetectorOutputs
# Write log file







# Delete data from tables (if needed)
#RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_test_kamera.tbl_detections_original")
#RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_test_kamera.tbl_detections_processed")

# Import data and process
## ORIGINAL DATA
original_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_test_kamera.tbl_detections_original_rgb")
original_id$max <- ifelse(length(original_id) == 0, 0, original_id$max)

fields <- max(count.fields(original_file, sep = ','))
original <- read.csv(original_file, header = FALSE, stringsAsFactors = FALSE, skip = 2, col.names = paste("V", seq_len(fields)))
if(fields == 11) {
  colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score")
} else if (fields == 13) {
  colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1")
}

if("type_x1" %notin% names(original)){
  original$type_x1 <- ""
}
if("type_score_x1" %notin% names(original)){
  original$type_score_x1 <- 0.0000000000
}

original <- original %>%
  mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
  mutate(id = 1:n() + original_id$max) %>%
  mutate(detection_file = original_file) %>%
  mutate(flight = flight) %>%
  mutate(camera_view = camera) %>%
  mutate(detection_id = paste("test_kamera", flight, camera, detection, sep = "_")) %>%
  select("id", "detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1", "flight", "camera_view", "detection_id", "detection_file")

rm(fields, original_id)

## PROCESSED DATA
processed_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_test_kamera.tbl_detections_processed_rgb")
processed_id$max <- ifelse(length(processed_id) == 0, 0, processed_id$max)

processed <- read.csv(processed_file, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score"))
processed <- processed %>%
  mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
  mutate(id = 1:n() + processed_id$max) %>%
  mutate(detection_file = processed_file) %>%
  mutate(flight = flight) %>%
  mutate(reviewer = reviewer) %>%
  mutate(camera_view = camera) %>%
  mutate(detection_id = paste("test_kamera", flight, camera, detection, sep = "_")) %>%
  select("id", "detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "flight", "camera_view", "detection_id", "reviewer", "detection_file")

rm(processed_id)

# Import data to DB
RPostgreSQL::dbWriteTable(con, c("surv_test_kamera", "tbl_detections_original_rgb"), original, append = TRUE, row.names = FALSE)
RPostgreSQL::dbWriteTable(con, c("surv_test_kamera", "tbl_detections_processed_rgb"), processed, append = TRUE, row.names = FALSE)
RPostgreSQL::dbDisconnect(con)
rm(con)
