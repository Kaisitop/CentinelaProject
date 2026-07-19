param(
  [Parameter(Mandatory = $true)]
  [string]$Repo
)

Set-Location $Repo
$raw = (git log -1 --format=%B) -join "`n"
Write-Host "BEFORE has coauthor: $($raw.Contains('Co-authored-by'))"
if (-not $raw.Contains("Co-authored-by")) {
  Write-Host "clean, skip"
  exit 0
}

$cleanLines = @()
foreach ($line in ($raw -split "`n")) {
  if ($line -notmatch "Co-authored-by") {
    $cleanLines += $line
  }
}
$clean = ($cleanLines -join "`n").TrimEnd() + "`n`n"

$tree = (git rev-parse 'HEAD^{tree}').Trim()
$parent = (git rev-parse 'HEAD~1').Trim()
$env:GIT_AUTHOR_NAME = (git log -1 --format=%an).Trim()
$env:GIT_AUTHOR_EMAIL = (git log -1 --format=%ae).Trim()
$env:GIT_AUTHOR_DATE = (git log -1 --format=%aD).Trim()
$env:GIT_COMMITTER_NAME = (git log -1 --format=%cn).Trim()
$env:GIT_COMMITTER_EMAIL = (git log -1 --format=%ce).Trim()

$path = Join-Path $env:TEMP ("strip-" + [guid]::NewGuid().ToString() + ".txt")
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $clean, $utf8)

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "git"
$psi.Arguments = "commit-tree $tree -p $parent"
$psi.WorkingDirectory = (Get-Location).Path
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true
$psi.EnvironmentVariables["GIT_AUTHOR_NAME"] = $env:GIT_AUTHOR_NAME
$psi.EnvironmentVariables["GIT_AUTHOR_EMAIL"] = $env:GIT_AUTHOR_EMAIL
$psi.EnvironmentVariables["GIT_AUTHOR_DATE"] = $env:GIT_AUTHOR_DATE
$psi.EnvironmentVariables["GIT_COMMITTER_NAME"] = $env:GIT_COMMITTER_NAME
$psi.EnvironmentVariables["GIT_COMMITTER_EMAIL"] = $env:GIT_COMMITTER_EMAIL

$p = [System.Diagnostics.Process]::Start($psi)
$p.StandardInput.Write($clean)
$p.StandardInput.Close()
$new = $p.StandardOutput.ReadToEnd().Trim()
$err = $p.StandardError.ReadToEnd()
$p.WaitForExit()

if (-not $new) {
  Write-Host "commit-tree failed: $err"
  exit 1
}

git reset --hard $new | Out-Null
$after = (git log -1 --format=%B) -join "`n"
Write-Host "AFTER has coauthor: $($after.Contains('Co-authored-by'))"
Write-Host $after

if ($after.Contains("Co-authored-by")) {
  Write-Host "FAILED"
  exit 1
}

git push --force-with-lease origin main
exit $LASTEXITCODE
