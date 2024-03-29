# Export image lists from DB
# S. Hardy, 25 July 2021

# Define user variables ------------------------------------------
## For DB query
db_schema <- "surv_jobss"
db_table <- "summ_data_inventory"

## For filtering images
altitude_minimum <- 0 #in m (152.4 m = 500 ft)
altitude_maximum <- 3000 #in m (609.6 m = 2000 ft)
keep_ir_nuc <- "N" # enter Y or N

## For defining image list names
project <- "jobss_2021"
list_description <- "batchProcessing"
run_date <- "20211005" # formatted as YYYYMMDD
detectionFileType <- "postSurvey" #either postSurvey, irNUC, or newFromML

## For assigning transformation files
transform_C <- "\\\\akc0ss-n086\\NMML_Polar\\ProgramMgmt\\Software\\Seal-TK\\Transformations_2021_JoBSS\\Revised_2021CalibrationFlight\\Otter_RGB-IR_C_100mm_0deg_20210412.h5"
transform_L <- "\\\\akc0ss-n086\\NMML_Polar\\ProgramMgmt\\Software\\Seal-TK\\Transformations_2021_JoBSS\\Revised_2021CalibrationFlight\\Otter_RGB-IR_L_100mm_25deg_20210412.h5"
transform_R <- "\\\\akc0ss-n086\\NMML_Polar\\ProgramMgmt\\Software\\Seal-TK\\Transformations_2021_JoBSS\\Revised_2021CalibrationFlight\\Otter_RGB-IR_R_100mm_25deg_20210412.h5"

## For exporting image lists and dataset_manifest.csv
export_directory <- "O:\\Data\\Annotations"
export_folder <- paste(project, run_date, list_description, sep = "_")

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

# Create export folder on network
export <- paste(export_directory, export_folder, sep = "\\")
dir.create(export)
dir.create(paste(export, "01_DetectorOutputs", sep = "\\"))
dir.create(paste(export, "02_AnnotationFiles_ForProcessing", sep = "\\"))
dir.create(paste(export, "03_AnnotationFiles_ReviewComplete", sep = "\\"))
dir.create(paste(export, "04_Corrections", sep = "\\"))
dir.create(paste(export, "Archive_DetectionFiles", sep = "\\"))
dir.create(paste(export, "Archive_DetectorInputs", sep = "\\"))

# Connect to DB
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

# Get list of images from DB
sql_code4export <- paste("SELECT * FROM ", db_schema, ".", db_table, sep = "")
images <- RPostgreSQL::dbGetQuery(con, sql_code4export)

# Create image_list export file names for each image
images <- images %>%
  filter(ins_altitude >= altitude_minimum,
         ins_altitude <= altitude_maximum,
         !is.na(ir_image_name),
         !is.na(rgb_image_name)) %>%
  filter(if (keep_ir_nuc == "Y") ir_nuc == 'N' | is.na(ir_nuc) else ir_nuc == ir_nuc | is.na(ir_nuc)) %>%  
  select(flight, camera_view, ir_image_path, rgb_image_path, uv_image_path) %>%
  mutate(image_list_rgb = paste(project, "_", flight, "_", camera_view, "_", list_description, "_rgb_images_", run_date, ".txt", sep = ""),
         image_list_ir = paste(project, "_", flight, "_", camera_view, "_", list_description, "_ir_images_", run_date, ".txt", sep = ""),
         image_list_uv = paste(project, "_", flight, "_", camera_view, "_", list_description, "_uv_images_", run_date, ".txt", sep = ""))

# Create dataset_manifest.csv: dataset_name, color_image_list, thermal_image_list, transformation_file
manifest <- images %>%
  select(flight, camera_view, image_list_rgb, image_list_ir, image_list_uv) %>%
  distinct(flight, camera_view, image_list_rgb, image_list_ir, image_list_uv) %>%
  mutate(dataset_name = paste(project, flight, camera_view, detectionFileType, sep = "_"),
         transformation_file = ifelse(camera_view == "C", transform_C,
                                      ifelse(camera_view == "L", transform_L, transform_R))) %>%
  rename(color_image_list = image_list_rgb,
         thermal_image_list = image_list_ir,
         uv_image_list = image_list_uv) %>%
  select(dataset_name, color_image_list, thermal_image_list, transformation_file, uv_image_list)

image_lists <- manifest %>%
  select(color_image_list, thermal_image_list, uv_image_list) 

manifest <- manifest %>%
  select(color_image_list, thermal_image_list, transformation_file)

write.csv(manifest, file = paste(export, "Archive_DetectorInputs", "dataset_manifest.csv", sep = "\\"), row.names = FALSE)

# Export image lists
for (i in 1:nrow(image_lists)){
  images_rgb <- images %>%
    filter(image_list_rgb == image_lists$color_image_list[i] & !is.na(rgb_image_path)) %>%
    select(rgb_image_path)

  images_ir <- images %>%
    filter(image_list_ir == image_lists$thermal_image_list[i] & !is.na(ir_image_path)) %>%
    select(ir_image_path)
  
  images_uv <- images %>%
    filter(image_list_uv == image_lists$uv_image_list[i] & !is.na(uv_image_path)) %>%
    select(uv_image_path)
  
  write.table(images_rgb, paste(export, "Archive_DetectorInputs", image_lists$color_image_list[i], sep = "\\"), row.names = FALSE, col.names = FALSE, quote = FALSE)
  write.table(images_ir, paste(export, "Archive_DetectorInputs", image_lists$thermal_image_list[i], sep = "\\"), row.names = FALSE, col.names = FALSE, quote = FALSE)
  write.table(images_uv, paste(export, "Archive_DetectorInputs", image_lists$uv_image_list[i], sep = "\\"), row.names = FALSE, col.names = FALSE, quote = FALSE)
}

# Clean up workspace
dbDisconnect(con)
rm(con, i)