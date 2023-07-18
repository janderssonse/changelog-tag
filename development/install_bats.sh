#!/usr/bin/env bash

# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: MIT

#install bats libs in scripts current folder/lib

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)

is_command_installed() {

  local -r sumprog=$1

  if ! [[ -x "$(command -v "${sumprog}")" ]]; then
    echo "${sumprog} could not be run, make sure it is installed and executable"
    return 1
  fi
}

download_bats() {

  local -r outputdir="${SCRIPT_DIR}/lib"
  mkdir -p "${outputdir}"
  (
    cd "${outputdir}"
    git clone --depth 1 https://github.com/bats-core/bats-core.git bats
    git clone --depth 1 https://github.com/bats-core/bats-support.git bats-support
    git clone --depth 1 https://github.com/bats-core/bats-assert.git bats-assert
    git clone --depth 1 https://github.com/bats-core/bats-file.git bats-file
  )

}

main() {

  is_command_installed "curl"
  is_command_installed "git"
  download_bats

}

main
