
library(shiny)
library(shinydashboard)
library(tidyverse)
library(DT)
library(scales)

header <- dashboardHeader(
  title = "Otay Mesa - Scenario Results Comparison",
  titleWidth = 300
)

sidebar <- dashboardSidebar(
  width = 300,
  selectInput("sceNum", "Number of Scenario Results to Compare:", choices = c("", seq(1:5))),
  br(),
  uiOutput('scenarioFiles')
)

body <- dashboardBody(
  uiOutput("mainTabs")
)

dashboardPage(header, sidebar, body)