# KIM-QA-Analysis
This repository contains codes used for KIM QA analysis using the 6 DoF robot. Three QA tests are performed to validate KIM's tracking accuracy and repeatability: 

1. Static localisation test
2. Dynamic localisation test
3. Treatment Interruption test

Details of the analysis procedure can be found in the attached document: KIM QA publication.pdf.  

# Instructions  

## Requirements:
* Tested with MATLAB (or MCR) 2021a 64 bit 
   * May work with previos version, should work with future versions
   * MCR is a distributable available from Mathworks that enable Matlab executables to be run on computers that do not have MATLAB installed. It can be downloaded from the Mathworks website  
* No toolboxes are required

## Instructions to run tests:  
1. Download analysis codes (AnalyseKIMQA_UI.mlapp & AnalyseKIMqa.m) if you have Matlab installed or the executable folder if you have MCR.  
2. If MATLAB has been installed, Open and run the MATLAB app (.mlapp file), otherwise run the executable  
   1. Dynamic & Treatment Interrupt tests
      Select the correct 'Analysis type' radio button so that documentation is correct
      * a) 'KIM log' - The folder that contains KIM log files. Usually the Image folder contains 'Markerlocation_GA.txt' file/files which is/are needed for this analyis.
      * b) 'Motion Trace' - load the motion file used by the 6DoF Robot or Hexamotion platform  
         The files are names according to the anatomical region they apply to (LiverTraj were sources from Liver treatments) and then the type of motion they contain  
         * Standard versions are located in the 'Robot Traces' folder; these should be suitable for standard dynamic testing  
         * Longer (20 min) versions are located in the subfolder 'Traces for interrupt testing'  
      * c) 'Coordinate file' - Contains the co-ordinates of the markers and the isocentre  
         * Can either be the KIM centroid file or have the following format  
            * Contains the [x y z] details of the marker positions in the patient (code assumes 3 markers per patient) followed by the [x y z] isocentre position in the patient  
            * One line per marker, all positions in mm  
            * Final line is the isocentre in the same format as the markers  
            * The code requires this file to only contain numbers.  
   2. Static Tests  
      Select the 'Static' analysis radio button to convert the UI to Static
      The UI requires the following inputs to perform the analysis:  
      * a) 'KIM log' - The folder that contains KIM log files. Usually the Image folder contains 'Markerlocation_GA.txt' file/files which is/are needed for this analyis.
      * b) 'Coordinate file' - Contains the co-ordinates of the markers and the isocentre  
         * Can either be the KIM centroid file or have the following format  
            * Contains the [x y z] details of the marker positions in the patient (code assumes 3 markers per patient) followed by the [x y z] isocentre position in the patient  
            * One line per marker, all positions in mm  
            * Final line is the isocentre in the same format as the markers  
            * The code requires this file to only contain numbers.  
      * c) 'Static shifts' - Applied couch shifts.  
      * d) 'Linac Vendor' - 
      * e) 'Output Folder' - Where the output files will be saved, by default its the KIM log file but can be changed
3. Click on 'Analyse'. 
   

## Output
This will produce a text file containing the mean, standard deviation and percentiles (5/95) difference between the KIM detected motion and the source motion used by the motion platform. Figures detailing the KIM trace and robot motion are also generated.  

## Notes
The parameter file is no longer required to match the traces  

# Test Cases
Within the folder *Test Files*, there are folders that contain relevent test data sets for static, dynamic and treatment interruption tests  
   * The folders under *Dynamic* & *Tx Interrupt* match up with the motion trace used  
      * E.g. *Baseline_cardiac* folder matches with the **LiverTraj_BaselineWanderWithCardiac70s_robot.txt** file  
   To run a dynamic test  
   1. Select the **Dynamic** radio button
   2. Select the desired folder e.g. *\KIM-QA-Analysis\Test Files\Varian\Dynamic\Large_SI_AP_Breathhold*  
   3. Select the matched motion trace e.g. *LiverTraj_LargeSIandAPWithBreathHold_robot.txt*  
   4. Select the *co-ords.txt* file located in the Vendor folder e.g. *\KIM-QA-Analysis\Test Files\Varian\co-ords.txt*  
   5. Select the correct vendor radio button e.g. **Varian**  
   6. Change the output folder if desired  
   7. Click 'Analyse' and inspect the results  