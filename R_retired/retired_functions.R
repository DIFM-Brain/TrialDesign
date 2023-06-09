
#' Create data of input rate information for two inputs at the same time
#'
#' Create data of input rate information for a single input. This can be used to assign rates to experiment plots using assign_rates()
#'
#' @param plot_info (data.frame) plot information created by make_input_plot_data
#' @param gc_rate (numeric) Input ate the grower would have chosen if not running an experiment. This rate is assigned to the non-experiment part of the field. This rate also becomes one of the trial input rates unless you specify the trial rates directly using rates argument
#' @param unit (string) unit of input
#' @param rates (numeric vector) Default is NULL. Sequence of trial rates in the ascending order.
#' @param min_rate (numeric) minimum input rate. Ignored if rates are specified.
#' @param max_rate (numeric) maximum input rate. Ignored if rates are specified
#' @param num_rates (numeric) Default is 5. It has to be an even number if design_type is "ejca". Ignored if rates are specified.
#' @param design_type (string) type of trial design. available options are Latin Square ("ls"), Strip ("strip"), Randomized Block ("rb"), Jump-conscious Latin Square ("jcls"), Sparse ("sparse"), and Extra Jump-conscious Alternate "ejca". See for more details.
#' @param rank_seq_ws (integer) vector of integers indicating the order of the ranking of the rates, which will be repeated "within" a strip.
#' @param rank_seq_as (integer) vector of integers indicating the order of the ranking of the rates, which will be repeated "across" strip for their first plots.
#' @returns data.frame of input rate information
#' @import data.table
#' @export
#' @examples
#' seed_plot_info <-
#'   prep_plot_fs(
#'     input_name = "seed",
#'     machine_width = 60,
#'     section_num = 24,
#'     harvester_width = 30,
#'     plot_width = 30
#'   )
#'
#' n_plot_info <-
#'   prep_plot_ms(
#'     input_name = "NH3",
#'     machine_width = measurements::conv_unit(60, "ft", "m"),
#'     section_num = 1,
#'     harvester_width = measurements::conv_unit(30, "ft", "m"),
#'     plot_width = measurements::conv_unit(60, "ft", "m")
#'   )
#'
#' plot_info <- list(seed_plot_info, n_plot_info)
#'
#' prep_rates_d(
#'   plot_info,
#'   gc_rate = c(30000, 160),
#'   unit = c("seeds", "lb"),
#'   rates = list(
#'     c(20000, 25000, 30000, 35000, 40000),
#'     c(100, 130, 160, 190, 220)
#'   )
#' )
#'
prep_rates_d <- function(plot_info, gc_rate, unit, rates = list(NULL, NULL), min_rate = c(NA, NA), max_rate = c(NA, NA), num_rates = c(5, 5), design_type = c(NA, NA), rank_seq_ws = list(NULL, NULL), rank_seq_as = list(NULL, NULL)) {
  if (class(plot_info) == "list") {
    plot_info <- dplyr::bind_rows(plot_info)
  }

  #++++++++++++++++++++++++++++++++++++
  #+ Dimension Checks
  #++++++++++++++++++++++++++++++++++++
  if (nrow(plot_info) != 2) {
    stop("Plot information (plot_info argument) should consist of two rows. Please check.")
  }

  fms_ls <- c(
    nrow(plot_info), length(gc_rate), length(unit), length(rates), length(min_rate),
    length(max_rate), length(num_rates), length(design_type), length(rank_seq_ws), length(rank_seq_as)
  )
  if (any(fms_ls != 2)) {
    stop("Inconsistent numbers of elements in the arguments.")
  }

  #--- extract input_name and unit ---#
  input_trial_data <-
    dplyr::select(plot_info, input_name) %>%
    #++++++++++++++++++++++++++++++++++++
    #+ design type
    #++++++++++++++++++++++++++++++++++++
    dplyr::mutate(design_type = design_type) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      design_type =
        if (is.na(design_type)) {
          #--- if design_type not specified, use jcls ---#
          "jcls"
        } else {
          design_type
        }
    ) %>%
    dplyr::ungroup() %>%
    #++++++++++++++++++++++++++++++++++++
    #+Specify the trial rates
    #++++++++++++++++++++++++++++++++++++
    dplyr::mutate(rates = rates) %>%
    dplyr::mutate(gc_rate = gc_rate) %>%
    dplyr::mutate(min_rate = min_rate) %>%
    dplyr::mutate(max_rate = max_rate) %>%
    dplyr::mutate(num_rates = num_rates) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(rates_ls = list(
      if (!is.null(rates)) {
        rates
      } else if (!is.na(min_rate) & !is.na(max_rate) & !is.na(num_rates)) {
        #--- if min_rate, max_rate, and num_rates are specified ---#
        message("Trial rates were not specified directly for ", input_name, " so the trial rates were calculated using min_rate, max_rate, gc_rate, and num_rates\n")
        get_rates(
          min_rate,
          max_rate,
          gc_rate,
          num_rates
        )
      } else {
        stop("Please provide either {rates} as a vector or all of {min_rate, max_rate, and num_rates}.")
      }
    )) %>%
    dplyr::mutate(rates_data = list(
      if (design_type %in% c("ls", "jcls", "strip", "rb")) {
        data.table(
          rate = rates_ls,
          rate_rank = 1:length(rates_ls)
        )
      } else if (design_type == "sparse") {
        if (!gc_rate %in% rates_ls) {
          stop(
            "Error: You specified the trial rates directly using the rates argument, but they do not include gc_rate. For the sparse design, please include gc_rate in the rates."
          )
        } else {
          rates_ls <- rates_ls[!rates_ls %in% gc_rate]
          data.table(
            rate = append(gc_rate, rates_ls),
            rate_rank = 1:(length(rates_ls) + 1)
          )
        }
      } else if (design_type == "ejca") {
        if (length(rates_ls) %% 2 == 1) {
          stop(
            "Error: You cannot have an odd number of rates for the ejca design. Please either specify rates directly with even numbers of rates or specify an even number for num_rates along with min_rate and max_rate."
          )
        } else {
          data.table(
            rate = rates_ls,
            rate_rank = 1:length(rates_ls)
          )
        }
      } else {
        stop("Error: design_type you specified does not match any of the options available.")
      }
    )) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(unit = unit) %>%
    dplyr::mutate(rank_seq_ws = rank_seq_ws) %>%
    dplyr::mutate(rank_seq_as = rank_seq_as)

  return(input_trial_data)
}

mod_rate_info <- function(rate_info, what, new_value) {
  #*+++++++++++++++++++++++++++++++++++
  #* Debug
  #*+++++++++++++++++++++++++++++++++++
  # data(rate_info)
  # what <- "rates"
  # new_value <- c(100, 130, 180, 230, 290)

  #*+++++++++++++++++++++++++++++++++++
  #* Main
  #*+++++++++++++++++++++++++++++++++++
  if (!what %in% colnames(rate_info)) {
    stop('The component you are referring to with "what" does not exist.')
  }

  setnames(rate_info, what, "temp")
  if (is.null(new_value)) {
    rate_info <- dplyr::mutate(rate_info, temp = new_value)
  } else if (length(new_value) > 1) {
    rate_info <- dplyr::mutate(rate_info, temp = list(new_value))
  }
  setnames(rate_info, "temp", what)
  
  return_info <- 
    prep_rates_s(
    plot_info = rate_info$plot_info[[1]],
    gc_rate = rate_info$gc_rate,
    unit = rate_info$unit,
    rates = rate_info$rates[[1]],
    min_rate = rate_info$min_rate,
    max_rate = rate_info$max_rate,
    num_rates = rate_info$num_rates,
    design_type = rate_info$design_type,
    rank_seq_ws = rate_info$rank_seq_ws,
    rank_seq_as = rate_info$rank_seq_as
    )
  
  return(return_info)
}

#' Prepare plot information for a two-input experiment (length in meter)
#'
#' Prepare plot information for a two-input experiment case. All the length values need to be specified in meter.
#'
#' @param input_name (character) A vector of two input names
#' @param machine_width (numeric) A vector of two numeric numbers in meter that indicate the width of the applicator or planter of the inputs 
#' @param section_num (numeric) A vector of two numeric numbers that indicate the number of sections of the applicator or planter of the inputs
#' @param harvester_width (numeric) A numeric number in meter that indicates the width of the harvester
#' @param plot_width (numeric) A vector of two numeric numbers in meter that indicate the plot width for each of the two inputs. Default is c(NA, NA). 
#' @param headland_length (numeric) A numeric number in meter that indicates the length of the headland (how long the non-experimental space is in the direction machines drive). Default is NA.
#' @param side_length (numeric) A numeric number in meter that indicates the length of the two sides of the field (how long the non-experimental space is in the direction perpendicular to the direction of machines). Default is NA.
#' @param max_plot_width (numeric) Maximum width of the plots in meter. Default is 36.576 meter (120 feet).
#' @param min_plot_length (numeric) Minimum length of the plots in meter. Default is 73.152 meter (240 feet).
#' @param max_plot_length (numeric) Maximum length of the plots in meter. Default is 91.44 meter (300 feet).
#' @returns a tibble with plot information necessary to create experiment plots
#' @import data.table
#' @export
#' @examples
#' input_name <- c("seed", "NH3")
#' machine_width <- c(12, 9)
#' section_num <- c(12, 1)
#' plot_width <- c(12, 36)
#' harvester_width <- 12
#' prep_plot_md(input_name, machine_width, section_num, harvester_width, plot_width)
#'
prep_plot_md <- function(input_name,
                         machine_width,
                         section_num,
                         harvester_width,
                         plot_width = c(NA, NA),
                         headland_length = NA,
                         side_length = NA,
                         max_plot_width = measurements::conv_unit(120, "ft", "m"), # 36.4576 meter
                         min_plot_length = measurements::conv_unit(240, "ft", "m"), # 73.152 feet
                         max_plot_length = measurements::conv_unit(300, "ft", "m") # 79.248 meter
) {

  #--- dimension check ---#
  fms_ls <- c(length(input_name), length(machine_width), length(section_num), length(plot_width))
  if (any(fms_ls != 2)) {
    stop("Inconsistent numbers of elements in input_name, machine_width, section_num, and plot_width. Check if all of them have two elements.")
  }

  section_width <- machine_width / section_num

  plot_data <-
    data.frame(
      input_name = input_name,
      machine_width = machine_width,
      section_num = section_num,
      harvester_width = harvester_width,
      plot_width = plot_width
    ) %>%
    dplyr::mutate(section_width = machine_width / section_num) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      lcm_found =
        lcm_check(section_width, harvester_width, max_plot_width)
    ) %>%
    dplyr::mutate(
      proposed_plot_width =
        find_plotwidth(section_width, harvester_width, max_plot_width)
    ) %>%
    dplyr::mutate(plot_width = ifelse(is.na(plot_width), proposed_plot_width, plot_width))

  for (i in 1:nrow(plot_data)) {
    temp <- plot_data[i, ]
      if ((temp$plot_width %% temp$section_width) != 0) {
        stop(paste0(
          "Plot width provided is not a multiple of the machine (section) width for ", temp$input_name,".\n"
        ))
     }
  }

  #++++++++++++++++++++++++++++++++++++
  #+ Check and notify the mixed treatment problems (with potential suggestions)
  #++++++++++++++++++++++++++++++++++++
  warning_message <-
    plot_data %>%
    dplyr::mutate(messages = list(
      if (lcm_found & plot_width %% proposed_plot_width == 0 & proposed_plot_width < plot_width) {
        paste0(
          "For ", input_name, ", there is a plot width that is smaller than the plot width you suggested and avoids mixed treatement problem. It is suggested that you use ", proposed_plot_width, " as the plot width."
        )
      } else if (lcm_found & plot_width %% proposed_plot_width != 0) {
        paste0(
          "For ", input_name, ", the plot width you specified would cause mixed treatment problems. However, there is a plot width that avoids them. It is suggested that you use ", proposed_plot_width, " as the plot width."
        )
      } else if (!lcm_found & plot_width != proposed_plot_width) {
        paste0(
          "For ", input_name, ", the plot width you specified would cause mixed treatment problems. Unfortunately, there is no plot width that avoids them. Plot width of ", proposed_plot_width, " ensures that at least one harvest path within the path of ", input_name, " does not have the problems."
        )
      } else {
        NULL
      }
    )) %>%
    dplyr::pull(messages)

  #--- notify the user of potential problems and improvements ---#
  message(unlist(warning_message))

  #--- warnd the user that they may have serious mixed treatment problems   ---#
  if (all(!plot_data$lcm_found)) {
    message(paste0(
      "Neither of ", input_name[1], " and ", input_name[2], " does not have a plot width without mixed treatment problems. Please consider running experiments with a single input instead of two."
    ))
  }

  #++++++++++++++++++++++++++++++++++++
  #+ head and side lengths
  #++++++++++++++++++++++++++++++++++++
  #--- head distance ---#
  if (is.na(headland_length)) {
    headland_length <- 2 * max(machine_width)
  }

  #--- side distance ---#
  if (is.na(side_length)) {
    side_length <- max(max(section_width), measurements::conv_unit(30, "ft", "m"))
  }

  #++++++++++++++++++++++++++++++++++++
  #+ put together the data
  #++++++++++++++++++++++++++++++++++++
  plot_data <-
    plot_data %>%
    dplyr::mutate(
      headland_length = headland_length,
      side_length = side_length,
      min_plot_length = min_plot_length,
      max_plot_length = max_plot_length
    ) %>%
    dplyr::select(
      input_name, machine_width, section_num, section_width, harvester_width, plot_width, proposed_plot_width, headland_length, side_length, min_plot_length, max_plot_length
    ) %>%
    dplyr::ungroup()

  return(plot_data)
}

#' Prepare plot information for a two-input experiment (length in feet)
#'
#' Prepare plot information for a two-input experiment case. All the length values need to be specified in feet.
#'
#' @param input_name (character) A vector of two input names
#' @param machine_width (numeric) A vector of two numeric numbers in feet that indicate the width of the applicator or planter of the inputs 
#' @param section_num (numeric) A vector of two numeric numbers that indicate the number of sections of the applicator or planter of the inputs
#' @param harvester_width (numeric) A numeric number in feet that indicates the width of the harvester
#' @param plot_width (numeric) A vector of two numeric numbers in feet that indicate the plot width for each of the two inputs. Default is c(NA, NA). 
#' @param headland_length (numeric) A numeric number in feet that indicates the length of the headland (how long the non-experimental space is in the direction machines drive). Default is NA.
#' @param side_length (numeric) A numeric number in feet that indicates the length of the two sides of the field (how long the non-experimental space is in the direction perpendicular to the direction of machines). Default is NA.
#' @param max_plot_width (numeric) Maximum width of the plots in feet. Default is (36.576 meter).
#' @param min_plot_length (numeric) Minimum length of the plots in feet. Default is 240 feet (73.152 meter).
#' @param max_plot_length (numeric) Maximum length of the plots in feet. Default is 300 feet (91.44 meter).
#' @returns a tibble with plot information necessary to create experiment plots
#' @import data.table
#' @export
#' @examples
#' input_name <- c("seed", "NH3")
#' machine_width <- c(12, 9)
#' section_num <- c(12, 1)
#' plot_width <- c(12, 36)
#' harvester_width <- 12
#' prep_plot_fd(input_name, machine_width, section_num, harvester_width, plot_width)
#'
prep_plot_fd <- function(input_name,
                         machine_width,
                         section_num,
                         harvester_width,
                         plot_width = c(NA, NA),
                         headland_length = NA,
                         side_length = NA,
                         max_plot_width = 120,
                         min_plot_length = 240,
                         max_plot_length = 300
) {

  #--- dimension check ---#
  fms_ls <- c(length(input_name), length(machine_width), length(section_num), length(plot_width))
  if (any(fms_ls != 2)) {
    stop("Inconsistent numbers of elements in input_name, machine_width, section_num, and plot_width. Check if all of them have two elements.")
  }

  section_width <- machine_width / section_num

  plot_data <-
    data.frame(
      input_name = input_name,
      machine_width = machine_width,
      section_num = section_num,
      harvester_width = harvester_width,
      plot_width = plot_width
    ) %>%
    dplyr::mutate(section_width = machine_width / section_num) %>%
    dplyr::rowwise() %>%
    dplyr::mutate(
      lcm_found =
        lcm_check(section_width, harvester_width, max_plot_width)
    ) %>%
    dplyr::mutate(
      proposed_plot_width =
        find_plotwidth(section_width, harvester_width, max_plot_width)
    ) %>%
    dplyr::mutate(plot_width = ifelse(is.na(plot_width), proposed_plot_width, plot_width))
  
  for (i in 1:nrow(plot_data)) {
    temp <- plot_data[i, ]
      if ((temp$plot_width %% temp$section_width) != 0) {
        stop(paste0(
          "Plot width provided is not a multiple of the machine (section) width for ", temp$input_name,".\n"
        ))
     }
  }

  #++++++++++++++++++++++++++++++++++++
  #+ Check and notify the mixed treatment problems (with potential suggestions)
  #++++++++++++++++++++++++++++++++++++
  warning_message <-
    plot_data %>%
    dplyr::mutate(messages = list(
      if (lcm_found & plot_width %% proposed_plot_width == 0 & proposed_plot_width < plot_width) {
        paste0(
          "For ", input_name, ", there is a plot width that is smaller than the plot width you suggested and avoids mixed treatement problem. It is suggested that you use ", proposed_plot_width, " as the plot width."
        )
      } else if (lcm_found & plot_width %% proposed_plot_width != 0) {
        paste0(
          "For ", input_name, ", the plot width you specified would cause mixed treatment problems. However, there is a plot width that avoids them. It is suggested that you use ", proposed_plot_width, " as the plot width."
        )
      } else if (!lcm_found & plot_width != proposed_plot_width) {
        paste0(
          "For ", input_name, ", the plot width you specified would cause mixed treatment problems. Unfortunately, there is no plot width that avoids them. Plot width of ", proposed_plot_width, " ensures that at least one harvest path within the path of ", input_name, " does not have the problems."
        )
      } else {
        NULL
      }
    )) %>%
    dplyr::pull(messages)

  #--- notify the user of potential problems and improvements ---#
  message(unlist(warning_message))

  #--- warnd the user that they may have serious mixed treatment problems   ---#
  if (all(!plot_data$lcm_found)) {
    message(paste0(
      "Neither of ", input_name[1], " and ", input_name[2], " does not have a plot width without mixed treatment problems. Please consider running experiments with a single input instead of two."
    ))
  }

  #++++++++++++++++++++++++++++++++++++
  #+ head and side lengths
  #++++++++++++++++++++++++++++++++++++
  #--- head distance ---#
  if (is.na(headland_length)) {
    headland_length <- 2 * max(machine_width)
  }

  #--- side distance ---#
  if (is.na(side_length)) {
    side_length <- max(max(section_width), 30)
  }
  #++++++++++++++++++++++++++++++++++++
  #+ put together the data
  #++++++++++++++++++++++++++++++++++++
  plot_data <-
    plot_data %>%
    dplyr::mutate(
      headland_length = headland_length,
      side_length = side_length,
      min_plot_length = min_plot_length,
      max_plot_length = max_plot_length
    ) %>%
    dplyr::select(
      input_name, machine_width, section_num, section_width, harvester_width, plot_width, proposed_plot_width, headland_length, side_length, min_plot_length, max_plot_length
    )

  #++++++++++++++++++++++++++++++++++++
  #+ Unit converstion (feet to meter)
  #++++++++++++++++++++++++++++++++++++
  cols_conv <- c("machine_width", "section_width", "harvester_width", "plot_width", "proposed_plot_width", "headland_length", "side_length", "min_plot_length", "max_plot_length")

  plot_data <- dplyr::mutate(plot_data, dplyr::across(dplyr::all_of(cols_conv), ~ measurements::conv_unit(.x, "ft", "m")))

  # plot_data[, (cols_conv) := lapply(.SD, function(x) measurements::conv_unit(x, "ft", "m")), .SDcols = cols_conv]

  return(plot_data)
}

