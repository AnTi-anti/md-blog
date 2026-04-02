[CmdletBinding()]
param(
  [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$logDirectory = Join-Path $repoRoot "logs"
$logFile = Join-Path $logDirectory "watcher.log"

if (-not (Test-Path -LiteralPath $logDirectory)) {
  New-Item -ItemType Directory -Path $logDirectory | Out-Null
}

Push-Location $repoRoot
try {
  Add-Content -LiteralPath $logFile -Value ("[{0}] watcher-service starting on branch {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Branch)
  & (Join-Path $PSScriptRoot "watch-and-publish.ps1") -Branch $Branch *>> $logFile
} finally {
  Add-Content -LiteralPath $logFile -Value ("[{0}] watcher-service stopped" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"))
  Pop-Location
}
