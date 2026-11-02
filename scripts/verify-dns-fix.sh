#!/usr/bin/env bash
# Read-only verification of the reported Waydroid hosts-file workaround.
set -u

expected_ip="192.168.240.1"
hostname="waydroid"
hosts_file="/etc/hosts"

printf 'Checking %s resolution...\n' "$hostname"

if ! command -v getent >/dev/null 2>&1; then
  echo "ERROR: getent is not installed; cannot verify name resolution." >&2
  exit 2
fi

resolved="$(getent ahostsv4 "$hostname" 2>/dev/null | awk 'NR == 1 { print $1 }')"

if [[ -z "$resolved" ]]; then
  echo "FAIL: $hostname did not resolve to an IPv4 address."
  exit 1
fi

printf 'Resolved address: %s\n' "$resolved"

if [[ "$resolved" != "$expected_ip" ]]; then
  printf 'FAIL: expected %s, got %s.\n' "$expected_ip" "$resolved"
  exit 1
fi

if [[ ! -r "$hosts_file" ]]; then
  printf 'WARNING: %s is not readable; resolution succeeded, but hosts entry cannot be checked.\n' "$hosts_file"
  exit 0
fi

if ! awk -v ip="$expected_ip" -v host="$hostname" '
  $1 == ip {
    for (i = 2; i <= NF; i++) {
      if ($i == host) found = 1
    }
  }
  END { exit(found ? 0 : 1) }
' "$hosts_file"; then
  printf 'WARNING: no exact "%s %s" mapping found in %s.\n' "$expected_ip" "$hostname" "$hosts_file"
  echo "The name may be resolving through another DNS source."
  exit 1
fi

printf 'PASS: %s resolves to %s and the matching hosts-file entry exists.\n' "$hostname" "$expected_ip"
