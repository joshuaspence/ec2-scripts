#!/bin/bash

# shellcheck source=lib/common.sh
source "$(dirname "$(readlink --canonicalize "${BASH_SOURCE[0]}")")/common.sh"

readonly INSTANCE_ID="$1"
shift

# Query the specified instance.
readonly INSTANCE=$(
  aws \
    "${AWS_OPTS[@]}" --output json \
    ec2 describe-instances \
    --instance-ids "${INSTANCE_ID}" \
    --query 'Reservations[0].Instances[0]'
  )
readonly HOSTNAME=$(
  echo "${INSTANCE}" \
  | jq \
    --raw-output --exit-status \
    'if .PublicDnsName != "" then .PublicDnsName else .PrivateDnsName end'
)
readonly VPC_ID=$(echo "${INSTANCE}" | jq --raw-output --exit-status '.VpcId')

readonly JUMPHOST=$(find_jumphost "${VPC_ID}")
if [[ -n $JUMPHOST ]]; then
  SSH_OPTS+=("-o ProxyCommand=ssh ${SSH_OPTS[*]} -W %h:%p ${JUMPHOST}")
fi

(( VERBOSE )) && set -x
ssh "${SSH_OPTS[@]}" "${HOSTNAME}" -- "$@"
