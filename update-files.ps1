# Regenerates the FILES array inside index.html from the .jpg files that
# actually live next to this script. Run via update-files.cmd (double-click)
# or directly: powershell -ExecutionPolicy Bypass -File .\update-files.ps1
#
# It looks for files whose names start with "<number>.<1|2>" (the
# diptych-pair convention used in this project), sorts them by pair number
# then by slot (1 before 2), and rewrites the block between the two
# sentinel comments FILES:BEGIN and FILES:END inside index.html.
#
# Original-file safety: writes UTF-8 with no BOM so the HTML stays clean,
# and only touches the lines between the sentinels.

$ErrorActionPreference = "Stop"

$dir  = $PSScriptRoot
$html = Join-Path $dir 'index.html'
if (-not (Test-Path $html)) { throw "index.html not found next to this script (looked in $dir)" }

# Collect every "<n>.<1|2>..." image. Common extensions only.
$files = Get-ChildItem -Path $dir -File |
  Where-Object { $_.Extension -match '^\.(jpe?g|png|webp)$' -and $_.Name -match '^\d+\.[12]' } |
  ForEach-Object {
    $m = [regex]::Match($_.Name, '^(\d+)\.([12])')
    [pscustomobject]@{
      Name = $_.Name
      Num  = [int]$m.Groups[1].Value
      Slot = [int]$m.Groups[2].Value
    }
  } |
  Sort-Object Num, Slot

if (-not $files) {
  Write-Host "No <number>.<1|2>... images found in $dir -- nothing to do." -ForegroundColor Yellow
  return
}

# Group consecutive files by their pair number so we can emit one line per
# pair (visual parity with the original hand-written layout). Orphan pair
# numbers (only one of .1 / .2 present) are noted in the summary but
# excluded from the array entirely so the FILES list contains only
# renderable pairs.
$grouped = $files | Group-Object -Property Num
$orphans = $grouped | Where-Object { $_.Count -lt 2 }
$complete = $grouped | Where-Object { $_.Count -ge 2 }

$lines = foreach ($g in $complete) {
  $quoted = ($g.Group | ForEach-Object { '"' + $_.Name + '"' }) -join ','
  '    ' + $quoted + ','
}
$body = $lines -join "`r`n"

# Splice between the sentinels.
$content = Get-Content -Raw -Encoding UTF8 -Path $html
$pattern = '(?s)(//\s*FILES:BEGIN)(.*?)(//\s*FILES:END)'
if (-not [regex]::IsMatch($content, $pattern)) {
  throw "FILES:BEGIN / FILES:END sentinels not found in index.html -- has the file been edited?"
}
$replacement = "// FILES:BEGIN`r`n$body`r`n    // FILES:END"
$new = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement })

# Write UTF-8 without BOM so PowerShell 5.1 doesn't corrupt the file's start.
$enc = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($html, $new, $enc)

$pairCount = $complete.Count
$orphanCount = $orphans.Count
Write-Host ""
Write-Host "index.html updated." -ForegroundColor Green
Write-Host ("  files:   {0}" -f $files.Count)
Write-Host ("  pairs:   {0}" -f $pairCount)
if ($orphanCount -gt 0) {
  $orphanList = ($orphans | ForEach-Object { $_.Name }) -join ', '
  Write-Host ("  orphans: {0}  (pair number(s): {1}) -- excluded from the FILES array" -f $orphanCount, $orphanList) -ForegroundColor Yellow
}
