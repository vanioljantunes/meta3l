#' Read all sheets from an Excel file
#'
#' Reads every sheet from an Excel workbook and returns a named list of
#' data frames. If both \code{author} and \code{year} columns are present in
#' a sheet, a \code{studlab} column is automatically constructed as
#' \code{paste0(author, ", ", year)}.
#'
#' @param path Character string giving the path to the Excel file
#'   (\code{.xlsx} or \code{.xls}), OR a URL to a public Google Sheets
#'   document. If a Google Sheets URL is provided, the sheet is exported as
#'   \code{data_outcome.xlsx} into the folder containing the active script
#'   (overwriting any existing file); if the script is unsaved, an interactive
#'   directory-chooser is opened. If \code{NULL} and the session is running
#'   inside RStudio, an interactive file-chooser dialog is opened. If
#'   \code{NULL} and RStudio is not available, an error is raised.
#'
#' @return A named list of \code{data.frame} objects, one per non-empty sheet.
#'   The list names correspond to the sheet names in the workbook. Empty sheets
#'   are skipped with a warning.
#'
#' @details Sets the global option \code{meta3l.mwd} to the directory
#'   containing the Excel file. This directory is used as the default output
#'   location by \code{forest.meta3L()}.
#'
#' @examples
#' \dontrun{
#' # Provide path explicitly
#' sheets <- read_multisheet_excel("path/to/data.xlsx")
#'
#' # Interactive selection in RStudio
#' sheets <- read_multisheet_excel()
#'
#' # Download from a public Google Sheets URL
#' sheets <- read_multisheet_excel(
#'   "https://docs.google.com/spreadsheets/d/ABC123/edit#gid=0"
#' )
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

  if (is.character(path) && length(path) == 1L &&
      grepl("^https?://", path)) {
    if (!grepl("docs\\.google\\.com/spreadsheets", path)) {
      stop(
        "Only Google Sheets URLs are supported for remote download.",
        call. = FALSE
      )
    }

    sheet_id <- sub(
      ".*/spreadsheets/d/([a-zA-Z0-9_-]+).*", "\\1", path
    )
    if (!nzchar(sheet_id) || sheet_id == path) {
      stop(
        "Could not extract Google Sheets ID from URL.",
        call. = FALSE
      )
    }
    export_url <- paste0(
      "https://docs.google.com/spreadsheets/d/",
      sheet_id, "/export?format=xlsx"
    )

    save_dir <- NULL
    if (rstudioapi::isAvailable()) {
      src_path <- tryCatch(
        rstudioapi::getSourceEditorContext()$path,
        error = function(e) ""
      )
      if (is.character(src_path) && nzchar(src_path)) {
        save_dir <- dirname(src_path)
      }
    }
    if (is.null(save_dir)) {
      if (!rstudioapi::isAvailable()) {
        stop(
          "Script is unsaved and RStudio is not available; ",
          "cannot determine a folder to save data_outcome.xlsx.",
          call. = FALSE
        )
      }
      save_dir <- rstudioapi::selectDirectory(
        caption = "Choose folder to save data_outcome.xlsx"
      )
      if (is.null(save_dir) || !nzchar(save_dir)) {
        stop(
          "No directory selected; cannot save downloaded file.",
          call. = FALSE
        )
      }
    }

    destfile <- file.path(save_dir, "data_outcome.xlsx")
    dl <- tryCatch(
      utils::download.file(
        export_url, destfile, mode = "wb", quiet = TRUE
      ),
      error = function(e) e,
      warning = function(w) w
    )
    if (inherits(dl, "condition") ||
        !file.exists(destfile) ||
        file.size(destfile) == 0L) {
      stop(
        "Could not download sheet. Verify the Google Sheet is publicly ",
        "shared (Anyone with the link \u2014 Viewer).",
        call. = FALSE
      )
    }

    path <- destfile
  }

  sheet_names <- readxl::excel_sheets(path)
  options(meta3l.mwd = dirname(normalizePath(path, mustWork = TRUE)))

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
