
shinyServer(function(input, output, session) {
  session$onSessionEnded(stopApp)
  
  output$numSce <- reactive({
    input$sceNum
  })
  
  output$scenarioFiles <- renderUI({
    numScenarios <- input$sceNum
    if(numScenarios == "") return(NULL)
    lapply(1:numScenarios, function(i){
      list(fileInput(paste0("sceFile", i), paste0("Scenario File - ", i), accept = c(".csv")))
    })
  })
  
  output$mainTabs <- renderUI({
    nTabs <- input$sceNum
    if(nTabs == "") return(NULL)
    
    #modelResultsTabs <- lapply(paste('Scenario Results ', 1: nTabs), tabPanel)
    
    # this should be done more efficiently 
    result1Tab <- list(tabPanel("Scenario Results 1", br(), dataTableOutput("sceResult1")))
    result2Tab <- list(tabPanel("Scenario Results 2", br(), dataTableOutput("sceResult2")))
    result3Tab <- list(tabPanel("Scenario Results 3", br(), dataTableOutput("sceResult3")))
    result4Tab <- list(tabPanel("Scenario Results 4", br(), dataTableOutput("sceResult4")))
    result5Tab <- list(tabPanel("Scenario Results 5", br(), dataTableOutput("sceResult5")))
    
    if(nTabs == 1) modelResultsTabs = result1Tab
    if(nTabs == 2) modelResultsTabs = append(result1Tab, result2Tab)
    if(nTabs == 3) modelResultsTabs = append(append(result1Tab, result2Tab), result3Tab)
    if(nTabs == 4) modelResultsTabs = append(append(append(result1Tab, result2Tab), result3Tab), result4Tab)
    if(nTabs == 5) modelResultsTabs = append(append(append(append(result1Tab, result2Tab), result3Tab), result4Tab), result5Tab)

    otherTabs <- list(tabPanel("Revenue By Hour", 
                      br(), fluidRow(column(12, checkboxGroupInput("revLaneType", label = "Select Lane(s)", 
                                                             choices = list("POV_GP","POV_RE","POV_SE","POV_SB","COM_GP","COM_SP","COM_SB"), inline = TRUE))),
                      div(style="display: inline-block;vertical-align:top; width: 80px;",selectInput("revStartTime", "Start Time:", choices = c("", seq(1:24)), selected = 1, width = "100px")),
                      div(style="display: inline-block;vertical-align:top; width: 50px;",HTML("<br>")),
                      div(style="display: inline-block;vertical-align:top; width: 80px;",selectInput("revEndTime", "End Time:", choices = c("", seq(1:24)), selected = 24, width = "100px")),
                      br(), plotOutput("revByHour")),
                      
                      tabPanel("Toll By Hour", 
                      br(), 
                      div(style="display: inline-block;vertical-align:top; width: 120px;", selectInput("tollVehType", "Vehicle Type:", choices = c("", "POV" = 1, "TRK" = 2), width = "100px")),
                      div(style="display: inline-block;vertical-align:top; width: 20px;",HTML("<br>")),
                      div(style="display: inline-block;vertical-align:top; width: 120px;", selectInput("tollDirection", "Direction:", choices = c("", "NB" = 1, "SB" = 2), width = "100px")),
                      br(), plotOutput("tollByHour")
                      ),
                      
                      tabPanel("Volume By Hour", 
                      br(), fluidRow(column(12, checkboxGroupInput("volLaneType", label = "Select Lane(s)", 
                                                                   choices = list("POV_GP","POV_RE","POV_SE","POV_SB","COM_GP","COM_SP","COM_SB"), inline = TRUE))),
                      fluidRow(column(12, checkboxGroupInput("volPort", label = "Select Port(s)", choices = list("SY","OM","OME"), inline = TRUE))),
                      div(style="display: inline-block;vertical-align:top; width: 80px;",selectInput("volStartTime", "Start Time:", choices = c("", seq(1:24)), selected = 1, width = "100px")),
                      div(style="display: inline-block;vertical-align:top; width: 50px;",HTML("<br>")),
                      div(style="display: inline-block;vertical-align:top; width: 80px;",selectInput("volEndTime", "End Time:", choices = c("", seq(1:24)), selected = 24, width = "100px")),
                      br(), plotOutput("volByHour"))
    )
                   
    allTabs <- append(modelResultsTabs, otherTabs)                         

    do.call(tabsetPanel, allTabs)
  })
  
  results_by_scenario <- reactive({
    results <- list()
    numScenarios <- input$sceNum
  
    for(i in 1:numScenarios){
      #input_file <- "C:/Users/kulshresthaa/Desktop/SANDAG/OtayMesa/sr11_ome/data_out/scenario_results_compare/17Baseline_poe_traffic.csv"
      
      # do this more smartly
      if(i == 1) inFile <- input$sceFile1
      if(i == 2) inFile <- input$sceFile2
      if(i == 3) inFile <- input$sceFile3
      if(i == 4) inFile <- input$sceFile4
      if(i == 5) inFile <- input$sceFile5
      
      if(is.null(inFile)) return(NULL)
      
      ## Using readxl::read_excel gives "Unknown Format" error
      ## This is open issue with readxl package
      ## Currently implemented a workaround - copy the file datapath and append .xlsx
      ## instead of using results[[i]] <- readxl::read_excel(inFile$datapath, sheet = 1)
      ## file.rename(inFile$datapath, paste(inFile$datapath, ".xlsx", sep=""))
      ## results[[i]] <- readxl::read_excel(paste(inFile$datapath, ".xlsx", sep=""), 1)
      
      # result file is now CSV format
      results[[i]] <- readr::read_csv(inFile$datapath)
    }
    return(results)
  })
    
  all_results <- reactive({
    sce_results <- results_by_scenario()
    if(is.null(sce_results)) return(NULL)
    
    numScenarios <- input$sceNum
    
    for(i in 1:numScenarios){
      sceResult <- sce_results[[i]]
      sceResult$Sce <- i
      if(i == 1) all_results <- sceResult
      if(i > 1) all_results <- rbind(all_results, sceResult)
    }
    return(all_results)
  })
  
  output$sceResult1 <- renderDataTable({
    sce_results <- results_by_scenario()
    if(is.null(sce_results[[1]])) return(NULL)
    datatable(sce_results[[1]], options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "lengthMenu" = c(10,25,50,100)), rownames = FALSE)
  })
  
  output$sceResult2 <- renderDataTable({
    sce_results <- results_by_scenario()
    if(is.null(sce_results[[2]])) return(NULL)
    datatable(sce_results[[2]], options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "lengthMenu" = c(10,25,50,100)), rownames = FALSE)
  })
  
  output$sceResult3 <- renderDataTable({
    sce_results <- results_by_scenario()
    if(is.null(sce_results[[3]])) return(NULL)
    datatable(sce_results[[3]], options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "lengthMenu" = c(10,25,50,100)), rownames = FALSE)
  })
  
  output$sceResult4 <- renderDataTable({
    sce_results <- results_by_scenario()
    if(is.null(sce_results[[4]])) return(NULL)
    datatable(sce_results[[4]], options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "lengthMenu" = c(10,25,50,100)), rownames = FALSE)
  })
  
  output$sceResult5 <- renderDataTable({
    sce_results <- results_by_scenario()
    if(is.null(sce_results[[5]])) return(NULL)
    datatable(sce_results[[5]], options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "lengthMenu" = c(10,25,50,100)), rownames = FALSE)
  })
  
  output$revByHour <- renderPlot({
    if(input$sceNum == "") return(NULL)
    if(is.null(all_results())) return(NULL)
    
    selLanes <- input$revLaneType
    if(length(selLanes)==0) return(NULL)
    
    startTime <- as.numeric(input$revStartTime)
    endTime <- as.numeric(input$revEndTime)
    
    input_data <- all_results() %>% mutate(processed = (Volume - Unprocessed), revenue = 0)
    input_data <- input_data %>% mutate( revenue = case_when(.$POE == "OME" & .$Lane %in% c("POV_GP", "POV_SE", "POV_RE") ~ (.$processed * .$`NB POV Toll`),
                                                             .$POE == "OME" & .$Lane %in% c("POV_SB") ~ (.$processed * .$`SB POV Toll`),
                                                             .$POE == "OME" & .$Lane %in% c("COM_GP", "COM_SP") ~ (.$processed * .$`NB Trk Toll`),
                                                             .$POE == "OME" & .$Lane %in% c("COM_SB") ~ (.$processed * .$`SB Trk Toll`),
                                                             TRUE ~ 0))
    
    input_data$Sce <- as.factor(input_data$Sce)
    
    input_data <- input_data %>%
                  filter(POE == "OME" & Lane %in% selLanes) %>%
                  filter(Time >= startTime & Time <= endTime) %>%
                  group_by(Time, Sce) %>% summarise(tot_revenue = sum(revenue))
    
    
    ggplot(input_data, aes(x=Time, y = tot_revenue)) + 
      geom_bar(aes(fill = Sce), position = "dodge", stat="identity", width = 0.75) + 
      scale_x_continuous(breaks=seq(startTime, endTime, 1)) + 
      scale_y_continuous(labels = scales::dollar) + 
      labs(x = "Hour", y = "Total Revenue") + theme_bw() + 
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) 
    
  })
  
  output$tollByHour <- renderPlot({
    if(is.null(all_results())) return(NULL)
    
    vehType <- input$tollVehType
    if(vehType == "") return(NULL)
  
    direction <- input$tollDirection
    if(direction == "") return(NULL)
    
    if(vehType == 1 & direction == 1) tollString <- paste("NB", "POV", sep = " ")
    if(vehType == 2 & direction == 1) tollString <- paste("NB", "Trk", sep = " ")
    if(vehType == 1 & direction == 2) tollString <- paste("SB", "POV", sep = " ")
    if(vehType == 2 & direction == 2) tollString <- paste("SB", "Trk", sep = " ")
    
    input_data <- all_results() %>%
      filter(POE == "OME") %>% 
      select(Time, Sce, starts_with(tollString)) %>% 
      group_by(Time, Sce) %>% summarise_all(mean)
    
    names(input_data) <- c("Time", "Sce", "Toll")
    input_data$Sce <- as.factor(input_data$Sce)
    
    ggplot(input_data, aes(x = Time, y = Toll)) +
      geom_bar(aes(fill = Sce), position = "dodge", stat="identity", width = 0.75) +
      scale_x_continuous(breaks=seq(1, 24, 1)) + 
      scale_y_continuous(labels = scales::dollar) + 
      labs(x = "Hour", y = "Toll") + theme_bw() + 
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) 
  })
  
  output$volByHour <- renderPlot({
    if(input$sceNum == "") return(NULL)
    if(is.null(all_results())) return(NULL)
    
    selLanes <- input$volLaneType
    port <- input$volPort
    
    if(length(selLanes)==0 | length(port)==0) return(NULL)
    
    startTime <- as.numeric(input$volStartTime)
    endTime <- as.numeric(input$volEndTime)
    
    input_data <- all_results()
    input_data$Sce <- as.factor(input_data$Sce)
    
    input_data <- input_data %>%
      filter(POE %in% port & Lane %in% selLanes) %>%
      filter(Time >= startTime & Time <= endTime) %>%
      group_by(Time, Sce) %>% summarise(tot_vol = sum(Volume))
    
    ggplot(input_data, aes(x=Time, y = tot_vol)) + 
      geom_bar(aes(fill = Sce), position = "dodge", stat="identity", width = 0.75) + 
      scale_x_continuous(breaks=seq(startTime, endTime, 1)) + 
      scale_y_continuous(labels = comma) + 
      labs(x = "Hour", y = "Total Volume") + theme_bw() + 
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) 
  })

  outputOptions(output, 'numSce', suspendWhenHidden = FALSE)
})