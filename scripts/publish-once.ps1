[CmdletBinding()]
param(
  [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Push-Location $repoRoot
try {
  git rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository. Run: git init -b main"
  }

  & (Join-Path $PSScriptRoot "update-posts.ps1")

  $status = git status --porcelain
  if (-not $status) {
    Write-Host "No changes to publish."
    return
  }

  git remote get-url origin *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Git remote 'origin' is missing. Run: git remote add origin <repo-url>"
  }

  git add .
  $changedMarkdown = git diff --cached --name-only | Where-Object { $_ -like "posts/*.md" }
  $message = if ($changedMarkdown) {
    "publish: " + (($changedMarkdown | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }) -join ", ")
  } else {
    "publish: site update"
  }

  git commit -m $message
  git push origin $Branch
  Write-Host "Pushed to origin/$Branch"
} finally {
  Pop-Location
}
