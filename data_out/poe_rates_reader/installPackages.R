# Ashish Kulshrestha | kulshresthaa@pbworld.com | Parsons Brinckerhoff
# Last Edited: July 31, 2016
# Script to check if requred packages are already installed, if not then install the packages.

packages <- c("tidyverse", "DT", "devtools")

if (length(setdiff(packages, rownames(installed.packages()))) > 0) {
  install.packages(setdiff(packages, rownames(installed.packages())))  
}

if(!"shinysky" %in% installed.packages()) devtools::install_github("AnalytixWare/ShinySky")