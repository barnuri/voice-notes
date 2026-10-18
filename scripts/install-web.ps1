#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$TaskName = 'VoiceNotes Web'
$Port = 5555
$MinNodeMajor = 22
$RestartDelaySeconds = 5
$Repo = Split-Path -Parent $PSScriptRoot
$WebDir = Join-Path $Repo 'web'
$MainScript = Join-Path $WebDir 'src\main.js'
$LogDir = Join-Path $env:LOCALAPPDATA 'VoiceNotes\logs'
$LogFile = Join-Path $LogDir 'web.log'
$UserId = "$env:USERDOMAIN\$env:USERNAME"

function ConvertTo-SingleQuoted([string]$Text) {
  "'" + ($Text -replace "'", "''") + "'"
}

function Find-Tailscale {
  $command = Get-Command tailscale -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }
  $installed = Join-Path $env:ProgramFiles 'Tailscale\tailscale.exe'
  if (Test-Path $installed) { return $installed }
  return $null
}

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) {
  Write-Error "Node.js is not on PATH. Install Node $MinNodeMajor or later, then run this script again."
}
$nodeMajor = [int](& $node.Source -p "process.versions.node.split('.')[0]")
if ($nodeMajor -lt $MinNodeMajor) {
  Write-Error "Node $(& $node.Source --version) is too old. Install Node $MinNodeMajor or later."
}

$tailscale = Find-Tailscale
$publicUrl = ''
if ($tailscale) {
  $tsHost = (& $tailscale status --json | Out-String | ConvertFrom-Json).Self.DNSName.TrimEnd('.')
  $publicUrl = "https://${tsHost}:$Port"
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$runner = @(
  '[Console]::OutputEncoding = [Text.Encoding]::UTF8'
  "`$env:VOICENOTES_PUBLIC_URL = $(ConvertTo-SingleQuoted $publicUrl)"
  'while ($true) {'
  "  & $(ConvertTo-SingleQuoted $node.Source) $(ConvertTo-SingleQuoted $MainScript) 2>&1 |"
  "    ForEach-Object { `$_.ToString() } | Out-File -FilePath $(ConvertTo-SingleQuoted $LogFile) -Append -Encoding utf8"
  "  Start-Sleep -Seconds $RestartDelaySeconds"
  '}'
) -join "`n"
$encodedRunner = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($runner))

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
  -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand $encodedRunner" `
  -WorkingDirectory $WebDir
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $UserId
$principal = New-ScheduledTaskPrincipal -UserId $UserId -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
  -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero) `
  -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask -TaskName $TaskName
  Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}
Get-CimInstance Win32_Process -Filter "Name = 'node.exe'" |
  Where-Object { $_.CommandLine -and $_.CommandLine.Contains($MainScript) } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force }

Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
  -Principal $principal -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $TaskName

Write-Host "VoiceNotes web: http://localhost:$Port  (this computer)"
Write-Host "Logs: $LogFile"
if (-not $tailscale) {
  Write-Host 'Tailscale is not installed, so the web app is reachable from this computer only.'
  exit 0
}

Write-Host "Publishing $publicUrl with tailscale serve (tailnet only)."
Write-Host 'If Tailscale prints an approval link, open it, approve Serve/HTTPS, and this step finishes.'
& $tailscale serve --bg "--https=$Port" "http://127.0.0.1:$Port"
if ($LASTEXITCODE -ne 0) {
  Write-Error "tailscale serve failed with exit code $LASTEXITCODE."
}
Write-Host "                $publicUrl  (any device on your tailnet)"
