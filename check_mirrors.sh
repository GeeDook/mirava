#!/usr/bin/env bash
set -euo pipefail

MIRROR_FILE="./mirrors_list.yaml"

declare -A PACKAGE_PATHS=(
  ["Ubuntu"]="ubuntu"
  ["Debian"]="debian"
  ["Arch Linux"]="archlinux"
  ["PyPI"]="pypi"
  ["npm"]="npm"
  ["CentOS"]="centos"
  ["Alpine"]="alpine"
  ["Composer"]="packages.json"
  ["Docker Registry"]="v2/"
  ["Homebrew"]="brew"
)

function check_url() {
  local url=$1
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url")
  echo "$status"
}

function check_docker_registry() {
  local url=$1
  # Docker Registry requires a GET to /v2/ and must respond with 200 or 401
  status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url/v2/")
  if [[ "$status" == "200" || "$status" == "401" ]]; then
    echo "✅ Docker Registry OK ($status)"
  else
    echo "❌ Docker Registry Failed ($status)"
  fi
}

for idx in $(seq 0 $(yq e '.mirrors | length - 1' "$MIRROR_FILE")); do
  name=$(yq e ".mirrors[$idx].name" "$MIRROR_FILE")
  base_url=$(yq e ".mirrors[$idx].url" "$MIRROR_FILE")
  echo -e "\n🔍 Checking mirror: $name"
  echo "URL: $base_url"

  package_count=$(yq e ".mirrors[$idx].packages | length" "$MIRROR_FILE")

  for j in $(seq 0 $((package_count - 1))); do
    package=$(yq e ".mirrors[$idx].packages[$j]" "$MIRROR_FILE")
    path=${PACKAGE_PATHS[$package]:-}

    if [[ "$package" == "Docker Registry" ]]; then
      check_docker_registry "$base_url"
    elif [[ -n "$path" ]]; then
      full_url="$base_url/$path"
      status=$(check_url "$full_url")
      if [[ "$status" == "200" || "$status" == "301" || "$status" == "302" ]]; then
        echo "✅ $package -> $full_url ($status)"
      else
        echo "❌ $package -> $full_url ($status)"
      fi
    else
      echo "⚠️ Unknown package type: $package"
    fi
  done

  echo "----------------------------"
done
