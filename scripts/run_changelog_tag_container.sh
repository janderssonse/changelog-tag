#!/usr/bin/env bash

# SPDX-FileCopyrightText: Josef Andersson
#
# SPDX-License-Identifier: CC0-1.0

# This scripts mounts and runs changelog_tag image.
# As we mount just about everything regarding ssl, and network host, use on your own risk
# or improve this solution :)

ARGS="$1"                          #List of args, example: '--interactive --semver patch'
REPO_PATH="$2"                     #FULL PATH to the Repo you are working on, default current dir
GITCONFIG="${3:-$HOME/.gitconfig}" #FULL PATH to your gitconfig, defaults to $HOME/gitconfig

if [[ -z "${REPO_PATH}" ]]; then
  REPO_PATH=$(pwd)
fi

printf "%s\n" "Choosen repo path: ${REPO_PATH}"

printf "%s\n" "Choosen git config path: ${GITCONFIG}"

docker run --env ARGS="${ARGS}" --volume "${GITCONFIG}":/etc/gitconfig:ro \
  --volume ~/.ssh/known_hosts:/etc/ssh/ssh_known_hosts:ro \
  --user "$UID":"$GID" --network host \
  --workdir="/app/repo" \
  --volume="/etc/group:/etc/group:ro" \
  --volume="/etc/passwd:/etc/passwd:ro" \
  --volume="/etc/shadow:/etc/shadow:ro" \
  --volume="$HOME/.m2/repository:/app/.m2/repository:ro" \
  -v "${REPO_PATH}":/app/repo \
  -v "$SSH_AUTH_SOCK:$SSH_AUTH_SOCK" \
  -e SSH_AUTH_SOCK="${SSH_AUTH_SOCK}" \
  --rm -it ghcr.io/janderssonse/changelog_tag:latest
