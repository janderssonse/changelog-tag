#!/usr/bin/env bash

# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: MIT

# Code Quality Check Script
# Uses mega-linter, reuse-tool and conform to check various linting, licenses, and commit compliance.
# Dependent on Podman

declare -A EXITCODES
declare -A SUCCESS_MESSAGES

readonly RED=$'\e[31m'
readonly NC=$'\e[0m'
readonly GREEN=$'\e[32m'
readonly YELLOW=$'\e[0;33m'

#Terminal chars
readonly CHECKMARK=$'\xE2\x9C\x94'
readonly MISSING=$'\xE2\x9D\x8C'

#Settings
COVERAGE_LIMIT=50.00

is_command_available() {
  local COMMAND="${1}"
  local INFO="${2}"

  if ! [ -x "$(command -v "${COMMAND}")" ]; then
    printf '%b Error:%b %s is not available in path/installed.\n' "${RED}" "${NC}" "${COMMAND}" >&2
    printf 'See %s for more info about the command.\n' "${INFO}" >&2
    exit 1
  fi
}

print_header() {
  local HEADER="$1"
  printf '%b\n************ %s ***********%b\n\n' "${YELLOW}" "$HEADER" "${NC}"
}

store_exit_code() {
  declare -i STATUS="$1"
  local KEY="$2"
  local INVALID_MESSAGE="$3"
  local VALID_MESSAGE="$4"

  if [[ "${STATUS}" -ne 0 ]]; then
    EXITCODES["${KEY}"]="${INVALID_MESSAGE}"
  else
    SUCCESS_MESSAGES["${KEY}"]="${VALID_MESSAGE}"
  fi
}

lint() {
  export MEGALINTER_DEF_WORKSPACE='/repo'
  print_header 'LINTER HEALTH (MEGALINTER)'
  podman run --rm --volume "$(pwd)":/repo -e MEGALINTER_CONFIG='development/mega-linter.yml' -e DEFAULT_WORKSPACE=${MEGALINTER_DEF_WORKSPACE} -e LOG_LEVEL=INFO oxsecurity/megalinter-java:v7.2.1
  store_exit_code "$?" "Lint" "${MISSING} ${RED}Lint check failed, see logs (std out and/or ./megalinter-reports) and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} Lint check passed${NC}\n"
  printf '\n\n'
}

license() {
  print_header 'LICENSE HEALTH (REUSE)'
  podman run --rm --volume "$(pwd)":/data fsfe/reuse:2-debian lint
  store_exit_code "$?" "License" "${MISSING} ${RED}License check failed, see logs and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} License check passed${NC}\n"
  printf '\n\n'
}

commit() {
  local compareToBranch='main'
  local currentBranch
  currentBranch=$(git branch --show-current)
  # siderolabs/conform:v0.1.0-alpha.27
  print_header 'COMMIT HEALTH (CONFORM)'

  if [[ "$(git rev-list --count ${compareToBranch}..)" == 0 ]]; then
    printf "%s" "${GREEN} No commits found in current branch: ${YELLOW}${currentBranch}${NC}, compared to: ${YELLOW}${compareToBranch}${NC} ${NC}"
    store_exit_code "$?" "Commit" "${MISSING} ${RED}Commit check count failed, see logs (std out) and fix problems.${NC}\n" "${YELLOW}${CHECKMARK}${CHECKMARK} Commit check skipped, no new commits found in current branch: ${YELLOW}${currentBranch}${NC}\n"
  else
    podman run --rm -i --volume "$(pwd)":/repo -w /repo ghcr.io/siderolabs/conform:v0.1.0-alpha.27 enforce --base-branch="${compareToBranch}"
    store_exit_code "$?" "Commit" "${MISSING} ${RED}Commit check failed, see logs (std out) and fix problems.${NC}\n" "${GREEN}${CHECKMARK}${CHECKMARK} Commit check passed${NC}\n"
  fi

  printf '\n\n'
}

compareLimit() {

  local pass_limit
  pass_limit=$(awk -v n1="$1" -v n2="$2" 'BEGIN {printf (n1<n2?"true":"false")"\n", n1, n2}')

  if [[ "${pass_limit}" == 'false' ]]; then
    store_exit_code "1" "Coverage" "${MISSING} ${RED}Coverage check failed, adjust tests, see reports (coverage/index.html and fix problems.${NC}\n" ""
  else
    store_exit_code "0" "Coverage" "" "${GREEN}${CHECKMARK}${CHECKMARK} Coverage check passed${NC}\n"
  fi
}

coverage() {

  print_header 'TEST COVERAGE (KCOV)'

  is_command_available './development/lib/bats/bin/bats' ''

  local jsonPath
  local percent_covered

  kcov \
    --clean \
    --bash-dont-parse-binary-dir \
    --exclude-pattern=src/test \
    --include-path=src \
    ./coverage/ ./development/lib/bats/bin/bats ./src/test >/dev/null 2>&1

  jsonPath=$(readlink coverage/bats)
  percent_covered=$(jq -r '.percent_covered' <"${jsonPath}/coverage.json")

  printf "Coverage: %s\nLimit: %s\n\n" "${percent_covered}" "${COVERAGE_LIMIT}"
  compareLimit "${COVERAGE_LIMIT}" "${percent_covered}"
}

check_exit_codes() {
  printf '%b********* CODE QUALITY RUN SUMMARY ******%b\n\n' "${YELLOW}" "${NC}"

  for key in "${!EXITCODES[@]}"; do
    printf '%b' "${EXITCODES[$key]}"
  done
  printf "\n"

  for key in "${!SUCCESS_MESSAGES[@]}"; do
    printf '%b' "${SUCCESS_MESSAGES[$key]}"
  done
  printf "\n"
}

is_command_available 'podman' 'https://podman.io/'
is_command_available 'kcov' 'https://github.com/SimonKagstrom/kcov'

lint
license
commit
coverage

check_exit_codes
