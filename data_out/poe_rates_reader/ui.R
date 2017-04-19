
library(shiny)
library(shinydashboard)
library(tidyverse)
library(DT)
library(shinysky)

header <- dashboardHeader(
  title = "Otay Mesa - POE Rates Reader",
  titleWidth = 300
)

sidebar <- dashboardSidebar(
  width = 300,
  fileInput("poeRateFile", "Select POE Rate File"),
  fluidRow(column(6, selectInput("vehType", "Vehicle Type", choices = c("", "POV" = 1, "COM" = 2), width = "150px"))),
  uiOutput('laneTypes'),
  uiOutput('portTypes')
)

body <- dashboardBody(
  tabsetPanel(
    tabPanel("POE Comparison", dataTableOutput("poeCompare")),
    tabPanel("POE Chart", br(),
      selectInput("attrType", "Select Attribute:",
                  choices = c("", "Max Lanes" = 1, "Open Lanes" = 2), selected = 1, width = "150px"),
      br(), plotOutput("poePlot")
    ),
    tabPanel("Edit Rates", hotable("editRates"), br(), downloadButton('saveData', 'Save'))
  )
)

dashboardPage(header, sidebar, body)