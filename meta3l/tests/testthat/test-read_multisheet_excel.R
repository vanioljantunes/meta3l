test_that("read_multisheet_excel reads temp Excel and returns named list of data.frames", {
  skip_if_not_installed("writexl")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  df1 <- data.frame(author = c("Smith", "Jones"), year = c(2020, 2021),
                    value = c(10, 20))
  df2 <- data.frame(x = 1:3, y = 4:6)

  writexl::write_xlsx(list(sheet1 = df1, sheet2 = df2), path = tmp)

  result <- read_multisheet_excel(tmp)

  expect_type(result, "list")
  expect_length(result, 2L)
  expect_named(result, c("sheet1", "sheet2"))
  expect_s3_class(result$sheet1, "data.frame")
  expect_s3_class(result$sheet2, "data.frame")
})

test_that("read_multisheet_excel auto-constructs studlab from author + year", {
  skip_if_not_installed("writexl")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  df <- data.frame(author = c("Smith", "Jones", "Lee"),
                   year   = c(2020, 2021, 2022),
                   value  = c(10, 20, 30))
  writexl::write_xlsx(list(data = df), path = tmp)

  result <- read_multisheet_excel(tmp)

  expect_true("studlab" %in% names(result$data))
  expect_equal(result$data$studlab, c("Smith, 2020", "Jones, 2021", "Lee, 2022"))
})

test_that("read_multisheet_excel does not add studlab when author/year absent", {
  skip_if_not_installed("writexl")
  tmp <- tempfile(fileext = ".xlsx")
  on.exit(unlink(tmp))

  df <- data.frame(x = 1:3, y = 4:6)
  writexl::write_xlsx(list(data = df), path = tmp)

  result <- read_multisheet_excel(tmp)

  expect_false("studlab" %in% names(result$data))
})

test_that("read_multisheet_excel errors when path is NULL and not in RStudio", {
  # Mock rstudioapi::isAvailable to return FALSE
  mockery_available <- requireNamespace("mockery", quietly = TRUE)
  skip_if(mockery_available, "mockery available: use proper mocking instead")

  # Without mockery, we test by direct call where isAvailable returns FALSE
  # We can test this logic by checking that path = NULL in non-interactive env errors
  # Since tests run outside RStudio, isAvailable() should be FALSE
  if (!rstudioapi::isAvailable()) {
    expect_error(
      read_multisheet_excel(path = NULL),
      "path argument is required"
    )
  } else {
    skip("Running inside RStudio; cannot test non-interactive path error")
  }
})
