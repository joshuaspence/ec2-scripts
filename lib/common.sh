#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

AWS_OPTS=()
FILTERS=()
VERBOSE=0

eval set -- "$(getopt --longoptions aws-profile:,aws-region:,verbose --longoptions "${OPTIONS:=}" --name "$0" --options '' -- "$@")"

while true; do
  case $1 in
    --aws-*)
      AWS_OPTS+=("--${1#--aws-}=${2}")
      shift 2
      ;;

    --verbose)
      # shellcheck disable=SC2034
      VERBOSE=1
      shift
      ;;

    # Just assume that any other provided flag, which isn't prefixed with
    # `aws-`, is a tag filter.
    --?*)
      FILTERS+=("Name=tag:${1#--},Values=${2}")
      shift 2
      ;;

    --)
      shift
      break
      ;;

    *)
      echo "Not implemented: $1" >&2
      exit 1
      ;;
  esac
done

if [[ ${#AWS_OPTS[@]} == 0 ]]; then
  echo 'No AWS options were specified.' >&2
  exit 1
fi

# Only include running instances.
FILTERS+=('Name=instance-state-name,Values=running')

# Set common SSH options.
SSH_OPTS=()
SSH_OPTS+=('-o LogLevel=ERROR')
SSH_OPTS+=('-o StrictHostKeyChecking=no')
SSH_OPTS+=('-o UserKnownHostsFile=/dev/null')

# Find a jumphost for the specified VPC.
#
# TODO: This would be easier if `aws elb describe-load-balancers` provided a
# `--filters` flag, similar to `aws ec2 describe-instances`.
function find_jumphost {
  if [[ -z $1 ]]; then
    return
  fi

  local -r JUMPHOST_SG=$(
    aws \
      "${AWS_OPTS[@]}" --output text \
      ec2 describe-security-groups \
      --filters \
        'Name=tag:Name,Values=jumphost_lb' \
        'Name=tag:role,Values=jumphost' \
        "Name=vpc-id,Values=${1}" \
      --query 'SecurityGroups[0].GroupId'
  )

  aws \
    "${AWS_OPTS[@]}" --output json \
    elb describe-load-balancers \
    | jq \
      --arg jumphost_sg "${JUMPHOST_SG}" \
      --raw-output --exit-status \
      '.LoadBalancerDescriptions[] | select(.SecurityGroups[] | contains($jumphost_sg)) | .DNSName'
}
