#!/bin/bash

_ec2_completions() {
  # shellcheck disable=SC2034
  local cur cword flags prev split words
  _init_completion -s || return

  flags=(--aws-profile --aws-region --verbose)

  case "${1}" in
    ec2-list) ;&
    ec2-pssh)
      flags+=(--environment --product --profile --role --stack)
      ;;
  esac

  case "${cur,,}" in
    --*)
      COMPREPLY+=($(compgen -W "${flags[*]}" -- "${COMP_WORDS[COMP_CWORD]}"))
      ;;
  esac

  case "${prev,,}" in
    --aws-profile)
      COMPREPLY+=($(compgen -W "$(_aws_profiles)" -- "${words[cword]}"))
      ;;

    --aws-region)
      COMPREPLY+=($(compgen -W "$(_aws_regions)" -- "${words[cword]}"))
      ;;
  esac
}

_aws_profiles() {
  sed --quiet --regexp-extended 's/^\[(.*)\]$/\1/p' ~/.aws/credentials
}

# See https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/Concepts.RegionsAndAvailabilityZones.html
_aws_regions() {
  if ! test -f ~/.aws/regions; then
    aws --profile "$(_aws_profiles | head --lines=1)" --region us-east-1 ec2 describe-regions | jq --raw-output '.Regions[].RegionName' > ~/.aws/regions
  fi

  cat ~/.aws/regions
}

complete -F _ec2_completions ec2-list
complete -F _ec2_completions ec2-pssh
complete -F _ec2_completions ec2-rsync
complete -F _ec2_completions ec2-ssh
