project_root <- function() {
  test_dir <- getwd()
  root <- test_dir
  while (root != dirname(root)) {
    if (file.exists(file.path(root, "dashboard"))) return(root)
    root <- dirname(root)
  }
  test_dir
}
