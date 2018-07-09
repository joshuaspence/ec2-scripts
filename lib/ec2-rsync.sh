#!/bin/bash

# shellcheck source=lib/common.sh
source "$(dirname "$(readlink --canonicalize "${BASH_SOURCE[0]}")")/common.sh"

# TODO: This seems rather hacky.
for ii in "${!AWS_OPTS[@]}"; do
  AWS_OPTS[$ii]="--aws-${AWS_OPTS[$ii]#--}"
done

# Find the path to `ec2-ssh`.
readonly EC2_SSH=$(readlink --canonicalize "$(dirname "${BASH_SOURCE[0]}")/../bin/ec2-ssh")

(( VERBOSE )) && set -x
rsync \
  --archive \
  --delete \
  --rsh "${EC2_SSH} ${AWS_OPTS[*]} --" \
  --rsync-path 'sudo rsync' \
  --compress \
  "$@"
