#!/bin/bash
# shellcheck disable=SC2068

set -o errexit
set -o nounset
set -o pipefail

AWS_OPTS=()
FILTERS=()

# Read command-line flags.
eval set -- "$(getopt --longoptions aws-profile:,aws-region:,environment:,product:,profile:,role:,stack: --name "$0" --options '' -- "$@")"

while true; do
  case $1 in
    --aws-*)
      AWS_OPTS+=("--${1#--aws-} ${2}")
      shift 2
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

if [[ ${#FILTERS[@]} == 0 ]]; then
  echo 'No filters were specified.' >&2
  exit 1
fi

# Ensure that AWS CLI outputs JSON.
AWS_OPTS+=('--output json')

# Only include running instances.
FILTERS+=('Name=instance-state-name,Values=running')

echo -e 'Instance ID\t\tPublic IP\tPrivate IP\tName'
aws ${AWS_OPTS[@]} ec2 describe-instances --filters ${FILTERS[@]} | \
jq --raw-output --exit-status '.Reservations[].Instances[] | "\(.InstanceId)\t\(if .PublicIpAddress != null then .PublicIpAddress else "N/A            " end)\t\(.PrivateIpAddress)\t\(.Tags[] | select(.Key == "Name") | .Value)"'
