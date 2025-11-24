#!/usr/bin/env bash
set -euo pipefail

# Print usernames and home directories
# Uses `getent passwd` when available; falls back to reading /etc/passwd

if command -v getent >/dev/null 2>&1; then
  DATA_SOURCE="getent passwd"
elif [[ -r /etc/passwd ]]; then
  DATA_SOURCE="cat /etc/passwd"
else
  echo "Error: Could not read user database (no getent and /etc/passwd not readable)." >&2
  exit 1
fi

# Output format: username<TAB>home_directory
if [[ "$(uname -s)" == "Darwin" ]]; then
  # macOS: query Open Directory via dscacheutil
  # Fields of interest: name: <username>, uid: <uid>, dir: <home_directory>
  # Filter out system users: names starting with '_' or low UIDs (< 500)
  dscacheutil -q user | awk '
    /^name:/ {name=$2}
    /^uid:/  {uid=$2}
    /^dir:/  {
      dir=$2;
      if (name != "" && dir != "" && uid >= 500 && name !~ /^_/) {
        print name ":" dir;
      }
      name=""; dir=""; uid="";
    }
  '
else
  # Linux/Unix: use getent/passwd and extract username (field1) and home (field6)
  # Filter out system users: names starting with '_'
  bash -c "$DATA_SOURCE" | awk 'BEGIN{FS=":"} $0 !~ /^#/ && NF >= 6 && $1 != "" && $6 != "" && $1 !~ /^_/ {print $1 ":" $6}'
fi
