# NoSleep Mouse - stay-online helper (Windows)
# Web UI *and* console/CLI. Runs a tiny local web server (loopback only, no admin,
# no installs) and/or a headless console loop that nudges real input on an interval
# so apps like Slack/Teams keep you "online".
#
# Examples (from a console):
#   powershell -ExecutionPolicy Bypass -File server.ps1                       # web UI (default)
#   powershell -ExecutionPolicy Bypass -File server.ps1 -NoBrowser            # web server, no popup
#   powershell -ExecutionPolicy Bypass -File server.ps1 -Console -Interval 30 -Dir circle -Distance 150
#   powershell -ExecutionPolicy Bypass -File server.ps1 -Console -Method key  # invisible F15, no UI
param(
  [int]$Interval,
  [int]$Distance,
  [ValidateSet('mouse','key')][string]$Method,
  [ValidateSet('random','horizontal','vertical','circle')][string]$Dir,
  [switch]$On,
  [switch]$Off,
  [switch]$Console,    # pure console mode: no web server, just the loop + logging
  [switch]$NoBrowser,  # web mode but don't auto-open the browser
  [switch]$KeepAlive,  # web mode: stay running even after the browser/UI is closed
  [int]$Port = 8787
)
$ErrorActionPreference = 'Stop'
$Root      = $PSScriptRoot
$WebDir    = Join-Path $Root 'web'
$ConfigPath = Join-Path $Root 'config.json'

# ---- native input (no dependencies, ships with Windows) ----
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class NSInput {
  [DllImport("user32.dll")] static extern void mouse_event(uint f,int dx,int dy,uint d,IntPtr e);
  [DllImport("user32.dll")] static extern void keybd_event(byte vk,byte sc,uint f,IntPtr e);
  [DllImport("user32.dll")] static extern bool SetCursorPos(int x,int y);
  [DllImport("user32.dll")] static extern bool GetCursorPos(out POINT p);
  public struct POINT { public int X; public int Y; }
  public static int CurX(){ POINT p; GetCursorPos(out p); return p.X; }
  public static int CurY(){ POINT p; GetCursorPos(out p); return p.Y; }
  public static void SetPos(int x,int y){ SetCursorPos(x,y); }
  // register real activity so the idle timer resets (this is what keeps you 'online')
  public static void Tick(){ mouse_event(0x0001,1,0,0,IntPtr.Zero); mouse_event(0x0001,-1,0,0,IntPtr.Zero); }
  // F15: a key nothing maps to, so it registers as activity but does nothing visible
  public static void Key(){ keybd_event(0x7E,0,0,IntPtr.Zero); keybd_event(0x7E,0,2,IntPtr.Zero); }
}
"@

# ---- config / state ----
$script:cfg = @{
  enabled      = $false
  intervalSec  = 60
  method       = 'mouse'   # 'mouse' | 'key'
  moveDistance = 60        # px, how far the cursor travels
  moveDir      = 'random'  # 'random' | 'horizontal' | 'vertical' | 'circle'
  hoursEnabled = $false
  fromTime     = '09:00'
  toTime       = '17:00'
}
function Load-Config {
  if (Test-Path $ConfigPath) {
    try {
      $j = Get-Content $ConfigPath -Raw | ConvertFrom-Json
      foreach ($k in @('enabled','intervalSec','method','moveDistance','moveDir','hoursEnabled','fromTime','toTime')) {
        if ($null -ne $j.$k) { $script:cfg[$k] = $j.$k }
      }
    } catch {}
  }
}
function Save-Config {
  try { ($script:cfg | ConvertTo-Json) | Set-Content -Path $ConfigPath -Encoding UTF8 } catch {}
}
Load-Config

# ---- apply CLI overrides (so everything is settable from the console too) ----
if ($PSBoundParameters.ContainsKey('Interval')) { $script:cfg.intervalSec  = [int][math]::Min(86400,[math]::Max(5,$Interval)) }
if ($PSBoundParameters.ContainsKey('Distance')) { $script:cfg.moveDistance = [int][math]::Min(2000,[math]::Max(1,$Distance)) }
if ($Method) { $script:cfg.method  = $Method }
if ($Dir)    { $script:cfg.moveDir = $Dir }
if ($On)     { $script:cfg.enabled = $true }
if ($Off)    { $script:cfg.enabled = $false }
Save-Config

$script:lastNudge = Get-Date
$script:count     = 0
$script:running   = $true
$script:lastSeen  = $null   # last time the web UI talked to us (for auto-shutdown)
$IdleShutdownSec  = 90      # UI polls every 1s; keep this generous so background-tab
                            # throttling (browsers slow inactive tabs) doesn't kill us

function In-ActiveHours {
  if (-not $script:cfg.hoursEnabled) { return $true }
  $now = (Get-Date).TimeOfDay
  $f = [TimeSpan]::Parse($script:cfg.fromTime)
  $t = [TimeSpan]::Parse($script:cfg.toTime)
  if ($f -le $t) { return ($now -ge $f -and $now -le $t) }
  return ($now -ge $f -or $now -le $t)   # overnight range
}

function Move-Mouse {
  $dist  = [int]$script:cfg.moveDistance
  $dir   = "$($script:cfg.moveDir)"
  $sx = [NSInput]::CurX(); $sy = [NSInput]::CurY()
  $steps = 14
  $delay = 10   # ms per step -> visible glide, ~0.3s round trip

  if ($dir -eq 'circle') {
    for ($i = 0; $i -le $steps; $i++) {
      $a = 2 * [math]::PI * $i / $steps
      [NSInput]::SetPos($sx + [int]([math]::Round([math]::Cos($a) * $dist)),
                        $sy + [int]([math]::Round([math]::Sin($a) * $dist)))
      Start-Sleep -Milliseconds $delay
    }
  }
  else {
    switch ($dir) {
      'horizontal' { $tx = $dist; $ty = 0 }
      'vertical'   { $tx = 0;     $ty = $dist }
      default {  # random angle
        $a  = (Get-Random -Minimum 0 -Maximum 360) * [math]::PI / 180
        $tx = [int]([math]::Round([math]::Cos($a) * $dist))
        $ty = [int]([math]::Round([math]::Sin($a) * $dist))
      }
    }
    for ($i = 1; $i -le $steps; $i++) {  # glide out
      [NSInput]::SetPos($sx + [int]($tx * $i / $steps), $sy + [int]($ty * $i / $steps))
      Start-Sleep -Milliseconds $delay
    }
    for ($i = $steps - 1; $i -ge 0; $i--) {  # glide back
      [NSInput]::SetPos($sx + [int]($tx * $i / $steps), $sy + [int]($ty * $i / $steps))
      Start-Sleep -Milliseconds $delay
    }
  }

  [NSInput]::SetPos($sx, $sy)  # land exactly where we started
  [NSInput]::Tick()            # guarantee the idle timer resets
}

function Do-Nudge {
  if ($script:cfg.method -eq 'key') { [NSInput]::Key() } else { Move-Mouse }
}

function Maybe-Nudge {
  if (-not $script:cfg.enabled) { return }
  if (-not (In-ActiveHours))    { return }
  $elapsed = ((Get-Date) - $script:lastNudge).TotalSeconds
  if ($elapsed -ge $script:cfg.intervalSec) {
    Do-Nudge
    $script:lastNudge = Get-Date
    $script:count++
  }
}

# ---- minimal HTTP over TcpListener (no urlacl / admin needed) ----
$mime = @{
  '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8';
  '.js'='application/javascript; charset=utf-8'; '.ttf'='font/ttf';
  '.json'='application/json; charset=utf-8'
}

function Send-Bytes($stream,$status,$ctype,[byte[]]$body){
  $head = "HTTP/1.1 $status`r`nContent-Type: $ctype`r`nContent-Length: $($body.Length)`r`nConnection: close`r`nCache-Control: no-store`r`n`r`n"
  $hb = [Text.Encoding]::ASCII.GetBytes($head)
  $stream.Write($hb,0,$hb.Length)
  if ($body.Length) { $stream.Write($body,0,$body.Length) }
  $stream.Flush()
}
function Send-Text($stream,$status,$ctype,$text){
  Send-Bytes $stream $status $ctype ([Text.Encoding]::UTF8.GetBytes($text))
}
function Send-Json($stream,$obj){
  Send-Text $stream "200 OK" $mime['.json'] ($obj | ConvertTo-Json -Compress)
}

function Status-Object {
  $left = $null
  if ($script:cfg.enabled) {
    $e = $script:cfg.intervalSec - ((Get-Date) - $script:lastNudge).TotalSeconds
    $left = [int][math]::Max(0, [math]::Ceiling($e))
  }
  [ordered]@{
    enabled         = [bool]$script:cfg.enabled
    intervalSec     = [int]$script:cfg.intervalSec
    method          = "$($script:cfg.method)"
    moveDistance    = [int]$script:cfg.moveDistance
    moveDir         = "$($script:cfg.moveDir)"
    hoursEnabled    = [bool]$script:cfg.hoursEnabled
    fromTime        = "$($script:cfg.fromTime)"
    toTime          = "$($script:cfg.toTime)"
    secondsUntilNext= $left
    count           = [int]$script:count
    inActiveHours   = [bool](In-ActiveHours)
  }
}

function Serve-Static($stream,$path){
  if ($path -eq '/' ) { $path = '/index.html' }
  $rel = $path.TrimStart('/').Replace('/', [IO.Path]::DirectorySeparatorChar)
  $full = Join-Path $WebDir $rel
  # keep inside web dir
  $resolved = [IO.Path]::GetFullPath($full)
  if (-not $resolved.StartsWith([IO.Path]::GetFullPath($WebDir))) {
    Send-Text $stream "403 Forbidden" 'text/plain' 'no'; return
  }
  if (-not (Test-Path $resolved -PathType Leaf)) {
    Send-Text $stream "404 Not Found" 'text/plain' 'not found'; return
  }
  $ext = [IO.Path]::GetExtension($resolved).ToLower()
  $ct  = $mime[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
  Send-Bytes $stream "200 OK" $ct ([IO.File]::ReadAllBytes($resolved))
}

# ---- console (headless) mode: no web server, just the nudge loop ----
if ($Console) {
  if (-not $Off) { $script:cfg.enabled = $true }   # running from console implies "go"
  $script:lastNudge = (Get-Date).AddSeconds(-$script:cfg.intervalSec)
  Write-Host ("NoSleep console | method={0} interval={1}s dir={2} dist={3}px enabled={4}" -f `
    $script:cfg.method, $script:cfg.intervalSec, $script:cfg.moveDir, $script:cfg.moveDistance, $script:cfg.enabled)
  Write-Host "Running. Press Ctrl+C to stop."
  while ($true) {
    $before = $script:count
    Maybe-Nudge
    if ($script:count -ne $before) { Write-Host ("[{0}] nudge #{1}" -f (Get-Date -Format HH:mm:ss), $script:count) }
    Start-Sleep -Milliseconds 250
  }
}

# ---- web UI mode ----
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $Port)
try {
  $listener.Start()
} catch {
  Write-Host ""
  Write-Host "ERROR: couldn't start the web server on port $Port."
  Write-Host "It's probably already in use (NoSleep already running, or another app)."
  Write-Host "Fix: run Stop.bat first, or start on another port:  server.ps1 -Port 8788"
  Write-Host ""
  return
}
if (-not $NoBrowser) { Start-Process "http://localhost:$Port/" }
$autoShutdown = -not $KeepAlive   # stop the service when the web UI is closed
Write-Host "NoSleep web UI -> http://localhost:$Port/"
if ($autoShutdown) {
  Write-Host "(auto-stops ~$IdleShutdownSec s after the browser tab is closed; use -KeepAlive to keep running)"
} else {
  Write-Host "(KeepAlive on: stays running after the tab closes; stop with Ctrl+C or Stop.bat)"
}

try {
  while ($script:running) {
    Maybe-Nudge

    # auto-shutdown: once the UI has connected, exit if it goes silent (tab closed)
    if ($autoShutdown -and $script:lastSeen -and
        ((Get-Date) - $script:lastSeen).TotalSeconds -gt $IdleShutdownSec) {
      Write-Host ("[{0}] browser/UI silent for >{1}s - assuming the tab was closed, stopping." -f (Get-Date -Format HH:mm:ss), $IdleShutdownSec)
      $script:running = $false; continue
    }

    if (-not $listener.Pending()) { Start-Sleep -Milliseconds 150; continue }

    $client = $listener.AcceptTcpClient()
    try {
      $client.NoDelay = $true
      $ns = $client.GetStream()
      $ns.ReadTimeout = 3000

      # read headers up to CRLF CRLF
      $ms = New-Object System.IO.MemoryStream
      $one = New-Object byte[] 1
      $headerText = ''
      while ($true) {
        $r = $ns.Read($one,0,1)
        if ($r -le 0) { break }
        $ms.WriteByte($one[0])
        $len = $ms.Length
        if ($len -ge 4) {
          $a = $ms.ToArray()
          if ($a[$len-4] -eq 13 -and $a[$len-3] -eq 10 -and $a[$len-2] -eq 13 -and $a[$len-1] -eq 10) {
            $headerText = [Text.Encoding]::ASCII.GetString($a,0,$len-4); break
          }
        }
      }
      if (-not $headerText) { continue }

      $lines = $headerText -split "`r`n"
      $reqParts = $lines[0] -split ' '
      $reqMethod = $reqParts[0]
      $rawPath = if ($reqParts.Count -ge 2) { $reqParts[1] } else { '/' }
      $path = ($rawPath -split '\?')[0]

      $script:lastSeen = Get-Date   # heartbeat: the UI is alive

      $contentLength = 0
      foreach ($l in $lines) { if ($l -match '^(?i)Content-Length:\s*(\d+)') { $contentLength = [int]$Matches[1] } }
      $body = ''
      if ($contentLength -gt 0) {
        $bb = New-Object byte[] $contentLength
        $read = 0
        while ($read -lt $contentLength) {
          $n = $ns.Read($bb,$read,$contentLength-$read)
          if ($n -le 0) { break }; $read += $n
        }
        $body = [Text.Encoding]::UTF8.GetString($bb,0,$read)
      }

      switch -regex ("$reqMethod $path") {
        '^GET /api/status$' { Send-Json $ns (Status-Object) }

        '^POST /api/config$' {
          try {
            $d = $body | ConvertFrom-Json
            $wasEnabled = $script:cfg.enabled
            if ($null -ne $d.enabled)      { $script:cfg.enabled = [bool]$d.enabled }
            if ($null -ne $d.intervalSec)  { $script:cfg.intervalSec = [int][math]::Min(86400,[math]::Max(5,$d.intervalSec)) }
            if ($null -ne $d.method)       { $script:cfg.method = "$($d.method)" }
            if ($null -ne $d.moveDistance) { $script:cfg.moveDistance = [int][math]::Min(2000,[math]::Max(1,$d.moveDistance)) }
            if ($null -ne $d.moveDir)      { $script:cfg.moveDir = "$($d.moveDir)" }
            if ($null -ne $d.hoursEnabled) { $script:cfg.hoursEnabled = [bool]$d.hoursEnabled }
            if ($null -ne $d.fromTime)     { $script:cfg.fromTime = "$($d.fromTime)" }
            if ($null -ne $d.toTime)       { $script:cfg.toTime = "$($d.toTime)" }
            # just turned on -> nudge promptly for instant feedback
            if (-not $wasEnabled -and $script:cfg.enabled) {
              $script:lastNudge = (Get-Date).AddSeconds(-$script:cfg.intervalSec)
            }
            Save-Config
          } catch {}
          Send-Json $ns (Status-Object)
        }

        '^POST /api/quit$' {
          Send-Text $ns "200 OK" 'text/plain' 'bye'
          Write-Host ("[{0}] quit requested - stopping." -f (Get-Date -Format HH:mm:ss))
          $script:running = $false
        }

        '^GET ' { Serve-Static $ns $path }

        default { Send-Text $ns "405 Method Not Allowed" 'text/plain' 'no' }
      }
    } catch {
    } finally {
      $client.Close()
    }
  }
} finally {
  $listener.Stop()
}
