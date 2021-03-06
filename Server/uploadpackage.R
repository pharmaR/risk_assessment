#####################################################################################################################
# uploadpackage.R - upload pacakge Source file for server Module.
# Author: K Aravind Reddy
# Date: July 13th, 2020
# License: MIT License
#####################################################################################################################


# Reactive variable to load the sample csv file into data().

data <- reactive({
  data1<-read_csv("./Data/upload_format.csv")
  data1<-data.table(data1)
  data1
})  # End of the reactive.

# Start of the observe's'

# 1. Observe to load the columns from DB into below reactive values.

observeEvent(list(input$total_new_undis_dup,input$uploaded_file), {
  req(values$upload_complete == "upload_complete")
  
  # After upload complete, update db dash screen with new package(s)
  values$db_pkg_overview <- update_db_dash()
  
  if (input$total_new_undis_dup == "All") {
    values$Total_New_Undis_Dup <- values$Total
  } else if (input$total_new_undis_dup == "New") {
    values$Total_New_Undis_Dup <- values$New
  } else if (input$total_new_undis_dup == "Undiscovered") {
    values$Total_New_Undis_Dup <- values$Undis
  } else if (input$total_new_undis_dup == "Duplicates") {
    values$Total_New_Undis_Dup <- values$Dup
  } 
}, ignoreInit = TRUE)  # End of the observe.

# 2. Observe to disable the input widgets while the packages uploading into DB.

observeEvent(input$uploaded_file, {
  # req(input$uploaded_file)
  values$uploaded_file_status <- file_upload_error_handling(input$uploaded_file)
  if (values$uploaded_file_status != "no_error") {
    shinyjs::hide("upload_summary_text")
    shinyjs::hide("upload_summary_select")
    shinyjs::hide("total_new_undis_dup_table")
    shinyjs::hide("dwnld_all_reports_btn")
    shinyjs::hide("all_reports_format")
    reset("uploaded_file") 
    return()
  } else{
    shinyjs::show("upload_summary_text")
    shinyjs::show("upload_summary_select")
    shinyjs::show("total_new_undis_dup_table")
  }
  file_to_read <- input$uploaded_file
  pkgs_file <-
    read.csv(file_to_read$datapath,
             sep = ",",
             stringsAsFactors = FALSE)
  names(pkgs_file) <- tolower(names(pkgs_file))
  pkgs_file$package <- trimws(pkgs_file$package)
  pkgs_file$version <- trimws(pkgs_file$version)
  values$Total <- pkgs_file
  pkgs_db1 <- db_fun("SELECT package FROM Packageinfo")
  values$Dup <- filter(values$Total, values$Total$package %in% pkgs_db1$package)
  values$New <- filter(values$Total, !(values$Total$package %in% pkgs_db1$package))
  withProgress(message = "Uploading Packages to DB:", value = 0, {
    if (nrow(values$New) != 0) {
      for (i in 1:nrow(values$New)) {
        incProgress(1 / (nrow(values$New) + 1), detail = values$New[i, 1])
        new_package<-values$New$package[i]
        get_packages_info_from_web(new_package)
        metric_mm_tm_Info_upload_to_DB(new_package)
        metric_cum_Info_upload_to_DB(new_package)
      }
    }
  })
  
  pkgs_db2 <- db_fun("SELECT package FROM Packageinfo")
  values$Undis <-
    filter(values$New,!(values$New$package %in% pkgs_db2$package))
  values$packsDB <- db_fun("SELECT package FROM Packageinfo")
  updateSelectizeInput(
    session,
    "select_pack",
    choices = c("Select", values$packsDB$package),
    selected = "Select"
  )
  
  showNotification(id = "show_notification_id", "Upload completed", type = "message")
  values$upload_complete <- "upload_complete"
  
  # Show the download reports buttons after all the packages have been loaded
  # and the information extracted.
  shinyjs::show("dwnld_all_reports_btn")
  shinyjs::show("all_reports_format")
  loggit("INFO", paste("Summary of the uploaded file:",input$uploaded_file$name, 
                       "Total Packages:", nrow(values$Total),
                       "New Packages:", nrow(values$New),
                       "Undiscovered Packages:", nrow(values$Undis),
                       "Duplicate Packages:", nrow(values$Dup)), echo = FALSE)
}, ignoreInit = TRUE)  # End of the Observe.

# End of the observe's'.

# Start of the render Output's'.

# 1. Render Output to download the sample format dataset.

output$upload_format_download <- downloadHandler(
  filename = function() {
    paste("Upload_file_structure", ".csv", sep = "")
  },
  content = function(file) {
    write.csv(read_csv(file.path("Data", "upload_format.csv")), file, row.names = F)
  }
)  # End of the render Output.

# 2. Render Output to show the summary of the uploaded csv into application.

output$upload_summary_text <- renderText({
  if (values$upload_complete == "upload_complete") {
    paste(
      "<br><br><hr>",
      "<h3><b>Summary of uploaded package(s) </b></h3>",
      "<h4>Total Packages: ", nrow(values$Total), "</h4>",
      "<h4>New Packages:",  nrow(values$New), "</h4>",
      "<h4>Undiscovered Packages:", nrow(values$Undis), "</h4>",
      "<h4>Duplicate Packages:", nrow(values$Dup), "</h4>",
      "<h4><b>Note: The information extracted of the package will be always from latest version irrespective of uploaded version."
    )
  }
})  # End of the render Output.

# 3. Render Output to show the select input to select the choices to display the table.

output$upload_summary_select <- renderUI({
  if (values$upload_complete == "upload_complete") {
    removeUI(selector = "#Upload")
    selectInput(
      "total_new_undis_dup",
      "",
      choices = c("All", "New", "Undiscovered", "Duplicates")
    )
  } 
})  # End of the render Output.

# 4. Render Output to show the data table of uploaded csv.

output$total_new_undis_dup_table <- DT::renderDataTable({
  if (values$upload_complete == "upload_complete") {
    datatable(
      values$Total_New_Undis_Dup,
      escape = FALSE,
      class = "cell-border",
      selection = 'none',
      extensions = 'Buttons',
      options = list(
        searching = FALSE,
        sScrollX = "100%",
        lengthChange = FALSE,
        aLengthMenu = list(c(5, 10, 20, 100,-1), list('5', '10', '20', '100', 'All')),
        iDisplayLength = 5
      )
    )
  }
}) # End of the render Output 
# End of the Render Output's'.


# 5. Render Output for download handler to export the report for each .
# Data displayed: values$Total_New_Undis_Dup
# file name uplaoded: input$uploaded_file$name
# selected type: input$upload_summary_select
values$cwd<-getwd()
output$dwnld_all_reports_btn <- downloadHandler(
  filename = function() {
    # name will include the type of packages selected to display in DT
    paste0(input$total_new_undis_dup, "_",
           stringr::str_remove(input$uploaded_file$name, ".csv"),
           ".zip")
  },
  content = function(file) {
    n_pkgs <- nrow(values$Total_New_Undis_Dup)
    req(n_pkgs > 0)
    shiny::withProgress(
      message = paste0("Downloading ",n_pkgs," Report",ifelse(n_pkgs > 1,"s","")),
      value = 0,
      max = n_pkgs + 2, # tell the progress bar the total number of events
      {
        shiny::incProgress(1)
        
        my_dir <- tempdir()
        if (input$all_reports_format == "html") {
          Report <- file.path(my_dir, "Report_html.Rmd")
          file.copy("Reports/Report_html.Rmd", Report, overwrite = TRUE)
        } else {
          Report <- file.path(my_dir, "Report_doc.Rmd")
          file.copy("Reports/Report_doc.Rmd", Report, overwrite = TRUE)
        }
        fs <- c()
        for (i in 1:n_pkgs) {
          # grab package name and version, then create filename and path
          this_pkg <- values$Total_New_Undis_Dup$package[i]
          this_ver <- values$Total_New_Undis_Dup$version[i]
          file_named <- paste0(this_pkg,"_",this_ver,"_Risk_Assessment.",input$all_reports_format)
          path <- file.path(my_dir, file_named)
          # render the report, passing parameters to the rmd file
          rmarkdown::render(
            input = Report,
            output_file = path,
            params = list(package = this_pkg,
                          version = this_ver,
                          cwd = values$cwd)
          )
          fs <- c(fs, path)  # save all the 
          shiny::incProgress(1) # increment progress bar
        }
        # zip all the files up, -j retains just the files in zip file
        zip(zipfile = file, files = fs ,extras = "-j")
        shiny::incProgress(1) # increment progress bar
      })
  },
  contentType = "application/zip"
)  # End of the render Output for download report.



# Observe Event for view sample dataset button.

observeEvent(input$upload_format, {
  dataTableOutput("sampletable")
  showModal(modalDialog(
    output$sampletable <- DT::renderDataTable(
      datatable(
        data(),
        escape = FALSE,
        class = "cell-border",
        editable = FALSE,
        filter = "none",
        selection = 'none',
        extensions = 'Buttons',
        options = list(
          sScrollX = "100%",
          aLengthMenu = list(c(5, 10, 20, 100, -1), list('5', '10', '20', '100', 'All')),
          iDisplayLength = 5,
          dom = 't'
        )
      )
    ),
    downloadButton("upload_format_download", "Download", class = "btn-secondary")
  ))
})  # End of the observe event for sample button.

# End of the upload package Source file for server Module.
