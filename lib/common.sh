#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

AWS_OPTS=()
FILTERS=()

eval set -- "$(getopt --longoptions aws-profile:,aws-region: --longoptions "${OPTIONS:=}" --name "$0" --options '' -- "$@")"

while true; do
  case $1 in
    --aws-*)
      AWS_OPTS+=("--${1#--aws-}=${2}")
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

if [[ ${#AWS_OPTS[@]} == 0 ]]; then
  echo 'No AWS options were specified.' >&2
  exit 1
fi
