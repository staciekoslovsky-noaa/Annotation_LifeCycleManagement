# Glacial: Export image lists and detection files for post-processing (by flight, not survey_id)

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
# Set variables
project_id = 'glacial_2021'
#project_id = 'glacial_2020'

# Extract data from DB ------------------------------------------------------------------
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              user = Sys.getenv("pep_admin"),
                              password = Sys.getenv("admin_pw"))

annotations <- RPostgreSQL::dbGetQuery(con, paste0("SELECT *
                                                    FROM surv_pv_gla.annotations_4postprocessing_seals
                                                    WHERE project_id = \'", project_id, "\'"))
                                       
images <- RPostgreSQL::dbGetQuery(con, paste0("SELECT image_name, image_dir
                                                    FROM surv_pv_gla.annotations_4postprocessing_images
                                                    WHERE project_id = \'", project_id, "\'"))
                                  
datasets <- annotations %>%
  select(flight, camera_view, project_id) %>%
  unique()

annotations_withPath <- annotations %>%
  left_join(images, by = 'image_name') %>%
  mutate(image_name = paste0(image_dir, '/', image_name)) %>%
  mutate(image_name = sub('//akc0ss-n086', 'Y:', image_name))
  

# Process data from each flight
for (i in 1:nrow(datasets)){
  annotations_subset <- annotations_withPath %>%
    filter(flight == datasets$flight[i] & camera_view == datasets$camera_view[i] & project_id == datasets$project_id[i]) %>%
    select(-flight, -camera_view, -project_id, -image_dir)
  
  write.table(annotations_subset, paste0("C:\\smk\\", datasets$project_id[i], '_', datasets$flight[i], '_', datasets$camera_view[i], "_sealDetections4analysis_", format(Sys.Date(), '%Y%m%d'), ".csv"), row.names = FALSE, quote = FALSE, col.names = FALSE, sep = ",")
}

# Disconnect for database and delete unnecessary variables ------------------------------
dbDisconnect(con)
rm(con)