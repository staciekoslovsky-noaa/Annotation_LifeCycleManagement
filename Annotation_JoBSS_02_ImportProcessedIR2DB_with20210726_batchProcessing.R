# Process JoBSS processed thermal detections to DB

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
wd <- "O:\\Data\\Annotations\\jobss_2021_20210726_batchProcessing\\02_AnnotationFiles_ForProcessing"

# Set up working environment
"%notin%" <- Negate("%in%")
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Delete data from tables (if needed)
RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_jobss.tbl_detections_processed_ir")

# Import data and process
folders <- data.frame(folder_path = list.dirs(path = wd, full.names = TRUE, recursive = FALSE), stringsAsFactors = FALSE)
folders <- folders %>%
  mutate(flight = str_extract(folder_path, "fl[0-9][0-9]"),
         camera_view = gsub("_", "", str_extract(folder_path, "_[A-Z]$")))

for (i in 1:nrow(folders)) {
  if(folders$flight[i] == 'fl07' & folders$camera_view[i] == 'L') next 
  processed_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_jobss.tbl_detections_processed_ir")
  processed_id$max <- ifelse(is.na(processed_id$max), 0, processed_id$max)
  
  files <- list.files(folders$folder_path[i])
  ir_validated <- files[grepl('ir_detections_validated', files)] 
  
  processed <- read.csv(paste(folders$folder_path[i], ir_validated, sep = "\\"), skip = 2, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", "detection_comments"))
  processed <- processed %>%
    mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
    mutate(id = 1:n() + processed_id$max) %>%
    mutate(detection_file = ir_validated) %>%
    mutate(flight = folders$flight[i]) %>%
    mutate(camera_view = folders$camera_view[i]) %>%
    mutate(detection_id = paste("surv_jobss", flight, camera_view, detection, sep = "_")) %>%
    select("id", "detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", "flight", "camera_view", "detection_id", "detection_file", "detection_comments")
  
  # Import data to DB
  RPostgreSQL::dbWriteTable(con, c("surv_jobss", "tbl_detections_processed_ir"), processed, append = TRUE, row.names = FALSE)
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
