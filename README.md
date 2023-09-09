# Annotation Life Cycle Management

This repository contains code for managing annotations across all projects using AI/ML.

The code is labeled by project. Code numbered 0+ are intended to be run sequentially as the data are available for processing. Code numbered 99 are stored for longetivity, but are intended to only be run once to address a specific issue or run as needed, depending on the intent of the code.

General annotation data management code:
* **Annotation_00_ExportImageListFromDB.R** - generic code for exporting an image list from the DB
* **Annotation_99_ProcessDataFromYuvalDB.R** - code to handle and process data managed separately by a former team member...still needs some work and attention

ChESS annotation data management code:
* **Annotation_ChESS_99_TestingTraining_PolarBears.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for polar bear sightings in the ChESS imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin
* **Annotation_ChESS_99_TestingTraining_SealPups.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for seal pup sightings in the ChESS imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin

JoBSS annotation data management code:
* **Annotation_JoBSS_01_ProcessDetectorOutputData_with20210726_batchProcessing.R** - processes the original (before review) detection data from JoBSS imagery into the PEP database
* **Annotation_JoBSS_02_ImportProcessedIR2DB_with20210726_batchProcessing.R** - processes the reviewed IR detection data from the JoBSS imagery into the PEP database
* **Annotation_JoBSS_03_SetRandomOrderAndQuartileBreaks_with20210726_batchProcessing.R** - after the IR detection data are imported, identifies quantile breaks in the data, which are important for processing steps
* **Annotation_JoBSS_04a_ImportProcessedRGB2DB_with20210726_batchProcessing.R** - processed the reviewed RGB detection data from the JoBSS imagery into the PEP database
* **Annotation_JoBSS_04b_MatchBoundingBoxes.Rmd** - matches the IR detections to the RGB detections, since the data do not share a common identifier; the outputs from this processing still need to be evaluated by biologists for identifying the "best" approach moving forward
* **Annotation_JoBSS_05_ImportProcessedUV2DB_with20210726_batchProcessing.R** - processed the reviewed UV detection data from the JoBSS imagery into the PEP database
* **Annotation_JoBSS_99_TestingTraining_PolarBears.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for polar bear sightings in the JoBSS imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin
* **Annotation_JoBSS_99_TestingTraining_SealPups.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for seal pup sightings in the JoBSS imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin

Polar bear (from polar_bear flights in Kotzebue and Deadhorse) annotation data management code:
* **Annotation_PolarBear_99_TestingTraining_SealPups.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for seal pup sightings in the polar_bear_2019 imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin

Glacial harbor seal survey annotation data management:
* **Annotation_Pv_G_01_ImportProcessedRGB2DB_byYear.R** - imports processed RGB detections to the DB by year and by survey area
* **Annotation_Pv_G_02_ExportData4PostProcessing.R** - exports reformatted processed RGB detections and associated image lists (exported by flight, rather than by survey area) for running the data through the KAMERA post-processing script
* **Annotation_Pv_G_03_ImportDetectionShp2DB.R** - imports the detection shapefiles (output from KAMERA post-processing) into the DB for further processing in the glacial project

Test (data from Kotzebue) annotation data management:
* **Annotation_TestKotz_99_TestingTraining_SealPups.txt** - SQL query for generating image lists and annotations (formatted for use in VIAME image processing software) for seal pup sightings in the test_kotz_2019 imagery; identifies which annotations are to be used for training detection models and which annotations are to be used for testing those models after development; must be run in PGAdmin

FAQ:
* Should users be adding the names of detection files to the tracking processing step form? Yes. They should be updated the processed/validated detection file names as they're created.
