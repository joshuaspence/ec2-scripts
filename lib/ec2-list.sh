#!/bin/bash

# shellcheck source=lib/common.sh
OPTIONS='environment:,product:,profile:,role:,stack:'
source "$(dirname "$(readlink --canonicalize "${BASH_SOURCE[0]}")")/common.sh"

# shellcheck disable=SC2016
aws "${AWS_OPTS[@]}" \
  --output table \
  --color off \
  ec2 describe-instances \
  --filters "${FILTERS[@]}" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId, "Public IP": PublicIpAddress, "Private IP": PrivateIpAddress, Name: Tags[?Key==`Name`] | [0].Value}' \
| tail --lines=+3
