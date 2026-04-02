[CmdletBinding()]
param(
  [string]$Branch = "main"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  & git @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git $($Arguments -join ' ')"
  }
}

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

Push-Location $repoRoot
try {
  & git rev-parse --is-inside-work-tree *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Current directory is not a git repository. Run: git init -b main"
  }

  & (Join-Path $PSScriptRoot "update-posts.ps1")

  $status = & git status --porcelain
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git status --porcelain"
  }

  if (-not $status) {
    Write-Host "No changes to publish."
    return
  }

  & git remote get-url origin *> $null
  if ($LASTEXITCODE -ne 0) {
    throw "Git remote 'origin' is missing. Run: git remote add origin <repo-url>"
  }

  Invoke-Git -Arguments @("add", ".")
  $changedMarkdown = & git diff --cached --name-only
  if ($LASTEXITCODE -ne 0) {
    throw "Git command failed: git diff --cached --name-only"
  }
  $changedMarkdown = $changedMarkdown | Where-Object { $_ -like "posts/*.md" }
  $message = if ($changedMarkdown) {
    "publish: " + (($changedMarkdown | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) }) -join ", ")
  } else {
    "publish: site update"
  }

  Invoke-Git -Arguments @("commit", "-m", $message)
  Invoke-Git -Arguments @("push", "origin", $Branch)
  Write-Host "Pushed to origin/$Branch"
} finally {
  Pop-Location
}
