#!/usr/bin/env bash
set -euo pipefail

# Script to track changes in the set of users (and their home directories)
# as reported by ./list_users.sh on a Linux system.

USERS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USERS_SCRIPT="$USERS_SCRIPT_DIR/list_users.sh"

CURRENT_USERS_FILE="/var/log/current_users"
USER_CHANGES_FILE="/var/log/user_changes"

if [[ ! -x "$USERS_SCRIPT" ]]; then
  echo "Error: $USERS_SCRIPT is not executable or not found" >&2
  exit 1
fi

# Generate current MD5 checksum of the users list
CURRENT_HASH="$($USERS_SCRIPT | sort | md5sum | awk '{print $1}')"

# If /var/log/current_users does not exist, initialize it and exit
if [[ ! -f "$CURRENT_USERS_FILE" ]]; then
  echo "$CURRENT_HASH" > "$CURRENT_USERS_FILE"
  exit 0
fi

OLD_HASH="$(cat "$CURRENT_USERS_FILE" 2>/dev/null || true)"

if [[ "$CURRENT_HASH" != "$OLD_HASH" ]]; then
  # Log the change with DATE TIME and update current_users
  NOW="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$NOW changes occurred" >> "$USER_CHANGES_FILE"
  echo "$CURRENT_HASH" > "$CURRENT_USERS_FILE"
fi
