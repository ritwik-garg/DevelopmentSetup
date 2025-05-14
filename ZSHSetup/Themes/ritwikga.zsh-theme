# --- Asynchronous Version Functions ---
source "$ZSH/lib/async_prompt.zsh"
_my_python_version_worker() { local py_path py_version; if py_path=$(command which python3 2>/dev/null); then py_version=$("$py_path" -V 2>&1 | command awk '{print $2}'); elif py_path=$(command which python 2>/dev/null); then py_version=$("$py_path" -V 2>&1 | command awk '{print $2}'); fi; [[ -n "$py_version" ]] && echo -n "$py_version"; }
_omz_register_handler _my_python_version_worker
python_version() { if [[ -v _OMZ_ASYNC_OUTPUT[_my_python_version_worker] ]]; then echo -n "${_OMZ_ASYNC_OUTPUT[_my_python_version_worker]}"; else :; fi; }
_my_node_version_worker() { local node_path node_version; if node_path=$(command which node 2>/dev/null); then node_version=$("$node_path" -v 2>/dev/null); fi; [[ -n "$node_version" ]] && echo -n "$node_version"; }
_omz_register_handler _my_node_version_worker
node_version() { if [[ -v _OMZ_ASYNC_OUTPUT[_my_node_version_worker] ]]; then echo -n "${_OMZ_ASYNC_OUTPUT[_my_node_version_worker]}"; else :; fi; }

# --- Custom Git Parser Function (with Counts) ---
function my_git_status_parser_with_counts() {
  local git_output status_string line added_count=0 modified_count=0 deleted_count=0 renamed_count=0 copied_count=0 untracked_count=0 unmerged_count=0
  if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then return; fi
  git_output=$(command git status --porcelain 2>/dev/null); if [[ -z "$git_output" ]]; then return; fi
  while IFS= read -r line || [[ -n "$line" ]]; do local x_status=${line[1]} y_status=${line[2]}; case "$x_status$y_status" in A\ |A?|AM) ((added_count++)) ;; M\ |M?|MM) ((modified_count++)) ;; D\ |D?) ((deleted_count++)) ;; R\ |R?) ((renamed_count++)) ;; C\ |C?) ((copied_count++)) ;; \ M) ((modified_count++)) ;; \ D) ((deleted_count++)) ;; \?\?) ((untracked_count++)) ;; DD|AU|UD|UA|DU|AA|UU) ((unmerged_count++));; esac; done <<< "$git_output"
  status_string=""; local added_sym=${ZSH_THEME_GIT_PROMPT_ADDED:-'+'} modified_sym=${ZSH_THEME_GIT_PROMPT_MODIFIED:-'✭'} deleted_sym=${ZSH_THEME_GIT_PROMPT_DELETED:-'-'} renamed_sym=${ZSH_THEME_GIT_PROMPT_RENAMED:-'→'} copied_sym="C" unmerged_sym=${ZSH_THEME_GIT_PROMPT_UNMERGED:-'✘'} untracked_sym=${ZSH_THEME_GIT_PROMPT_UNTRACKED:-'?'}
  if [[ $added_count -gt 0 ]]; then status_string+="${added_sym}${added_count}"; fi; if [[ $modified_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${modified_sym}${modified_count}"; fi; if [[ $deleted_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${deleted_sym}${deleted_count}"; fi; if [[ $renamed_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${renamed_sym}${renamed_count}"; fi; if [[ $copied_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${copied_sym}${copied_count}"; fi; if [[ $unmerged_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${unmerged_sym}${unmerged_count}"; fi; if [[ $untracked_count -gt 0 ]]; then [[ -n "$status_string" ]] && status_string+=" "; status_string+="${untracked_sym}${untracked_count}"; fi
  [[ -n "$status_string" ]] && echo -n " ${status_string}"
}

# --- Custom Path Function ---
_my_custom_pwd() {
  setopt localoptions noksharrays; local logical_path=$(pwd -L) pwd_string prefix=""
  if [[ "$logical_path" == "$HOME" ]]; then pwd_string="~"; elif [[ "$logical_path" == "$HOME/"* ]]; then pwd_string="~${logical_path#$HOME}"; else pwd_string="$logical_path"; fi
  if [[ "$pwd_string" == "/" ]]; then echo -n "/"; return; fi; if [[ "$pwd_string" == "~" ]]; then echo -n "~"; return; fi
  if [[ "$pwd_string" == "~/"* ]]; then prefix="~/"; pwd_string="${pwd_string#\~\/}"; elif [[ "$pwd_string" == "/"* ]]; then prefix="/"; pwd_string="${pwd_string#/}"; fi
  local -a path_parts; if [[ -n "$pwd_string" ]]; then path_parts=("${(@s:/:)pwd_string}"); else path_parts=(); fi
  local short_path=""; local num_parts=${#path_parts[@]} current_part_index=1
  for part in "${path_parts[@]}"; do [[ -z "$part" ]] && continue; if [[ $current_part_index -lt $num_parts ]]; then short_path+="${part[1]}/"; else short_path+="${part}"; fi; ((current_part_index++)); done
  echo -n "${prefix}${short_path}"
}

# --- Git Prompt Configuration ---
ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[blue]%}:(%{$reset_color%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$fg_bold[blue]%})%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_ADDED="%{$fg[cyan]%}+"
ZSH_THEME_GIT_PROMPT_MODIFIED="%{$fg[yellow]%}✭"
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg[red]%}-"
ZSH_THEME_GIT_PROMPT_RENAMED="%{$fg[blue]%}→"
ZSH_THEME_GIT_PROMPT_UNMERGED="%{$fg[magenta]%}✘"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%{$fg[grey]%}?"
ZSH_THEME_GIT_PROMPT_STASHED="%{$fg[cyan]%}$"
# <<< Using symbols from user's last provided code
ZSH_THEME_GIT_PROMPT_AHEAD="%{$fg[blue]%}"    # User symbol for ahead
ZSH_THEME_GIT_PROMPT_BEHIND="%{$fg[blue]%}"   # User symbol for behind

# <<< NEW: Function to build the entire Git segment dynamically --- START ---
_my_build_git_prompt_segment() {
  # Check if we are inside a git repository FIRST
  if ! command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    return # Exit if not in a git repo
  fi

  # Define local variables used in this function
  local local_branch remote_branch branch_display git_segment stash_count stash_segment="" diff_segment="" status_segment=""

  # Get local branch name
  local_branch=$(command git rev-parse --abbrev-ref HEAD 2>/dev/null)
  # Check if an upstream branch is configured and get its name
  remote_branch=$(command git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null)

  # Construct branch display string & Get Ahead/Behind counts
  if [[ -n "$remote_branch" ]]; then
      branch_display="${local_branch}  ${remote_branch}" # User separator

      # Get Ahead/Behind counts logic
      local ahead_count behind_count diff_output
      diff_output=$(command git rev-list --count --left-right @{u}...HEAD 2>/dev/null)
      if [[ $? -eq 0 && -n "$diff_output" ]]; then
          read ahead_count behind_count <<< "$diff_output"
          local ahead_sym=${ZSH_THEME_GIT_PROMPT_AHEAD:-''}
          local behind_sym=${ZSH_THEME_GIT_PROMPT_BEHIND:-''}
          [[ $ahead_count -gt 0 ]] && diff_segment+=" ${ahead_sym}${ahead_count}"
          [[ $behind_count -gt 0 ]] && diff_segment+=" ${behind_sym}${behind_count}"
      fi
  else
      branch_display="${local_branch}"
  fi

  # Check for stashed changes
  stash_count=$(command git stash list 2>/dev/null | wc -l | tr -d ' ');
  if [[ $stash_count -gt 0 ]]; then
      local stashed_sym=${ZSH_THEME_GIT_PROMPT_STASHED:-'$'}
      stash_segment=" ${stashed_sym}${stash_count}"
  fi

  # Get the status symbols + counts by calling the parser function
  status_segment=$(my_git_status_parser_with_counts)

  # Construct the full Git segment string
  # Only add the segment if local_branch was successfully determined
  if [[ -n "$local_branch" ]]; then
      git_segment=""
      git_segment+="${ZSH_THEME_GIT_PROMPT_PREFIX}"                # Prefix
      git_segment+="%{$fg_bold[red]%}${branch_display}%{$reset_color%}"    # Branch(es)
      git_segment+="${diff_segment}"                              # Ahead/Behind Counts
      git_segment+="${status_segment}"                            # Status Symbols+Counts (already has leading space if needed)
      git_segment+="${stash_segment}"                             # Stash Count (already has leading space if needed)
      git_segment+="${ZSH_THEME_GIT_PROMPT_SUFFIX}"                # Suffix

      # Output the final segment
      echo -n "${git_segment}"
  fi
}
# <<< NEW: Function to build the entire Git segment dynamically --- END ---


# --- Prompt Definition ---

# Part 1: Static conditional status (Double quotes OK)
PROMPT="%(?:%{$fg_bold[green]%}%1{%} :%{$fg_bold[red]%}%1{%} )"

# Part 2: Dynamic path (Use SINGLE quotes for PROMPT+=)
# Note the space before %{fg...
PROMPT+=' %{$fg[cyan]%}$( _my_custom_pwd )%{$reset_color%}'

# Part 3: Dynamic Git segment (Use SINGLE quotes for PROMPT+=)
PROMPT+='$( _my_build_git_prompt_segment )'

# Part 4: Static final conditional (Double quotes OK)
# Note the space before %(?:...
PROMPT+=" %(?:%{$fg_bold[green]%}%1{󰁔%} :%{$fg_bold[red]%}%1{󰁔%} )"

# --- RPROMPT --- (Remains the same)
RPROMPT='%{$fg[green]%}󰎙($(node_version)) %{$fg[green]%}($(python_version)) %{$fg[yellow]%}%n@%M %{$fg[cyan]%}%w,%t%{$reset_color%}'

# --- END OF PROMPT/RPROMPT DEFINITIONS ---