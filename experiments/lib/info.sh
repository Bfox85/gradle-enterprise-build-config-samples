#!/usr/bin/env bash

info() {
  printf "${INFO_COLOR}%s${RESTORE}\n" "$1"
}

infof() {
  local format_string="$1"
  shift
  # the format string is constructed from the caller's input. There is no
  # good way to rewrite this that will not trigger SC2059, so outright
  # disable it here.
  # shellcheck disable=SC2059  
  printf "${INFO_COLOR}${format_string}${RESTORE}\n" "$@"
}

print_experiment_name() {
  info
  info "Experiment ${EXP_NO}: ${EXP_NAME}"
  info "-----------------------------------------"
}

print_scan_tags() {
  local fmt="%-20s%-10s"

  info
  infof "$fmt" "Experiment Tag:" "${EXP_SCAN_TAG}"
  infof "$fmt" "Experiment Run ID:" "${RUN_ID}"
}
