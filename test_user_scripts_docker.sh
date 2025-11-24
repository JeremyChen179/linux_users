#!/usr/bin/env bash
set -euo pipefail

# Automated test for list_users.sh and track_user_changes.sh using Docker.
# Requires: Docker installed on the host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="${IMAGE:-ubuntu:24.04}"

echo "Using Docker image: $IMAGE"

docker run --rm -i \
  -v "$SCRIPT_DIR":/scripts/linux-users \
  "$IMAGE" bash <<'EOF'
set -euo pipefail

echo "[*] Updating package index and installing dependencies..."
apt-get update -qq
apt-get install -y -qq passwd procps >/dev/null

cd /scripts/linux-users
chmod +x list_users.sh track_user_changes.sh

echo "[*] Running initial tracking script..."
./track_user_changes.sh

if [[ ! -f /var/log/current_users ]]; then
  echo "[FAIL] /var/log/current_users not created on first run"
  exit 1
fi

FIRST_HASH="$(cat /var/log/current_users)"
if [[ -z "$FIRST_HASH" ]]; then
  echo "[FAIL] /var/log/current_users is empty after first run"
  exit 1
fi
echo "[OK] current_users created with initial hash: $FIRST_HASH"

echo "[*] Creating test user 'testuser'..."
useradd -m testuser

echo "[*] Verifying list_users.sh reports testuser..."
if ! ./list_users.sh | grep -q '^testuser:/home/testuser$'; then
  echo "[FAIL] testuser not found in list_users.sh output"
  ./list_users.sh
  exit 1
fi
echo "[OK] testuser appears in list_users.sh output"

echo "[*] Running tracking script after user change..."
./track_user_changes.sh

if [[ ! -f /var/log/user_changes ]]; then
  echo "[FAIL] /var/log/user_changes not created after change"
  exit 1
fi

if ! grep -q 'changes occurred' /var/log/user_changes; then
  echo "[FAIL] No 'changes occurred' line in /var/log/user_changes"
  cat /var/log/user_changes
  exit 1
fi

NEW_HASH="$(cat /var/log/current_users)"
if [[ "$NEW_HASH" == "$FIRST_HASH" ]]; then
  echo "[FAIL] Hash in /var/log/current_users did not change after user addition"
  exit 1
fi

echo "[OK] user_changes logged and current_users hash updated:"
echo "     old: $FIRST_HASH"
echo "     new: $NEW_HASH"

echo "[PASS] All tests passed inside Docker."
EOF
