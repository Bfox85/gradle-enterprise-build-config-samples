#!/usr/bin/env bash
#
# Runs Experiment 01 -  Optimize for incremental building
#
script_dir="$(cd "$(dirname "$(readlink -e "${BASH_SOURCE[0]}")")" && pwd)"
script_name=$(basename "$0")

# Include and parse the command line arguments
# shellcheck source=lib/01/parsing.sh
source "${script_dir}/lib/01/parsing.sh" || { echo "Couldn't find '${script_dir}/lib/01/parsing.sh' parsing library."; exit 1; }

#set -e
experiment_dir="${script_dir}/data/${script_name%.*}"
run_id=$(uuidgen)

main() {
  if [ "$_arg_wizard" == "on" ]; then
    wizard_execute
  else
    execute
  fi
}

execute() {
 print_experiment_name
 print_scan_tags

 collect_project_details
 collect_gradle_task
 make_experiment_dir

 clone_project
 execute_first_build
 execute_second_build

 print_summary
}

wizard_execute() {
 print_introduction

 explain_scan_tags
 print_scan_tags

 explain_collect_project_details
 collect_project_details

 explain_collect_gradle_task
 collect_gradle_task

 explain_experiment_dir
 make_experiment_dir

 #clone_project

 #explain_first_build
 #execute_first_build

 #explain_second_build
 #execute_second_build

 #explain_summary
 #print_summary
}

print_experiment_name() {
  info
  info "Experiment 01: Validate Incremental Build"
  info "-----------------------------------------"
}

print_scan_tags() {
  local fmt="%-20s%-10s"

  info
  infof "$fmt" "Experiment Tag:" "exp1"
  infof "$fmt" "Experiment Run ID:" "${run_id}"
}

collect_project_details() {

  if [ -n "${_arg_git_url}" ]; then
     project_url=$_arg_git_url
  else
    echo
    read -r -p "What is the project's GitHub URL? " project_url
  fi

  if [ -n "${_arg_branch}" ]; then
     project_branch=$_arg_branch
  else
     read -r -p "What branch should we checkout (press enter to use the project's default branch)? " project_branch
  fi

  project_name=$(basename -s .git "${project_url}")
}

collect_gradle_task() {
  if [ -z "$_arg_task" ]; then
    echo
    read -r -p "What Gradle task do you want to run? (assemble) " task

    if [[ "${task}" == "" ]]; then
      task=assemble
    fi
  else
    task=$_arg_task
  fi
}

make_experiment_dir() {
  mkdir -p "${experiment_dir}"
}

clone_project() {
   info
   info "Cloning ${project_name}"

   local clone_dir="${experiment_dir}/${project_name}"

   local branch=""
   if [ -n "${project_branch}" ]; then
      branch="--branch ${project_branch}"
   fi

   rm -rf "${clone_dir}"
   # shellcheck disable=SC2086  # we want $branch to expand into multiple arguments
   git clone --depth=1 ${branch} "${project_url}" "${clone_dir}"
   cd "${clone_dir}"
   info
}

execute_first_build() {
  info "Running first build (invoking clean)."
  info 
  info "./gradlew --no-build-cache -Dscan.tag.exp1 -Dscan.tag.${run_id} clean ${task}"

  invoke_gradle --no-build-cache clean "${task}"
}

execute_second_build() {
  info "Running second build (without invoking clean)."
  info 
  info "./gradlew --no-build-cache -Dscan.tag.exp1 -Dscan.tag.${run_id} ${task}"

  invoke_gradle --no-build-cache "${task}"
}

invoke_gradle() {
  # The gradle --init-script flag only accepts a relative directory path. ¯\_(ツ)_/¯
  local script_dir_rel
  script_dir_rel=$(realpath --relative-to="$( pwd )" "${script_dir}")
  ./gradlew --init-script "${script_dir_rel}/lib/capture-build-scan-info.gradle" -Dscan.tag.exp1 -Dscan.tag."${run_id}" "$@"
}

read_scan_info() {
  base_url=()
  scan_url=()
  scan_id=()
  # This isn't the most robust way to read a CSV,
  # but we control the CSV so we don't have to worry about various CSV edge cases
  while IFS=, read -r field_1 field_2 field_3; do
     base_url+=("$field_1")
     scan_id+=("$field_2")
     scan_url+=("$field_3")
  done < scans.csv
}

print_summary() {
 read_scan_info

 local branch
 branch=$(git branch)
 if [ -n "$_arg_branch" ]; then
   branch=${_arg_branch}
 fi

 local fmt="%-25s%-10s"
 info
 info "SUMMARY"
 info "----------------------------"
 infof "$fmt" "Project:" "${project_name}"
 infof "$fmt" "Branch:" "${branch}"
 infof "$fmt" "Gradle Task(s):" "${task}"
 infof "$fmt" "Experiment Dir:" "${experiment_dir}"
 infof "$fmt" "Experiment Tag:" "exp1"
 infof "$fmt" "Experiment Run ID:" "${run_id}"
 print_build_scans
 print_starting_points
}

print_build_scans() {
 local fmt="%-25s%-10s"
 infof "$fmt" "First Build Scan:" "${scan_url[0]}"
 infof "$fmt" "Second Build Scan:" "${scan_url[1]}"
}

print_starting_points() {
 local fmt="%-25s%-10s"
 info 
 info "SUGGESTED STARTING POINTS"
 info "----------------------------"
 infof "$fmt" "Scan Comparision:" "${base_url[0]}/c/${scan_id[0]}/${scan_id[1]}/task-inputs"
 infof "$fmt" "Longest-running tasks:" "${base_url[0]}/s/${scan_id[1]}/timeline?outcome=SUCCESS,FAILED&sort=longest"
 info
}

info() {
  printf "${YELLOW}${BOLD}%s${RESTORE}\n" "$1"
}

infof() {
  local format_string="$1"
  shift
  printf "${YELLOW}${BOLD}${format_string}${RESTORE}\n" "$@"
}

print_introduction() {
  local lines text ifs_bak
  IFS='' read -r -d '' text <<EOF
${CYAN}                              ;x0K0d,
${CYAN}                            kXOxx0XXO,
${CYAN}              ....                '0XXc
${CYAN}       .;lx0XXXXXXXKOxl;.          oXXK
${CYAN}      xXXXXXXXXXXXXXXXXXX0d:.     ,KXX0
${CYAN}     .,KXXXXXXXXXXXXXXXXXO0XXKOxkKXXXX:
${CYAN}   lKX:'0XXXXXKo,dXXXXXXO,,XXXXXXXXXK;       Gradle Enterprise Trial
${CYAN} ,0XXXXo.oOkl;;oKXXXXXXXXXXXXXXXXXKo.
${CYAN}:XXXXXXXKdllxKXXXXXXXXXXXXXXXXXX0c.
${CYAN}'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXk'
${CYAN}xXXXXXXXXXXXXXXXXXXXXXXXXXXXXXc           Experiment 01:
${CYAN}KXXXXXXXXXXXXXXXXXXXXXXXXXXXXl            Validate Incremental Build
${CYAN}XXXXXXklclkXXXXXXXklclxKXXXXK
${CYAN}OXXXk.     .OXXX0'     .xXXXx
${CYAN}oKKK'       ,KKK:       .KKKo

Wecome! This is the first of several experiments that are part of your Gradle
Enterprise Trial. Each experiment will help you to make concrete improvements
to your existing build. The experiments will also help you to build the data
necessary to recommend Gradle Enerprise to your organization.

This script (and the other experiment scripts) will run some of the experiment
steps for you, but we'll walk you through each step so that you know exactly
what we are doing, and why.

In this first experiment, we will be optimizing your existing build so that all
tasks participate in Gradle's incremental build feature. Gradle will only
execute tasks if their inputs have changed since the last time you ran them.
This let's Gradle avoid running tasks unecessarily (after all, why run a task
again if it's already completed it's work?).

For this experiment, we will run a clean build, and then we will run the same
build again without making any changes (but without invoking clean).
Afterwards, we'll look at the build scans to find tasks that were executed the
second time. In a fully optimized build, no tasks should run when no changes
have been made.

The Gradle Solutions engineer will then work with you to figure out why some
(if any) tasks ran on the second build, and how to optimize them so that all
tasks participate in Gradle's incremental building feature.
EOF

  print_in_box "${text}"
  wizard_pause "Press enter when you're ready to get started."
}

explain_scan_tags() {
  wizard "Below is the ID for this particular run of this experiment. Every time you run this script, \
we'll generate a new unique ID. This ID is added as a tag on all of the build scans, which \
makes it easy to find the build scans for each run of the experiment. We will also add an \
'exp1' tag to every build scan so that you can easily find all of the build scans for all \
runs of this experiment."
}

explain_collect_project_details() {
  wizard "We are going to create a fresh checkout of your project. That way, the experiment will be \
infleunced by as few outside factors as possible)."
}

explain_collect_gradle_task() {
  if [ -z "$_arg_task" ]; then
    wizard "We need a build task (or tasks) to run on each build of the experiment. If this is the first \
time you are running the experiment, then you may want to run a task that doesn't take very long to \
complete. You can run more complete (and longer) builds after you become more comfortable with running \
the experiment."
  fi
}

explain_experiment_dir() {
  wizard "All of the work we do for this experiment will be stored in ${YELLOW}${experiment_dir}${BLUE}."
}

explain_first_build() {
  wizard 
  wizard "OK! We are ready to run our first build!"
  wizard
  wizard "For this run, we'll execute 'clean ${task}'. We will also add a few more flags to \
make sure build caching is disabled (since we are just focused on icremental building \
for now), and to add the build scan tags we talked about before."
  wizard
  wizard "Effectively, this is what we are going to run (the actual command is a bit more complex):"

  info 
  info "./gradlew --no-build-cache -Dscan.tag.exp1 -Dscan.tag.${run_id} clean ${task}"

  wizard_pause "Press enter to run the first build."
}

explain_second_build() {
  wizard
  wizard "Now we are going to run the build again, but this time we will invoke it without \
'clean'. This will let us see how well the build takes advantage of Gradle's incremental build."

  wizard_pause "Press enter to run the second build."
}

explain_summary() {
  if [ "$_arg_wizard" == "on" ]; then
    read_scan_info

    wizard "-----------------------------------------------------------------------------"
    wizard "Now that both builds have completed, there is a lot of valuable \
data in Gradle Enterprise to look at. The data can help you find ineffiencies \
in your build."
    wizard
    wizard "After running the experiment, I will generate a summary table that \
contains useful data and links to help you analze the experiment results. Most \
of the data in the summmary is self-explainitory, but there are a few things \
that are worth reviewing:"
    wizard
    print_build_scans
    wizard
    wizard "^^ These are links to the build scans for the builds. A build scan is a \
report that provides statistics about the build execution."
    wizard
    print_starting_points
    wizard
    wizard "^^ These are links to help you get started in your analysis. The first link \
is to a comparison of the two build scans. Comparisions show you what was different \
between two different builds."
    wizard
    wizard "The second link takes you to the timeline view of the second build \
scan and automatically shows only the tasks that were executed, sorted by \
execution time (with the longest-running tasks listed first). You can use this \
to quickly identify tasks that were executed again unecessarily. You will want \
to optimize any such tasks that also take a significant amount of time to \
complete."
    wizard
    wizard "Take some time to look over the build scans and the build \
comparison. You might be surprised by what you find!"
    wizard
    wizard "If you do find something to optimize, then you will want to run \
this expirment again after you have implemented the optimizations (to \
validate the optimizations were effective.) Here is the command you can use \
to run the experiment again with the same inputs:"
   wizard
   info "./${script_name} --git-url ${project_url} --branch ${project_branch} --task ${task}"
   wizard
   wizard "Congratulations! You have completed this experiment."
   wizard "-----------------------------------------------------------------------------"
  fi
}

wizard() {
  local text
  #text=$(printf "${BLUE}${BOLD}${1}${RESTORE}\n" | fmt -w 80)
  text=$(printf "${1}\n" | fmt -w 76)

  print_in_box "${text}"
}

wizard_pause() {
  echo "${YELLOW}"
  read -r -p "$1"
  echo "${RESTORE}"
}


function print_in_box()
{
  local lines adjusted_lines b w

  # Convert the input into an array
  #   In bash, this is tricky, expecially if you want to preserve leading 
  #   whitespace and blank lines!
  ifs_bak=$IFS
  IFS=''
  while read line; do
    lines+=( "$line" )
  done <<< "$*"
  IFS=${ifs_bak}

  # Calculate the longest text width (w is witdh), excluding color codes
  # Also save the longest line in b ('b' for buffer)
  #    We'll use 'b' later to fill in the top and bottom borders
  for l in "${lines[@]}"; do
    no_color="$(echo "$l" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
    ((w<${#no_color})) && { b="$no_color"; w="${#no_color}"; }
  done

  echo -n "${BOX_COLOR}"
  echo "┌─${b//?/─}─┐"
  echo "│ ${b//?/ } │"
  for l in "${lines[@]}"; do
    # Adjust padding for color codes (add spaces for removed color codes)
    local no_color padding
    no_color="$(echo "$l" | sed $'s,\x1b\\[[0-9;]*[a-zA-Z],,g')"
    padding=$((w+${#l}-${#no_color}))
    printf '│ %s%*s%s │\n' "${WIZ_COLOR}" "-$padding" "$l" "${BOX_COLOR}"
  done
  echo "│ ${b//?/ } │"
  echo "└─${b//?/─}─┘"
  echo -n "${RESET}"
}

# Color and text escape sequences
RESTORE=$(echo -en '\033[0m')
RED=$(echo -en '\033[00;31m')
GREEN=$(echo -en '\033[00;32m')
YELLOW=$(echo -en '\033[00;33m')
BLUE=$(echo -en '\033[00;34m')
MAGENTA=$(echo -en '\033[00;35m')
PURPLE=$(echo -en '\033[00;35m')
CYAN=$(echo -en '\033[00;36m')
LIGHTGRAY=$(echo -en '\033[00;37m')
LRED=$(echo -en '\033[01;31m')
LGREEN=$(echo -en '\033[01;32m')
LYELLOW=$(echo -en '\033[01;33m')
LBLUE=$(echo -en '\033[01;34m')
LMAGENTA=$(echo -en '\033[01;35m')
LPURPLE=$(echo -en '\033[01;35m')
LCYAN=$(echo -en '\033[01;36m')
WHITE=$(echo -en '\033[01;37m')

BOLD=$(echo -en '\033[1m')
DIM=$(echo -en '\033[2m')
UNDERLINE=$(echo -en '\033[4m')

WIZ_COLOR="${BLUE}${BOLD}"
BOX_COLOR="${CYAN}"

main
