#!/bin/bash

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

# Only include running instances.
FILTERS+=('Name=instance-state-name,Values=running')

# shellcheck disable=SC2016,SC2068
aws ${AWS_OPTS[@]} \
  --output table \
  --color off \
  ec2 describe-instances \
  --filters ${FILTERS[@]} \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, "Public IP": PublicIpAddress, "Private IP": PrivateIpAddress, Name: Tags[?Key==`Name`] | [0].Value}' \
| tail --lines=+3
