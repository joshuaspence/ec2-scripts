#!/bin/bash

# shellcheck source=lib/common.sh
OPTIONS='environment:,product:,profile:,role:,stack:'
source "$(dirname "$(readlink --canonicalize "${BASH_SOURCE[0]}")")/common.sh"

if [[ $# == 0 ]]; then
  echo 'No command was specified.' >&2
  exit 1
fi

# Query the specified instances.
readonly INSTANCES=$(
  aws \
    "${AWS_OPTS[@]}" --output json \
    ec2 describe-instances \
    --filters "${FILTERS[@]}" \
    --query 'Reservations[*].Instances[0]'
  )

# Ensure that all instances are in the same VPC.
mapfile -t VPC_ID < <(
  echo "${INSTANCES}" \
  | jq \
    --raw-output --exit-status \
    '.[].VpcId' \
  | sort \
  | uniq
)
if [[ ${#VPC_ID[@]} -gt 1 ]]; then
  echo 'Instances must all reside in the same VPC.' >&2
  exit 1
fi

PSSH_OPTS=()
PSSH_OPTS+=('--timeout=0')

PSSH_OPTS+=('--option=LogLevel=ERROR')
PSSH_OPTS+=('--option=StrictHostKeyChecking=no')
PSSH_OPTS+=('--option=UserKnownHostsFile=/dev/null')

readonly JUMPHOST=$(find_jumphost "${VPC_ID[0]}")
if [[ -n $JUMPHOST ]]; then
  PSSH_OPTS+=("--option=ProxyCommand=ssh ${SSH_OPTS[*]} -W %h:%p ${JUMPHOST}")
fi

# shellcheck disable=SC2207
HOSTS=($(
  echo "${INSTANCES}" \
  | jq \
    --raw-output --exit-status \
    '.[] | "--host=" + if .PublicDnsName != "" then .PublicDnsName else .PrivateDnsName end'
))

set -x
pssh \
  "${HOSTS[@]}" \
  --timeout=0 \
  "${PSSH_OPTS[@]}" \
  --verbose \
  --inline \
  -- \
  "$@"
