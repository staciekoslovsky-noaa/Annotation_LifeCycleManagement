# Process detector output data (original detections) to DB
# S. Hardy, 10 August 2021

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

# Install libraries -----------------------------------------------
library(tidyverse)
library(RPostgreSQL)

# Set up working environment -----------------------------------------------
"%notin%" <- Negate("%in%")

con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              #port = Sys.getenv("pep_port"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

wd <- "O:/Data/Annotations"
setwd(wd)

# Prepare list of directories with original data -----------------------------------------------
dir <- data.frame(network_path = list.dirs(wd, full.names = TRUE, recursive = FALSE), stringsAsFactors = FALSE) %>%
  mutate(path = basename(network_path)) %>%
  subset(path != "_Database") %>%
  subset(path != "_ImportLogs") %>%
  subset(path != "_TEMPLATE_project_YYYYMMDD_datasetDescription") %>%
  subset(!grepl("X$", path)) %>%
  mutate(project_schema = ifelse(grep("jobss", path) == TRUE, "surv_jobss", "TO BE WRITTEN"))

for (i in 1:nrow(dir)){
  i <- 1
  # Create detector_path variable
  if (file.exists(paste(dir$network_path[i], "01_DetectorOutputs", "outputs_success", sep = "/"))){
    detector_path <- paste(dir$network_path[i], "01_DetectorOutputs", "outputs_success", sep = "/")
  } else {
    detector_path <- paste(dir$network_path[i], "01_DetectorOutputs", sep = "/")
  }

  # Create pipeline dataset for import into DB
  if (file.exists(paste(dir$network_path[i], "01_DetectorOutputs", "pipelines", sep = "/"))){
    pipe_path <- paste(dir$network_path[i], "01_DetectorOutputs", "pipelines", sep = "/")
    
    pipes_by_file <- data.frame(file_name = list.files(pipe_path, full.names = FALSE), stringsAsFactors = FALSE) %>%
      mutate(flight = str_extract(file_name, "fl[0-9][0-9]")) %>%
      mutate(camera_view = gsub("_", "", str_extract(file_name, "_[A-Z]_"))) %>%
      mutate(list_type = sub("\\-.*", "", sub(".*_[A-Z]_", "", file_name)))

  } else {
    pipes <- "user_to_specify"
  }
  
  # Create input files dataset for import into DB
  inputs_by_file <- data.frame(file_name = list.files(paste(dir$network_path[i], "Archive_DetectorInputs", sep = "/"), full.names = FALSE), stringsAsFactors = FALSE) %>%
    filter(file_name != "dataset_manifest.csv") %>%
    mutate(flight = str_extract(file_name, "fl[0-9][0-9]")) %>%
    mutate(camera_view = gsub("_", "", str_extract(file_name, "_[A-Z]_"))) %>%
    mutate(list_type = sub("\\-.*", "", sub(".*_[A-Z]_", "", file_name)))

  # Get list of detection files
  files <- data.frame(file_name = list.files(detector_path, full.names = FALSE), stringsAsFactors = FALSE) %>%
    mutate(file_type = ifelse(grepl("detections", file_name) == TRUE, "detection", "image_list")) %>%
    mutate(image_type = ifelse(grepl("rgb", file_name) == TRUE, "rgb", 
                               ifelse(grepl("ir", file_name) == TRUE, "ir", "uv"))) %>%
    mutate(flight = str_extract(file_name, "fl[0-9][0-9]")) %>%
    mutate(camera_view = gsub("_", "", str_extract(file_name, "_[A-Z]_"))) %>%
    mutate(processing_dt = str_extract(file_name, "[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]")) %>%
    mutate(list_type = sub("\\_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9].*", "", sub(".*_[A-Z]_", "", file_name)))
  
  # Combine IR and RGB files to get list of files by processing run
  image_list_ir <- files %>%
    filter(image_type == "ir" & file_type == "image_list") %>%
    select(flight, camera_view, list_type, processing_dt, file_name) %>%
    rename(ir_image_list = file_name) 
  image_list_rgb <- files %>%
    filter(image_type == "rgb" & file_type == "image_list") %>%
    select(flight, camera_view, list_type, processing_dt, file_name) %>%
    rename(rgb_image_list = file_name)
  
  detections_ir <- files %>%
    filter(image_type == "ir" & file_type == "detection") %>%
    select(flight, camera_view, list_type, processing_dt, file_name) %>%
    rename(ir_detection_csv = file_name)
  detections_rgb <- files %>%
    filter(image_type == "rgb" & file_type == "detection") %>%
    select(flight, camera_view, list_type, processing_dt, file_name) %>%
    rename(rgb_detection_csv = file_name)
  
  # Create starting dataset for importing to tbl_detector_meta
  detector_meta <- image_list_ir %>%
    left_join(detections_ir, by = c("flight", "camera_view", "list_type", "processing_dt")) %>%
    left_join(image_list_rgb, by = c("flight", "camera_view", "list_type", "processing_dt")) %>%
    left_join(detections_rgb, by = c("flight", "camera_view", "list_type", "processing_dt")) %>%
    mutate(process_status = ifelse(is.na(str_extract(rgb_detection_csv, "_X.csv")), "to_be_processed", "do_not_process")) %>%
    mutate(project_schema = dir$project_schema[i]) %>%
    mutate(algorithm_run_location = "office") %>%
    mutate(algorithm_run_machine = ifelse(exists('pipes_by_file') == TRUE, "GPU VM", "user_to_specify")) %>%
    mutate(algorithm_run_dt = as.POSIXlt(processing_dt, tz = "", "%Y%m%d-%H%M%S")) %>%
    mutate(input_image_list_uv = NA) %>%
    mutate(uv_image_list = NA) %>%
    mutate(uv_detection_csv = NA) %>%
    mutate(annotation_status_lku = ifelse(process_status == "will_be_processed", "R", "X"))
  
    # Join pipeline data
  
    # Join input lists
  
  rm(image_list_ir, image_list_rgb, detections_ir, detections_rgb)
  
  # Process files where process_status == to_be_processed
  detector_process <- detector_meta %>%
    filter(process_status == "to_be_processed")
  
  for (j in 1:nrow(detector_process)){
    image_list_ir <- paste(detector_path, detector_process$ir_image_list[j], sep = '/')
    image_list_rgb <- paste(detector_path, detector_process$rgb_image_list[j], sep = '/')
    detection_file_ir <- paste(detector_path, detector_process$ir_detection_csv[j], sep = '/')
    detection_file_rgb <- paste(detector_path, detector_process$rgb_detection_csv[j], sep = '/')
    
    # Import original data to DB                                                              ######### WRITE CODE LATER TO PROCESS AS A FUNCTION, RATHER THAN REPEATING IMPORT CODE #########
    if (dir$project_schema == "surv_jobss") {
      
      # # Import image lists to DB -- IR
      # images_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_jobss.tbl_images_imagelists")
      # images_id$max <- ifelse(is.na(images_id$max) == TRUE, 0, images_id$max)
      # 
      # images <- read.table(image_list_ir, header = FALSE, stringsAsFactors = FALSE, col.names = "image_name")
      # 
      # images <- images %>%
      #   mutate(id = 1:n() + images_id$max) %>%
      #   mutate(image_list = detector_process$ir_image_list[j]) %>%
      #   select("id", "image_name", "image_list")
      # 
      # rm(images_id)
      # 
      # RPostgreSQL::dbWriteTable(con, c("surv_jobss", "tbl_images_imagelists"), images, append = TRUE, row.names = FALSE)
      # 
      # # Import image lists to DB -- RGB
      # images_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_jobss.tbl_images_imagelists")
      # images_id$max <- ifelse(is.na(images_id$max) == TRUE, 0, images_id$max)
      # 
      # images <- read.table(image_list_rgb, header = FALSE, stringsAsFactors = FALSE, col.names = "image_name")
      # 
      # images <- images %>%
      #   mutate(id = 1:n() + images_id$max) %>%
      #   mutate(image_list = detector_process$ir_image_list[j]) 
      # select("id", "image_name", "image_list")
      # 
      # rm(fields, original_id)
      # 
      # RPostgreSQL::dbWriteTable(con, c("surv_jobss", "tbl_images_imagelists"), images, append = TRUE, row.names = FALSE)
      # 
      # # Import original detections to DB -- IR
      # original_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_jobss.tbl_detections_original_ir")
      # original_id$max <- ifelse(is.na(original_id$max) == TRUE, 0, original_id$max)
      # 
      # fields <- max(count.fields(detection_file_ir, sep = ','))
      # original <- read.csv(detection_file_ir, header = FALSE, stringsAsFactors = FALSE, skip = 4, col.names = paste("V", seq_len(fields)))
      # if(fields == 11) {
      #   colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score")
      # } else if (fields == 13) {
      #   colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1")
      # }
      # 
      # if("detection_type_x1" %notin% names(original)){
      #   original$detection_type_x1 <- ""
      # }
      # if("type_score_x1" %notin% names(original)){
      #   original$type_score_x1 <- 0.0000000000
      # }
      # 
      # original <- original %>%
      #   mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
      #   mutate(id = 1:n() + original_id$max) %>%
      #   mutate(detection_file = detection_file_ir) %>%
      #   mutate(flight = str_extract(image_name, "fl[0-9][0-9]")) %>%
      #   mutate(camera_view = gsub("_", "", str_extract(image_name, "_[A-Z]_"))) %>%
      #   mutate(detection_id = paste("surv_jobss", flight, camera_view, detection, sep = "_")) %>%
      #   select("id", "detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1", "flight", "camera_view", "detection_id", "detection_file")
      # 
      # rm(fields, original_id)
      # 
      # RPostgreSQL::dbWriteTable(con, c("surv_jobss", "tbl_detections_original_ir"), original, append = TRUE, row.names = FALSE)
      # 
      # # Import original detections to DB -- RGB
      # original_id <- RPostgreSQL::dbGetQuery(con, "SELECT max(id) FROM surv_jobss.tbl_detections_original_rgb")
      # original_id$max <- ifelse(is.na(original_id$max) == TRUE, 0, original_id$max)
      # 
      # fields <- max(count.fields(detection_file_rgb, sep = ','))
      # original <- read.csv(detection_file_ir, header = FALSE, stringsAsFactors = FALSE, skip = 4, col.names = paste("V", seq_len(fields)))
      # if(fields == 11) {
      #   colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score")
      # } else if (fields == 13) {
      #   colnames(original) <- c("detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1")
      # }
      # 
      # if("detection_type_x1" %notin% names(original)){
      #   original$detection_type_x1 <- ""
      # }
      # if("type_score_x1" %notin% names(original)){
      #   original$type_score_x1 <- 0.0000000000
      # }
      # 
      # original <- original %>%
      #   mutate(image_name = sapply(strsplit(image_name, split= "\\/"), function(x) x[length(x)])) %>%
      #   mutate(id = 1:n() + original_id$max) %>%
      #   mutate(detection_file = detection_file_ir) %>%
      #   mutate(flight = str_extract(image_name, "fl[0-9][0-9]")) %>%
      #   mutate(camera_view = gsub("_", "", str_extract(image_name, "_[A-Z]_"))) %>%
      #   mutate(detection_id = paste("surv_jobss", flight, camera_view, detection, sep = "_")) %>%
      #   select("id", "detection", "image_name", "frame_number", "bound_left", "bound_bottom", "bound_right", "bound_top", "score", "length", "detection_type", "type_score", "detection_type_x1", "type_score_x1", "flight", "camera_view", "detection_id", "detection_file")
      # 
      # rm(fields, original_id)
      # 
      # RPostgreSQL::dbWriteTable(con, c("surv_jobss", "tbl_detections_original_rgb"), original, append = TRUE, row.names = FALSE)
      
      # Add steps to tbl_detector_processing based on project                                 
      
      
    } else if (dir$project_schema == "surv_chess") {                                          ######### NOT CURRENTLY RELEVANT -- ADD CODE LATER #########
      
    } else if (dir$project_schema == "surv_boss") {                                           ######### NOT CURRENTLY RELEVANT -- ADD CODE LATER #########
      
    } else if (dir$project_schema == "surv_polar_bear") {                                     ######### NOT CURRENTLY RELEVANT -- ADD CODE LATER #########
      
    } else if (dir$project_schema == "surv_test_kotz") {                                      ######### NOT CURRENTLY RELEVANT -- ADD CODE LATER #########
      
    }
    
    # Create flight_cameraView folder in 02... folder and copy files there. Add _Processed to end of file name
    
  }
  
    
      

  
    
  
  # Process files where process_status == do_not_process ######### NOT CURRENTLY RELEVANT -- ADD CODE LATER #########
  detector_process_no <- detector_meta %>%
    filter(project_status == "do_not_process")
  
    # Archive files

  
  # Upload data to tbl_detector_meta
  
}

# When done, move all files to Archive_DetectorOutputs

# Write log file



RPostgreSQL::dbDisconnect(con)
rm(con)
