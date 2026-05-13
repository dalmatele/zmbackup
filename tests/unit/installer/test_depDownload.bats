#!/usr/bin/env bats

load '../../setup'

setup() {
  setup_mock_path
  source "${INSTALLER_DIR}/vars.sh" 2>/dev/null || true
  source "${INSTALLER_DIR}/depDownload.sh"
}

# ---------------------------------------------------------------------------
# install_ubuntu
# ---------------------------------------------------------------------------

@test "install_ubuntu: succeeds when apt succeeds" {
  MOCK_APT_FAIL=0
  run install_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "install_ubuntu: exits ERR_DEPNOTFOUND when apt fails" {
  MOCK_APT_FAIL=1
  run install_ubuntu
  [ "$status" -eq "$ERR_DEPNOTFOUND" ]
  [[ "$output" == *"wasn't installed"* ]]
}

@test "install_ubuntu: prints manual command hint on failure" {
  MOCK_APT_FAIL=1
  run install_ubuntu
  [[ "$output" == *"apt update"* ]]
}

# ---------------------------------------------------------------------------
# install_redhat
# ---------------------------------------------------------------------------

@test "install_redhat: succeeds when yum succeeds (CentOS 7)" {
  MOCK_YUM_FAIL=0
  # CentOS 7 - grep for "6" fails (not CentOS 6)
  run install_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "install_redhat: exits ERR_DEPNOTFOUND when yum fails" {
  MOCK_YUM_FAIL=1
  run install_redhat
  [ "$status" -eq "$ERR_DEPNOTFOUND" ]
  [[ "$output" == *"wasn't installed"* ]]
}

@test "install_redhat: exits ERR_NO_CONNECTION when wget fails on CentOS 6" {
  MOCK_YUM_FAIL=0
  MOCK_WGET_FAIL=1
  # Simulate CentOS 6 detection: override grep for redhat-release
  grep() {
    if [[ "$*" == *"redhat-release"* ]]; then
      return 0  # "6" found
    fi
    command grep "$@"
  }
  run install_redhat
  [ "$status" -eq "$ERR_NO_CONNECTION" ]
  [[ "$output" == *"Tange"* ]]
}

@test "install_redhat: prints manual command hint on failure" {
  MOCK_YUM_FAIL=1
  run install_redhat
  [[ "$output" == *"yum install"* ]]
}

# ---------------------------------------------------------------------------
# remove_ubuntu
# ---------------------------------------------------------------------------

@test "remove_ubuntu: succeeds when apt remove succeeds" {
  MOCK_APT_FAIL=0
  run remove_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "remove_ubuntu: prints warning but does not exit on apt failure" {
  MOCK_APT_FAIL=1
  run remove_ubuntu
  [ "$status" -eq 0 ]
  [[ "$output" == *"wasn't removed"* ]]
}

@test "remove_ubuntu: prints manual command hint on failure" {
  MOCK_APT_FAIL=1
  run remove_ubuntu
  [[ "$output" == *"apt remove"* ]]
}

# ---------------------------------------------------------------------------
# remove_redhat
# ---------------------------------------------------------------------------

@test "remove_redhat: succeeds when yum remove succeeds (CentOS 7)" {
  MOCK_YUM_FAIL=0
  run remove_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"success"* ]]
}

@test "remove_redhat: prints warning but does not exit on yum failure" {
  MOCK_YUM_FAIL=1
  run remove_redhat
  [ "$status" -eq 0 ]
  [[ "$output" == *"wasn't removed"* ]]
}

@test "remove_redhat: prints manual command hint on failure" {
  MOCK_YUM_FAIL=1
  run remove_redhat
  [[ "$output" == *"yum install"* ]]
}
