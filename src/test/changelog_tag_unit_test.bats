# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: MIT

# Bats tests.
# https://github.com/bats-core/bats-core
# Ok, One can argue we test implementation details here (did value X get set and exported),
# but as bash is quite brittle so, we don't give a f:) in this case, this is relevant in bug hunting imho.
# Test various functions.

setup() {

  load './testutils'
  _init_bats

  TEST_TEMP_DIR="$(temp_make)"

  source changelog_tag.sh

  INPUT_TAG=''

}

function is_command_installed_fails_without_command_installed_or_success_if_command_found { #@test

  run is_command_installed "a non existing program" "linke"
  assert_failure

  run is_command_installed "cat"
  assert_success
}

function is_command_runnable_fails_without_command_runnable_or_success_if_command_found { #@test

  mocko() {
    echo "No version is set"
  }

  run is_command_runnable "mocko" "linke"
  assert_failure

  run is_command_runnable "macko"
  assert_success
}

function validate_and_split_semver() { #@test

  run validate_and_split_semver 'v1.2.3'
  assert_success

  run validate_and_split_semver 'tag'
  assert_output --partial "Tag tag is invalid semver"
  assert_failure
}

function validate_input_validate_and_split_semver_if_input_tag_or_if_empty_tag_dont_validate() { #@test

  git() {
    echo "a_branch_name"
  }

  validate_and_split_semver() {
    printf "%s" "validating semver"
  }

  local INPUT_GIT_BRANCH_NAME=$(git)
  local INPUT_TAG='1.2.3'

  run validate_input
  assert_output --partial 'validating semver'
  assert_success

  INPUT_TAG=
  run validate_input
  refute_output --partial 'validating semver'
  assert_success

}

function validate_input_git_check_success_on_same_branchnames_but_fails_on_branch_different_branchnames { #@test

  git() {
    echo "a_branch_name"
  }

  local INPUT_GIT_BRANCH_NAME=$(git)

  #with default branch_name ("a_branch_name")
  run validate_input
  assert_success

  # diffing branchnames
  INPUT_GIT_BRANCH_NAME="another_branch_name"

  run validate_input
  assert_output --partial 'You are running the script from checkout branch'
  assert_failure

}

function calculate_next_version_exits_if_input_tag_is_set() { #@test

  INPUT_TAG='7.8.9'
  local NEXT_TAG=''

  calculate_next_version
  assert_equal "$NEXT_TAG" "$INPUT_TAG"

}

function calculate_next_version_gets_latest_tag_if_no_tags_given() { #@test

  # git tag exists
  git() {
    echo "v0.0.3"
  }

  calculate_next_version
  assert_equal "$NEXT_TAG" "v0.0.4"

}

function calculate_next_version_sets_default_tag_if_no_tags_found() { #@test
  # sets a default tag

  git() {
    echo ''
  }
  validate_and_split_semver() {
    echo "in_validate $@"
  }
  run calculate_next_version

  assert_output --partial "Could not find any existing tags in project. Default return v0.0.1"

}

function tag_with_next_version_success_and_fail_test() { #@test
  # sets a default tag
  git() {
    return 0
  }

  local NEXT_TAG='next_tag'

  run tag_with_next_version
  assert_output --partial "Tagged (signed): ${YELLOW}next_tag${NC}"
  assert_success

  git() {
    echo "errs"
  }

  run tag_with_next_version
  assert_output --partial "Something went wrong"
  assert_failure

}

function generate_changelog_success() { #@test

  git() {
    echo "http://a.b.git"
  }
  git-chglog() {
    echo "$@"
  }

  run generate_changelog
  assert_output --partial 'repository-url http://a.b'
  assert_output --partial 'git-chglog-gl.yml -o CHANGELOG.md'
  assert_output --partial "Generated changelog as ${YELLOW}./CHANGELOG.md${NC}"
  assert_success

}

function generate_changelog_autoscrub_basic_auth_success() { #@test
  # secretlint-disable
  git() {
    echo "https://basic:auth@a.b.git"
  }
  git-chglog() {
    echo "$@"
  }

  # secretlint-enable
  run generate_changelog
  assert_output --partial 'repository-url https://a.b'
  assert_output --partial 'git-chglog-gl.yml -o CHANGELOG.md'
  assert_output --partial "Generated changelog as ${YELLOW}./CHANGELOG.md${NC}"
  assert_success
}

function update_npm_success() { #@test

  npm() {
    echo "mocknpm $@"
  }

  local NEXT_TAG='next_tag'

  run update_npm_version

  assert_output --partial 'mocknpm --no-git-tag-version --allow-same-version version next_tag'
  assert_success

}

function update_pom_success() { #@test

  mvn() {
    echo "mockmvn $@"
  }

  local NEXT_TAG='next_tag'

  run update_pom_version

  assert_output --partial 'mockmvn -q versions:set -DnewVersion=next_tag'
  assert_success

}

function update_gradle_success() { #@test

  sed() {
    echo "mocksed $@"
  }

  local NEXT_TAG='next_tag'

  run update_gradle_version

  assert_output --partial 'mocksed -i -E s/version=.+/version=next_tag/g gradle.properties'
  assert_success

}

function update_projectfile_version_chooses_pom_or_package_correctly() { #@test

  echo "${TEST_TEMP_DIR}"

  update_pom_version() {
    echo "mock_update_pom_version"
  }

  update_npm_version() {
    echo "mock_update_npm_version"
  }

  update_gradle_version() {
    echo "mock_update_gradle_version"
  }

  # Could not decide project type

  local project_file_path="${TEST_TEMP_DIR}"
  local mvnfile="${project_file_path}/pom.xml"
  local npmfile="${project_file_path}/package.json"
  local gradlefile="${project_file_path}/gradle.properties"

  run update_projectfile_version
  assert_success

  touch "${TEST_TEMP_DIR}/pom.xml"

  # A pom file found
  PROJECT_FILE="${mvnfile}"
  PROJECT_TYPE='mvn'
  run update_projectfile_version
  assert_output --partial 'mock_update_pom_version'
  assert_success

  rm "${TEST_TEMP_DIR}/pom.xml"
  touch "${TEST_TEMP_DIR}/package.json"

  PROJECT_FILE="${npmfile}"
  PROJECT_TYPE='npm'
  # A package json file found
  run update_projectfile_version
  assert_output --partial 'mock_update_npm_version'
  assert_success

  rm "${TEST_TEMP_DIR}/package.json"
  touch "${TEST_TEMP_DIR}/gradle.properties"

  PROJECT_FILE="${gradlefile}"
  PROJECT_TYPE='gradle'
  # A gradle properties file found
  run update_projectfile_version
  assert_output --partial 'mock_update_gradle_version'
  assert_success

  rm "${TEST_TEMP_DIR}/gradle.properties"

  PROJECT_FILE=''
  PROJECT_TYPE=''
  #Input project file given
  local INPUT_PROJECT_TYPE=''

  # TODO:Could not decide project type, multiple gradle pom and package.json same dir, fail
  run update_projectfile_version
  assert_output --partial "${YELLOW} Skipped project file version update, as there"
  #assert_output --partial 'Could not find project file for project type ?'
  #assert_failure
  #
}

function commit_changelog_and_projectfile_triggers_git_calls_with_correct_variables() { #@test

  local NEXT_TAG='testtag'
  local PROJECT_FILE='testfilename'
  local commit_msg="chore: release ${NEXT_TAG}"

  git() {
    echo "gitmock: arguments: $@"
  }
  move_tag_to_release_commit() {
    return 0

  }

  run commit_changelog_and_projectfile
  assert_output --partial "Added and committed ${YELLOW}CHANGELOG.md testfilename${NC}. Commit message: ${YELLOW}chore: release testtag${NC}"
  assert_output --partial "gitmock: arguments: commit -q --signoff --gpg-sign -m ${commit_msg}"
  assert_success
}

function move_tag_to_release_commit_triggers_git_correct_git_calls_with_correct_parameters() { #@test

  local NEXT_TAG='testtag'

  git() {
    echo ''
  }

  run move_tag_to_release_commit
  assert_output --partial "Moved tag ${YELLOW}testtag${NC} to latest commit ${YELLOW}${NC}"

}

function push_release_commit_with_tag_and_branchname_if_arguments_set() { #@test

  local NEXT_TAG='testtag'
  local INPUT_GIT_BRANCH_NAME=

  git() {
    echo "gitmock: arguments: $@"
  }

  run push_release_commit
  assert_output --partial "was empty"
  assert_success

  INPUT_GIT_BRANCH_NAME='branchname'
  run push_release_commit

  assert_output --partial "gitmock: arguments: push origin branchname"
  assert_output --partial "gitmock: arguments: push origin testtag"
  assert_success

}
