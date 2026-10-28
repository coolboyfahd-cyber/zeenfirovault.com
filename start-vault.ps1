$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$serverScript = Join-Path $root "serve-vault.ps1"
$stateDirectory = Join-Path $env:LOCALAPPDATA "stillcooldad"
$pidFile = Join-Path $stateDirectory "server.pid"
$url = "http://127.0.0.1:8765/passwordvault.html"
$chromePaths = @(
    (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
    (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
    (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe")
)

function Test-VaultServer {
    try {
        $request = [System.Net.WebRequest]::Create("http://127.0.0.1:8765/")
        $request.Method = "HEAD"
        $request.Timeout = 1200
        $response = $request.GetResponse()
        try {
            return $response.Headers["X-Stillcooldad-Vault"] -eq "local-only"
        } finally {
            $response.Close()
        }
    } catch {
        return $false
    }
}

Add-Type -AssemblyName System.Drawing
foreach ($size in @(192, 512)) {
    $iconPath = Join-Path $root "icon-$size.png"
    if (Test-Path -LiteralPath $iconPath) { continue }

    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $graphics.Clear([System.Drawing.Color]::FromArgb(224, 248, 249))
        $markBounds = [System.Drawing.RectangleF]::new($size * .14, $size * .14, $size * .72, $size * .72)
        $markBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(40, 126, 134))
        $graphics.FillEllipse($markBrush, $markBounds)
        $markBrush.Dispose()

        $scale = $size / 192.0
        $pen = [System.Drawing.Pen]::new([System.Drawing.Color]::White, 8 * $scale)
        $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
        $graphics.DrawArc($pen, 69 * $scale, 49 * $scale, 54 * $scale, 58 * $scale, 180, 180)
        $lockPath = [System.Drawing.Drawing2D.GraphicsPath]::new()
        $corner = 12 * $scale
        $lockX = 64 * $scale
        $lockY = 78 * $scale
        $lockWidth = 64 * $scale
        $lockHeight = 55 * $scale
        $lockPath.AddArc($lockX, $lockY, $corner, $corner, 180, 90)
        $lockPath.AddArc($lockX + $lockWidth - $corner, $lockY, $corner, $corner, 270, 90)
        $lockPath.AddArc($lockX + $lockWidth - $corner, $lockY + $lockHeight - $corner, $corner, $corner, 0, 90)
        $lockPath.AddArc($lockX, $lockY + $lockHeight - $corner, $corner, $corner, 90, 90)
        $lockPath.CloseFigure()
        $graphics.DrawPath($pen, $lockPath)
        $lockPath.Dispose()
        $graphics.DrawEllipse($pen, 92 * $scale, 96 * $scale, 8 * $scale, 8 * $scale)
        $pen.Dispose()

        $bitmap.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
if (-not (Test-VaultServer)) {
    $arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$serverScript`""
    $serverProcess = Start-Process -FilePath "powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -PassThru

    $ready = $false
    for ($attempt = 0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 300
        if (Test-VaultServer) {
            $ready = $true
            break
        }
        if ($serverProcess.HasExited) {
            throw "The local vault server stopped during startup. Check that port 8765 is available."
        }
    }
    if (-not $ready) {
        throw "The local vault server did not respond. Check that port 8765 is available."
    }
}

$chrome = $chromePaths | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
if ($chrome) {
    Start-Process -FilePath $chrome -ArgumentList $url
} else {
    Start-Process $url
}
