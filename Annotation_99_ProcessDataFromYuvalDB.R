# Process annotation data from Yuval for import into pep DB
# S. Koslovsky

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
install_pkg("snakecase")

# Run code -------------------------------------------------------
# Set working directory
wd <- "C:/Users/Stacie.Hardy/Work/SMK/Projects/AS__Annotations/Data/YuvalDB_ParseFromSQL_20220707"
setwd(wd)

# --- Process annotation data ---
# Load data for creating annotation datasets
anno_annotation <- read.table(file = 'annotation_data.annotation.tsv', sep = '\t', header = TRUE)
anno_annotation <- anno_annotation %>%
  rename(rgb_event_key = eo_event_key)

anno_boxes <- read.table(file = 'annotation_data.bounding_boxes.tsv', sep = '\t', header = TRUE)

anno_species <- read.table(file = 'annotation_data.species.tsv', sep = '\t', header = TRUE) 
anno_species <- anno_species %>%
  rename(species = name) %>%
  mutate(species = gsub("UNK", "unknown", species)) %>%
  mutate(species = snakecase::to_snake_case(species))

surv_image_eo <- read.table(file = 'survey_data.eo_image.tsv', sep = '\t', header = TRUE) %>%
  rename_with( ~ paste0("rgb_", .x))
surv_image_ir <- read.table(file = 'survey_data.ir_image.tsv', sep = '\t', header = TRUE) %>%
  rename_with( ~ paste0("ir_", .x))

# --- Create IR annotation dataset for import ---
annotations_ir <- anno_annotation %>%
  mutate(age_class = ifelse(age_class == '\\N', "adult", age_class)) %>%
  filter(ir_event_key != '\\N') %>%
  mutate(ir_box_id = as.integer(ifelse(ir_box_id == '\\N', "-99", ir_box_id))) %>%
  # Join and process species data
  left_join(anno_species, by = c("species_id" = "id")) %>%
  # Join and process IR bounding box data
  left_join(anno_boxes, by = c("ir_box_id" = "id")) %>%
  rename(detection = id,
    detection_type = species,
    bound_top = x1,
    bound_bottom = x2,
    bound_left = y1,
    bound_right = y2,
    confidence = confidence,
    reviewer = worker_id,
    job = job_id) %>%
  # Join image data
  left_join(surv_image_ir, by = "ir_event_key") %>%
  rename(image_name = ir_filename) %>%
  select(detection, image_name, bound_left, bound_top, bound_right, bound_bottom,
    detection_type, reviewer, job) %>%
  filter(job != "Original_Beafort_19_job" & job != "kotz_manual_review")

# Create RGB annotation dataset for import
annotations_rgb <- anno_annotation %>%
  mutate(age_class = ifelse(age_class == '\\N', "adult", age_class)) %>%
  filter(rgb_event_key != '\\N') %>%
  mutate(rgb_box_id = as.integer(ifelse(eo_box_id == '\\N', "-99", eo_box_id))) %>%
  # Join and process species data
  left_join(anno_species, by = c("species_id" = "id")) %>%
  # Join and process IR bounding box data
  left_join(anno_boxes, by = c("eo_box_id" = "id")) %>%
  rename(detection = id,
    detection_type = species,
    bound_top = x1,
    bound_bottom = x2,
    bound_left = y1,
    bound_right = y2,
    confidence = confidence,
    reviewer = worker_id,
    job = job_id) %>%
  # Join image data
  left_join(surv_image_eo, by = "rgb_event_key") %>%
  rename(image_name = rgb_filename) %>%
  select(detection, image_name, bound_left, bound_top, bound_right, bound_bottom,
    detection_type, reviewer, job) %>%
  filter(job != "Original_Beafort_19_job" & job != "kotz_manual_review")

rm(anno_annotation, anno_boxes, anno_species)
### Want to calculate flight, camera_view, dt fields? (probably should do this!)

# --- Process image data ---
# Load data for generating lists of images and how they were used (will update surv_chess.tbl_iamges_unfilt)
ir_verified_background <- read.table(file = 'manual_review.ir_verified_background.tsv', sep = '\t', header = TRUE) %>%
  left_join(surv_image_ir, by = "ir_event_key") %>%
  select(ir_filename) %>%
  rename(image_name = ir_filename) %>%
  mutate(ml_imagestatus = 'background')

anno_train_test_valid <- read.table(file = 'annotation_data.train_test_valid.tsv', sep = '\t', header = TRUE) 
anno_train_test_valid <- anno_train_test_valid %>%
  rename(ml_imagestatus = type,
    rgb_event_key = eo_event_key) %>%
  left_join(surv_image_eo, by = "rgb_event_key") %>%
  left_join(surv_image_ir, by = "ir_event_key") %>%
  select(rgb_filename, ir_filename, ml_imagestatus) 

anno_train_test_valid_rgb <- anno_train_test_valid %>% 
  select(rgb_filename, ml_imagestatus) %>% 
  rename(image_name = rgb_filename)

anno_train_test_valid_ir <- anno_train_test_valid %>% 
  select(ir_filename, ml_imagestatus) %>% 
  rename(image_name = ir_filename) %>%
  anti_join(ir_verified_background, by = "image_name")

# Create image use dataset for import
frames <- ir_verified_background %>%
  rbind(anno_train_test_valid_rgb) %>%
  rbind(anno_train_test_valid_ir) %>%
  filter(!is.na(image_name)) %>%
  mutate(image_name = sub("^[0-9][0-9][0-9]_", "", image_name)) %>%
  mutate(project = substr(image_name, 1, 8)) %>%
  mutate(image_type = ifelse(
    grepl("ir", image_name), 
    "ir_image",
    ifelse(
      grepl("rgb", image_name), 
      "rgb_image", 
      ifelse(
        grepl("COLOR", image_name), 
        "rgb_image",
        ifelse(
          grepl("THERM", image_name), 
          "ir_image", 
          "help"
    ))))) %>%
  filter(project != 'CHESS_ru') %>% # not sure what these data are, so not keeping them! :/
  mutate(image_name = sub("rgb.jpg", "rgb.tif", image_name)) # for test_kotz and polar_bear data (face palm)

frames %>%
  group_by(project) %>% 
  summarize(count = n())

rm(ir_verified_background, anno_train_test_valid, anno_train_test_valid_rgb, anno_train_test_valid_ir, surv_image_eo, surv_image_ir)
## Code working through this step

# --- Process data to DB
# Connect to DB
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"), 
                              password = Sys.getenv("admin_pw"))

# Process ChESS IR and RGB annotations to DB
RPostgreSQL::dbWriteTable(con, c("surv_chess", "tbl_detections_modeldev_ir"), annotations_ir, overwrite = TRUE, row.names = FALSE)
RPostgreSQL::dbWriteTable(con, c("surv_chess", "tbl_detections_modeldev_rgb"), annotations_rgb, overwrite = TRUE, row.names = FALSE)

# Update ml_imagestatus fields in DB based on this list of images
## Write data to annotations.tbl_temp
RPostgreSQL::dbWriteTable(con, c("annotations", "temp"), frames, overwrite = TRUE, row.names = FALSE)

## surv_chess.tbl_images_unfilt
RPostgreSQL::dbSendQuery(con, "UPDATE surv_chess.tbl_images_unfilt SET ml_imagestatus = NULL")
RPostgreSQL::dbSendQuery(con, 
  "UPDATE surv_chess.tbl_images_unfilt i
  SET ml_imagestatus = t.ml_imagestatus 
  FROM annotations.temp t
  WHERE t.image_name = i.unfilt_image;")


## surv_polar_bear.tbl_images
RPostgreSQL::dbSendQuery(con, "UPDATE surv_polar_bear.tbl_images SET ml_imagestatus = NULL")
RPostgreSQL::dbSendQuery(
  con, 
  "UPDATE surv_polar_bear.tbl_images i
  SET ml_imagestatus = t.ml_imagestatus 
  FROM annotations.temp t
  WHERE t.image_name = i.image_name;")

## surv_test_kotz.tbl_images
RPostgreSQL::dbSendQuery(con, "UPDATE surv_test_kotz.tbl_images SET ml_imagestatus = NULL")
RPostgreSQL::dbSendQuery(
  con, 
  "UPDATE surv_test_kotz.tbl_images i
  SET ml_imagestatus = t.ml_imagestatus 
  FROM annotations.temp t
  WHERE t.image_name = i.image_name;")

## Delete data from annotations.tbl_temp
RPostgreSQL::dbSendQuery(con, "DROP TABLE IF EXISTS annotations.temp")

# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)