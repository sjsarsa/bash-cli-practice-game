#!/bin/bash

# ======================================================================
# Progress Tracking (auto-updated by game)
# ======================================================================
# SKILL 1: Navigating the filesystem
#   TASK 1: working_dir [ ]
#   TASK 2: go_to_subdir [ ]
#   TASK 3: find_file [ ]
#   TASK 4: return_to_root [ ]
# SKILL 2: Managing files and folders
#   TASK 1: create_empty_file [ ]
#   TASK 2: create_dir_and_file [ ]
#   TASK 3: create_file_with_text [ ]
#   TASK 4: delete_file_and_dir [ ]
#   TASK 5: delete_recursively [ ]  # add check that we are in the game dir
#   TASK 6: copy_file [ ]
#   TASK 8: move [ ]
#   TASK 7: copy_recursively [ ]
# SKILL 3: Modifying file and folder permissions
#   TASK 1: make_executable [ ]
#   TASK 2: set_owner_permissions [ ]
# SKILL 4: Writing and executing simple scripts
#   TASK 1: create_and_run_simple [ ]
#   TASK 2: create_and_run_ls [ ]
#   TASK 3: echo and redirect [ ]
# SKILL 5: Using pipes
#   TASK 2: pipes
#   TASK 3: pipes

# ======================================================================

# ======================================================================
# Global Variables
# ======================================================================
GAME_DIR=""
SCRIPT_ABS_PATH=$(realpath "$0")
CURRENT_SKILL_ID=""
CURRENT_TASK_INDEX=-1
GAME_PROMPT="[CMD_ADVENTURE] > "
LATEST_COMMAND_OUTPUT=""

# Randomized targets
declare -A TARGET_DIRS
declare -A TARGET_FILES
declare -A TARGET_SCRIPTS

declare -a SKILLS=(
)

# Revert to hard coding if dynamic reading fails on e.g. Git Bash
# Read dynamically from task definition comments below with grep
task_lines=$(grep -E '^# SKILL [0-9]+ - (\w+\s*)+$' $SCRIPT_ABS_PATH)
readarray -t SKILLS < <(echo "$task_lines" | sed -E 's|^# SKILL [0-9]+ - (.+)$|\1|')
num_tasks=${#SKILLS[@]}

for i in $(seq 1 "$num_tasks"); do
  declare -a "SKILL_${i}_TASKS=()"
done

for i in $(seq 1 "$num_tasks"); do
  # Read tasks for this task
  task_lines=$(grep -E "^# SKILL $i - TASK [0-9] - (.+)$" "$SCRIPT_ABS_PATH" | sed -E "s|^# SKILL $i - TASK [0-9] - (.+)$|\1|")
  while IFS= read -r line; do
    eval "SKILL_${i}_TASKS+=(\"$line\")"
  done <<<"$task_lines"
done

# echo "Detected ${#SKILLS[@]} tasks from script comments."
# echo "Skills:"
# for i in "${!SKILLS[@]}"; do
#   substarts_var="SKILL_$((i + 1))_TASKS[@]"
#   echo "  $((i + 1)). ${SKILLS[$i]}"
#   echo "    tasks:"
#   echo "    ----------------"
#   for task in "${!substarts_var}"; do
#     echo "      - $task"
#   done
# done

# ======================================================================
# Utility / UI
# ======================================================================
print_separator() {
  echo ""
  echo "=============================================================================="
  echo ""
}

print_separator_thin() {
  echo ""
  echo "------------------------------------------------------------------------------"
  echo ""
}

# Mark task in this script file as completed (updates the header lines)
mark_task_completed() {
  local task_id=$1 sub_idx=$2 sub_name
  sub_name=$(get_current_task_name "$task_id" $((sub_idx - 1)))
  # Replace the specific task header line: [ ] -> [✔]
  sed -i "s|#   TASK ${sub_idx}: ${sub_name} \[ \]|#   TASK ${sub_idx}: ${sub_name} [✔]|" "$SCRIPT_ABS_PATH"
}

show_progress() {
  print_separator
  if [[ -z "$CURRENT_SKILL_ID" ]]; then
    echo "Skill Progress:"
    local i
    for i in "${!SKILLS[@]}"; do
      task_num=$((i + 1))
      if is_task_completed "$task_num"; then status="[✔]"; else status="[ ]"; fi
      echo "$status ${SKILLS[$i]}"
    done
  else
    echo "task Progress for ${SKILLS[$((CURRENT_SKILL_ID - 1))]}:"
    local tasks
    declare -n tasks="SKILL_${CURRENT_SKILL_ID}_TASKS"
    for i in "${!tasks[@]}"; do
      sub_num=$((i + 1))
      line="#   TASK ${sub_num}: ${tasks[i]} [✔]"
      if grep -qF "$line" "$SCRIPT_ABS_PATH"; then status="[✔]"; else status="[ ]"; fi
      echo "$status ${tasks[i]}"
    done
  fi
  print_separator
}

is_task_completed() {
  local task_id=$1
  local tasks
  declare -n tasks="SKILL_${task_id}_TASKS"

  local i
  for i in "${!tasks[@]}"; do
    sub_num=$((i + 1))
    line="#   TASK ${sub_num}: ${tasks[i]} [✔]"
    if ! grep -qF "$line" "$SCRIPT_ABS_PATH"; then
      return 1
    fi
  done
  return 0
}

# Utility to check if any path arguments in a command are outside the allowed base directory
outside_paths() {
  local base_dir="$1" # The "allowed" parent directory
  shift               # Remaining arguments are the command + args

  # Canonicalize base_dir
  base_dir="$(realpath -m "$base_dir")"

  for arg in "$@"; do
    # Detect arguments that look like paths (absolute or relative)
    if [[ "$arg" == /* || "$arg" == .* || "$arg" == */* ]]; then
      # Try to resolve the argument into a canonical absolute path
      if realpath_arg=$(realpath -m "$arg" 2>/dev/null); then
        # Check if it is under the allowed base_dir
        case "$realpath_arg" in
        "$base_dir"/*) ;; # OK (inside base_dir)
        "$base_dir") ;;   # OK (exactly base_dir)
        *)
          return 0 # Found a path outside base_dir
          ;;
        esac
      else
        # Skip if realpath fails
        continue
      fi
    fi
  done
  return 1 # No unallowed paths found
}

# ======================================================================
# Game Setup / Cleanup
# ======================================================================
setup_game() {
  clear
  print_separator
  echo "Welcome to the Bash Command Line Interactive Practice! 🚀"
  echo ""

  GAME_DIR=$(mktemp -d -t cmd-adventure-XXXXXXXX)
  if [[ ! -d "$GAME_DIR" ]]; then
    echo "Error: Could not create temporary directory. Exiting."
    exit 1
  fi
  HISTFILE=$(mktemp)
  HISTSIZE=1000
  HISTFILESIZE=2000

  echo "Game environment created at: $GAME_DIR"
  cd "$GAME_DIR" || exit
}

# shellcheck disable=SC2329 # called in trap
cleanup() {
  print_separator
  echo "Cleaning up game environment..."
  cd /tmp || exit
  rm -rf "$GAME_DIR"
  echo "Done. Thanks for playing! 👋"
  print_separator
}

# ==============================================================================
# Course-like Instructions
# ==============================================================================

# Colors
BOLD_YELLOW="\e[1;33m"
CYAN="\e[36m"
DIM="\e[2m"
RESET="\e[0m"

prompt_enter_or_q() {
  echo -ne "Press Enter to continue or q to exit..."
  read -r -n 1 -s key
  if [[ "$key" == "q" ]]; then
    echo ""
    return 1
  fi
  echo -e "\r\033[K"
  return 0
}

show_instructions() {
  print_separator
  case "$1" in
  "0")
    echo "General Command Line Instructions:

The command line is a text-based interface to interact with your computer.
You can navigate the filesystem, manage files and directories, and run
programs.

The basic structure of a command is the name of the command followed
by options (usually prefixed with '-' or '--') and arguments.
For example, in the command 'ls -1 . ..', 'ls' is the command, '-l' is an
option, and '.' and '..' are arguments.

Importantly, the command and its options and arguments are separated by
spaces. If we'd write 'ls-1', it would be interpreted as a single command
name, which likely doesn't exist. Similarly, the command 'ls -1 .,..' would
have a single argument '..,.'
"
    ;;
  "1")
    echo -e "
Navigating the Filesystem:

Nearly all filesystems today are hierarchical, meaning that files are organised into directories in tree-like structure. Such as:

${CYAN}/
├── home
│   └── user
│       ├── docs
│       ├── pics
│       └── music
└── system
    └── log
        ├── syslog
        └── auth.log${RESET}

We can move around and explore the file systems contents quickly using only a few command line commands."

    prompt_enter_or_q || return

    echo -e "A path in a filesystem specifies the location of a file or directory in the filesystem. It can be absolute (starting from the root, e.g., ${CYAN}/home/user/docs${RESET}) or relative (starting from the current working directory, e.g., ${CYAN}../docs/file.txt${RESET}). In Unix-like systems, paths use forward slashes (${CYAN}/${RESET}) to separate directories. In Windows, backslash (${CYAN}\\\\${RESET}) is the default path separator, although many Windows command line tools (such as PowerShell and Git Bash) accept forward slashes.

Special directory names:
  - The root of the filesystem is represented by a single forward slash (${CYAN}/${RESET}).
  - Your home directory is represented by a tilde (${CYAN}~${RESET}).
  - A single dot (${CYAN}.${RESET}) represents the current directory.
  - A double dot (${CYAN}..${RESET}) represents the parent directory (one level up)."

    prompt_enter_or_q || return

    echo -e "Common commands for navigation:
  - ${BOLD_YELLOW}pwd${RESET} (Print Working Directory): Shows you where you are.

  - ${BOLD_YELLOW}ls${RESET} (List): Shows what files and folders are in your current location.
      • Use ${CYAN}ls -1${RESET} to print one entry per line.
      • Use ${CYAN}ls -a${RESET} to include hidden files.
      • Options can be combined, e.g., ${CYAN}ls -1a${RESET}.

  - ${BOLD_YELLOW}cd [dir]${RESET} (Change Directory): Moves you to another folder specified by the given argument.
      • ${CYAN}cd ..${RESET} moves you up one level.
      • ${CYAN}cd ../..${RESET} moves you up two levels.
      • ${CYAN}cd /${RESET} takes you to the root directory.
      • Just ${CYAN}cd${RESET} or ${CYAN}cd ~${RESET} moves you to your home directory.
        ${DIM}(Don't try that within the game since you will exit the game root directory.
        To come back, restart the task with ${CYAN}start 1${DIM}.${RESET})

  - ${BOLD_YELLOW}tree${RESET} (tree.com in Windows): Displays the directory structure in a tree-like format.
      • Great for getting a full overview.
      • ${DIM}NOTE: This command may not be installed by default on all systems.${RESET}
          - On Ubuntu/Debian: ${CYAN}sudo apt install tree${RESET}
          - On MacOS: ${CYAN}brew install tree${RESET}
          - On Windows Git Bash: not available, instead use Windows' ${CYAN}tree.com //f${RESET}
            (${CYAN}//f${RESET} shows files in the tree view).
  "
    ;;
  "2")
    echo "Managing Files and Folders:
You can create and manage files and directories directly from the command line.
  - **mkdir** (Make Directory): Creates a new, empty folder. Use 'mkdir foldername'.
  - **touch**: Creates a new, empty file. It's often used to update the timestamp of an existing file but works great for creating new ones.
  - **echo >**: The 'echo' command prints text. The '>' symbol redirects that text into a file, creating it if it doesn't exist or overwriting it if it does.
  - **rm** (Remove): Deletes files. Use 'rm filename'. Be careful, this is permanent!
  - **rmdir**: Deletes empty directories."
    ;;
  "3")
    echo "Modifying File and Folder Permissions:
Every file and folder has permissions that control who can read, write, or execute it. This is crucial for security.
  - **chmod** (Change Mode): Changes file permissions. Permissions are represented in a three-digit octal number (e.g., 755).
    - The first digit is for the **owner**.
    - The second is for the **group**.
    - The third is for **others**.
    Each digit is a sum of: **4** (read), **2** (write), and **1** (execute). For example, 7 means '4+2+1' (read, write, execute).
    'chmod +x filename' is a quick way to add execute permissions for everyone."
    ;;
  "4")
    echo "Writing and Executing Simple Scripts:
A shell script is a file containing a series of commands. They're used to automate repetitive tasks.
  - **Creating a script**: Use 'echo >' or a text editor to write commands into a file.
  - **Making it executable**: You must give a script execute permissions using 'chmod +x scriptname.sh'.
  - **Running a script**: To run an executable script, you need to specify its path. If it's in the current directory, use './scriptname.sh'."
    ;;
  esac
  print_separator
}

# ======================================================================
# task helpers
# ======================================================================

# Helper to fetch task name for the current task & index
get_current_task_name() {
  local tid=$1 idx=$2
  local tasks
  declare -n tasks="SKILL_${tid}_TASKS"
  if [[ "$idx" -ge 0 && "$idx" -lt "${#tasks[@]}" ]]; then
    echo "${tasks[$idx]}"
  else
    echo ""
  fi
}

get_task_count_for_task() {
  local tid=$1
  local tasks
  declare -n tasks="SKILL_${tid}_TASKS"
  echo "${#tasks[@]}"
}

# Run (explain/setup) current task
run_current_task() {
  local name
  name=$(get_current_task_name "$CURRENT_SKILL_ID" "$CURRENT_TASK_INDEX")
  if [[ -z "$name" ]]; then
    echo "No task available. Returning to main menu."
    CURRENT_SKILL_ID=""
    CURRENT_TASK_INDEX=-1
    main_menu
    return
  fi
  clear
  show_progress
  echo "General task commands:"
  echo "  info       - Show general instructions for the skill to practice"
  echo "  skip       - Skip this task and move to the next"
  echo "  task-info  - Re-run the task explanation/setup"
  echo "  main-menu  - Quit the current task and return to main menu"
  echo "  quit       - Exit the game"
  print_separator_thin
  echo "task: $name"
  # ensure we are in game dir
  cd "$GAME_DIR" || exit
  "setup_$name"
  "explain_$name"
  echo "(When you're ready, run shell commands to complete the task.)"
  echo ""
}

# Check the currently active task and advance if completed
check_current_task() {
  if [[ -z "$CURRENT_SKILL_ID" || "$CURRENT_TASK_INDEX" -lt 0 ]]; then
    return
  fi
  local name
  name=$(get_current_task_name "$CURRENT_SKILL_ID" "$CURRENT_TASK_INDEX")
  if [[ -z "$name" ]]; then return; fi

  if "check_$name"; then
    # mark in script
    mark_task_completed "$CURRENT_SKILL_ID" $((CURRENT_TASK_INDEX + 1))
    echo "🎉 task '$name' completed!"

    # prompt for enter to continue
    read -rp "Press Enter to continue..."
    echo "---"

    # advance to next task
    local total
    total=$(get_task_count_for_task "$CURRENT_SKILL_ID")
    CURRENT_TASK_INDEX=$((CURRENT_TASK_INDEX + 1))
    if [[ "$CURRENT_TASK_INDEX" -lt "$total" ]]; then
      # prepare next task
      cd "$GAME_DIR" || exit
      run_current_task
    else
      echo "All tasks for '${SKILLS[$((CURRENT_SKILL_ID - 1))]}' completed!"
      CURRENT_SKILL_ID=""
      CURRENT_TASK_INDEX=-1
      main_menu
    fi
  fi
}

# Helper for building a haystack for finding files
# shellcheck disable=SC2329
make_haystack() {
  local HAYSTACK_DIR=${1:-"./haystack"} # default dir unless provided
  local NUM_TOP_DIRS=${2:-20}           # default top-level dirs
  local MAX_DEPTH=${3:-5}               # max depth
  local FILES_PER_DIR=${4:-5}           # files per dir

  # Start fresh
  rm -rf "$HAYSTACK_DIR"
  mkdir -p "$HAYSTACK_DIR"
  echo "Building randomized haystack in $HAYSTACK_DIR ..."

  # Recursive helper function
  create_random_tree() {
    local DIR=$1
    local DEPTH=$2

    # Create random files in this directory
    local NUM_FILES=$((RANDOM % FILES_PER_DIR + 1))
    for f in $(seq 1 "$NUM_FILES"); do
      EXTENSIONS=(txt log md conf csv dat)
      EXT=${EXTENSIONS[$RANDOM % ${#EXTENSIONS[@]}]}
      FILENAME="file$(printf "%03d" $f)_$(tr -dc 'a-z0-9' </dev/urandom | head -c 5).$EXT"
      echo "This is $FILENAME inside $DIR" >"$DIR/$FILENAME"
    done

    # Maybe create subdirectories (stop if max depth)
    if [ "$DEPTH" -lt "$MAX_DEPTH" ]; then
      local NUM_SUBDIRS=$((RANDOM % 4)) # up to 3 subdirs
      for s in $(seq 1 $NUM_SUBDIRS); do
        SUBDIR="$DIR/subdir$(tr -dc 'a-z0-9' </dev/urandom | head -c 3)"
        mkdir -p "$SUBDIR"
        create_random_tree "$SUBDIR" $((DEPTH + 1))
      done
    fi
  }

  # Build the top-level structure
  for d in $(seq 1 $NUM_TOP_DIRS); do
    DIR="$HAYSTACK_DIR/dir$d"
    mkdir -p "$DIR"
    create_random_tree "$DIR" 1
  done

  # Plant a "needle" files at random depths
  local NEEDLE_DIR
  NEEDLE_DIR="$HAYSTACK_DIR/dir$(shuf -i 1-$NUM_TOP_DIRS -n 1)/$(find "$HAYSTACK_DIR/dir$(shuf -i 1-$NUM_TOP_DIRS -n 1)" -type d | shuf -n 1)"
  echo "SECRET_PASSWORD=opensesame" >"$NEEDLE_DIR/needle.txt"
}

# ======================================================================
# task Implementations (each task has a setup and a check)
# Each setup should prepare the environment and tell the user what to do.
# Each check should return 0 when the user's actions satisfy the task.
# ======================================================================

##############################################
# SKILL 1 - Navigation
##############################################

# ============================================
# SKILL 1 - TASK 1 - working_dir
# ============================================
# shellcheck disable=SC2329
setup_working_dir() {
  random_suffix=$(shuf -i 100-999 -n 1)
  random_suffix2=$(shuf -i 100-999 -n 1)
  TARGET_DIRS[working_dir]="data_$random_suffix/users/user$random_suffix2"

  mkdir -p "$GAME_DIR/${TARGET_DIRS[working_dir]}"
  cd "$GAME_DIR/${TARGET_DIRS[working_dir]}" || exit
}

# shellcheck disable=SC2329
explain_working_dir() {
  echo "You are in the game root directory.
Enter the command that shows the directory you are currently in (hint: try
entering the command 'info')."
}

# shellcheck disable=SC2329
check_working_dir() {
  [[ "$LATEST_COMMAND_OUTPUT" == "$GAME_DIR/${TARGET_DIRS[working_dir]}" ]]
}

# ============================================
# SKILL 1 - TASK 2 - go_to_subdir
# ============================================
# shellcheck disable=SC2329
setup_go_to_subdir() {
  TARGET_DIRS[go_to_subdir]="data_$(shuf -i 100-999 -n 1)"
  mkdir -p "${TARGET_DIRS[go_to_subdir]}/docs/archive"
}

# shellcheck disable=SC2329
explain_go_to_subdir() {
  echo "Go into the directory '${TARGET_DIRS[go_to_subdir]}' (use cd).
The directory was created under the game root."
}

# shellcheck disable=SC2329
check_go_to_subdir() {
  [[ "$(basename "$PWD")" == "${TARGET_DIRS[go_to_subdir]}" ]]
}

# ============================================
# SKILL 1 - TASK 3 - find_file
# ============================================
# shellcheck disable=SC2329
setup_find_file() {
  TARGET_DIRS[find_file]="data_$(shuf -i 100-999 -n 1)"
  mkdir -p "${TARGET_DIRS[find_file]}/docs/archive"
  TARGET_FILES[find_file]="secret_file.txt"
  touch "${TARGET_DIRS[find_file]}/docs/archive/${TARGET_FILES[find_file]}"
}

# shellcheck disable=SC2329
explain_find_file() {
  echo "A file named '${TARGET_FILES[find_file]}' is placed inside '${TARGET_DIRS[find_file]}/docs/archive'.
Find and cd into the directory containing it."
}

# shellcheck disable=SC2329
check_find_file() {
  local expected_dir="$GAME_DIR/${TARGET_DIRS[find_file]}/docs/archive"
  [[ "$PWD" == "$expected_dir" && -f "${TARGET_FILES[find_file]}" ]]
}

# ============================================
# SKILL 1 - TASK 4 - return_to_root
# ============================================
# shellcheck disable=SC2329
setup_return_to_root() {
  TARGET_DIRS[return_to_root]="data_$(shuf -i 100-999 -n 1)"
  mkdir -p "${TARGET_DIRS[return_to_root]}/docs/archive"
  cd "${TARGET_DIRS[return_to_root]}/docs/archive" || exit
}

# shellcheck disable=SC2329
explain_return_to_root() {
  echo "You are now deep inside a directory tree. Return to the game root directory ($GAME_DIR)."
}

# shellcheck disable=SC2329
check_return_to_root() {
  [[ "$PWD" == "$GAME_DIR" ]]
}

# ============================================
# SKILL 1 - TASK 5 - find_file2
# ============================================
# shellcheck disable=SC2329
setup_find_file2() {
  TARGET_DIRS[find_file2]=$(make_haystack "$GAME_DIR/haystack_$(shuf -i 100-999 -n 1)")
}

# shellcheck disable=SC2329
explain_find_file2() {
  echo "A file named 'needle.txt' has been hidden somewhere inside the directory tree '$GAME_DIR/haystack_xxx' (where xxx is a random number).
Navigate to the directory containing the file. Hint: Use the 'find' command to locate it."
}

# shellcheck disable=SC2329
check_find_file2() {
  local expected_file="needle.txt"
  [[ "$PWD" == *"${TARGET_DIRS[find_file2]}"* && -f "$expected_file" ]]
}

##############################################
# SKILL 2 - Managing files and folders
##############################################

# ============================================
# SKILL 2 - TASK 1 - create_empty_file
# ============================================
# shellcheck disable=SC2329
setup_create_empty_file() {
  TARGET_FILES[create_empty_file]="report_$(shuf -i 100-999 -n 1).txt"
}

# shellcheck disable=SC2329
explain_create_empty_file() {
  echo "Create an empty file named '${TARGET_FILES[create_empty_file]}' in the game root."
}

# shellcheck disable=SC2329
check_create_empty_file() {
  [[ -f "$GAME_DIR/${TARGET_FILES[create_empty_file]}" ]]
}

# ============================================
# SKILL 2 - TASK 2 - create_file_with_text
# ============================================
# shellcheck disable=SC2329
setup_create_file_with_text() {
  TARGET_FILES[create_file_with_text]="hello.txt"
}

# shellcheck disable=SC2329
explain_create_file_with_text() {
  echo "Create '${TARGET_FILES[create_file_with_text]}' in the current directory containing the text: Hello my file!.
Tip: Use echo with redirection (>) or open a text editor with the filename as an argument."
}

# shellcheck disable=SC2329
check_create_file_with_text() {
  [[ -f "$GAME_DIR/${TARGET_FILES[create_file_with_text]}" && "$(cat "$GAME_DIR/${TARGET_FILES[create_file_with_text]}")" == "Hello my file!" ]]
}

# ============================================
# SKILL 2 - TASK 3 - view_file_content
# ============================================
# shellcheck disable=SC2329
setup_view_file_content() {
  TARGET_FILES[create_empty_file]="report_$(shuf -i 100-999 -n 1).txt"
}

# shellcheck disable=SC2329
explain_view_file_content() {
  echo "View the contents of the file '${TARGET_FILES[create_empty_file]}' in the game root.
Hint: Use the 'cat' command."
}

# shellcheck disable=SC2329
check_view_file_content() {
  [[ -f "$GAME_DIR/${TARGET_FILES[create_empty_file]}" ]]
}

# ============================================
# SKILL 2 - TASK 4 - create_dir_and_file
# ============================================
# shellcheck disable=SC2329
setup_create_dir_and_file() {
  TARGET_DIRS[create_dir_and_file]="project_$(shuf -i 100-999 -n 1)"
  TARGET_FILES[create_dir_and_file]="notes.txt"
}

# shellcheck disable=SC2329
explain_create_dir_and_file() {
  echo "Create directory '${TARGET_DIRS[create_dir_and_file]}' in the game root and a file named 'notes.txt' inside it."
}

# shellcheck disable=SC2329
check_create_dir_and_file() {
  [[ -f "$GAME_DIR/${TARGET_DIRS[create_dir_and_file]}/${TARGET_FILES[create_dir_and_file]}" ]]
}

# ============================================
# SKILL 2 - TASK 5 - remove_file
# ============================================
# shellcheck disable=SC2329
setup_remove_file() {
  TARGET_DIRS[remove_file]="project_$(shuf -i 100-999 -n 1)"
  TARGET_FILES[remove_file]="notes.txt"
}

# shellcheck disable=SC2329
explain_remove_file() {
  echo "Delete the file '${TARGET_DIRS[remove_file]}/${TARGET_FILES[remove_file]}' without deleting the directory."
}

# shellcheck disable=SC2329
check_remove_file() {
  [[ ! -f "$GAME_DIR/${TARGET_DIRS[remove_file]}/${TARGET_FILES[remove_file]}" && -d "$GAME_DIR/${TARGET_DIRS[remove_file]}" ]]
}

##############################################
# SKILL 3 - Permissions
##############################################

# ============================================
# SKILL 3 - TASK 1 - make_executable
# ============================================
# shellcheck disable=SC2329
setup_make_executable() {
  TARGET_DIRS[make_executable]="secure_vault_$(shuf -i 100-999 -n 1)"
  mkdir -p "${TARGET_DIRS[make_executable]}"
  TARGET_FILES[make_executable]="${TARGET_DIRS[make_executable]}/locked.txt"
  touch "${TARGET_FILES[make_executable]}"
  chmod 600 "${TARGET_FILES[make_executable]}"
}

# shellcheck disable=SC2329
explain_make_executable() {
  echo "Make '${TARGET_FILES[make_executable]}' executable for everyone (hint: chmod +x).
Current mode has been set to 600 to make the change obvious."
}

# shellcheck disable=SC2329
check_make_executable() {
  [[ -x "$GAME_DIR/${TARGET_FILES[make_executable]}" ]] || [[ -x "${TARGET_FILES[make_executable]}" ]]
}

# ============================================
# SKILL 3 - TASK 2 - set_owner_permissions
# ============================================
# shellcheck disable=SC2329
setup_set_owner_permissions() {
  TARGET_DIRS[set_owner_permissions]="secure_vault_$(shuf -i 100-999 -n 1)"
  mkdir -p "${TARGET_DIRS[set_owner_permissions]}"
  TARGET_FILES[set_owner_permissions]="${TARGET_DIRS[set_owner_permissions]}/secret.sh"
  touch "${TARGET_FILES[set_owner_permissions]}"
  chmod 755 "${TARGET_FILES[set_owner_permissions]}"
}

# shellcheck disable=SC2329
explain_set_owner_permissions() {
  echo "Change permissions of '${TARGET_FILES[set_owner_permissions]}' to 700 (owner only)."
}

# shellcheck disable=SC2329
check_set_owner_permissions() {
  [[ "$(stat -c %a "$GAME_DIR/${TARGET_FILES[set_owner_permissions]}")" == "700" ]]
}

##############################################
# SKILL 4 - Scripts
##############################################

# ============================================
# SKILL 4 - TASK 1 - create_and_run_simple
# ============================================
# shellcheck disable=SC2329
setup_create_and_run_simple() {
  TARGET_SCRIPTS[create_and_run_simple]="myscript_$(shuf -i 100-999 -n 1).sh"
}

# shellcheck disable=SC2329
explain_create_and_run_simple() {
  echo "Create script '${TARGET_SCRIPTS[create_and_run_simple]}' that prints: Hello from script!
Make it executable and run it."
}

# shellcheck disable=SC2329
check_create_and_run_simple() {
  [[ -f "$GAME_DIR/${TARGET_SCRIPTS[create_and_run_simple]}" && -x "$GAME_DIR/${TARGET_SCRIPTS[create_and_run_simple]}" ]]
}

# ============================================
# SKILL 4 - TASK 2 - create_and_run_ls
# ============================================
# shellcheck disable=SC2329
setup_create_and_run_ls() {
  TARGET_SCRIPTS[create_and_run_ls]="list_files_$(shuf -i 100-999 -n 1).sh"
}

# shellcheck disable=SC2329
explain_create_and_run_ls() {
  echo "Create script '${TARGET_SCRIPTS[create_and_run_ls]}' that lists files (e.g. ls -la).
Make it executable and run it."
}

# shellcheck disable=SC2329
check_create_and_run_ls() {
  [[ -f "$GAME_DIR/${TARGET_SCRIPTS[create_and_run_ls]}" && -x "$GAME_DIR/${TARGET_SCRIPTS[create_and_run_ls]}" ]]
}

# ======================================================================
# Menu / Loop
# ======================================================================
main_menu() {
  print_separator
  echo "Choose a skill to practice:"
  local i
  for i in "${!SKILLS[@]}"; do
    task_num=$((i + 1))
    if is_task_completed "$task_num"; then status="[✔]"; else status="[ ]"; fi
    echo "$status $task_num. ${SKILLS[$i]}"
  done
  print_separator_thin
  echo "Type '<skill_number>', e.g. '1' to begin practicing a skill."
  echo "Type 'info' to see general instructions."
  echo "Type 'help' to see all game commands."
  echo "Type 'quit' to exit the game."
  echo ""
  echo "Press Enter to execute the typed command."
  print_separator
}

help() {
  echo "Available commands:"
  echo "  <number>        - Start practicing a skill (1-$task_num) (only in main menu)"
  echo "  info [<number>] - Show skill instructions (1-$task_num) or general command line instructions (0)
                    if no number is given, shows instructions for current skill to practice"
  echo "  progress        - Show current progress"
  echo "  main-menu       - Go to main menu (will abandon current task if active)"
  echo "  help            - Show this help message"
  echo "  quit            - Exit the game"
  echo ""
  echo "In addition while completing a task:"
  echo "  skip            - Skip the current task"
  echo "  task-info       - Show the explanation that was shown when starting the task"
  print_separator_thin
}

trap cleanup EXIT
setup_game
main_menu

while true; do

  # Prepare autocompletion for commands with dummy files
  commands="info progress main-menu help quit"
  task_commands="skip task-info"
  touch $commands
  [[ -n "$CURRENT_SKILL_ID" ]] && touch $task_commands

  # printf "%s" "$GAME_PROMPT"
  read -e -r -p "$GAME_PROMPT" command

  case "$command" in
  quit | exit)
    break
    ;;
  help)
    help
    ;;
  progress)
    show_progress
    ;;
  info\ [1-4])
    if [[ "$command" =~ ^info[[:space:]]+([1-4])$ ]]; then
      skill_id="${BASH_REMATCH[1]}"
      show_instructions "$skill_id"
    else
      if [[ -z "$CURRENT_SKILL_ID" ]]; then
        show_instructions "0"
      else
        show_instructions "$CURRENT_SKILL_ID"
      fi
    fi
    ;;
  info)
    if [[ -z "$CURRENT_SKILL_ID" ]]; then show_instructions "0"; else show_instructions "$CURRENT_SKILL_ID"; fi
    ;;
  [1-4])
    if [[ "$command" =~ ^[1-4]$ ]]; then
      CURRENT_SKILL_ID="$command"
      CURRENT_TASK_INDEX=0
      cd "$GAME_DIR" || exit
      run_current_task
    else
      echo "Invalid task number. Choose 1-4."
    fi
    ;;
  skip)
    if [[ -n "$CURRENT_SKILL_ID" ]]; then
      total=$(get_task_count_for_task "$CURRENT_SKILL_ID")
      CURRENT_TASK_INDEX=$((CURRENT_TASK_INDEX + 1))
      if [[ "$CURRENT_TASK_INDEX" -lt "$total" ]]; then
        run_current_task
      else
        echo "All tasks completed for this task. Returning to main menu."
        CURRENT_SKILL_ID=""
        CURRENT_TASK_INDEX=-1
        clear
        main_menu
      fi
    else
      echo "No active task to skip."
    fi
    ;;
  task-info)
    name=$(get_current_task_name "$CURRENT_SKILL_ID" "$CURRENT_TASK_INDEX")
    if [[ -z "$name" ]]; then
      echo "No active task."
    else
      "explain_$name"
    fi
    ;;
  main-menu | quit-task)
    CURRENT_SKILL_ID=""
    CURRENT_TASK_INDEX=-1
    clear
    main_menu
    ;;
  *)
    # Evaluate arbitrary shell commands in the game environment.
    if [[ -n "$command" ]]; then
      tmp_output_file=$(mktemp)
      # If not in game dir do not eval but warn the user to cd into the game dir befor continuing
      if [[ "$PWD" != "$GAME_DIR"* ]]; then
        echo "You have left the game directory. Please 'cd $GAME_DIR' to return before continuing."
        continue
      fi

      # If any path arguments lead outside the game dir, do not eval but warn the user
      if outside_paths "$GAME_DIR" $command; then
        echo "Error: One or more path arguments given to the command lead to outside the game directory. Quit the game if you want to work outside the game."
        continue
      fi

      # hide dummy autocompletion files
      tmp_dummyfile_dir=$(mktemp -d)
      mv $commands $task_commands "$tmp_dummyfile_dir/" >/dev/null 2>&1

      eval "$command" 2> >(sed -E "s|$0:\sline\s[0-9]+:\s||") >"$tmp_output_file"
      LATEST_COMMAND_OUTPUT=$(<"$tmp_output_file")
      if [[ -n "$LATEST_COMMAND_OUTPUT" ]]; then
        echo "$LATEST_COMMAND_OUTPUT"
      fi
      rm "$tmp_output_file"

      mv --update=none "$tmp_dummyfile_dir/"* . >/dev/null 2>&1
    fi
    # After running the user's command, check whether they've completed the active task.
    if [[ -n "$CURRENT_SKILL_ID" ]]; then
      check_current_task
    fi
    ;;
  esac

  history -s "$command"
  history -a

done

exit 0
