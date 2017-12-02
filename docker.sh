#!/bin/bash
#
# This file is largely cargo-culted from cockroachdb/cockroach/build/builder.sh.

set -euo pipefail

DOCKER_IMAGE_TAG=activerecord_test_container

# Build the docker image to use.
docker build -t ${DOCKER_IMAGE_TAG} build/

# Absolute path to this repository.
repo_root=$(cd "$(dirname "${0}")" && pwd)

# Make a fake passwd file for the invoking user.
#
# This setup is so that files created from inside the container in a mounted
# volume end up being owned by the invoking user and not by root.
# We'll mount a fresh directory owned by the invoking user as /root inside the
# container because the container needs a $HOME (without one the default is /)
# and because various utilities (e.g. bash writing to .bash_history) need to be
# able to write to there.
username=$(id -un)
uid_gid=$(id -u):$(id -g)
container_root=${repo_root}/docker_root
mkdir -p "${container_root}"/{etc,home,home/"${username}"/activerecord-cockroachdb-adapter,home/.gems}
echo "${username}:x:${uid_gid}::/home/${username}:/bin/bash" > "${container_root}/etc/passwd"

docker run \
  --volume="${container_root}/etc/passwd:/etc/passwd" \
  --volume="${container_root}/home/${username}:/home/${username}" \
  --volume="${repo_root}:/home/${username}/activerecord-cockroachdb-adapter" \
  --workdir="/home/${username}/activerecord-cockroachdb-adapter" \
  --env=PIP_USER=1 \
  --env=GEM_HOME="/home/${username}/.gems" \
  --user="${uid_gid}" \
  "${DOCKER_IMAGE_TAG}" \
  "$@"
