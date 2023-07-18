# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: MIT

# Bats tests.
# https://github.com/bats-core/bats-core
#
# Tests that the user input sets correct flags

function changelog_tag_mock_base_setup() {

  command() {
    echo "/usr/bin/ls"
  }

  npm() {
    echo "mock npm with arg $*"

  }
  git() {
    echo "mock git with arg $*"

  }
  mvn() {
    echo "mock mvn with arg $*"

  }

  export -f command
  export -f npm
  export -f git
  export -f mvn

}

setup() {

  load './testutils'
  _init_bats

  source changelog_tag.sh
  changelog_tag_mock_base_setup
}

function help_flag_outputs_usage { #@test

  run parse_params -h
  assert_output --partial "changelog_tag is a glue"
  assert_success

  run parse_params --help

  assert_output --partial "changelog_tag is a glue"
  assert_success
}

function semver_scope_flag_is_set { #@test

  local INPUT_SEMVER_SCOPE=''

  parse_params -s 'scope'

  assert_equal 'scope' "${INPUT_SEMVER_SCOPE}"

}

function semver_scope_long_flag_is_set { #@test

  local INPUT_SEMVER_SCOPE=''

  parse_params --semver-scope 'another_semverscope'

  assert_equal 'another_semverscope' "${INPUT_SEMVER_SCOPE}"

}

function next_tag_flag_is_set { #@test

  local INPUT_TAG=''

  parse_params -t 'set_tag'

  assert_equal 'set_tag' "${INPUT_TAG}"

}

function next_tag_long_flag_is_set { #@test

  local INPUT_TAG=''

  parse_params --next-tag 'set_long_tag'

  assert_equal 'set_long_tag' "${INPUT_TAG}"

}

function project_type_flag_is_set { #@test

  local INPUT_PROJECT_TYPE=''
  parse_params -p 'mvn'

  assert_equal 'mvn' "${INPUT_PROJECT_TYPE}"

}

function project_type_long_flag_is_set { #@test

  local INPUT_PROJECT_TYPE=''
  parse_params --project-type 'mvn'

  assert_equal 'mvn' "${INPUT_PROJECT_TYPE}"

}

function git_branch_name_flag_is_set { #@test

  local INPUT_GIT_BRANCH_NAME=''

  parse_params -b 'branch'

  assert_equal 'branch' "${INPUT_GIT_BRANCH_NAME}"

}

function git_branch_name_long_flag_is_set { #@test

  local INPUT_GIT_BRANCH_NAME=''

  parse_params --git-branch-name 'long_branch'

  assert_equal 'long_branch' "${INPUT_GIT_BRANCH_NAME}"

}

function interactive_flag_is_set { #@test

  local INPUT_IS_INTERACTIVE=''

  parse_params --interactive

  assert_equal 'y' "${INPUT_IS_INTERACTIVE}"

}

function repourl_is_set { #@test

  local INPUT_REPOURL=''

  parse_params --repository-url 'https://github.com/test'

  assert_equal 'https://github.com/test' "${INPUT_REPOURL}"

}

function unknown_flag_shows_usage() { #@test

  run parse_params -z
  assert_output --partial "changelog_tag is a glue"
  assert_success

}

function all_flags_are_set() { #@test

  local INPUT_TAG=''
  local INPUT_SEMVER_SCOPE=''
  local INPUT_PROJECT_TYPE=''
  local INPUT_GIT_BRANCH_NAME=''
  local INPUT_IS_INTERACTIVE=''
  local INPUT_REPOURL=''

  parse_params -s 'scope' -t 'tag' -p 'type' -b 'branch' --interactive --repository-url 'https://github.com/justtesting'

  assert_equal 'tag' "${INPUT_TAG}"
  assert_equal 'scope' "${INPUT_SEMVER_SCOPE}"
  assert_equal 'type' "${INPUT_PROJECT_TYPE}"
  assert_equal 'branch' "${INPUT_GIT_BRANCH_NAME}"
  assert_equal 'y' "${INPUT_IS_INTERACTIVE}"
  assert_equal 'https://github.com/justtesting' "${INPUT_REPOURL}"

}
