$ErrorActionPreference = "Stop"

$port = 8765
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$stateDirectory = Join-Path $env:LOCALAPPDATA "stillcooldad"
$pidFile = Join-Path $stateDirectory "server.pid"
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://127.0.0.1:$port/")

New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
Set-Content -LiteralPath $pidFile -Value $PID -Encoding Ascii

$routes = @{
    "/" = @{ File = "passwordvault.html"; Type = "text/html; charset=utf-8" }
    "/passwordvault.html" = @{ File = "passwordvault.html"; Type = "text/html; charset=utf-8" }
    "/manifest.webmanifest" = @{ File = "manifest.webmanifest"; Type = "application/manifest+json; charset=utf-8" }
    "/service-worker.js" = @{ File = "service-worker.js"; Type = "text/javascript; charset=utf-8" }
    "/icon-192.png" = @{ File = "icon-192.png"; Type = "image/png" }
    "/icon-512.png" = @{ File = "icon-512.png"; Type = "image/png" }
}

$listener.Start()
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        try {
            $response.Headers["X-Stillcooldad-Vault"] = "local-only"
            $response.Headers["X-Content-Type-Options"] = "nosniff"
            $response.Headers["Referrer-Policy"] = "no-referrer"
            $response.Headers["X-Frame-Options"] = "DENY"
            $response.Headers["Cache-Control"] = "no-store"
            $response.Headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; manifest-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'self'; form-action 'self'; frame-ancestors 'none'"

            if ($context.Request.HttpMethod -notin @("GET", "HEAD")) {
                $response.StatusCode = 405
                $response.Headers["Allow"] = "GET, HEAD"
                continue
            }

            $route = $routes[$context.Request.Url.AbsolutePath]
            if (-not $route) {
                $response.StatusCode = 404
                continue
            }

            $filePath = Join-Path $root $route.File
            if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) {
                $response.StatusCode = 404
                continue
            }

            $response.ContentType = $route.Type
            if ($context.Request.HttpMethod -eq "HEAD") {
                $response.StatusCode = 200
                continue
            }

            $bytes = [System.IO.File]::ReadAllBytes($filePath)
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } catch {
            Write-Error "Local vault server request failed: $($_.Exception.Message)"
            $response.StatusCode = 500
        } finally {
            $response.Close()
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
    Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
}
