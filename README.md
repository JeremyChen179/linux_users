# Linux Users Lister

Scripts to list Linux users and track changes to the user list over time.

## Files

- `list_users.sh`: Prints all usernames and their home directories in the format `username:/home/dir`.
- `track_user_changes.sh`: Computes an MD5 checksum of the full `list_users.sh` output and logs changes.
- `test_user_scripts_docker.sh`: Automated end-to-end test runner using a Docker Linux container.

## 1. list_users.sh

### Description

`list_users.sh` prints lines of the form:

```text
username:/home/username
```

On Linux it uses `getent passwd` when available and falls back to `/etc/passwd`.

### Usage

1. Make the script executable:
   ```bash
   chmod +x list_users.sh
   ```
2. Run it:
   ```bash
   ./list_users.sh
   ```

Example output:

```text
root:/root
nobody:/nonexistent
ubuntu:/home/ubuntu
```

## 2. track_user_changes.sh

### Description

`track_user_changes.sh`:

- Runs `list_users.sh` and takes the **full output**.
- Computes a single MD5 hash using `md5sum`.
- On first run, stores the hash in `/var/log/current_users`.
- On subsequent runs, if the hash changes:
  - Appends a line `DATE TIME changes occurred` to `/var/log/user_changes`.
  - Replaces the old hash in `/var/log/current_users` with the new one.

Assumes it runs with sufficient permissions to read the user database and write to `/var/log`.

### Usage

1. Make it executable:
   ```bash
   chmod +x track_user_changes.sh
   ```
2. Run it (typically as root):
   ```bash
   ./track_user_changes.sh
   ```

On first run it will create `/var/log/current_users` containing a single MD5 hash. When the user set changes, later runs will append to `/var/log/user_changes` and update `/var/log/current_users`.

## 3. Automated Docker Test: test_user_scripts_docker.sh

### Description

`test_user_scripts_docker.sh` runs an automated end-to-end test of both scripts using a fresh Ubuntu Docker container. It:

- Starts an `ubuntu:24.04` container (or another image via the `IMAGE` env var).
- Installs required packages inside the container.
- Runs `track_user_changes.sh` once and verifies `/var/log/current_users` is created with a non-empty hash.
- Creates a real test user `testuser` inside the container.
- Confirms `list_users.sh` outputs `testuser:/home/testuser`.
- Runs `track_user_changes.sh` again and checks that:
  - `/var/log/user_changes` contains a `changes occurred` entry.
  - The hash in `/var/log/current_users` has changed.

### Usage

On the host (with Docker installed):

```bash
chmod +x test_user_scripts_docker.sh
./test_user_scripts_docker.sh
```

On success, the script prints output similar to:

```text
Using Docker image: ubuntu:24.04
[*] Updating package index and installing dependencies...
[*] Running initial tracking script...
[OK] current_users created with initial hash: 0e27f14693fc9c21c265b55509119a51
[*] Creating test user 'testuser'...
[*] Verifying list_users.sh reports testuser...
[OK] testuser appears in list_users.sh output
[*] Running tracking script after user change...
[OK] user_changes logged and current_users hash updated:
     old: 0e27f14693fc9c21c265b55509119a51
     new: 3706818fe7355c02f45926387b6d8446
[PASS] All tests passed inside Docker.
```

## 4. Cron Setup

To run the tracking script hourly from cron (assuming both scripts are in `/scripts/linux-users`):

```cron
0 * * * * /scripts/linux-users/track_user_changes.sh >/dev/null 2>&1
```

This cron entry:

- Runs at minute `0` of every hour.
- Calls `track_user_changes.sh`, which in turn calls `list_users.sh`.
- Ensures that user list changes are detected and logged over time.
