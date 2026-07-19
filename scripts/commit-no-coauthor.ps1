param(
  [Parameter(Mandatory = $true)]
  [string]$Repo,
  [Parameter(Mandatory = $true)]
  [string]$Message,
  [Parameter(Mandatory = $true)]
  [string[]]$Files
)

Set-Location $Repo
git add @Files
$status = git status --porcelain
if (-not $status) {
  Write-Host "nothing to commit"
  exit 0
}

# Stage is done; create commit via commit-tree to avoid Cursor trailer injection
$tree = (git write-tree).Trim()
$parentArgs = @()
git rev-parse --verify HEAD 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
  $parent = (git rev-parse HEAD).Trim()
  $parentArgs = @("-p", $parent)
}

$msg = $Message.TrimEnd() + "`n"
$path = Join-Path $env:TEMP ("cnoc-" + [guid]::NewGuid().ToString() + ".txt")
$utf8 = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($path, $msg, $utf8)

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "git"
$psi.Arguments = (@("commit-tree", $tree) + $parentArgs) -join " "
$psi.WorkingDirectory = (Get-Location).Path
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$psi.UseShellExecute = $false
$psi.CreateNoWindow = $true

$p = [System.Diagnostics.Process]::Start($psi)
$p.StandardInput.Write($msg)
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
Write-Host $after
if ($after.Contains("Co-authored-by")) {
  Write-Host "FAILED: coauthor present"
  exit 1
}
exit 0
