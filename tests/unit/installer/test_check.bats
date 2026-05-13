#!/usr/bin/env bats

load '../../setup'

setup() {
  setup_mock_path
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  source "${INSTALLER_DIR}/check.sh"
  # Defaults used by check_env
  ZMBKP_VERSION="zmbackup version: 1.2.6"
  OSE_USER="zimbra"
}

# ---------------------------------------------------------------------------
# check_env: root check
# ---------------------------------------------------------------------------

@test "check_env: exits with ERR_NOROOT when not root" {
  MOCK_ID_UID=1000
  run check_env
  [ "$status" -eq 2 ]
  [[ "$output" == *"root"* ]]
}

@test "check_env: proceeds when running as root" {
  MOCK_ID_UID=0
  # su mock returns empty (no zmbackup found -> new install)
  MOCK_SU_FAIL=1
  # apt mock exists so SO=ubuntu
  run check_env
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# check_env: install detection
# ---------------------------------------------------------------------------

@test "check_env: sets UPGRADE=N and UNINSTALL=N for new install" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=1   # whereis zmbackup fails -> new install
  check_env
  [ "$UPGRADE" = "N" ]
  [ "$UNINSTALL" = "N" ]
}

@test "check_env: sets UNINSTALL=Y with --remove flag when zmbackup exists" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=0   # whereis zmbackup succeeds -> existing install
  check_env "--remove"
  [ "$UNINSTALL" = "Y" ]
}

@test "check_env: sets UNINSTALL=Y with -r flag when zmbackup exists" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=0
  check_env "-r"
  [ "$UNINSTALL" = "Y" ]
}

@test "check_env: sets UPGRADE=Y with --force-upgrade when version differs" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=0
  # Override the zmbackup version check: first su call (whereis) succeeds,
  # second (zmbackup -h) returns old version
  MOCK_SU_OUTPUT="zmbackup version: 1.0.0"
  check_env "--force-upgrade"
  [ "$UPGRADE" = "Y" ]
}

@test "check_env: exits 0 with --force-upgrade when already at newest version" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=0
  MOCK_SU_OUTPUT="zmbackup version: 1.2.6"
  run check_env "--force-upgrade"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NEWEST VERSION"* ]]
}

# ---------------------------------------------------------------------------
# check_env: OS detection
# ---------------------------------------------------------------------------

@test "check_env: detects Ubuntu when apt is available" {
  MOCK_ID_UID=0
  MOCK_SU_FAIL=1
  # apt mock is in MOCKS_DIR and always succeeds
  check_env
  [ "$SO" = "ubuntu" ]
}

# ---------------------------------------------------------------------------
# check_config
# ---------------------------------------------------------------------------

@test "check_config: displays configuration summary" {
  OSE_USER="zimbra"
  OSE_INSTALL_ADDRESS="192.168.1.1"
  OSE_INSTALL_LDAPPASS="secret"
  OSE_INSTALL_DIR="/opt/zimbra"
  OSE_DEFAULT_BKP_DIR="/opt/zimbra/backup"
  ZMBKP_SRC="/usr/local/bin"
  ZMBKP_CONF="/etc/zmbackup"
  ROTATE_TIME="30"
  MAX_PARALLEL_PROCESS="3"
  LOCK_BACKUP="true"
  SESSION_TYPE="TXT"
  run bash -c "
    source '${INSTALLER_DIR}/check.sh'
    echo '' | check_config
  "
  [[ "$output" == *"Summary"* ]]
  [[ "$output" == *"zimbra"* ]]
}
