#!/bin/bash

bind 'TAB:complete'

# ==============================================================================
# Progress Tracking (auto-updated by game)
# ==============================================================================
# TASK 1: Navigating the filesystem
#   SUBTASK 1: go_to_subdir [ ]
#   SUBTASK 2: find_file [ ]
#   SUBTASK 3: return_to_root [ ]
# TASK 2: Creating and deleting files and folders
#   SUBTASK 1: create_empty_file [ ]
#   SUBTASK 2: create_dir_and_file [ ]
#   SUBTASK 3: create_file_with_text [ ]
# TASK 3: Modifying file and folder permissions
#   SUBTASK 1: make_executable [ ]
#   SUBTASK 2: set_owner_permissions [ ]
# TASK 4: Writing and executing simple scripts
#   SUBTASK 1: create_and_run_simple [ ]
#   SUBTASK 2: create_and_run_ls [ ]
# ==============================================================================

# ==============================================================================
# Global Variables
# ==============================================================================
GAME_DIR=""
SCRIPT_ABS_PATH=$(realpath "$0")
CURRENT_TASK_ID=""
CURRENT_SUBTASK_INDEX=-1
GAME_PROMPT="[CMD_ADVENTURE] > "

# Randomized targets
declare -A TARGET_DIRS
declare -A TARGET_FILES
declare -A TARGET_SCRIPTS

# ==============================================================================
# Task Definitions
# ==============================================================================
declare -a TASKS=(
  "Navigating the filesystem"
  "Creating and deleting files and folders"
  "Modifying file and folder permissions"
  "Writing and executing simple scripts"
)

declare -a SUBTASKS_NAV=("go_to_subdir" "find_file" "return_to_root")
declare -a SUBTASKS_CREATE=("create_empty_file" "create_dir_and_file" "create_file_with_text")
declare -a SUBTASKS_PERMISSIONS=("make_executable" "set_owner_permissions")
declare -a SUBTASKS_SCRIPTS=("create_and_run_simple" "create_and_run_ls")

# ==============================================================================
# Utility Functions
# ==============================================================================
print_separator() {
  echo "=============================================================================="
}

# ==============================================================================
# Self-modifying progress helpers
# ==============================================================================
mark_subtask_completed() {
  local task_id=$1
  local subtask_id=$2
  local task_name="${TASKS[$((task_id - 1))]}"
  local subtask_name
  case "$task_id" in
  1) subtask_name="${SUBTASKS_NAV[$((subtask_id - 1))]}" ;;
  2) subtask_name="${SUBTASKS_CREATE[$((subtask_id - 1))]}" ;;
  3) subtask_name="${SUBTASKS_PERMISSIONS[$((subtask_id - 1))]}" ;;
  4) subtask_name="${SUBTASKS_SCRIPTS[$((subtask_id - 1))]}" ;;
  esac
  # Replace the line with [✔]
  sed -i "s|#   SUBTASK ${subtask_id}: ${subtask_name} \[ \]|#   SUBTASK ${subtask_id}: ${subtask_name} [✔]|" "$SCRIPT_ABS_PATH"
}

show_progress() {
  print_separator
  local i
  if [[ -z "$CURRENT_TASK_ID" ]]; then
    echo "Task Progress:"
    for i in "${!TASKS[@]}"; do
      task_num=$((i + 1))
      if grep -q "# TASK ${task_num}: .*\\[✔\\]" "$SCRIPT_ABS_PATH"; then
        status="[✔]"
      else
        status="[ ]"
      fi
      echo "$status ${TASKS[$i]}"
    done
  else
    task_id="$CURRENT_TASK_ID"
    echo "Subtask Progress for ${TASKS[$((task_id - 1))]}:"
    local subtasks
    case "$task_id" in
    1) subtasks=("${SUBTASKS_NAV[@]}") ;;
    2) subtasks=("${SUBTASKS_CREATE[@]}") ;;
    3) subtasks=("${SUBTASKS_PERMISSIONS[@]}") ;;
    4) subtasks=("${SUBTASKS_SCRIPTS[@]}") ;;
    esac
    for i in "${!subtasks[@]}"; do
      sub_num=$((i + 1))
      line="#   SUBTASK ${sub_num}: ${subtasks[j]} [✔]"
      if grep -qF "$line" "$SCRIPT_ABS_PATH"; then
        status="[✔]"
      else
        status="[ ]"
      fi
      echo "$status ${subtasks[j]}"
    done
  fi
  print_separator
}

# ==============================================================================
# Game Setup / Cleanup
# ==============================================================================
setup_game() {
  print_separator
  echo "Welcome to the Bash Command Line Adventure! 🚀"
  print_separator

  GAME_DIR=$(mktemp -d -t cmd-adventure-XXXXXXXX)
  if [ ! -d "$GAME_DIR" ]; then
    echo "Error: Could not create temporary directory. Exiting."
    exit 1
  fi
  echo "Game environment created at: $GAME_DIR"
  cd "$GAME_DIR" || exit
}

cleanup() {
  print_separator
  echo "Cleaning up game environment..."
  cd /tmp || exit
  rm -rf "$GAME_DIR"
  echo "Done. Thanks for playing! 👋"
  print_separator
}

# ==============================================================================
# Instructions
# ==============================================================================
show_instructions() {
  print_separator
  case "$1" in
  "0") echo "General command line info..." ;;
  "1") echo "Navigating the filesystem instructions..." ;;
  "2") echo "Creating/deleting files and folders instructions..." ;;
  "3") echo "Modifying permissions instructions..." ;;
  "4") echo "Writing/executing scripts instructions..." ;;
  esac
  print_separator
}

# ==============================================================================
# Task Handling
# ==============================================================================
explain_task() {
  if [[ -z "$CURRENT_TASK_ID" || "$CURRENT_SUBTASK_INDEX" -lt 0 ]]; then
    echo "No task selected."
    return
  fi
  print_separator
  echo "TASK: ${TASKS[$((CURRENT_TASK_ID - 1))]}"

  local current_subtask
  case "$CURRENT_TASK_ID" in
  1) current_subtask="${SUBTASKS_NAV[$CURRENT_SUBTASK_INDEX]}" ;;
  2) current_subtask="${SUBTASKS_CREATE[$CURRENT_SUBTASK_INDEX]}" ;;
  3) current_subtask="${SUBTASKS_PERMISSIONS[$CURRENT_SUBTASK_INDEX]}" ;;
  4) current_subtask="${SUBTASKS_SCRIPTS[$CURRENT_SUBTASK_INDEX]}" ;;
  esac

  cd "$GAME_DIR" || exit

  case "$current_subtask" in
  "go_to_subdir")
    TARGET_DIRS["$current_subtask"]="data_$(shuf -i 100-999 -n 1)"
    mkdir -p "${TARGET_DIRS[$current_subtask]}/docs/archive"
    echo "Go into '${TARGET_DIRS[$current_subtask]}' directory."
    ;;
  "find_file")
    TARGET_DIRS["$current_subtask"]="data_$(shuf -i 100-999 -n 1)"
    mkdir -p "${TARGET_DIRS[$current_subtask]}/docs/archive"
    TARGET_FILES["$current_subtask"]="secret_file.txt"
    touch "${TARGET_DIRS[$current_subtask]}/docs/archive/${TARGET_FILES[$current_subtask]}"
    echo "Find and navigate to 'secret_file.txt' inside '${TARGET_DIRS[$current_subtask]}' tree."
    ;;
  "return_to_root")
    TARGET_DIRS["$current_subtask"]="data_$(shuf -i 100-999 -n 1)"
    mkdir -p "${TARGET_DIRS[$current_subtask]}/docs/archive"
    cd "${TARGET_DIRS[$current_subtask]}/docs/archive"
    echo "Return to the root of the game directory from deep inside."
    ;;
  "create_empty_file")
    TARGET_FILES["$current_subtask"]="report_$(shuf -i 100-999 -n 1).txt"
    echo "Create an empty file named '${TARGET_FILES[$current_subtask]}'."
    ;;
  "create_dir_and_file")
    TARGET_DIRS["$current_subtask"]="project_$(shuf -i 100-999 -n 1)"
    TARGET_FILES["$current_subtask"]="notes.txt"
    echo "Create directory '${TARGET_DIRS[$current_subtask]}' and 'notes.txt' inside."
    ;;
  "create_file_with_text")
    TARGET_FILES["$current_subtask"]="hello.txt"
    echo "Create 'hello.txt' with text 'Hello World!'."
    ;;
  "make_executable")
    TARGET_DIRS["$current_subtask"]="secure_vault_$(shuf -i 100-999 -n 1)"
    TARGET_FILES["$current_subtask"]="locked.txt"
    mkdir "${TARGET_DIRS[$current_subtask]}"
    touch "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}"
    chmod 600 "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}"
    echo "Make '${TARGET_FILES[$current_subtask]}' executable for everyone."
    ;;
  "set_owner_permissions")
    TARGET_DIRS["$current_subtask"]="secure_vault_$(shuf -i 100-999 -n 1)"
    TARGET_FILES["$current_subtask"]="secret.sh"
    mkdir "${TARGET_DIRS[$current_subtask]}"
    touch "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}"
    chmod 755 "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}"
    echo "Set permissions of '${TARGET_FILES[$current_subtask]}' to 700."
    ;;
  "create_and_run_simple")
    TARGET_SCRIPTS["$current_subtask"]="myscript_$(shuf -i 100-999 -n 1).sh"
    echo "Create script '${TARGET_SCRIPTS[$current_subtask]}' that prints 'Hello from script!'"
    ;;
  "create_and_run_ls")
    TARGET_SCRIPTS["$current_subtask"]="list_files_$(shuf -i 100-999 -n 1).sh"
    echo "Create script '${TARGET_SCRIPTS[$current_subtask]}' that lists files."
    ;;
  esac
  print_separator
}

check_task_completion() {
  if [[ -z "$CURRENT_TASK_ID" || "$CURRENT_SUBTASK_INDEX" -lt 0 ]]; then
    return
  fi

  local current_subtask
  case "$CURRENT_TASK_ID" in
  1) current_subtask="${SUBTASKS_NAV[$CURRENT_SUBTASK_INDEX]}" ;;
  2) current_subtask="${SUBTASKS_CREATE[$CURRENT_SUBTASK_INDEX]}" ;;
  3) current_subtask="${SUBTASKS_PERMISSIONS[$CURRENT_SUBTASK_INDEX]}" ;;
  4) current_subtask="${SUBTASKS_SCRIPTS[$CURRENT_SUBTASK_INDEX]}" ;;
  esac

  local completed=0
  case "$current_subtask" in
  "go_to_subdir")
    [[ "$(basename "$PWD")" == "${TARGET_DIRS[$current_subtask]}" ]] && completed=1
    ;;
  "find_file")
    [[ -f "${TARGET_FILES[$current_subtask]}" ]] && completed=1
    ;;
  "return_to_root")
    [[ "$PWD" == "$GAME_DIR" ]] && completed=1
    ;;
  "create_empty_file")
    [[ -f "${TARGET_FILES[$current_subtask]}" ]] && completed=1
    ;;
  "create_dir_and_file")
    [[ -f "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}" ]] && completed=1
    ;;
  "create_file_with_text")
    [[ -f "${TARGET_FILES[$current_subtask]}" && "$(cat "${TARGET_FILES[$current_subtask]}")" == "Hello World!" ]] && completed=1
    ;;
  "make_executable")
    [[ -x "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}" ]] && completed=1
    ;;
  "set_owner_permissions")
    [[ "$(stat -c %a "${TARGET_DIRS[$current_subtask]}/${TARGET_FILES[$current_subtask]}")" == "700" ]] && completed=1
    ;;
  "create_and_run_simple" | "create_and_run_ls")
    [[ -f "${TARGET_SCRIPTS[$current_subtask]}" && -x "${TARGET_SCRIPTS[$current_subtask]}" ]] && completed=1
    ;;
  esac

  if [[ "$completed" -eq 1 ]]; then
    print_separator
    echo "🎉 Subtask completed!"
    mark_subtask_completed "$CURRENT_TASK_ID" "$((CURRENT_SUBTASK_INDEX + 1))"
    show_progress

    local subtask_count
    case "$CURRENT_TASK_ID" in
    1) subtask_count=${#SUBTASKS_NAV[@]} ;;
    2) subtask_count=${#SUBTASKS_CREATE[@]} ;;
    3) subtask_count=${#SUBTASKS_PERMISSIONS[@]} ;;
    4) subtask_count=${#SUBTASKS_SCRIPTS[@]} ;;
    esac

    ((CURRENT_SUBTASK_INDEX++))
    if [[ "$CURRENT_SUBTASK_INDEX" -lt "$subtask_count" ]]; then
      cd "$GAME_DIR" || exit
      explain_task
    else
      echo "All subtasks completed! Returning to main menu."
      CURRENT_TASK_ID=""
      CURRENT_SUBTASK_INDEX=-1
      cd "$GAME_DIR" || exit
      main_menu
    fi
    print_separator
  fi
}

is_task_completed() {
  local task_id=$1
  local subtasks
  case "$task_id" in
  1) subtasks=("${SUBTASKS_NAV[@]}") ;;
  2) subtasks=("${SUBTASKS_CREATE[@]}") ;;
  3) subtasks=("${SUBTASKS_PERMISSIONS[@]}") ;;
  4) subtasks=("${SUBTASKS_SCRIPTS[@]}") ;;
  esac

  local i
  for i in "${!subtasks[@]}"; do
    sub_num=$((i + 1))
    line="#   SUBTASK ${sub_num}: ${subtasks[i]} [✔]"
    if ! grep -qF "$line" "$SCRIPT_ABS_PATH"; then
      return 1 # At least one subtask is incomplete
    fi
  done
  return 0 # All subtasks complete
}

# ==============================================================================
# Menu
# ==============================================================================
main_menu() {
  print_separator
  echo "Choose a skill to practice:"
  local i
  for i in "${!TASKS[@]}"; do
    task_num=$((i + 1))
    if is_task_completed "$task_num"; then
      status="[✔]"
    else
      status="[ ]"
    fi
    echo "$status $task_num. ${TASKS[$i]}"
  done
  echo "------------------------------------------------------------------------------"
  echo "Type 'quit' to exit the game."
  echo "Type 'start <number>' to begin a task."
  echo "Type 'progress' to see progress."
  echo "Type 'help' for a list of special commands."
  print_separator
}

# ==============================================================================
# Main Game Loop
# ==============================================================================
trap cleanup EXIT
setup_game
main_menu

while true; do
  printf "%s" "$GAME_PROMPT"
  read -e -r command

  case "$command" in
  "quit" | "exit") break ;;
  "help") main_menu ;;
  "progress") show_progress ;;
  "start "*)
    task_num=$(echo "$command" | awk '{print $2}')
    if [[ "$task_num" =~ ^[1-4]$ ]]; then
      CURRENT_TASK_ID="$task_num"
      CURRENT_SUBTASK_INDEX=0
      cd "$GAME_DIR" || exit
      explain_task
    else
      echo "Invalid task number. Choose 1-4."
    fi
    ;;
  "info")
    if [[ -z "$CURRENT_TASK_ID" ]]; then show_instructions "0"; else show_instructions "$CURRENT_TASK_ID"; fi
    ;;
  "skip")
    if [[ "$CURRENT_TASK_ID" ]]; then
      case "$CURRENT_TASK_ID" in
      1) subtask_count=${#SUBTASKS_NAV[@]} ;;
      2) subtask_count=${#SUBTASKS_CREATE[@]} ;;
      3) subtask_count=${#SUBTASKS_PERMISSIONS[@]} ;;
      4) subtask_count=${#SUBTASKS_SCRIPTS[@]} ;;
      esac
      ((CURRENT_SUBTASK_INDEX++))
      if [[ "$CURRENT_SUBTASK_INDEX" -lt "$subtask_count" ]]; then
        cd "$GAME_DIR" || exit
        explain_task
      else
        CURRENT_TASK_ID=""
        CURRENT_SUBTASK_INDEX=-1
        main_menu
      fi
    else
      echo "No task to skip."
    fi
    ;;
  "re-explain")
    explain_task
    ;;
  "quit_task")
    CURRENT_TASK_ID=""
    CURRENT_SUBTASK_INDEX=-1
    main_menu
    ;;
  *)
    eval "$command"
    check_task_completion
    ;;
  esac
done

exit 0
