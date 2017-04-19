args=commandArgs(trailingOnly=TRUE)
folder_address = args[1]

if(!"shiny" %in% installed.packages()) install.packages("shiny")
if(!"shinydashboard" %in% installed.packages()) install.packages("shinydashboard")

suppressWarnings(suppressMessages(require(shiny)))
suppressWarnings(suppressMessages(runApp(folder_address, launch.browser=TRUE)))