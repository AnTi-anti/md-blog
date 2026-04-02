[CmdletBinding()]
param(
  [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$postsDirectory = Resolve-Path (Join-Path $repoRoot "posts")
$scriptRoot = $PSScriptRoot

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $postsDirectory
$watcher.Filter = "*.md"
$watcher.IncludeSubdirectories = $false
$watcher.NotifyFilter = [System.IO.NotifyFilters]'FileName, LastWrite, CreationTime'
$watcher.EnableRaisingEvents = $true

$script:isPublishing = $false
$createdId = "posts.created"
$changedId = "posts.changed"
$renamedId = "posts.renamed"
$deletedId = "posts.deleted"

$publishAction = {
  param($Source, $EventArgs)

  if ($script:isPublishing) {
    return
  }

  $script:isPublishing = $true
  Start-Sleep -Milliseconds 500

  try {
    Write-Host ("Detected change: {0} {1}" -f $EventArgs.ChangeType, $EventArgs.Name)
    & (Join-Path $scriptRoot "publish-once.ps1") -Branch $Branch
  } catch {
    Write-Error $_
  } finally {
    $script:isPublishing = $false
  }
}

Register-ObjectEvent -InputObject $watcher -EventName Created -SourceIdentifier $createdId -Action $publishAction | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Changed -SourceIdentifier $changedId -Action $publishAction | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Renamed -SourceIdentifier $renamedId -Action $publishAction | Out-Null
Register-ObjectEvent -InputObject $watcher -EventName Deleted -SourceIdentifier $deletedId -Action $publishAction | Out-Null

Write-Host "Watching directory: $postsDirectory"
Write-Host "Markdown changes will update the index and push to origin/$Branch"
Write-Host "Press Ctrl+C to stop."

try {
  while ($true) {
    Wait-Event -Timeout 1 | Out-Null
  }
} finally {
  Unregister-Event -SourceIdentifier $createdId -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $changedId -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $renamedId -ErrorAction SilentlyContinue
  Unregister-Event -SourceIdentifier $deletedId -ErrorAction SilentlyContinue
  $watcher.Dispose()
}
