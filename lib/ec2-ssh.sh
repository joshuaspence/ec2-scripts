#!/bin/bash

# shellcheck source=lib/common.sh
source "$(dirname "$(readlink --canonicalize "${BASH_SOURCE[0]}")")/common.sh"

if [[ $# != 1 ]]; then
  echo 'Exactly one instance ID must be specified.' >&2
  exit 1
fi

SSH_OPTS=()
SSH_OPTS+=('-o LogLevel=ERROR')
SSH_OPTS+=('-o StrictHostKeyChecking=no')
SSH_OPTS+=('-o UserKnownHostsFile=/dev/null')

# Query the specified instance.
readonly INSTANCE=$(aws "${AWS_OPTS[@]}" --output json ec2 describe-instances --instance-ids "$1" --query 'Reservations[0].Instances[0]')
readonly HOSTNAME=$(echo "${INSTANCE}" | jq --raw-output --exit-status 'if .PublicDnsName != "" then .PublicDnsName else .PrivateDnsName end')

# Discover the VPC jumphost.
#
# TODO: This would be easier if `aws elb describe-load-balancers` provided a
# `--filters` flag, similar to `aws ec2 describe-instances`.
readonly VPC_ID=$(echo "${INSTANCE}" | jq --raw-output --exit-status '.VpcId')
readonly JUMPHOST_SG=$(aws "${AWS_OPTS[@]}" --output text ec2 describe-security-groups --filters 'Name=tag:Name,Values=jumphost_lb' 'Name=tag:role,Values=jumphost' "Name=vpc-id,Values=${VPC_ID}" --query 'SecurityGroups[0].GroupId')
readonly JUMPHOST=$(aws "${AWS_OPTS[@]}" --output json elb describe-load-balancers | jq --arg jumphost_sg "${JUMPHOST_SG}" --raw-output --exit-status '.LoadBalancerDescriptions[] | select(.SecurityGroups[] | contains($jumphost_sg)) | .DNSName')
if [[ -n $JUMPHOST ]]; then
  SSH_OPTS+=("-o ProxyCommand=ssh ${SSH_OPTS[*]} -W %h:%p ${JUMPHOST}")
fi

set -x
# shellcheck disable=SC2029
ssh "${SSH_OPTS[@]}" "${HOSTNAME}"
