
shinyServer(function(input, output) {
  
  poe_rates <- reactive({
    inFile <- input$poeRateFile
    if (is.null(inFile)) return(NULL)
    #input_file <- "C:/Users/kulshresthaa/Desktop/SANDAG/OtayMesa/poe_rates_reader/poe_rates_constrain0327.csv"
    #read_csv(input_file)
    read_csv(inFile$datapath)
  })
  
  output$laneTypes <- renderUI({
    laneVars <- c("", "GP", "RE", "SE", "SB")
    if(input$vehType == 2) laneVars <- c("", "GP", "SP", "SB")
    fluidRow(column(6, selectInput("laneType", "Lane Type", choices = laneVars)))
  })

  output$portTypes <- renderUI({
    portVars <- list("SY", "OM", "OME")
    if(input$vehType == 2) portVars <- list("OM", "OME")
    fluidRow(column(12, checkboxGroupInput("portType", label = "Select Port(s)", choices = portVars, inline = TRUE)))
  })
  
  edit_rates <- reactive({
    if(is.null(input$editRates)){return(poe_rates())}
    else if(!identical(poe_rates(),input$editRates)){return(as.data.frame(hot.to.df(input$editRates)))}
  })
  
  output$poeCompare <- renderDataTable({
    if(is.null(poe_rates())) return(NULL)
    
    laneType <- input$laneType
    ports <- input$portType
    vehType <- input$vehType
    
    if(input$vehType < 1) return(NULL)
    if(length(ports)==0 | !input$laneType %in% c("GP", "RE", "SE", "SP", "SB")) return(NULL)
    
    if(vehType == 1) tokens <- paste(ports, laneType, sep="_")
    if(vehType == 2) tokens <- paste(paste0(ports, "C"),laneType, sep="_")
    
    rates <- poe_rates() %>% select(HOUR, TIME, sapply(tokens, starts_with))
    DT::datatable(rates, options = list("scrollX" = TRUE, "searching" = FALSE, "processing" = TRUE, "paging" = FALSE), rownames = FALSE)
  })
  
  output$poePlot <- renderPlot({
    if(is.null(poe_rates())) return(NULL)
    
    laneType <- input$laneType
    ports <- input$portType
    vehType <- input$vehType
    
    if(input$attrType == 1) attribute <- "MAX"
    if(input$attrType == 2) attribute <- "OPEN"
    
    if(input$vehType < 1) return(NULL)
    if(length(ports)==0 | !input$laneType %in% c("GP", "RE", "SE", "SP", "SB")) return(NULL)
    
    if(vehType == 1) tokens <- paste(ports, laneType, attribute, sep="_")
    if(vehType == 2) tokens <- paste(paste0(ports, "C"),laneType, attribute, sep="_")
    
    input_data <- poe_rates() %>% select(HOUR, sapply(tokens, starts_with))
    input_data <- gather(input_data, Port, value, -HOUR)
    
    ggplot(input_data, aes(x=HOUR, y = value)) + geom_bar(aes(fill = Port), position = "dodge", stat="identity") + 
      labs(x = "Hour", y = "Lanes") + scale_fill_discrete(labels = ports) + 
      scale_x_continuous(breaks=seq(0, 24, 1)) + theme_bw() + 
      theme(panel.grid.major = element_blank(), panel.grid.minor = element_blank()) 
  })
  
  output$editRates <- renderHotable({edit_rates()}, readOnly = F)  
  
  output$saveData <- downloadHandler(filename = "poe_rates_revised.csv", content = function(file) {write.csv(edit_rates(), file, row.names = FALSE)})
})
