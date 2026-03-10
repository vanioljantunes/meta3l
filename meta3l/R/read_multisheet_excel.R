#' Read all sheets from an Excel file
#'
#' Reads every sheet from an Excel workbook and returns a named list of
#' data frames. If both \code{author} and \code{year} columns are present in
#' a sheet, a \code{studlab} column is automatically constructed as
#' \code{paste0(author, ", ", year)}.
#'
#' @param path Character string giving the path to the Excel file
#'   (\code{.xlsx} or \code{.xls}). If \code{NULL} and the session is running
#'   inside RStudio, an interactive file-chooser dialog is opened. If
#'   \code{NULL} and RStudio is not available, an error is raised.
#'
#' @return A named list of \code{data.frame} objects, one per non-empty sheet.
#'   The list names correspond to the sheet names in the workbook. Empty sheets
#'   are skipped with a warning.
#'
#' @examples
#' \dontrun{
#' # Provide path explicitly
#' sheets <- read_multisheet_excel("path/to/data.xlsx")
#'
#' # Interactive selection in RStudio
#' sheets <- read_multisheet_excel()
#' }
#'
#' @export
read_multisheet_excel <- function(path = NULL) {
  if (is.null(path)) {
    if (rstudioapi::isAvailable()) {
      path <- rstudioapi::selectFile(
        caption = "Choose Excel file",
        filter  = "Excel files (*.xlsx, *.xls)"
      )
    } else {
      stop(
        "path argument is required in non-RStudio environments.",
        call. = FALSE
      )
    }
  }

  sheet_names <- readxl::excel_sheets(path)

  result <- lapply(sheet_names, function(s) {
    df <- as.data.frame(readxl::read_excel(path, sheet = s))

    if (nrow(df) == 0L) {
      warning(
        "Sheet '", s, "' is empty and will be skipped.",
        call. = FALSE
      )
      return(NULL)
    }

    if ("author" %in% names(df) && "year" %in% names(df)) {
      df$studlab <- paste0(df$author, ", ", df$year)
    }

    df
  })

  names(result) <- sheet_names
  result[!vapply(result, is.null, logical(1L))]
}
