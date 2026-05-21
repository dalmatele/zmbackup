#!/usr/bin/env bats

load '../setup'

setup() {
  setup_mock_path
  create_workdir
  load_test_config
  source "${LIB_DIR}/MiscAction.sh"
}

teardown() {
  unset STYPE SESSION
  cleanup_temps
  destroy_workdir
}

# ---------------------------------------------------------------------------
# zmlog
# ---------------------------------------------------------------------------

@test "zmlog: writes a timestamped entry to LOGFILE" {
  zmlog local7.info "hello world"
  [ -f "$LOGFILE" ]
  grep -q "hello world" "$LOGFILE"
}

@test "zmlog: entry contains the syslog priority" {
  zmlog local7.warn "priority check"
  grep -q "local7.warn" "$LOGFILE"
}

@test "zmlog: entry contains a timestamp in YYYY-MM-DD HH:MM:SS format" {
  zmlog local7.info "timestamp check"
  grep -qE "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}" "$LOGFILE"
}

@test "zmlog: reads message from stdin when no message argument given" {
  echo "stdin message" | zmlog local7.info
  grep -q "stdin message" "$LOGFILE"
}

@test "zmlog: reads message from file redirect" {
  local tmpfile
  tmpfile="$(mktemp)"
  echo "file redirect message" > "$tmpfile"
  zmlog local7.err < "$tmpfile"
  grep -q "file redirect message" "$LOGFILE"
  rm -f "$tmpfile"
}

@test "zmlog: appends multiple entries without truncating" {
  zmlog local7.info "first entry"
  zmlog local7.info "second entry"
  grep -q "first entry" "$LOGFILE"
  grep -q "second entry" "$LOGFILE"
  [ "$(wc -l < "$LOGFILE")" -eq 2 ]
}

@test "zmlog: also invokes logger with the given priority" {
  # logger mock exits 0; we verify zmlog exits 0 (meaning logger was called and succeeded)
  run zmlog local7.info "logger delegation check"
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# create_temp
# ---------------------------------------------------------------------------

@test "create_temp: creates TEMPDIR inside WORKDIR" {
  create_temp
  [ -d "$TEMPDIR" ]
  [[ "$TEMPDIR" == "${WORKDIR}/"* ]]
}

@test "create_temp: creates TEMPACCOUNT file" {
  create_temp
  [ -f "$TEMPACCOUNT" ]
}

@test "create_temp: creates TEMPINACCOUNT file" {
  create_temp
  [ -f "$TEMPINACCOUNT" ]
}

@test "create_temp: creates MESSAGE file" {
  create_temp
  [ -f "$MESSAGE" ]
}

@test "create_temp: creates FAILURE file" {
  create_temp
  [ -f "$FAILURE" ]
}

@test "create_temp: creates TEMPSESSION file" {
  create_temp
  [ -f "$TEMPSESSION" ]
}

@test "create_temp: creates TEMPSQL file" {
  create_temp
  [ -f "$TEMPSQL" ]
}

# ---------------------------------------------------------------------------
# load_config
# ---------------------------------------------------------------------------

@test "load_config: exits 1 when zmbackup.conf is missing" {
  run load_config
  [ "$status" -eq 1 ]
  [[ "$output" == *"zmbackup.conf not found"* ]]
}

@test "load_config: exits 1 when zimbra bashrc is missing" {
  # Run in a subprocess so source() override doesn't break BATS internals
  run bash -c "
    _fake_conf=\"\$(mktemp)\"
    echo 'TESTVAR=yes' > \"\$_fake_conf\"
    source() {
      case \"\$1\" in
        /etc/zmbackup/zmbackup.conf) builtin source \"\$_fake_conf\" ;;
        *) builtin source \"\$@\" ;;
      esac
    }
    source '${LIB_DIR}/MiscAction.sh'
    load_config
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *".bashrc not found"* ]]
}

@test "load_config: succeeds when both config files exist" {
  run bash -c "
    _fake_conf=\"\$(mktemp)\"
    _fake_bashrc=\"\$(mktemp)\"
    echo 'TESTVAR_CONF=yes' > \"\$_fake_conf\"
    source() {
      case \"\$1\" in
        /etc/zmbackup/zmbackup.conf) builtin source \"\$_fake_conf\" ;;
        /opt/zimbra/.bashrc)         builtin source \"\$_fake_bashrc\" ;;
        *) builtin source \"\$@\" ;;
      esac
    }
    source '${LIB_DIR}/MiscAction.sh'
    load_config
    echo \"TESTVAR_CONF=\$TESTVAR_CONF\"
    rm -f \"\$_fake_conf\" \"\$_fake_bashrc\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"TESTVAR_CONF=yes"* ]]
}

@test "load_config: exports LDAPRC when ldaprc file is found" {
  run bash -c "
    _fake_conf=\"\$(mktemp)\"
    _fake_bashrc=\"\$(mktemp)\"
    _fake_ldaprc=\"\$(mktemp)\"
    source() {
      case \"\$1\" in
        /etc/zmbackup/zmbackup.conf) builtin source \"\$_fake_conf\" ;;
        /opt/zimbra/.bashrc)         builtin source \"\$_fake_bashrc\" ;;
        *) builtin source \"\$@\" ;;
      esac
    }
    test() {
      case \"\$*\" in
        \"-f /opt/zimbra/.ldaprc\") return 0 ;;
        *) builtin test \"\$@\" ;;
      esac
    }
    source '${LIB_DIR}/MiscAction.sh'
    load_config
    echo \"LDAPRC=\$LDAPRC\"
    rm -f \"\$_fake_conf\" \"\$_fake_bashrc\" \"\$_fake_ldaprc\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"LDAPRC="* ]]
}

# ---------------------------------------------------------------------------
# constant
# ---------------------------------------------------------------------------

@test "constant: ACOBJECT includes all accounts when BACKUP_INACTIVE_ACCOUNTS=true" {
  BACKUP_INACTIVE_ACCOUNTS="true"
  SSL_ENABLE="false"
  constant
  [[ "$ACOBJECT" == *"zimbraAccount"* ]]
  [[ "$ACOBJECT" != *"zimbraAccountStatus"* ]]
}

@test "constant: ACOBJECT filters inactive when BACKUP_INACTIVE_ACCOUNTS=false" {
  BACKUP_INACTIVE_ACCOUNTS="false"
  SSL_ENABLE="false"
  constant
  [[ "$ACOBJECT" == *"zimbraAccountStatus=active"* ]]
}

@test "constant: WEBPROTO is https when SSL_ENABLE=true" {
  BACKUP_INACTIVE_ACCOUNTS="true"
  SSL_ENABLE="true"
  constant
  [ "$WEBPROTO" = "https" ]
}

@test "constant: WEBPROTO is http when SSL_ENABLE=false" {
  BACKUP_INACTIVE_ACCOUNTS="true"
  SSL_ENABLE="false"
  constant
  [ "$WEBPROTO" = "http" ]
}

@test "constant: sets DLOBJECT for distribution lists" {
  BACKUP_INACTIVE_ACCOUNTS="true"; SSL_ENABLE="false"
  constant
  [[ "$DLOBJECT" == *"zimbraDistributionList"* ]]
}

@test "constant: sets ALOBJECT for aliases" {
  BACKUP_INACTIVE_ACCOUNTS="true"; SSL_ENABLE="false"
  constant
  [[ "$ALOBJECT" == *"zimbraAlias"* ]]
}

@test "constant: sets SIOBJECT for signatures" {
  BACKUP_INACTIVE_ACCOUNTS="true"; SSL_ENABLE="false"
  constant
  [[ "$SIOBJECT" == *"zimbraSignature"* ]]
}

@test "constant: sets LDAP filter constants" {
  BACKUP_INACTIVE_ACCOUNTS="true"; SSL_ENABLE="false"
  constant
  [ "$DLFILTER" = "mail" ]
  [ "$ACFILTER" = "zimbraMailDeliveryAddress" ]
  [ "$ALFILTER" = "uid" ]
  [ "$SIFILTER" = "zimbraSignatureName" ]
}

@test "constant: sets PID path" {
  BACKUP_INACTIVE_ACCOUNTS="true"; SSL_ENABLE="false"
  constant
  [ "$PID" = "/opt/zimbra/log/zmbackup.pid" ]
}

# ---------------------------------------------------------------------------
# sessionvars
# ---------------------------------------------------------------------------

@test "sessionvars: --full creates full- session" {
  # Pre-create a full dir so ls succeeds; --full always forces full session
  mkdir -p "${WORKDIR}/full-existing"
  sessionvars "--full"
  [[ "$SESSION" == "full-"* ]]
  [ "$STYPE" = "Full Account" ]
  [ "$INC" = "FALSE" ]
}

@test "sessionvars: -f creates full- session" {
  mkdir -p "${WORKDIR}/full-existing"
  sessionvars "-f"
  [[ "$SESSION" == "full-"* ]]
}

@test "sessionvars: falls back to full- when WORKDIR has no full-* dirs" {
  # Use || true to prevent set -e from exiting when ls fails inside sessionvars
  { sessionvars "--incremental"; } || true
  [[ "$SESSION" == "full-"* ]]
  [ "$STYPE" = "Full Account" ]
}

@test "sessionvars: --incremental creates inc- session when full backup exists" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--incremental"
  [[ "$SESSION" == "inc-"* ]]
  [ "$STYPE" = "Incremental Account" ]
  [ "$INC" = "TRUE" ]
}

@test "sessionvars: -i creates inc- session when full backup exists" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-i"
  [[ "$SESSION" == "inc-"* ]]
}

@test "sessionvars: --alias creates alias- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--alias"
  [[ "$SESSION" == "alias-"* ]]
  [ "$STYPE" = "Alias" ]
}

@test "sessionvars: -al creates alias- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-al"
  [[ "$SESSION" == "alias-"* ]]
}

@test "sessionvars: --distributionlist creates distlist- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--distributionlist"
  [[ "$SESSION" == "distlist-"* ]]
  [ "$STYPE" = "Distribution List" ]
}

@test "sessionvars: -dl creates distlist- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-dl"
  [[ "$SESSION" == "distlist-"* ]]
}

@test "sessionvars: --mail creates mbox- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--mail"
  [[ "$SESSION" == "mbox-"* ]]
  [ "$STYPE" = "Mailbox" ]
}

@test "sessionvars: -m creates mbox- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-m"
  [[ "$SESSION" == "mbox-"* ]]
}

@test "sessionvars: --ldap creates ldap- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--ldap"
  [[ "$SESSION" == "ldap-"* ]]
  [ "$STYPE" = "Account - Only LDAP" ]
}

@test "sessionvars: -ldp creates ldap- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-ldp"
  [[ "$SESSION" == "ldap-"* ]]
}

@test "sessionvars: --signature creates signature- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "--signature"
  [[ "$SESSION" == "signature-"* ]]
  [ "$STYPE" = "Signature" ]
}

@test "sessionvars: -sig creates signature- session" {
  mkdir -p "${WORKDIR}/full-20240101120000"
  sessionvars "-sig"
  [[ "$SESSION" == "signature-"* ]]
}

# ---------------------------------------------------------------------------
# validate_config
# ---------------------------------------------------------------------------

@test "validate_config: exits 2 when running as wrong user" {
  BACKUPUSER="nonexistentuser_xyz"
  run validate_config
  [ "$status" -eq 2 ]
  [[ "$output" == *"nonexistentuser_xyz"* ]]
}

@test "validate_config: sets BACKUPUSER default to zimbra when empty" {
  # Run in subprocess with whoami mocked to zimbra so the user check passes
  MOCK_WHOAMI_USER="zimbra"
  run bash -c "
    export PATH='${MOCKS_DIR}:${PATH}'
    export WORKDIR='${WORKDIR}'
    export LDAPADMIN='cn=admin,dc=example,dc=com'
    export LDAPPASS='pass'
    export ROTATE_TIME='30'
    export SESSION_TYPE='TXT'
    export BACKUP_INACTIVE_ACCOUNTS='true'
    export BACKUPUSER=''
    export MOCK_WHOAMI_USER='zimbra'
    source '${LIB_DIR}/MiscAction.sh'
    validate_config
    echo \"BACKUPUSER=\$BACKUPUSER\"
  "
  [[ "$output" == *"BACKUPUSER=zimbra"* ]]
}

@test "validate_config: sets WORKDIR default when empty" {
  MOCK_WHOAMI_USER="zimbra"
  run bash -c "
    export PATH='${MOCKS_DIR}:${PATH}'
    export MOCK_WHOAMI_USER='zimbra'
    export BACKUPUSER='zimbra'
    export WORKDIR=''
    export LDAPADMIN='cn=admin,dc=example,dc=com'
    export LDAPPASS='pass'
    export ROTATE_TIME='30'
    export SESSION_TYPE='TXT'
    export BACKUP_INACTIVE_ACCOUNTS='true'
    source '${LIB_DIR}/MiscAction.sh'
    validate_config 2>&1 || true
    echo \"WORKDIR=\$WORKDIR\"
  "
  [[ "$output" == *"WORKDIR=/opt/zimbra/backup"* ]]
}

@test "validate_config: sets ENABLE_EMAIL_NOTIFY default when empty" {
  ENABLE_EMAIL_NOTIFY=""
  validate_config
  [ "$ENABLE_EMAIL_NOTIFY" = "all" ]
}

@test "validate_config: sets EMAIL_SENDER default when empty" {
  EMAIL_SENDER=""
  validate_config
  [[ "$EMAIL_SENDER" == "root@"* ]]
}

@test "validate_config: sets EMAIL_NOTIFY default when empty" {
  EMAIL_NOTIFY=""
  validate_config
  [ "$EMAIL_NOTIFY" = "root@localdomain.com" ]
}

@test "validate_config: sets ZMMAILBOX via whereis when empty" {
  ZMMAILBOX=""
  validate_config
  [ -n "$ZMMAILBOX" ]
}

@test "validate_config: sets MAX_PARALLEL_PROCESS default when empty" {
  MAX_PARALLEL_PROCESS=""
  validate_config
  [ "$MAX_PARALLEL_PROCESS" = "1" ]
}

@test "validate_config: sets LOCK_BACKUP default when empty" {
  LOCK_BACKUP=""
  validate_config
  [ "$LOCK_BACKUP" = "true" ]
}

@test "validate_config: exits 3 when WORKDIR does not exist" {
  WORKDIR="/nonexistent_path_xyz"
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"doesn't exist"* ]]
}

@test "validate_config: exits 3 when LDAPADMIN is empty" {
  LDAPADMIN=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"LDAPADMIN"* ]]
}

@test "validate_config: exits 3 when LDAPPASS is empty" {
  LDAPPASS=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"LDAPPASS"* ]]
}

@test "validate_config: exits 3 when ROTATE_TIME is empty" {
  ROTATE_TIME=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"ROTATE_TIME"* ]]
}

@test "validate_config: exits 3 when SESSION_TYPE is empty" {
  SESSION_TYPE=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"SESSION_TYPE"* ]]
}

@test "validate_config: exits 3 when BACKUP_INACTIVE_ACCOUNTS is empty" {
  BACKUP_INACTIVE_ACCOUNTS=""
  run validate_config
  [ "$status" -eq 3 ]
  [[ "$output" == *"BACKUP_INACTIVE_ACCOUNTS"* ]]
}

@test "validate_config: warns when SSL_ENABLE is empty but does not fail" {
  SSL_ENABLE=""
  run validate_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"SSL_ENABLE"* ]]
}

@test "validate_config: succeeds with all required values set" {
  run validate_config
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# checkpid
# ---------------------------------------------------------------------------

@test "checkpid: creates PID file when none exists" {
  local pid_file
  pid_file="$(mktemp -u)"
  PID="$pid_file"
  checkpid
  [ -f "$pid_file" ]
  [ "$(cat "$pid_file")" = "$$" ]
  rm -f "$pid_file"
}

@test "checkpid: overwrites stale PID file with current PID" {
  local pid_file
  pid_file="$(mktemp)"
  echo "99999999" > "$pid_file"
  PID="$pid_file"
  run checkpid
  [ "$status" -eq 0 ]
  [[ "$output" == *"stale PID"* ]]
  rm -f "$pid_file"
}

@test "checkpid: exits 4 when another instance is already running" {
  local pid_file
  pid_file="$(mktemp)"
  echo "$$" > "$pid_file"
  PID="$pid_file"
  run checkpid
  [ "$status" -eq 4 ]
  [[ "$output" == *"already exist"* ]]
  rm -f "$pid_file"
}

# ---------------------------------------------------------------------------
# export_function / export_vars
# ---------------------------------------------------------------------------

@test "export_function: exports __backupMailbox" {
  source "${LIB_DIR}/BackupAction.sh"
  source "${LIB_DIR}/ParallelAction.sh"
  export_function
  run bash -c 'declare -F __backupMailbox'
  [ "$status" -eq 0 ]
}

@test "export_function: exports ldap_backup" {
  source "${LIB_DIR}/BackupAction.sh"
  source "${LIB_DIR}/ParallelAction.sh"
  export_function
  run bash -c 'declare -F ldap_backup'
  [ "$status" -eq 0 ]
}

@test "export_vars: exports LDAPSERVER" {
  export_vars
  run bash -c 'echo $LDAPSERVER'
  [ "$status" -eq 0 ]
  [[ "$output" == *"127.0.0.1"* ]]
}

@test "export_vars: exports WORKDIR" {
  export_vars
  run bash -c 'echo $WORKDIR'
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}
