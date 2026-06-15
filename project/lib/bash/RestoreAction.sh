#!/bin/bash
################################################################################
# Restore Session - LDAP/Mailbox/DistList/Alias
################################################################################

################################################################################
# restore_main_mailbox: Manage the restore action for one or all mailbox
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
#    $3 - The destination of the restored account
################################################################################
function restore_main_mailbox()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    SESSION=$(grep -E ": $1 started" "$WORKDIR"/sessions.txt | grep 'started' | \
                  awk '{print $2}' | sort | uniq)
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    SESSION=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select * from backup_session where sessionID='$1'")
  fi
  if [ -n "$SESSION" ]; then
    printf "Restore mail process with session %s started at %s" "$1" "$(date)"
    if [[ -n $3 && $2 == *"@"* ]]; then
      TEMP_CLI_OUTPUT=$(mktemp)
      if $ZMMAILBOX -t0 -z -m "$3" postRestURL '//?fmt=tgz&resolve=skip' "$WORKDIR"/"$1"/"$2".tgz > "$TEMP_CLI_OUTPUT" 2>&1; then
        BASHERRCODE=0
        if grep -q "No such file or directory" "$TEMP_CLI_OUTPUT"; then
          printf "Account %s has nothing to restore - skipping..." "$2"
        fi
      else
        BASHERRCODE=$?
        printf "Error during the restore process for account %s. Error message below:" "$2"
        printf "\n%s: " "$2"
        cat "$TEMP_CLI_OUTPUT"
      fi
      rm -rf "${TEMP_CLI_OUTPUT:?}"
    else
      build_listRST "$1" "$2"
      parallel --jobs "$MAX_PARALLEL_PROCESS" "mailbox_restore '$1' '{}'" < "$TEMPACCOUNT"
      BASHERRCODE=$?
    fi
    if [[ $BASHERRCODE -eq 0 ]]; then
      printf "\nRestore mail process with session %s completed at %s\n" "$1" "$(date)"
    else
      printf "\nRestore mail process with session %s completed with errors at %s\n" "$1" "$(date)"
    fi
    return $BASHERRCODE
  else
    echo "Nothing to do. Closing..."
    rm -rf "$PID"
    return 0
  fi
}

################################################################################
# restore_main_domain: Manage the restore action for Zimbra domain LDAP entries.
# Run this before restore_main_ldap when restoring to a clean installation so
# that the domain parent DN exists before account entries are added.
# Options:
#    $1 - The session to be restored
#    $2 - Comma-separated list of domains to restore, or empty for all domains
#         in the session
################################################################################
function restore_main_domain()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    SESSION=$(grep -E ": $1 started" "$WORKDIR"/sessions.txt | grep 'started' | \
                  awk '{print $2}' | sort | uniq)
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    SESSION=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select * from backup_session where sessionID='$1'")
  fi
  if [ -n "$SESSION" ]; then
    echo "Restore Domain LDAP process with session $1 started at $(date)"
    if [[ -n "$2" ]]; then
      for i in $(echo "$2" | tr ',' ' '); do
        echo "$i" >> "$TEMPACCOUNT"
      done
    else
      build_listRST "$1" ""
    fi
    parallel --jobs "$MAX_PARALLEL_PROCESS" "domain_restore '$1' '{}'" < "$TEMPACCOUNT"
    BASHERRCODE=$?
    if [[ $BASHERRCODE -eq 0 ]]; then
      echo "Restore Domain LDAP process with session $1 completed at $(date)"
    else
      echo "Restore Domain LDAP process with session $1 completed with errors at $(date)"
    fi
    return $BASHERRCODE
  else
    echo "Nothing to do. Closing..."
    return 0
  fi
}

################################################################################
# restore_main_ldap: Manage the restore action for one or all ldap accounts
# Options:
#    $1 - The session to be restored
#    $2 - The list of accounts to be restored.
################################################################################
function restore_main_ldap()
{
  if [[ $SESSION_TYPE == 'TXT' ]]; then
    SESSION=$(grep -E ": $1 started" "$WORKDIR"/sessions.txt | grep 'started' | \
                  awk '{print $2}' | sort | uniq)
  elif [[ $SESSION_TYPE == "SQLITE3" ]]; then
    SESSION=$(sqlite3 "$WORKDIR"/sessions.sqlite3 "select * from backup_session where sessionID='$1'")
  fi
  if [ -n "$SESSION" ]; then
    echo "Restore LDAP process with session $1 started at $(date)"
    build_listRST "$1" "$2"
    parallel --jobs "$MAX_PARALLEL_PROCESS" "ldap_restore '$1' '{}'" < "$TEMPACCOUNT"
    BASHERRCODE=$?
    if [[ $BASHERRCODE -eq 0 ]]; then
      echo "Restore LDAP process with session $1 completed at $(date)"
    else
      echo "Restore LDAP process with session $1 completed with errors at $(date)"
    fi
    return $BASHERRCODE
  else
    echo "Nothing to do. Closing..."
    return 0
  fi
}
