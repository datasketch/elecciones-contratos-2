library(shiny)
library(tidyverse)
library(DT)
library(formattable)
library(hgchmagic)
library(shinyinvoer)

# Data
contratos <- read_csv('data/contratos_cruces.csv')
dic_contratos <- read_csv('data/dic.csv')
info_all <- read_csv('data/aportes.csv', col_types = cols(.default = "c"))
dic_candts <- read_csv('data/dic_candidatos.csv')

ui <- 
  fluidPage(
    suppressDependencies("bootstrap"),
    tags$head(
      tags$meta(name="viewport", content="width=device-width, initial-scale=1.0"),
      tags$link(rel="stylesheet", type="text/css", href="styles.css"),
      includeScript("js/iframeSizer.contentWindow.min.js")
    ),
    div(class = 'bg-blue seccion-descripcion',
        tags$img(class = 'line-decoration', src='divider_large.png'),
        div(class = 'content',
                div(class = 'texto-descripcion',
                    h1(class = 'title text-aqua', 'en esta sección'),
                    p(class = 'general-text text-white',
                      'Podrás conocer información agregada sobre los financiadores de campañas políticas que 
                      recibieron contratos estatales entre los años 2015 y 2019
'
                    )
                )
            )
        ),
    div(class = 'summary',
        div(class = 'content',
            div(class = 'results',
                div(class = 'filtros',
                    h4('filtros'),
                    div(class = 'panel',
     uiOutput('campana'),
     uiOutput('anio_secop'), 
     uiOutput('moneda_secop'),
     uiOutput('rango_dinero'),
     uiOutput('base'),
     uiOutput('variables_interes'), 
     uiOutput('legal_secop'),
     HTML("<div class = 'title-filter text-blue'>Tipo de visualización</div>"),
     uiOutput('vizOptions')
     )),
     div(class = 'viz-results',
         h4('visualización'),
         div(class = 'panel',
    highchartOutput('viz',  height = 550)
           )
         ),
    div(class = 'data-summary',
        h4('financiadores resultantes'),
        div(class = 'panel',
            h3('Da click en el gráfico para filtrar tabla'),
           # verbatimTextOutput('lista'),
            dataTableOutput('data_viz'),
            uiOutput('descarga_vista')))
    ))
    )
  )

server <-
  function(input, output, session) {

    output$campana <- renderUI({
      selectizeInput("id_campana", HTML("<div class = 'title-filter text-blue'> Campaña </div>"), c( "Congreso 2018", "Presidente 2018", "Regionales 2015"))
    })
    
    
    output$legal_secop <- renderUI({
       radioButtons(inputId = 'id_legal', HTML("<div class = 'title-filter text-blue'> Relación del financiador</div>"), c('Contratista' = 'contratista_id', 'Representante Legal' = 'rep_legal_id'), inline = T)
    })
    
    
    filter_contributor <- reactive({
      camp_sel <- input$id_campana
      if (is.null(camp_sel)) return()
      dt_candidatos <- info_all %>% filter(campaign %in% camp_sel)
      leg_elg <- input$id_legal
      if (is.null(leg_elg)) return()
      if (leg_elg == 'contratista_id') {
         dt_secop <- contratos %>% filter(contratista_id %in% unique(dt_candidatos$Identificación.Normalizada))
      } else {
         dt_secop <- contratos %>% filter(rep_legal_id %in% unique(dt_candidatos$Identificación.Normalizada))
      }
      list(aportantes = dt_candidatos, secop = dt_secop)
    })
    
    
   output$anio_secop <- renderUI({
     dt_filter <- filter_contributor()$secop
     if (is.null(dt_filter)) return()
     anios <- sort(unique(dt_filter$cont_firma_ano))
     selectizeInput('id_anio', HTML("<div class = 'title-filter text-blue'> Año de firma del contrato </div>"), anios, select = anios[1],multiple = TRUE, options = list(plugins= list('remove_button')))
   })
 
   
   filter_secop <- reactive({
     anio <- input$id_anio
     if (is.null(anio)) return()
     dt_secop <- filter_contributor()$secop
     dt_secop <- dt_secop %>% filter(cont_firma_ano %in% anio)
     dt_secop
   })
   
   

   output$moneda_secop <- renderUI({
     sc_filter <- filter_secop()
     if (is.null(sc_filter)) return()
     moneda <- unique(sc_filter$moneda)
     radioButtons('id_moneda', HTML("<div class = 'title-filter text-blue'>Moneda</div>"), moneda, inline = T)
   })
   

   
   output$rango_dinero <- renderUI({
      moneda_sel <- input$id_moneda
      if (is.null(moneda_sel)) return()
      dt <- filter_secop()
      if (is.null(dt)) return()
      dt <-  dt %>% 
               filter(moneda %in% moneda_sel)  
     min_val <- min(dt$cont_valor_tot)
     max_val <- max(dt$cont_valor_tot)
     sliderInput('id_rango', HTML("<div class = 'title-filter text-blue'>Cuantía del contrato</div>"), min = min_val, max = max_val, value = c(min_val, max_val))
   })
   
   
   
   filter_data <- reactive({
      moneda_sel <- input$id_moneda
      if (is.null(moneda_sel)) return()
      rango_sel <- input$id_rango
      if (sum(is.null(rango_sel)) > 0) return()
      dt_secop <- filter_secop()
      if (is.null(dt_secop)) return()
      dt_secop <- dt_secop %>%
                    filter(moneda %in% moneda_sel, cont_valor_tot >= rango_sel[1] & cont_valor_tot <= rango_sel[2])
      dt_aports <- filter_contributor()$aportantes
      if (is.null(dt_aports)) return()
      dt_aports <- dt_aports %>%
                     filter(Identificación.Normalizada %in% unique(dt_secop$contratista_id) | Identificación.Normalizada %in% unique(dt_secop$rep_legal_id))
      list(aportantes = dt_aports, secop = dt_secop)
   })
   
   
   output$variables_interes <- renderUI({
     var_secop <- dic_contratos %>% filter(!is.na(varInteres))
     var_secop$grupo <- 'SECOP'
     var_candt <- dic_candts %>% filter(!is.na(varInteres)) 
     var_candt$grupo <- 'CAMPAÑAS'
     data <- bind_rows(var_secop, var_candt)
     lista_dim <- purrr::map(1:nrow(data), function(i) setNames(data$id[[i]], data$label[[i]]))
     names(lista_dim) <- data$grupo
     
     selectizeInput('id_variable', HTML("<div class = 'title-filter text-blue'>Variable de interés</div>"), lista_dim)
   })
   
   

   
   
   data_viz <- reactive({
      dt_secop <- filter_data()$secop
      if (is.null(dt_secop)) return()
      
      var_int <- input$id_variable
      if (is.null(var_int)) return()
      leg_con <- input$id_legal
      if (is.null(leg_con)) return()
      dt_fincs <- filter_data()$aportantes
      dt_fincs_filt <- dt_fincs %>% select(APORTANTE.NORMALIZADO, Identificación.Normalizada) %>% distinct(.keep_all = T)
      if (sum(var_int %in% dic_candts$id) == 1) {
         dt_secop <- dt_secop %>% group_by_('cont_firma_ano',leg_con, 'secop') %>% summarize(total = n(), valor = sum(cont_valor_tot))
         dt_fincs_filt <-  dt_fincs %>% select_('APORTANTE.NORMALIZADO', 'Identificación.Normalizada', var_int) %>% distinct(.keep_all = T)
         final <- dt_fincs_filt  %>% 
            inner_join(dt_secop, by = c('Identificación.Normalizada' = leg_con))
      } else {
      dt_secop <- dt_secop %>% group_by_('cont_firma_ano',leg_con, var_int, 'secop') %>% summarize(total = n(), valor = sum(cont_valor_tot))
      final <- dt_fincs_filt  %>%
                 inner_join(dt_secop, by = c('Identificación.Normalizada' = leg_con))
      }
      
      viz_dt <- final %>% group_by_('cont_firma_ano', var_int) %>% summarise(num = n())
      dic_all <- bind_rows(dic_candts, dic_contratos)

      var_el <- list(prefix = dic_all$label[dic_all$id == var_int][1],
                     suffix = ifelse(leg_con == 'rep_legal_id', 'representantes', 'contratistas'))
  
      dic_viz <- dic_all %>% distinct(id, .keep_all = T)
      dic_viz <- inner_join(data.frame(id = names(viz_dt)), dic_viz)
      names(viz_dt) <- dic_viz$label
      
      dic_final <- dic_all %>% distinct(id, .keep_all = T)
      dic_final <- inner_join(data.frame(id = names(final)), dic_final)
      names(final) <- dic_final$label
      
      
      # dt_names <- dt_fincs %>% select(APORTANTE.NORMALIZADO, id = Identificación.Normalizada) %>% distinct(.keep_all = T)
      # names(dt_names) <- c('Nombre', leg_con)
      # dt_secop <- dt_secop %>% inner_join(dt_names)
      
      # if (length(unique(dt_secop$secop)) == 1) {
      #     dic_all <- dic_all %>% filter(secop == tolower(unique(dt_secop$secop)))
      #     dt_secop <- dt_secop[,c(1,2)]
      #     dt_secop <- contratos %>% left_join(dt_secop)
      #     dic_secp <- inner_join(data.frame(id=names(dt_secop)), dic_all)
      #     names(dt_secop) <- dic_secp$label
      #  }  else {
      #  secop1_data <- dt_secop %>% filter(secop == 'Uno') %>% select(-secop)
      #  dic_sec1 <- dic_all %>% filter(secop == 'uno')
      #  secop1_data <- secop1_data %>% select(-secop)
      #  dic_sec1 <- inner_join(data.frame(id=names(secop1_data)), dic_sec1)
      #  names(secop1_data) <- dic_sec1$label
      #  secop2_data <- dt_secop %>% filter(secop == 'Dos') %>% select(-secop)
      #  dic_sec2 <- dic_all %>% filter(secop == 'dos')
      #  secop2_data <- secop2_data %>% select(-secop)
      #  dic_sec2 <- inner_join(data.frame(id=names(secop2_data)), dic_sec2)
      #  names(secop2_data) <- dic_sec2$label
      #  dt_secop <- list(secop1 = secop1_data, secop2 = secop2_data)
      #  }
      # selec = var_el
      # secop = dt_secop,dt_fincs_filt, fianciadores = dt_fincs,
      list( join = final, viz = viz_dt, selec = var_el)
   })
   
   output$vizOptions <- renderUI({
      charts <- c("bar", "line")
      shinyinvoer::buttonImageInput(inputId = "last_chart", label = " ", 
                                    images = charts,
                                    path = "icons/")
   })

   titulo <- reactive({
      var_int <- data_viz()$selec$prefix
      if (is.null(var_int)) return()
      leg_con <-  data_viz()$selec$suffix
      if (is.null(leg_con)) return()

      if (sum(var_int %in% c('Nivel Entidad', 'Modalidad de contrato', 'Estado del Proceso', 'Departamento Ejecución', 'Grupo')) == 1) {
         tx <- paste0('Número de financiadores que ejecutan contratos con el estado como ', leg_con, ' por ', var_int)   
      } else if (sum(var_int %in% c('Genero')) == 1) {
         tx <- paste0('Candidatos por género cuyos financiadores ejecutan contratos con el estado como ', leg_con)
      } else if (sum(var_int %in% c('Elegido')) == 1) {
        tx <- paste0('Candidatos elegidos cuyos financiadores ejecutan contratos con el estado como ', leg_con)
      } else {
         tx <- paste0(var_int, ' de los financiadores que ejecutan contratos con el estado como ', leg_con)
      }
      
      tx
   })
   
   output$viz <- renderHighchart({
      
      chart <- input$last_chart
      if (is.null(chart)) return()
      
      dt_viz <- data_viz()$viz
      if (is.null(dt_viz)) return()
      
      anios <- input$id_anio
      if (is.null(anios)) return()
      
      colores <- c("#fdb731","#0a446b", "#137fc0", "#c250c2", "#fa8223", "#64c6f2", "#f49bf9", "#fc7e5b", "#ffe566", "#64f4c8", "#137fc0", "#c250c2", "#f03a47", "#fdb731", "#36c16f", "#022f40", "#691f6b", "#931c4d", "#fa8223", "#2b6d46")
      ort <- 'hor'
      
      myFunc <- JS("function(event) {Shiny.onInputChange('hcClicked',  {id:event.point.category.name, cat:this.name, timestamp: new Date().getTime()});}")
      
      if (length(anios) == 1) {
         colores <- "#fdb731"
         myFunc <- JS("function(event) {Shiny.onInputChange('hcClicked',  {id:event.point.name, timestamp: new Date().getTime()});}")
      } 
      
      if (chart == 'line' & length(anios) == 1) myFunc <- JS("function(event) {Shiny.onInputChange('hcClicked',  {id:event.point.name, timestamp: new Date().getTime()});}")
      if (chart == 'line' & length(anios) > 1)  myFunc <- JS("function(event) {Shiny.onInputChange('hcClicked',  {cat:event.point.category.name, id:this.name, timestamp: new Date().getTime()});}")
      

            
      if (chart == 'line') ort <- 'ver'

      opts_viz <- list(title = titulo(),
                       caption = '<b>Fuente:</b> SECOP y cuentas claras',
                       orientation = ort,
                       allow_point = TRUE,
                       cursor =  'pointer',
                       color_hover = "#fa8223",
                       color_click  = "#fa8223",
                       labelWrap = 100,
                       labelWrapV = c(100, 100),
                       clickFunction = myFunc,
                       startAtZero = TRUE,
                       spline = FALSE,
                       fill_opacity = 0.9,
                       agg_text = " ",
                       export =  TRUE,
                       border_color = '#000000',
                       theme =  list(stylesX_lineWidth = 0, 
                                                 #height = 570,
                                                 colors = colores,
                                                 font_family = "Raleway",
                                                 font_size = '11px',
                                                 font_color = '#000000',
                                                 stylesTitleY_fontWeight = 'bold',
                                                 stylesTitleX_fontWeight = 'bold'))
      
      if (nrow(dt_viz) == 0) return('No hay aportantes con las caracteristicas elegidas')
      if (length(anios) == 1) {
         dt_viz <- dt_viz[,-1]
         viz <- paste0('hgch_', chart, '_CatNum')
         if (chart == 'line') viz <- paste0('hgch_', chart, '_YeaNum')
         v <-  do.call(viz, c(list(data = dt_viz, opts = opts_viz)))
      } else {
         viz <- paste0('hgch_', chart, '_CatCatNum')
         if (chart == 'line') {
            viz <- paste0('hgch_', chart, '_CatYeaNum')
            dt_viz <- dt_viz[,c(2,1,3)]
         }
         v <-  do.call(viz, c(list(data = dt_viz, opts = opts_viz)))
      }
      v
   })
   
   
   # output$lista <- renderPrint({
   #    var_sel <- input$hcClicked$id
   #    var_sel
   # })
   
   data_filter <- reactive({
      var_int <- data_viz()$selec$prefix
      if (is.null(var_int)) return()
      var_sel <- input$hcClicked$id
      anio_sel <- input$hcClicked$cat
      dt <- data_viz()$join
      if (is.null(dt)) return()
      anios <- input$id_anio
      if (is.null(anios)) return()

      if (!is.null(anio_sel)) dt <- dt %>%  filter(`Año Firma del Contrato` %in% anio_sel)


      if (is.null(var_sel)) {
         dt <- dt
      } else if (is.na(var_sel)){
         dt <- dt[is.na(dt[var_int]),] 
      } else {
         if (sum(dt[var_int] == var_sel) == 0) {
            dt <- dt
         } else  {
           dt <- dt[dt[var_int] == var_sel,]  
         }
      }

      dt
     
   })
   
   
   output$data_viz <- renderDataTable({
      dt <-  data_filter()
      if (is.null(dt)) return()
      pg <- nrow(dt)
      if (nrow(dt) > 10) pg <- 11
      options(scipen = 9999)
      dt$`Total valor del contrato` <- format(dt$`Total valor del contrato`,big.mark = ',', small.mark = '.')
      datatable(dt,
                options = list(
                   pageLength = pg, 
                   language = list(url = '//cdn.datatables.net/plug-ins/1.10.11/i18n/Spanish.json'),
                   lengthChange = F,
                   rownames = F,
                   initComplete = JS(
                      "function(settings, json) {",
                      "$(this.api().table().header()).css({'background-color': '#0A446B', 'color': '#fff'});",
                      "}"),
                   searching = FALSE
                )) %>% 
         formatStyle( 0 , target= 'row',color = '#0A446B', fontSize ='13px', lineHeight='15px')   %>% 
         formatStyle(c(1:dim(dt)[2]),  textAlign = 'right')
      
   })
   
   
   output$descarga_vista <- renderUI({
      downloadButton('descarga_summary', 'Descarga vista')
   })
   
   output$descarga_summary <- downloadHandler(
      filename = function() {
         "data-filtros.csv"
      },
      content = function(file) {
         data <- data_filter()
         write_csv(data, file, na = '')
      }
   )
   
  }

shinyApp(ui, server)