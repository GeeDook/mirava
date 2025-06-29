#!/usr/bin/env bash
set -euo pipefail

# Requirements: yq, curl, dig or getent

MIRROR_FILE="mirrors_list.yaml"

# Check dependencies
if ! command -v yq &>/dev/null; then
  echo "Error: 'yq' is not installed."
  exit 1
fi
if ! command -v curl &>/dev/null; then
  echo "Error: 'curl' is not installed."
  exit 1
fi

# Check for DNS resolver command
if command -v dig &>/dev/null; then
  DNS_CMD="dig +short"
elif command -v getent &>/dev/null; then
  DNS_CMD="getent hosts"
else
  echo "Error: neither 'dig' nor 'getent' found for DNS resolution."
  exit 1
fi

# Get number of mirrors in the YAML file
mirror_count=$(yq e '.mirrors | length' "$MIRROR_FILE")

# Function to check a single mirror
check_mirror() {
  local idx=$1
  local name url domain ip http_status reachable

  # Extract mirror name and URL from the YAML file
  name=$(yq e ".mirrors[$idx].name" "$MIRROR_FILE")
  url=$(yq e ".mirrors[$idx].url" "$MIRROR_FILE")

  # Extract domain from URL for DNS resolution
  domain=$(echo "$url" | awk -F/ '{print $3}')

  # Resolve IP address using dig or getent
  if [[ $DNS_CMD == "dig +short" ]]; then
    ip=$($DNS_CMD "$domain" | head -n1)
  else
    ip=$($DNS_CMD "$domain" | awk '{print $1}' | head -n1)
  fi

  # If IP is empty, mark as unavailable
  if [[ -z "$ip" ]]; then
    ip="Unavailable"
  fi

  # Try HTTP request to get status code (with 10 seconds timeout)
  http_status=$(curl -sL --max-time 10 -o /dev/null -w "%{http_code}" "$url") || http_status="000"

  # If initial curl fails, retry with --insecure to skip SSL certificate errors
  if [[ "$http_status" == "000" ]]; then
    http_status=$(curl -sL --insecure --max-time 10 -o /dev/null -w "%{http_code}" "$url") || http_status="000"
  fi

  # Determine reachability based on HTTP status
  if [[ "$http_status" == "000" ]]; then
    reachable="Unreachable or HTTP error"
  else
    reachable="Reachable (HTTP $http_status)"
  fi

  # Print results (suitable for Persian terminals, no emojis)
  echo "Mirror Name: $name"
  echo "URL: $url"
  echo "IP: $ip"
  echo "Status: $reachable"
  echo "-----------------------------"
}

export -f check_mirror
export MIRROR_FILE
export DNS_CMD

# Run mirror checks in parallel, max 5 at a time for speed
pids=()
for ((i=0; i<mirror_count; i++)); do
  check_mirror "$i" &
  pids+=($!)
  if (( ${#pids[@]} >= 5 )); then
    wait "${pids[0]}"
    pids=("${pids[@]:1}")
  fi
done

# Wait for any remaining jobs to finish
wait

exit 0
