$ErrorActionPreference = "Stop"

$pidFile = Join-Path (Join-Path $env:LOCALAPPDATA "stillcooldad") "server.pid"
if (-not (Test-Path -LiteralPath $pidFile)) {
    Write-Output "The local vault server is not running."
    exit 0
}

$serverPid = 0
if (-not [int]::TryParse((Get-Content -LiteralPath $pidFile -Raw).Trim(), [ref]$serverPid)) {
    throw "The local vault server PID file is invalid. No process was stopped."
}

$process = Get-CimInstance Win32_Process -Filter "ProcessId = $serverPid" -ErrorAction SilentlyContinue
if (-not $process -or $process.Name -ne "powershell.exe" -or $process.CommandLine -notlike "*serve-vault.ps1*") {
    Remove-Item -LiteralPath $pidFile -Force
    Write-Output "The saved server process is no longer running."
    exit 0
}

Stop-Process -Id $serverPid
Write-Output "The local vault server has been stopped."
