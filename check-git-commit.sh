#!/usr/bin/bash
#
# Add a warning with <line_number> and <msg>.
#

add_warning() {
  local line_number=$1
  local warning=$2
  WARNINGS[$line_number]="${WARNINGS[$line_number]}$warning;"
}

#
# Output warnings.
#

display_warnings() {
  if [ $SKIP_DISPLAY_WARNINGS -eq 1 ]; then
    # if the warnings were skipped then they should be displayed next time
    SKIP_DISPLAY_WARNINGS=0
    return
  fi

  for i in "${!WARNINGS[@]}"; do
    printf "%-74s ${WHITE}%s${NC}\n" "${COMMIT_MSG_LINES[$(($i-1))]}" "[line ${i}]"
    IFS=';' read -ra WARNINGS_ARRAY <<< "${WARNINGS[$i]}"
    for ERROR in "${WARNINGS_ARRAY[@]}"; do
      echo -e " ${YELLOW}- ${ERROR}${NC}"
    done
  done

#   echo
#   echo -e "${RED}$(cat <<-EOF
# How to Write a Git Commit Message
# EOF
# )${NC}"
}

#
# Read the contents of the commit msg into an array of lines.
#

read_commit_message() {
  # reset commit_msg_lines
  COMMIT_MSG_LINES="$1"
}

#
# Validate the contents of the commmit msg agains the good commit guidelines.
#

validate_commit_message() {
  # reset warnings
  WARNINGS=()
  # capture the subject, and remove the 'squash! ' prefix if present
  COMMIT_SUBJECT=${COMMIT_MSG_LINES[0]/#squash! /}

  # if the commit is empty there's nothing to validate, we can return here
  COMMIT_MSG_STR="${COMMIT_MSG_LINES[*]}"
  test -z "${COMMIT_MSG_STR[*]// }" && return;

  # if the commit subject starts with 'fixup! ' there's nothing to validate, we can return here
  [[ $COMMIT_SUBJECT == 'fixup! '* ]] && return;

  # skip first token in subject (e.g. issue ID from bugtracker which is validated otherwise)
  skipfirsttokeninsubject=$(git config --get hooks.goodcommit.subjectskipfirsttoken || echo 'false')
  if [ "$skipfirsttokeninsubject" == "true" ]; then
    COMMIT_SUBJECT_TO_PROCESS=${COMMIT_SUBJECT#* }
  else
    COMMIT_SUBJECT_TO_PROCESS=$COMMIT_SUBJECT
  fi

  # 0. Check spelling
  # ------------------------------------------------------------------------------
  ASPELL=$(which aspell)
  if [ $? -ne 0 ]; then
      echo "Aspell not installed - unable to check spelling"
  else
      LINE_NUMBER=1
      MISSPELLED_WORDS=$(echo "$COMMIT_MSG_LINES[LINE_NUMBER]" | $ASPELL --lang=en --list --home-dir=scripts --personal=aspell-pws)
      if [ -n "$MISSPELLED_WORDS" ]; then
        add_warning LINE_NUMBER "Possible misspelled word(s): $MISSPELLED_WORDS"
      fi
  fi

  # 1. Separate subject from body with a blank line
  # ------------------------------------------------------------------------------

  test ${#COMMIT_MSG_LINES[@]} -lt 1 || test -z "${COMMIT_MSG_LINES[1]}"
  test $? -eq 0 || add_warning 2 "Separate subject from body with a blank line"

  # 2. Limit the subject line to configured number of characters
  # ------------------------------------------------------------------------------

  subject_max_length=$(git config --get hooks.goodcommit.subjectmaxlength || echo '50')
  test "${#COMMIT_SUBJECT}" -le $subject_max_length
  test $? -eq 0 || add_warning 1 "Limit the subject line to $subject_max_length characters (${#COMMIT_SUBJECT} chars)"

  # 3. Capitalize the subject line
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_SUBJECT_TO_PROCESS} =~ ^[[:blank:]]*([[:upper:]]{1}[[:lower:]]*|[[:digit:]]+)([[:blank:]]|[[:punct:]]|$) ]]
  test $? -eq 0 || add_warning 1 "Capitalize the subject line"

  # 4. Do not end the subject line with a period
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_SUBJECT} =~ [^\.]$ ]]
  test $? -eq 0 || add_warning 1 "Do not end the subject line with a period"

  # 5. Use the imperative mood in the subject line
  # ------------------------------------------------------------------------------

  IMPERATIVE_MOOD_DENYLIST=(
    added          adds          adding
    adjusted       adjusts       adjusting
    amended        amends        amending
    avoided        avoids        avoiding
    bumped         bumps         bumping
    changed        changes       changing
    checked        checks        checking
    committed      commits       committing
    copied         copies        copying
    corrected      corrects      correcting
    created        creates       creating
    decreased      decreases     decreasing
    deleted        deletes       deleting
    disabled       disables      disabling
    dropped        drops         dropping
    duplicated     duplicates    duplicating
    enabled        enables       enabling
    excluded       excludes      excluding
    fixed          fixes         fixing
    handled        handles       handling
    implemented    implements    implementing
    improved       improves      improving
    included       includes      including
    increased      increases     increasing
    installed      installs      installing
    introduced     introduces    introducing
    merged         merges        merging
    moved          moves         moving
    pruned         prunes        pruning
    refactored     refactors     refactoring
    released       releases      releasing
    removed        removes       removing
    renamed        renames       renaming
    replaced       replaces      replacing
    resolved       resolves      resolving
    reverted       reverts       reverting
    showed         shows         showing
    tested         tests         testing
    tidied         tidies        tidying
    updated        updates       updating
    used           uses          using
  )

  # enable case insensitive match
  shopt -s nocasematch

  for DENYLISTED_WORD in "${IMPERATIVE_MOOD_DENYLIST[@]}"; do
    [[ ${COMMIT_SUBJECT_TO_PROCESS} =~ ^[[:blank:]]*$DENYLISTED_WORD ]]
    test $? -eq 0 && add_warning 1 "Use the imperative mood in the subject line, e.g., 'fix' not 'fixes'" && break
  done

  # disable case insensitive match
  shopt -u nocasematch

  # 6. Wrap the body at 72 characters
  # ------------------------------------------------------------------------------

  URL_REGEX='^[[:blank:]]*(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

  for i in "${!COMMIT_MSG_LINES[@]}"; do
    LINE_NUMBER=$((i+1))
    test "${#COMMIT_MSG_LINES[$i]}" -le 72 || [[ ${COMMIT_MSG_LINES[$i]} =~ $URL_REGEX ]]
    test $? -eq 0 || add_warning $LINE_NUMBER "Wrap the body at 72 characters (${#COMMIT_MSG_LINES[$i]} chars)"
  done

  # 7. Use the body to explain what and why vs. how
  # ------------------------------------------------------------------------------

  # ?

  # 8. Do no write single worded commits
  # ------------------------------------------------------------------------------

  COMMIT_SUBJECT_WORDS=(${COMMIT_SUBJECT_TO_PROCESS})
  test "${#COMMIT_SUBJECT_WORDS[@]}" -gt 1
  test $? -eq 0 || add_warning 1 "Do no write single worded commits"

  # 8a. Do not mention C source filenames
  [[ ${COMMIT_SUBJECT_TO_PROCESS} =~ [_a-zA-Z0-9]+\.[ch]$ ]]
  test $? -eq 1 || add_warning 1 "Avoid mentioning C source filenames"

  # 9. Do not start the subject line with whitespace
  # ------------------------------------------------------------------------------

  [[ ${COMMIT_SUBJECT_TO_PROCESS} =~ ^[[:blank:]]+ ]]
  test $? -eq 1 || add_warning 1 "Do not start the subject line with whitespace"
}

#
# It's showtime.
#

if tty >/dev/null 2>&1; then
  TTY=$(tty)
else
  TTY=/dev/tty
fi

OMMIT_MSG_LINES=()
for ARG in "$@"; do
  COMMIT_MSG_LINES+=("$ARG")
done  
  # read_commit_message "$COMMIT_MSG"

  validate_commit_message

  # if there are no WARNINGS are empty then we're good to break out of here
  # test ${#WARNINGS[@]} -eq 0 && exit 0;

  display_warnings

  # Ask the question (not using "read -p" as it uses stderr not stdout)
#   echo -en "${CYAN}Proceed with commit? [e/n/?] ${NC}"

#   # Check if the reply is valid
#   case "$REPLY" in
#     E*|e*) $HOOK_EDITOR "$COMMIT_MSG_FILE" < $TTY; continue ;;
#     N*|n*) exit 1 ;;
#     *)     SKIP_DISPLAY_WARNINGS=1; prompt_help; continue ;;
#   esac

