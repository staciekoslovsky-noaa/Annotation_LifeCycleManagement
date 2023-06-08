# Process glacial processed RGB detections to DB

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set variables for processing
year <- '2021'

# Set up working environment
"%notin%" <- Negate("%in%")
wd <- paste0("//akc0ss-n086/NMML_Polar_Imagery/Surveys_HS/Glacial/Projects/Surveys Glacial Sites Counts/", year)
setwd(wd)
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Delete data from tables (if needed)
# RPostgreSQL::dbSendQuery(con, "DELETE FROM surv_pv_gla.tbl_detections_processed_rgb")

# Import data and process
folders <- data.frame(folder_path = list.dirs(path = wd, full.names = TRUE, recursive = FALSE), stringsAsFactors = FALSE)
folders <- folders %>%
  filter(grepl("sample", folder_path)) 

for (i in 1:nrow(folders)) {
  files <- list.files(folders$folder_path[i])
  rgb_validated <- files[grepl('_processed.csv|_processed_transposedRGB.csv', files)] 
  if(length(rgb_validated) == 0) next
  
  for (j in 1:length(rgb_validated)){
    processed_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_pv_gla.tbl_detections_processed_rgb")
    processed_id$max <- ifelse(is.na(processed_id$max), 0, processed_id$max)
    
    processed <- read.csv(paste(folders$folder_path[i], rgb_validated[j], sep = "\\"), skip = 2, header = FALSE, stringsAsFactors = FALSE, col.names = c("detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", 
                                                                                                                                                      "att1", "att2", "att3", "att4", "att5", "att6", "att7", "att8"))
    
    if (nrow(processed) > 0) {
      processed <- data.frame(lapply(processed, function(x) {gsub("\\(trk-atr\\) *", "", x)})) %>%
      mutate(image_name = basename(sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)]))) %>%
      mutate(id = 1:n() + processed_id$max) %>%
      mutate(detection_file = rgb_validated[j]) %>%
      mutate(flight = str_extract(image_name, "fl[0-9][0-9]")) %>%
      mutate(camera_view = gsub("_", "", str_extract(image_name, "_[A-Z]_"))) %>%
      mutate(detection_id = paste("surv_pv_gla", year, str_extract(image_name, "fl[0-9][0-9]"), gsub("_", "", str_extract(image_name, "_[A-Z]_")), detection, sep = "_")) %>%
      select("id", "detection", "image_name", "frame_number", "bound_left", "bound_top", "bound_right", "bound_bottom", "score", "length", "detection_type", "type_score", 
             "flight", "camera_view", "detection_id", "detection_file",)
    
      # Import data to DB
      RPostgreSQL::dbWriteTable(con, c("surv_pv_gla", "tbl_detections_processed_rgb"), processed, append = TRUE, row.names = FALSE)
    }
  }
}

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
