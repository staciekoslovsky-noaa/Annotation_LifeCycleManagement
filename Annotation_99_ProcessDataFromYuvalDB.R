# Process annotation data from Yuval for import into pep DB
# S. Hardy

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
wd <- "C:/Users/Stacie.Hardy/Work/Work/Projects/AS__Annotations/Data/YuvalDB_ParseFromSQL_20220707"
setwd(wd)

anno_annotation <- read.table(file = 'annotation_data.annotation.tsv', sep = '\t', header = TRUE) %>%
  rename(rgb_event_key = eo_event_key)
anno_boxes <- read.table(file = 'annotation_data.bounding_boxes.tsv', sep = '\t', header = TRUE)
anno_species <- read.table(file = 'annotation_data.species.tsv', sep = '\t', header = TRUE) %>%
  rename(species = name,
         rgb_event_key = eo_event_key) %>%
  mutate(species = gsub("UNK", "unknown", species)) %>%
  mutate(species = snakecase::to_snake_case(species))
anno_train_test_valid <- read.table(file = 'annotation_data.train_test_valid.tsv', sep = '\t', header = TRUE) %>%
  select(ir_event_key, eo_event_key, type) %>%
  rename(image_used_for = type,
         rgb_event_key = eo_event_key)

ir_uncertain_background <- read.table(file = 'manual_review.ir_uncertain_background.tsv', sep = '\t', header = TRUE)
ir_verified_background <- read.table(file = 'manual_review.ir_verified_background.tsv', sep = '\t', header = TRUE)
ir_with_error <- read.table(file = 'manual_review.ir_with_error.tsv', sep = '\t', header = TRUE)
ir_without_errors <- read.table(file = 'manual_review.ir_without_errors.tsv', sep = '\t', header = TRUE)

surv_camera <- read.table(file = 'survey_data.camera.tsv', sep = '\t', header = TRUE) %>%
  rename(camera_view = cam_name,
         camera_id = id)
surv_flight <- read.table(file = 'survey_data.flight.tsv', sep = '\t', header = TRUE) %>%
  rename(flight = flight_name, 
         flight_id = id) %>%
  mutate(flight = tolower(flight))
surv_survey <- read.table(file = 'survey_data.survey.tsv', sep = '\t', header = TRUE) %>%
  rename(survey = name,
         survey_id = id)

surv_image_eo <- read.table(file = 'survey_data.eo_image.tsv', sep = '\t', header = TRUE) %>%
  rename_with( ~ paste0("rgb_", .x))
surv_image_ir <- read.table(file = 'survey_data.ir_image.tsv', sep = '\t', header = TRUE) %>%
  rename_with( ~ paste0("ir_", .x))


# Join and clean up files annotation + survey files
annotations_ir <- anno_annotation %>%
  mutate(age_class = ifelse(age_class == '\\N', "adult", age_class)) %>%
  mutate(ir_box_id = as.integer(ifelse(ir_box_id == '\\N', "-99", ir_box_id))) %>%
  # Join and process species data
  left_join(anno_species, by = c("species_id" = "id")) %>%
  # Join and process IR bounding box data
  left_join(anno_boxes, by = c("ir_box_id" = "id")) %>%
  rename(ir_bound_top = x1,
         ir_bound_bottom = x2,
         ir_bound_left = y1,
         ir_bound_right = y2,
         ir_confidence = confidence,
         ir_reviewer = worker_id,
         ir_job = job_id) %>%
  # Join train-test-valid data
  select(-rgb_event_key) %>%
  filter(ir_event_key != '\\N') %>%
  left_join(anno_train_test_valid, by = c("ir_event_key")) 

annotations_rgb <- anno_annotation %>%
  mutate(age_class = ifelse(age_class == '\\N', "adult", age_class)) %>%
  mutate(ir_box_id = as.integer(ifelse(ir_box_id == '\\N', "-99", ir_box_id))) %>%
  # Join and process species data
  left_join(anno_species, by = c("species_id" = "id")) %>%
  # Join and process RGB bounding box data
  left_join(anno_boxes, by = c("eo_box_id" = "id")) %>%
  rename(rgb_event_key = eo_event_key,
         rgb_box_id = eo_box_id, 
         rgb_bound_top = x1,
         rgb_bound_bottom = x2,
         rgb_bound_left = y1,
         rgb_bound_right = y2,
         rgb_confidence = confidence,
         rgb_reviewer = worker_id,
         rgb_job = job_id) %>%
  # Join train-test-valid data
  select(-ir_event_key) %>%
  filter(rgb_event_key != '\\N') %>%
  left_join(anno_train_test_valid, by = "rgb_event_key")

data_ir <- surv_survey %>%
  left_join(surv_flight, by = "survey_id") %>%
  left_join(surv_camera, by = "flight_id") %>%
  left_join(surv_image_ir, by = c("camera_id" = "ir_camera_id")) %>%
  select(-survey_id, -flight_id, -camera_id) %>%
  full_join(annotations_ir, by = "ir_event_key")

data_rgb <- surv_survey %>%
  left_join(surv_flight, by = "survey_id") %>%
  left_join(surv_camera, by = "flight_id") %>%
  left_join(surv_image_eo, by = c("camera_id" = "rgb_camera_id")) %>%
  select(-survey_id, -flight_id, -camera_id) %>%
  full_join(annotations_rgb, by = "rgb_event_key")

write.csv(data_ir, "Annotations_IR_FromYuval_20220725.csv", row.names = FALSE)
write.csv(data_rgb, "Annotations_RGB_FromYuval_20220725.csv", row.names = FALSE)
            