@echo off
setlocal

set "SCRIPT_DIR=%~dp0"
set "KEY_FILE=%SCRIPT_DIR%.local-ssh\id_ed25519_md_blog"
set "KNOWN_HOSTS_FILE=%SCRIPT_DIR%.local-ssh\known_hosts"

"C:\Windows\System32\OpenSSH\ssh.exe" ^
  -F NUL ^
  -i "%KEY_FILE%" ^
  -o "IdentitiesOnly=yes" ^
  -o "StrictHostKeyChecking=accept-new" ^
  -o "UserKnownHostsFile=%KNOWN_HOSTS_FILE%" ^
  -o "HostName=ssh.github.com" ^
  -p 443 ^
  %*
