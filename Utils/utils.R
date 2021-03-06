#####################################################################################################################
# utils.R - UI and Server utility functions for the application.
# Author: K Aravind Reddy
# Date: July 13th, 2020
# License: MIT License
#####################################################################################################################

# Stores the database name.
db_name <- "database.sqlite"

# Create a local database.
create_db <- function(){
  
  # Create an empty database.
  con <- dbConnect(RSQLite::SQLite(), db_name)
  
  # Set the path to the queries.
  path <- file.path("Utils", "sql_queries")
  
  # Queries needed to run the first time the db is created.
  queries <- c(
    "create_Packageinfo_table.sql",
    "create_MaintenanceMetrics_table.sql",
    "create_CommunityUsageMetrics_table.sql",
    "create_TestMetrics_table.sql",
    "create_Comments_table.sql"
  )
  
  # Append path to the queries.
  queries <- file.path(path, queries)
  
  # Apply each query.
  sapply(queries, function(x){
    res <- dbSendStatement(
      con,
      paste(scan(x, sep = "\n", what = "character"), collapse = ""))
    
    dbClearResult(res)
  })
  
  dbDisconnect(con)
}

db_fun <- function(query){
  con <- dbConnect(RSQLite::SQLite(), db_name)
  dat <- dbGetQuery(con,query)  # this does SendQuery, Fetch and ClearResult all in one
  dbDisconnect(con)
  return(dat)
}

# You need to use dbExecute() to perform delete, update or insert queries.
db_ins <- function(query){
  # con <- dbConnect(RSQLite::SQLite(), "./risk_assessment_app.db")
  con <- dbConnect(RSQLite::SQLite(), db_name)
  dbExecute(con, query)
  dbDisconnect(con)
}

TimeStamp <- function(){
  return(lubridate::with_tz(Sys.time(), "UTC"))
}

GetUserName <- function() {
  # Returns user name of computer with twist for Unix
  # Args
  #   none
  # Returns
  #  string of user login name
  
  x <- Sys.info()[["user"]]
  
  # if blank try other methods
  if (is.null(x) | x == "") {
    # On windows machines
    Sys.getenv("USERNAME")  
  } else {
    # from helpfiles for Unix
    Sys.getenv("LOGNAME")  
  }
  
  # Could get something but it is unknown error
  if (identical(x, "unknown")) {
    warning("unknown returned")
  }
  
  return(x)
}

# function to re-run everytime a package is uploaded to db, or
# when a comment is submitted
update_db_dash <- function(){
  db_fun(
    "SELECT 
       pi.package
      , pi.version
      , pi.score
      , pi.decision
      , c.last_comment
      FROM Packageinfo as pi
      LEFT JOIN (
        SELECT comm_id
             , max(added_on) as last_comment
        FROM Comments
        GROUP BY comm_id
      ) as c
      on c.comm_id = pi.package
      ORDER BY 1 DESC
    "
  )
}

insert_comment <- function(package, versn, name, role, comment, cm_type) {
  db_ins(
    paste0(
      "INSERT INTO Comments values('",
      package,            "',",
      "'",  versn,        "',",
      "'",  name,         "',",
      "'",  role,         "',",
      "'",  gsub("'","''",comment),      "',",
      "'",  cm_type,      "',",
      "'",  TimeStamp(),  "'" ,
      ")"
    )
  )
}

select_comments <- function(package_name, cm_type) {
  comment_one <-
    db_fun(
      paste0(
        "SELECT user_name, user_role, comment, added_on FROM Comments WHERE comm_id = '",
        package_name,
        "' AND comment_type = '", cm_type, "'" 
      )
    )
  data.frame(comment_one %>% map(rev))
}

display_comments <- function(cmt_tbl) {
  return(
    paste(
      "<div class='col-sm-12 comment-border-bottom'><i class='fa fa-user-tie fa-4x'></i><h3 class='ml-3'><b class='user-name-color'>",
      cmt_tbl$user_name,
      "(",
      cmt_tbl$user_role,
      ")",
      "</b><sub>",
      cmt_tbl$added_on,
      "</sub></h3><h4 class='ml-3 lh-4'>",
      cmt_tbl$comment,
      "</h4></div>"
    )
  )
}
