#####################################################################################################################
# communityusage_metrics.R - Community Usage Metrics Source file for Server Module.  
# Author: K Aravind Reddy
# Date: July 13th, 2020
# License: MIT License
#####################################################################################################################


# Start of the observe's'

# 1. Observe to load the columns from DB into reactive values.
observe({
  req(input$select_pack)
  if (input$tabs == "cum_tab_value") {
    if (input$select_pack != "Select") {
    
      # Load the columns into values$riskmetrics.
      pkgs_in_db <- db_fun(paste0("SELECT cum_id FROM CommunityUsageMetrics"))
      
      if (input$select_pack %in% pkgs_in_db$cum_id &&
          !identical(pkgs_in_db$cum_id, character(0))) {
        values$riskmetrics_cum <-
          db_fun(
            paste0(
              "SELECT * FROM CommunityUsageMetrics WHERE cum_id ='",
              input$select_pack,
              "'"
            )
          )
      } else{
        if (input$select_pack != "Select") {
          metric_cum_Info_upload_to_DB(input$select_pack)
          values$riskmetrics_cum <-
            db_fun(
              paste0(
                "SELECT * FROM CommunityUsageMetrics WHERE cum_id ='",
                input$select_pack,
                "'"
              )
            )
        }
      }
      
      # Load the data table column into reactive variable for time since first release.
      values$time_since_first_release_info <-
        values$riskmetrics_cum$time_since_first_release[1]
      
      # Load the data table column into reactive variable for time since version release.
      values$time_since_version_release_info <-
        values$riskmetrics_cum$time_since_version_release[1]
      
      # Load the data table column into reactive variable for num dwnlds in year
      values$no_of_downloads_last_year_info <-
        values$riskmetrics_cum$no_of_downloads_last_year[1]
      
      runjs( "setTimeout(function(){ capturingSizeOfInfoBoxes(); }, 100);" )
      
      if (!is.null(input$cum_comment)) {
        if(values$time_since_version_release_info == "NA"){ runjs( "setTimeout(function(){ updateInfoBoxesColorWhenNA('time_since_version_release');}, 500);" ) }
        if(values$time_since_first_release_info == "NA"){ runjs( "setTimeout(function(){ updateInfoBoxesColorWhenNA('time_since_first_release');}, 500);" ) }
        if (values$riskmetrics_cum$no_of_downloads_last_year[1] == 0) { runjs("setTimeout(function(){ updateText('no_of_downloads');}, 500);") }
        req(values$selected_pkg$decision)
        if (values$selected_pkg$decision != "") {
          runjs("setTimeout(function(){ var ele = document.getElementById('cum_comment'); ele.disabled = true; }, 500);" )
          runjs("setTimeout(function(){ var ele = document.getElementById('submit_cum_comment'); ele.disabled = true; }, 500);")
        }
      }
    }
  }
})  # End of the observe.

# End of the observe's'

# Start of the render Output's'

# 1. Render Output info box to show the content for time since first release.

output$time_since_first_release <- renderInfoBox({
  req(values$time_since_first_release_info)
  infoBox(
    title = "Package Maturity",
    values$time_since_first_release_info,
    subtitle = ifelse(values$time_since_first_release_info != "NA",
                      "Months since first release.",
                      "Metric is not applicable for this source of package."),
    icon = shiny::icon("calendar"),
    width = 3,
    fill = TRUE
  )
})  # End of the time since first release render Output.

# 2. Render Output info box to show the content for time since version release.

output$time_since_version_release <- renderInfoBox({
  req(values$time_since_version_release_info)
  infoBox(
    title = "Version Maturity",
    values$time_since_version_release_info,
    subtitle = ifelse(values$time_since_version_release_info != "NA", 
                      "Months since version release.",
                      "Metric is not applicable for this source of package."),
    icon = shiny::icon("calendar"),
    width = 3,
    fill = TRUE
  )
  
})  # End of the time since version release render Output.



# 2.5 Render Output info box to show the number of downloads last year

output$dwnlds_last_yr <- renderInfoBox({
  req(values$no_of_downloads_last_year_info)
  infoBox(
    title = "Download Count",
    formatC(values$no_of_downloads_last_year_info, format="f", big.mark=",", digits=0),
    subtitle = ifelse(values$no_of_downloads_last_year_info != "NA",
                      "Downloads in Last Year",
                      "Metric is not applicable for this source of package."),
    icon = shiny::icon("signal"),
    width = 3,
    fill = TRUE
  )

})  # End 


# 3. Render Output to show the plot for number of downloads on the application.
output$no_of_downloads <- 
  plotly::renderPlotly({
    num_dwnlds_plot(data = values$riskmetrics_cum,
                    input_select_pack = input$select_pack)
})



# 4. Render output to show the comments.

output$cum_commented <- renderText({
  if (values$cum_comment_submitted == "yes" ||
      values$cum_comment_submitted == "no") {
    values$comment_cum2 <- select_comments(input$select_pack, "cum")
    req(values$comment_cum2$comment)
    values$cum_comment_submitted <- "no"
    display_comments(values$comment_cum2)
  }
})  # End of the render output for comments.

# End of the Render Output's'.

values$cum_comment_submitted <- "no"

# Start of the Observe Events.

# Observe event for cum comment submit button. 

observeEvent(input$submit_cum_comment, {
  if (trimws(input$cum_comment) != "") {
    # insert into comments table
    insert_comment(input$select_pack, input$select_ver, values$name, values$role, input$cum_comment, cm_type = "cum")
    values$cum_comment_submitted <- "yes"
    updateTextAreaInput(session, "cum_comment", value = "")
    # After comment added to Comments table, update db dash
    values$db_pkg_overview <- update_db_dash()
  }
})  # End of the submit button observe event.


# End of the Community Usage Metrics server source file.
