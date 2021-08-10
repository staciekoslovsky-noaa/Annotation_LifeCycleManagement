# Process detector output data (original detections) to DB
# S. Hardy, 10 August 2020

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

wd <- "O:\\Data\\Annotations"
setwd(wd)

# 

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
