# JoBSS: Set random order for species ID and quartile breaks for species misclassification

# Install libraries
library(tidyverse)
library(RPostgreSQL)

# Set up working environment
con <- RPostgreSQL::dbConnect(PostgreSQL(), 
                              dbname = Sys.getenv("pep_db"), 
                              host = Sys.getenv("pep_ip"), 
                              #port = Sys.getenv("pep_port"), 
                              user = Sys.getenv("pep_admin"), 
                              rstudioapi::askForPassword(paste("Enter your DB password for user account: ", Sys.getenv("pep_admin"), sep = "")))

# Get data from DB
ir_summary <- RPostgreSQL::dbGetQuery(con, "SELECT flight, camera_view, count(flight) FROM surv_jobss.tbl_detections_processed_ir WHERE hotspot_type = \'animal\' OR hotspot_type = \'animal_new\' GROUP BY flight, camera_view")

# Set random order and update DB
set.seed(129)
ir_summary <- ir_summary[sample(1:nrow(ir_summary)), ]
ir_summary$random_order <- 1:nrow(ir_summary)



  


# Disconnect from DB
RPostgreSQL::dbDisconnect(con)
rm(con)
