#!/usr/bin/env bash

# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Glues together operations for
# * Setting or increase git tag,
# * Setting the version in the project file
# * Generate a changelog
# * Commit the changelog and updated project file in a "release commit.
#

# abort on nonzero exitstatus
set -o errexit
# don't hide errors within pipes
set -o pipefail
# Allow error traps on function calls, subshell environment, and command substitutions
set -o errtrace

INPUT_GIT_BRANCH_NAME="none"
INPUT_IS_INTERACTIVE=""
INPUT_PROJECT_TYPE=""
INPUT_SEMVER_SCOPE="patch"
INPUT_REPOURL=''
INPUT_TAG=""

# ---
PROJECT_TYPE=''
PROJECT_FILE=""
PROJECT_ROOT_FOLDER='./'
NEXT_TAG=""
APPLY_ACTION='y'
SKIP_SSH='n'

SEMVER_SCOPE_REGEX="^(patch)|(minor)|(major)$"
PROJECT_TYPE_REGEX="^(mvn)|(gradle)|(npm)|(none)$"

# SemVer REGEX
# Official SemVer regex with leading vV https://semver.org/#is-there-a-suggested-regular-expression-regex-to-check-a-semver-string
MMP='0|[1-9][0-9]*'
ALPHANUM='[0-9]*[A-Za-z-][0-9A-Za-z-]*'
PRE="$MMP|$ALPHANUM"
BUILD='[0-9A-Za-z-]+'

SEMVER_REGEX="^[vV]?($MMP)\\.($MMP)\\.($MMP)(\\-(${PRE})(\\.(${PRE}))*)?(\\+${BUILD}(\\.${BUILD})*)?$"
SEMVER_ARR=''

# - Fancy colours
readonly RED=$'\e[31m'
readonly NC=$'\e[0m'
readonly GREEN=$'\e[32m'
readonly YELLOW=$'\e[0;33m'

#Terminal chars
readonly CHECKMARK=$'\xE2\x9C\x94'
readonly MISSING=$'\xE2\x9D\x8C'

check_interactive() {

  if [[ "${INPUT_IS_INTERACTIVE}" == 'y' ]]; then
    local user_info=$1

    while true; do
      read -r -n 1 -p "${user_info}" APPLY_ACTION
      case "${APPLY_ACTION}" in
      [y]*)
        printf "\n"
        break
        ;;
      [n]*)
        printf "\n"
        break
        ;;
      *)
        printf "\n%s\n" 'Please answer y or n: '
        ;;
      esac
    done

  fi
}

err() {
  printf "\n"
  printf "%s\n" "${MISSING} ${RED} $* ${NC}" >&2
  printf "\n"
  exit 1
}

info() {
  printf "%s\n" "$@"
}

validate_and_split_semver() {
  local version=$1

  if [[ "$version" =~ $SEMVER_REGEX ]]; then
    local major=${BASH_REMATCH[1]}
    local minor=${BASH_REMATCH[2]}
    local patch=${BASH_REMATCH[3]}
    local prerelease=${BASH_REMATCH[4]}
    local build=${BASH_REMATCH[8]}
    SEMVER_ARR=("$major" "$minor" "$patch" "$prerelease" "$build")
    return 0
  else
    err "Tag ${version} is invalid semver (vV)'x.y.z(-prerelease)(+build)'."
  fi
}

validate_basic_ssh_conf() {

  if [[ "${SKIP_SSH}" == 'y' ]]; then
    return 0
  fi

  local ssh_agent_has_added_identity

  # Has the user an ssh running
  ssh-add -l >/dev/null
  if [[ "$?" -eq 2 ]]; then
    # shellcheck disable=SC2016

    err "Tested ssh-add -l, failed - is the ssh-agent running? Hint: Run ${YELLOW}'eval \$(ssh-agent -s)'${NC}"
  fi

  # Has the user an ssh running, with at least one identiy added?
  ssh_agent_has_added_identity=$(ssh-add -l)
  if [[ "${ssh_agent_has_added_identity=}" == 'The agent has no identities.' ]]; then
    err "ssh-agent has no added identities. Hint: Run ${YELLOW}'ssh-add <your-priv-ssh-key>'${NC}"
  fi

}

validate_basic_git_conf() {

  local git_user
  local git_email
  local git_gpgformat
  local git_commitsign
  local git_tagsign
  local user_signingkey
  git_user=$(git config --get user.name)
  git_email=$(git config --get user.email)
  git_gpgformat=$(git config --get gpg.format)
  git_commitsign=$(git config --get commit.gpgsign)
  git_tagsign=$(git config --get tag.gpgsign)
  user_signingkey=$(git config --get user.signingkey)

  # Has the user configured git user,email,gpgformat,commit, tag and signingkey correctly?
  if [[ -z "${git_user}" ]]; then
    err "Git user is not set in your Git configuration. Please check your git config: (git config --get user.name)."
  fi

  if [[ -z "${git_email}" ]]; then
    err "Git email is not set in your Git configuration. Please check your git config: (git config --get user.email)."
  fi

  case "${git_gpgformat}" in
  'ssh') ;;
  'openpgp' | 'x509')
    info "Git gpg format is not set to ssh in your configuration. Which might be perfectly fine. (git config --get gpg.format)."
    SKIP_SSH='y'
    ;;
  *)
    err "Git gpg format is not set in your Git configuration. Please check your git config: (git config --get gpg.format)."
    ;;
  esac

  if [[ "${git_commitsign}" != 'true' ]]; then
    err "Git is not set to sign commits. Please check your git config: (git config --get commit.gpgsign)."
  fi

  if [[ "${git_tagsign}" != 'true' ]]; then
    err "Git is not set to sign tags. Please check your git config: (git config --get tag.gpgsign)."
  fi

  if [[ "${user_signingkey}" == '' ]]; then
    err "Git user signingkey is not set in your configuration. Please check your git config: (git config --get user.signingkey)."
  fi
}

validate_flag_semver_scope() {

  if [[ "$INPUT_SEMVER_SCOPE" =~ $SEMVER_SCOPE_REGEX ]]; then
    return 0
  else
    err "Option -s / --semver-scope must be <patch|minor|major>, was $INPUT_SEMVER_SCOPE."
  fi

}

validate_flag_project_type() {

  if [[ "$INPUT_PROJECT_TYPE" =~ $PROJECT_TYPE_REGEX ]]; then
    return 0
  else
    err "Option -p / --project-type must be <mvn|npm|gradle|none>, was $INPUT_PROJECT_TYPE."
  fi

}

# Basic sanity checks
validate_input() {

  local current_branch
  current_branch=$(git branch --show-current)

  #shellcheck disable=SC2181
  if [[ "$?" -gt 0 ]]; then
    err "Failed git branch --show-current, it seems you are not running this from a Git enabled directory"
  fi

  # Warn for potential git branch mismatch
  if [[ "${INPUT_GIT_BRANCH_NAME}" != "none" && "${INPUT_GIT_BRANCH_NAME}" != "${current_branch}" ]]; then

    info "${GREEN} To help avoid misfortunes with Git Push, run the script from same branch you will push to. ${NC} To push, set -b /--git-branch-name option."
    err "You are running the script from checkout branch: ${current_branch} and would like to push to: ${INPUT_GIT_BRANCH_NAME}"
  fi

  #Validate given tag
  if [[ -n "${INPUT_TAG}" ]]; then
    validate_and_split_semver "${INPUT_TAG}"
  fi

  if [[ -n "${INPUT_SEMVER_SCOPE}" ]]; then
    validate_flag_semver_scope "${INPUT_SEMVER_SCOPE}"
  fi

  if [[ -n "${INPUT_PROJECT_TYPE}" ]]; then
    validate_flag_project_type "${INPUT_PROJECT_TYPE}"
  fi

}

set_project_type_or_guess_from_project_file() {

  local project_file_path="$1"
  local mvnfile="${project_file_path}pom.xml"
  local npmfile="${project_file_path}package.json"
  local gradlefile="${project_file_path}gradle.properties"

  #TOOO_ validate file exists if choosen
  #TODO: Add scenario of multiple files found
  if [[ -n ${INPUT_PROJECT_TYPE} ]]; then
    PROJECT_TYPE="${INPUT_PROJECT_TYPE}"
    if [[ "${PROJECT_TYPE}" == 'mvn' ]]; then
      PROJECT_FILE="${mvnfile}"
    elif [[ "${PROJECT_TYPE}" == 'npm' ]]; then
      PROJECT_FILE="${npmfile}"
    elif [[ "${PROJECT_TYPE}" == 'gradle' ]]; then
      PROJECT_FILE="${gradlefile}"
    fi
  elif [[ -e "${npmfile}" ]]; then
    PROJECT_TYPE="npm"
    PROJECT_FILE="${npmfile}"
  elif [[ -e "${mvnfile}" ]]; then
    PROJECT_TYPE="mvn"
    PROJECT_FILE="${mvnfile}"
  elif [[ -e "${gradlefile}" ]]; then
    PROJECT_TYPE="gradle"
    PROJECT_FILE="${gradlefile}"
  else
    PROJECT_TYPE="none"
  fi

  readonly PROJECT_TYPE
  readonly PROJECT_FILE

  #if mvn, check all deps are available locally or fail (i.e we don't want to bulid and fetch etc)
  if [[ "${PROJECT_TYPE}" == 'mvn' ]]; then

    if [[ -n "${LOCAL_MVN_REPO:-}" ]]; then
      mvn -q clean -Dmaven.repo.local="${LOCAL_MVN_REPO}"
    else
      mvn -q clean
    fi
    # shellcheck disable=SC2181
    if [[ "$?" -gt 0 ]]; then
      err 'With Maven as project type, make sure all dependencies are fetched before this script'
    fi
  fi
}

pre_run_validation() {
  validate_basic_git_conf
  validate_basic_ssh_conf
  validate_input

}

usage() {

  info \
    "${YELLOW}Usage:${NC} changelog_tag [-h][-d][-i][-s semver-scope][-p project-type][-b git-branch-name]" \
    "" \
    "changelog_tag is a glue for the flow of" \
    " bumping a git tag " \
    " generating a changelog " \
    " update project file version" \
    " generating a release commit (CHANGELOG and project file)" \
    " " \
    "Run it from the root of your git project structure, see README for more info." \
    "" \
    "${YELLOW}Available options:${NC}" \
    "" \
    " -h --help            Print this help and exit" \
    " -d --debug           Output extra script run information" \
    " -s --semver-scope    Semver scope for next tag when autoidentify <major|minor|patch>. Default: patch" \
    " -t --next-tag        Specify next tag instead of autoidentify" \
    " -p --project-type    Which project type <npm|mvn|gradle|none>. Default: try autoidentify by existing file." \
    " -b --git-branch-name Git branch name to push to (any_name). 'none' skips push. Default: none. " \
    " -r --repository-url  Full repository url. Default: autoidentify from git remote url." \
    " -i --interactive     Interactive run. Every workflow step has to be acknowledged." \
    " "
  exit 0
}

is_command_installed() {

  local prog=$1
  local link=$2

  # is symbolic link?
  #if [[ -L "$(command -v "${prog}")" ]]; then
  #  return 0
  #fi

  if ! [[ -x "$(command -v "${prog}")" ]]; then

    info "Tool ${YELLOW}${prog}${NC} could not be found, make sure it is installed!" \
      "Recommended to use the asdf-vm version if there is a plugin for the tool."
    info "See ${GREEN}${link}${NC} or your package manager for install options."
    exit 1
  fi
}

calculate_next_version() {

  #Tag was explictly given
  if [[ -n "${INPUT_TAG}" ]]; then
    NEXT_TAG="${INPUT_TAG}"
    return 0
  fi

  local latest_tag=""
  latest_tag=$(git describe --abbrev=0 --tags)

  if [[ -z $latest_tag ]]; then
    NEXT_TAG='v0.0.1'
    info "Could not find any existing tags in project. Default return v0.0.1"
    return 0
  fi

  info "... Calculating next tag from semver scope: ${YELLOW}${INPUT_SEMVER_SCOPE}${NC}"

  validate_and_split_semver "$latest_tag"
  local -i major="${SEMVER_ARR[0]}"
  local -i minor="${SEMVER_ARR[1]}"
  local -i patch="${SEMVER_ARR[2]}"
  local prerelease="${SEMVER_ARR[3]:-''}"
  local build="${SEMVER_ARR[4]:-''}"

  case "$INPUT_SEMVER_SCOPE" in
  major) NEXT_TAG="$((major + 1)).0.0" ;;
  minor) NEXT_TAG="${major}.$((minor + 1)).0" ;;
  patch) NEXT_TAG="${major}.${minor}.$((patch + 1))" ;;
  preelease) NEXT_TAG="${major}.${minor}.{$patch}-${prerelease}" ;;
  build) NEXT_TAG="${major}.${minor}.${patch}-${prerelease}+${build}" ;;
  esac

  if [[ $latest_tag == v* ]]; then
    NEXT_TAG="v${NEXT_TAG}"
  fi

  info "$GREEN $CHECKMARK ${NC} Calculated next tag version as: ${YELLOW}${NEXT_TAG}${NC}. Current latest project tag is: ${YELLOW}${latest_tag}${NC}"
}

tag_with_next_version() {

  local tag_err_status=''
  tag_err_status=$(git tag -s "${NEXT_TAG}" -m "${NEXT_TAG}" 2>&1)

  if [[ -z $tag_err_status ]]; then
    info "${GREEN} ${CHECKMARK} ${NC} Tagged (signed): ${YELLOW}${NEXT_TAG}${NC}"
  else
    err "Something went wrong when running Git tag -s ${NEXT_TAG} -m ${NEXT_TAG}, exiting. Verify your gpg or ssh signing Git signing conf"
  fi

}

generate_changelog() {

  # git-chlglog needs a repourl to generate links
  local repourl
  # autoremove basic auth from URL for both http and https if user tries to add it
  local sed_cmd='s/\(https\{0,1\}:\/\/\)\([^:@]*\):[^@]*@\([^/]*\)/\1\3/'

  if [[ -n "${INPUT_REPOURL}" ]]; then
    repourl="${INPUT_REPOURL}"
  else
    repourl=$(git config --get remote.origin.url)
    repourl="${repourl::-4}" #remove.g
    repourl=$(echo "${repourl}" | sed -e "$sed_cmd")
    repourl=$(echo "${repourl}" | sed "s/git@gitlab.com:/https:\/\/gitlab.com\//")
    repourl=$(echo "${repourl}" | sed "s/git@github.com:/https:\/\/github.com\//")

  fi

  local scriptdir
  scriptdir=$(dirname -- "$0")

  local git_chglog_conf="${scriptdir}/changelog_tag_templates/git-chglog-gl.yml"

  # Different styles for gitlab/github
  if [[ "${repourl}" == *'github'* ]]; then
    git_chglog_conf="${scriptdir}/changelog_tag_templates/git-chglog-gh.yml"
  fi

  #info "Generate changelog ........ ${repourl}"
  git-chglog --repository-url "${repourl}" -c "${git_chglog_conf}" -o CHANGELOG.md
  info "${GREEN} ${CHECKMARK} ${NC} Generated changelog as ${YELLOW}${PROJECT_ROOT_FOLDER}CHANGELOG.md${NC}"
}

update_npm_version() {
  npm --no-git-tag-version --allow-same-version version "${NEXT_TAG}"
  info "${GREEN} ${CHECKMARK} ${NC} Updated package.json version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_pom_version() {
  if [[ -n "${LOCAL_MVN_REPO:-}" ]]; then
    mvn -q versions:set -DnewVersion="${NEXT_TAG}" -Dmaven.repo.local="${LOCAL_MVN_REPO}"
  else
    mvn -q versions:set -DnewVersion="${NEXT_TAG}"
  fi

  info "${GREEN} ${CHECKMARK} ${NC} Updated pom.xml version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_gradle_version() {
  #./gradlew properties -q | grep "version:" | awk '{print $2}'
  sed -i -E 's/version=.+/version='"${NEXT_TAG}"'/g' gradle.properties
  info "${GREEN} ${CHECKMARK} ${NC} Updated gradle.properties version to ${YELLOW}${NEXT_TAG}${NC}"
}

update_projectfile_version() {

  if [[ "${PROJECT_TYPE}" == "mvn" ]]; then
    update_pom_version
  elif [[ "${PROJECT_TYPE}" == "npm" ]]; then
    update_npm_version
  elif [[ "${PROJECT_TYPE}" == "gradle" ]]; then
    update_gradle_version
  else
    info "${YELLOW} Skipped project file version update, as there was no project type found. Type: ${PROJECT_TYPE} File: ${PROJECT_FILE}${NC}"
  fi

}

move_tag_to_release_commit() {

  local latest_commit
  latest_commit=$(git rev-parse HEAD)

  git tag -f "${NEXT_TAG}" "${latest_commit}" -m "${NEXT_TAG}"
  info "${GREEN} ${CHECKMARK} ${NC} Moved tag ${YELLOW}${NEXT_TAG}${NC} to latest commit ${YELLOW}${latest_commit}${NC}"
}

push_release_commit() {

  if [[ "${INPUT_GIT_BRANCH_NAME}" == "none" ]]; then
    info "${YELLOW}No Git branch was given (option -b | --git-branch-name). Skipping final Git push. ${NC}"
    return 0
  fi

  if [[ -z "${INPUT_GIT_BRANCH_NAME}" ]]; then
    info "${YELLOW}INPUT_GIT_BRANCH_NAME was empty, skipping git push. Set branch with -b/--git-branch-name${NC}"
    return 0
  fi

  #-- we could use --atomic here, but on real life tests traditional pipelines are acting on push OR push tag - not both
  # so...lets do two seperate "events"
  git push origin "${INPUT_GIT_BRANCH_NAME}"
  git push origin "${NEXT_TAG}"

  info "${GREEN} ${CHECKMARK} ${NC} Git pushed tag and release commit to branch ${INPUT_GIT_BRANCH_NAME}"
}

package_lock_exists() {

  if [[ -f "${PROJECT_ROOT_FOLDER}package-lock.json" ]]; then
    echo "exists"
  else
    echo ''
  fi
}

git_add() {
  local addfile=$1
  git add "${addfile}" 1>/dev/null
}

commit_changelog_and_projectfile() {

  local commit_msg="chore: release ${NEXT_TAG}"
  git_add CHANGELOG.md

  if [[ -n "${PROJECT_FILE}" ]]; then

    git_add "${PROJECT_FILE}"

    if [[ "${PROJECT_TYPE}" == 'npm' ]]; then
      local have_package_lock
      have_package_lock=$(package_lock_exists)

      if [[ -n "${have_package_lock}" ]]; then
        git_add "${PROJECT_ROOT_FOLDER}package-lock.json"
      fi
    fi
  fi

  git commit -q --signoff --gpg-sign -m "${commit_msg}"

  if [[ -n ${PROJECT_FILE} ]]; then
    info "${GREEN} ${CHECKMARK} ${NC} Added and committed ${YELLOW}CHANGELOG.md ${PROJECT_FILE}${NC}. Commit message: ${YELLOW}${commit_msg}${NC}"
  else
    info "${GREEN} ${CHECKMARK} ${NC} Added and committed ${YELLOW}CHANGELOG.md${NC}. Commit message: ${YELLOW}${commit_msg}${NC}"
  fi

  move_tag_to_release_commit
  check_interactive "Git push your latest commit (and tag) to remote? (y/n). Would push to origin, branch: ${INPUT_GIT_BRANCH_NAME}: "
  if [[ "${APPLY_ACTION}" == 'y' ]]; then
    push_release_commit
  else
    info "${YELLOW} Skipped git push of changelog and project file!${NC}"
  fi
}

run_() {

  pre_run_validation
  set_project_type_or_guess_from_project_file "${PROJECT_ROOT_FOLDER}"
  calculate_next_version

  check_interactive "Tag the project with calculated Git tag ${NEXT_TAG}? (y/n): "
  if [[ "${APPLY_ACTION}" == 'y' ]]; then
    tag_with_next_version
  else
    info "${YELLOW} Skipped Git tagging!${NC}"
  fi

  check_interactive "Generate a Changelog? (y/n): "
  if [[ "${APPLY_ACTION}" == 'y' ]]; then
    generate_changelog
  else
    info "${YELLOW} Skipped Changelog generation!${NC}"
  fi

  check_interactive "Set the project version to ${NEXT_TAG}? (y/n): "
  if [[ "${APPLY_ACTION}" == 'y' ]]; then
    update_projectfile_version
  else
    info "${YELLOW} Skipped project file version update!${NC}"
  fi

  check_interactive "Commit a release commit with the Changelog and projectfile? (y/n): "
  if [[ "${APPLY_ACTION}" == 'y' ]]; then
    commit_changelog_and_projectfile
  else
    info "${YELLOW} Skipped git commit of changelog and project file!${NC}"
  fi

}

parse_params() {

  local args=("$@")
  local arrlength=${#args[@]}
  #    echo $arrlength
  #[[ arrlength -eq 0 ]] && usage

  for ((var = 0; var < arrlength; var++)); do
    #        echo "${args[$var]}"
    case "${args[$var]}" in
    -h | --help)
      usage
      ;;
    -d | --debug)
      set -x
      ;;
    -t | --next-tag)
      INPUT_TAG="${args[$var + 1]}"
      readonly INPUT_TAG
      var=$var+1
      ;;
    -s | --semver-scope)
      INPUT_SEMVER_SCOPE="${args[$var + 1]}"
      readonly INPUT_SEMVER_SCOPE
      var=$var+1
      ;;
    -p | --project-type)
      INPUT_PROJECT_TYPE="${args[$var + 1]}"
      readonly INPUT_PROJECT_TYPE
      var=$var+1
      ;;
    -b | --git-branch-name)
      INPUT_GIT_BRANCH_NAME="${args[$var + 1]}"
      readonly INPUT_GIT_BRANCH_NAME
      var=$var+1
      ;;
    -r | --repository-url)
      INPUT_REPOURL="${args[$var + 1]}"
      readonly INPUT_REPOURL
      var=$var+1
      ;;
    -i | --interactive)
      INPUT_IS_INTERACTIVE="y"
      readonly INPUT_IS_INTERACTIVE
      ;;
    -?*)
      printf "\n%s\n\n" "${RED}**Unknown option**:${NC} ${args[var]}" && usage && exit 1
      ;;
    *)
      break
      ;;
    esac
  done

  return 0
}

main() {

  is_command_installed "git" "https://git-scm.com/"
  is_command_installed "git-chglog" "https://github.com/git-chglog/git-chglog"
  is_command_installed "npm" "https://github.com/asdf-vm/asdf-nodejs"
  is_command_installed "mvn" "https://github.com/Proemion/asdf-maven"
  is_command_installed "ssh-add" ""

  printf "%s\n" "Running ${GREEN} changelog_tag${NC}... -h or --help for help."
  parse_params "$@"
  run_
}

# Only runs main if not sourced.
# For easier testing with bats
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # abort on unbound variable
  set -o nounset
  if ! main "$@"; then
    exit 1
  fi
fi
