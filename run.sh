#!/bin/bash
# shellcheck disable=1090

set -e

function _env {
  local env
  local splitted_envs=""

  if [[ -n "$1" ]]; then
    env="$1"
  elif [[ -e .env ]]; then
    env=".env"
  fi

  if [[ -n "$env" ]]; then
    set -a
    . $env
    set +a

    splitted_envs=$(splitenvs "$env" --lines)
  fi

  printf "%s" "$splitted_envs"
}

function _timestamp {
  date +'%s'
}

function _raise_on_no_env_file {
  if [[ -n "$DOCKER_ENV_FILE" ]]; then
    return 0
  fi

  if [[ -z "$1" ]] || [[ ! -e "$1" ]]; then
    printf "\nenv filename has not been provided or invalid.\n"
    printf "You may also source your environment file.\n\n"
    exit 1
  fi
}

function cert {
  : "Generate certificate for use with HTTPS"

  _raise_on_no_env_file "$@"

  _env "$1"

  local path
  path="$(_timestamp)"

  mkdir -p "$path"
  rm -rf certs && mkdir -p certs

  cd "$path"

  mkcert -install "${DOMAIN}"

  cd -

  find "./$path" -type f -name "*.pem" -exec mv {} certs \;
  rm -rf "./$path"

  printf "127.0.0.1 %s\n" "$DOMAIN" | sudo tee -a /etc/hosts
}

function dev {
  : "Start docker compose services required for development"

  _raise_on_no_env_file "$@"

  _env "$1"

  local services="mysql app ng p-admin mail"

  clear

  # shellcheck disable=2086
  docker compose up -d $services &&
    docker compose logs -f $services
}

function help {
  : "List available tasks."
  compgen -A function | grep -v "^_" | while read -r name; do
    paste <(printf '%s' "$name") <(type "$name" | sed -nEe 's/^[[:space:]]*: ?"(.*)";/    \1/p')
  done

  printf "\n"
}

TIMEFORMAT="Task completed in %3lR"
time "${@:-help}"
