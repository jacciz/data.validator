#' Create a UI segment element.
#' @description Create a UI segment element.
#' @param title Title of the segment.
#' @param ... Additional arguments inside segment.
#' @return Segment.
#' @keywords internal
segment <- function(title, ...) {
  htmltools::div(
    class = "ui raised segment",
    style = "margin-bottom: 0.5em",
    htmltools::div(class = "ui demo ribbon label blue", title),
    ...
  )
}

#' Prepare modal content.
#' @description Prepare modal content.
#' @param error Assertr error.
#' @param df_error_head_n Number of rows to display in error table.
#' @return Modal content.
#' @keywords internal
prepare_modal_content <- function(error, df_error_head_n) {
  data_part <- NULL # nolint: object_usage_linter
  errors_number <- seq_along(error$error_df[[1]])
  purrr::map(errors_number, ~ {
    data_part <-
      htmltools::div(
        style = "padding-left: 1em;",
        htmltools::div(class = "ui header", "Violated data (sample)"),
        htmltools::HTML(
          knitr::kable(
            utils::head(error$error_df[[1]][[.x]], n = df_error_head_n),
            "html",
            align = NULL,
            table.attr = "class=\"ui cellable table\""
          )
        ),
        htmltools::div(class = "ui horizontal divider", shiny.semantic::icon("flag"))
      )
    htmltools::tagList(
      htmltools::tags$table(
        class = "ui definition table",
        htmltools::tags$tbody(
          htmltools::tags$tr(
            htmltools::tags$td(htmltools::tags$h6("Error message")),
            htmltools::tags$td(
              class = "middle aligned",
              htmltools::tags$code(
                style = "white-space: pre-wrap; font-size: 0.85em",
                error$message[[1]][.x]
              )
            )
          ),
          htmltools::tags$tr(
            htmltools::tags$td(htmltools::tags$h6("Violations")),
            htmltools::tags$td(class = "middle aligned", error$num.violations[[1]][.x])
          )
        )
      ),
      data_part
    )
  }) %>% htmltools::tagList()
}

#' Create table row.
#' @description Create table row.
#' @param results Results to display in a row.
#' @param type Result type.
#' @param mark Icon to display.
#' @param df_error_head_n Number of rows to display in error table.
#' @return Table row.
#' @importFrom dplyr %>%
#' @importFrom rlang .data
#' @keywords internal
make_table_row <- function(results, type, mark, df_error_head_n) {
  description <- results %>% dplyr::pull(.data$description)
  id <- results %>% dplyr::pull(.data$assertion.id)
  data_name <- results %>% dplyr::pull(.data$table_name)
  result <- type
  button_class <- "ui disabled button"
  onclick <- NULL
  modal <- NULL
  if (result != success_id) {
    button_class <- "ui tiny button"

    onclick <- sprintf("$('#%s').modal('show');", id)
    modal_header <- paste0(data_name, ": ", description)
    modal <- htmltools::div(
      id = id,
      class = "ui longer test modal visible scrolling",
      htmltools::div(class = "header", htmltools::tags$h5(modal_header)),
      htmltools::div(
        class = "scrolling content",
        htmltools::div(
          class = "description",
          htmltools::tagList(
            prepare_modal_content(results, df_error_head_n)
          )
        )
      )
    )
  }

  htmltools::tags$tr(
    htmltools::tags$td(
      class = "left aligned",
      htmltools::tags$h6(description)
    ),
    htmltools::tags$td(
      class = "center aligned",
      shiny.semantic::icon(mark)
    ),
    htmltools::tags$td(
      class = "center aligned",
      htmltools::tagList(
        modal,
        htmltools::tags$button(class = button_class, "Show", onclick = onclick)
      )
    )
  )
}

#' Create table with results.
#' @description Create table with results.
#' @param results Result to display in table.
#' @param type Result type.
#' @param mark Icon to display.
#' @param df_error_head_n Number of rows to display in error table.
#' @return Table row.
#' @keywords internal
result_table <- function(results, type, mark, df_error_head_n) {
  if (nrow(results) == 0) {
    "No cases to display."
  } else {
    results <- dplyr::group_by(results, .data$table_name, .data$assertion.id, .data$description) %>%
      dplyr::summarise_at(dplyr::vars(-dplyr::group_cols()), list)
    htmltools::tags$table(
      class = "ui padded striped table",
      htmltools::tags$thead(
        htmltools::tags$tr(
          htmltools::tags$th(
            class = "twelve wide left aligned",
            htmltools::tags$h5("Validation rule")
          ),
          htmltools::tags$th(class = "one wide center aligned", htmltools::tags$h5("Status")),
          htmltools::tags$th(
            class = "three wide center aligned",
            htmltools::tags$h5("Error details")
          )
        )
      ),
      htmltools::tags$tbody(
        purrr::map(
          seq_len(nrow(results)),
          ~ make_table_row(
            results[.x, ],
            type,
            mark,
            df_error_head_n = df_error_head_n
          )
        )
      )
    )
  }
}

#' Create a UI accordion container.
#' @description Create a UI accordion container.
#' @param ... Additional arguments inside accordion container.
#' @return Accordion container.
#' @keywords internal
make_accordion_container <- function(...) {
  htmltools::tagList(
    htmltools::div(class = "ui styled accordion", style = "width:100%", ...)
  )
}

#' Create a UI accordion element.
#' @description Create a UI accordion element.
#' @param results Results to display.
#' @param mark Icon to display.
#' @param label Label.
#' @param color Color of the label icon.
#' @param type Result type.
#' @param active Is active?
#' @param df_error_head_n Number of rows to display in error table.
#' @return Accordion.
#' @keywords internal
make_accordion_element <- function(
    results,
    color = "green",
    label,
    active = FALSE,
    type,
    mark,
    df_error_head_n) {
  state <- NULL
  if (active) {
    state <- "active"
  }
  htmltools::tagList(
    htmltools::div(
      class = paste("title", state), shiny.semantic::icon("dropdown"),
      htmltools::tagList(
        shiny.semantic::label(
          length(unique(results$assertion.id)),
          class = paste(color, "circular tiny"),
          is_link = FALSE
        ),
        label
      )
    ),
    htmltools::div(
      class = paste("content", state),
      result_table(results, type, mark, df_error_head_n)
    )
  )
}

#' Displays results of validations.
#' @description Displays results of validations.
#' @param data Report data.
#' @param n_passes Number of successful assertions.
#' @param n_fails Number of warning assertions.
#' @param n_warns Number of violation assertions.
#' @param df_error_head_n Number of rows to display in error table.
#' @return Validation report.
#' @keywords internal
display_results <- function(data, n_passes, n_fails, n_warns, df_error_head_n) {
  data_name <- data$table_name[1]
  results_failed <- data %>%
    dplyr::filter(.data$type == error_id)
  results_warning <- data %>%
    dplyr::filter(.data$type == warning_id)
  results_passed <- data %>%
    dplyr::filter(.data$type == success_id)

  is_negative_active <- is_neutral_active <- FALSE
  label_color_negative <- label_color_neutral <- ""
  if (nrow(results_failed) > 0) {
    is_negative_active <- TRUE
    label_color_negative <- "red"
  }
  if (nrow(results_warning) > 0) {
    is_neutral_active <- TRUE
    label_color_neutral <- "blue"
  }
  segment_title <- data_name
  code <- segment(
    segment_title,
    htmltools::p(),
    make_accordion_container(
      if (!is.null(n_fails)) {
        make_accordion_element(
          results = results_failed,
          color = label_color_negative,
          label = "Failed",
          mark = "red big remove",
          type = error_id,
          active = is_negative_active,
          df_error_head_n = df_error_head_n
        )
      },
      if (!is.null(n_warns)) {
        make_accordion_element(
          results = results_warning,
          color = label_color_neutral,
          label = "Warnings",
          mark = "big blue exclamation circle",
          type = warning_id,
          active = is_neutral_active,
          df_error_head_n = df_error_head_n
        )
      },
      if (!is.null(n_passes)) {
        make_accordion_element(
          results = results_passed,
          label = "Passed",
          type = success_id,
          mark = "big green checkmark"
        )
      }
    )
  )
  code
}

#' Create summary table row.
#' @description Create summary table row.
#' @param id ID.
#' @param number Number to display.
#' @param color Color of the label.
#' @param label Label to display.
#' @return Summary table row.
#' @keywords internal
create_summary_row <- function(id, number, color, label) {
  list(
    htmltools::tags$td(
      id = id,
      class = "two wide right aligned",
      shiny.semantic::label(number, class = paste(color, "circular huge"), is_link = FALSE)
    ),
    htmltools::tags$td(class = "three wide left aligned", htmltools::tags$h2(label))
  )
}

#' Create summary table.
#' @description Create summary table.
#' @param n_passes Number of passed validations.
#' @param n_fails Number of failed validations.
#' @param n_warns Number of warnings.
#' @return Summary table.
#' @keywords internal
make_summary_table <- function(n_passes, n_fails, n_warns) {
  fails_label_color <- "red"
  if (identical(n_fails, 0)) {
    fails_label_color <- ""
  }
  warns_label_color <- "blue"
  if (identical(n_warns, 0)) {
    warns_label_color <- ""
  }
  code <- htmltools::tags$table(
    id = "summary",
    class = "ui padded table",
    htmltools::tags$tbody(
      htmltools::tags$tr(
        if (!is.null(n_fails)) {
          create_summary_row("failed_total", n_fails, fails_label_color, "Failed")
        },
        if (!is.null(n_warns)) {
          create_summary_row("warned_total", n_warns, warns_label_color, "Warnings")
        },
        if (!is.null(n_passes)) create_summary_row("passed_total", n_passes, "green", "Passed")
      )
    )
  )
  code
}

#' Generate HTML report.
#' @description Generate HTML validation report.
#' @param n_passes Number of passed validations
#' @param n_fails Number of failed validations.
#' @param n_warns Number of warnings.
#' @param validation_results Data frame with validation results.
#' @param df_error_head_n Number of rows to display in error table.
#' @return HTML validation report.
#' @keywords internal
get_semantic_report_ui <- function(
    n_passes,
    n_fails,
    n_warns,
    validation_results,
    df_error_head_n) {
  summary_table <- make_summary_table(n_passes, n_fails, n_warns)
  unique_objects <- validation_results %>%
    dplyr::pull(.data$table_name) %>%
    unique()
  html_report <- unique_objects %>%
    purrr::map(~ {
      validation_results %>%
        dplyr::filter(.data$table_name == .x) %>%
        display_results(n_passes, n_fails, n_warns, df_error_head_n)
    }) %>%
    htmltools::div()

  htmltools::div(summary_table, html_report)
}

post_render_js <- "
  function activateAccordion() {
    setTimeout(
      function() {
        $('.ui.accordion').accordion();
      },
      1000
    )
  }
"

#' Render semantic version of report
#'
#' @description Renders content of semantic report version.
#'
#' @param validation_results Validation results table (see \link{get_results}).
#' @param success Should success results be presented?
#' @param warning Should warning results be presented?
#' @param error Should error results be presented?
#' @param df_error_head_n Number of rows to display in error table.
#' Works in the same way as \code{head} function.
#' @export
render_semantic_report_ui <- function(validation_results,
                                      success = TRUE,
                                      warning = TRUE,
                                      error = TRUE,
                                      df_error_head_n = 6L) {
  n_passes <- NULL
  n_fails <- NULL
  n_warns <- NULL
  if (success) {
    n_passes <- length(
      unique(validation_results[validation_results$type == success_id, ]$assertion.id)
    )
  }
  if (warning) {
    n_warns <- length(
      unique(validation_results[validation_results$type == warning_id, ]$assertion.id)
    )
  }
  if (error) {
    n_fails <- length(
      unique(validation_results[validation_results$type == error_id, ]$assertion.id)
    )
  }
  get_semantic_report_ui(
    n_passes,
    n_fails,
    n_warns,
    validation_results,
    df_error_head_n
  ) %>%
    shiny.semantic::uirender(width = "100%", height = "100%") %>%
    htmlwidgets::onRender(post_render_js)
}

#' Render simple version of report
#'
#' @description Renders content of simple report version that prints \code{validation_results}
#'   table.
#'
#' @param validation_results Validation results table (see \link{get_results}).
#' @param success Should success results be presented?
#' @param warning Should warning results be presented?
#' @param error Should error results be presented?
#' @export
render_raw_report_ui <- function(validation_results, success = TRUE, warning = TRUE, error = TRUE) {
  types <- c(success_id, warning_id, error_id)[c(success, warning, error)]

  n_passes <- length(
    unique(validation_results[validation_results$type == success_id, ]$assertion.id)
  )
  n_fails <- length(
    unique(validation_results[validation_results$type == error_id, ]$assertion.id)
  )
  n_warns <- length(
    unique(validation_results[validation_results$type == warning_id, ]$assertion.id)
  )

  htmltools::tagList(
    if (success) htmltools::tags$div("Passed rules:", n_passes),
    if (error) htmltools::tags$div("Failed rules:", n_fails),
    if (warning) htmltools::tags$div("Warning rules:", n_warns),
    htmltools::HTML(
      knitr::kable(
        tidyr::unnest(validation_results, .data$error_df, keep_empty = TRUE) %>%
          dplyr::filter(.data$type %in% types),
        "html",
        align = NULL, table.attr = "class=\"ui cellable table\""
      )
    )
  )
}
