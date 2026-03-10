#' @keywords internal
#' @aliases meta3l-package
#' @importFrom metafor escalc vcalc rma.mv robust transf.ilogit transf.iarcsin
#' @importFrom readxl excel_sheets read_excel
#' @importFrom stats as.formula model.matrix
"_PACKAGE"

utils::globalVariables(c("yi", "vi", "TE_id"))
