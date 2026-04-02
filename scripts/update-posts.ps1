[CmdletBinding()]
param(
  [string]$PostsDirectory,
  [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $PostsDirectory) {
  $PostsDirectory = Join-Path $PSScriptRoot "..\\posts"
}

if (-not $OutputFile) {
  $OutputFile = Join-Path $PSScriptRoot "..\\posts.json"
}

function Get-Slug {
  param(
    [string]$Name
  )

  $slug = $Name.ToLowerInvariant()
  $slug = [System.Text.RegularExpressions.Regex]::Replace($slug, "[^a-z0-9\-_]+", "-")
  $slug = [System.Text.RegularExpressions.Regex]::Replace($slug, "-{2,}", "-")
  $slug = $slug.Trim("-")

  if ([string]::IsNullOrWhiteSpace($slug)) {
    throw "Cannot generate a slug from file name '$Name'. Rename it with letters or digits."
  }

  return $slug
}

function Get-FrontMatter {
  param(
    [string]$Content
  )

  $meta = @{}
  $body = $Content

  if ($Content -match '(?s)^---\r?\n(.*?)\r?\n---\r?\n?(.*)$') {
    $frontMatter = $matches[1]
    $body = $matches[2]
    $activeArrayKey = $null

    foreach ($line in ($frontMatter -split '\r?\n')) {
      if ($line -match '^\s*-\s*(.+)\s*$' -and $activeArrayKey) {
        if (-not $meta.ContainsKey($activeArrayKey)) {
          $meta[$activeArrayKey] = @()
        }
        $meta[$activeArrayKey] += $matches[1].Trim()
        continue
      }

      if ($line -match '^([A-Za-z0-9_-]+):\s*(.*)$') {
        $key = $matches[1]
        $value = $matches[2].Trim()

        if ([string]::IsNullOrWhiteSpace($value)) {
          $meta[$key] = @()
          $activeArrayKey = $key
          continue
        }

        $meta[$key] = $value.Trim([char[]]@([char]34, [char]39))
        $activeArrayKey = $null
      } else {
        $activeArrayKey = $null
      }
    }
  }

  [pscustomobject]@{
    Meta = $meta
    Body = $body
  }
}

if (-not (Test-Path -LiteralPath $PostsDirectory)) {
  throw "Posts directory does not exist: $PostsDirectory"
}

$posts = foreach ($file in (Get-ChildItem -LiteralPath $PostsDirectory -Filter *.md -File | Sort-Object LastWriteTimeUtc -Descending)) {
  $content = Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8
  $parsed = Get-FrontMatter -Content $content
  $firstHeading = [System.Text.RegularExpressions.Regex]::Match($parsed.Body, '^\s*#\s+(.+)$', [System.Text.RegularExpressions.RegexOptions]::Multiline)
  $slug = Get-Slug -Name $file.BaseName

  if ($file.BaseName -cne $slug) {
    throw "File '$($file.Name)' must use the slug as its file name, for example '$slug.md'."
  }

  $meta = $parsed.Meta
  $title = if ($meta.ContainsKey("title") -and $meta["title"]) {
    $meta["title"]
  } elseif ($firstHeading.Success) {
    $firstHeading.Groups[1].Value.Trim()
  } else {
    $file.BaseName
  }

  $summary = if ($meta.ContainsKey("summary") -and $meta["summary"]) {
    $meta["summary"]
  } else {
    $plainText = (($parsed.Body -replace '(?m)^\s*#.*$', '' -replace '\s+', ' ').Trim())
    if ($plainText.Length -gt 120) {
      $plainText.Substring(0, 120)
    } else {
      $plainText
    }
  }

  $date = if ($meta.ContainsKey("date") -and $meta["date"]) {
    $meta["date"]
  } else {
    $file.LastWriteTime.ToString("yyyy-MM-dd")
  }

  $tags = @()
  if ($meta.ContainsKey("tags")) {
    if ($meta["tags"] -is [System.Array]) {
      $tags = $meta["tags"]
    } elseif ($meta["tags"]) {
      $tags = @($meta["tags"])
    }
  }

  [pscustomobject]@{
    slug = $slug
    title = $title
    date = $date
    summary = $summary
    tags = $tags
    source = ("posts/{0}" -f $file.Name)
  }
}

$postList = @($posts)
if ($postList.Count -eq 0) {
  $json = "[]"
} elseif ($postList.Count -eq 1) {
  $json = "[`n$($postList[0] | ConvertTo-Json -Depth 5)`n]"
} else {
  $json = $postList | ConvertTo-Json -Depth 5
}

Set-Content -LiteralPath $OutputFile -Value $json -Encoding UTF8
Write-Host "Generated posts index: $OutputFile"
