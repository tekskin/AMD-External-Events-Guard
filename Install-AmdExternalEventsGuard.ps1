#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$taskName = 'Enforce AMD External Events Utility Disabled'
$serviceDisplayName = 'AMD External Events Utility'

$installedServices = @(
    Get-CimInstance -ClassName Win32_Service `
        -Filter "DisplayName='$serviceDisplayName'" `
        -ErrorAction Stop
)
if ($installedServices.Count -eq 0) {
    throw "The service '$serviceDisplayName' was not found. Confirm the AMD driver is installed."
}
if ($installedServices.Count -gt 1) {
    throw "More than one service has the display name '$serviceDisplayName'; refusing to change an ambiguous service."
}

$workerScript = @'
$ErrorActionPreference = 'Stop'
$services = @(Get-CimInstance -ClassName Win32_Service -Filter "DisplayName='AMD External Events Utility'" -ErrorAction Stop)

if ($services.Count -gt 1) {
    throw "More than one service has the display name 'AMD External Events Utility'; refusing to change an ambiguous service."
}

if ($services.Count -eq 0) {
    Write-Output "The service 'AMD External Events Utility' is not installed; no action was needed."
    return
}

$service = Get-Service -Name $services[0].Name -ErrorAction Stop
if ($service.Status -eq [System.ServiceProcess.ServiceControllerStatus]::Running) {
    Stop-Service -Name $service.Name -Force -ErrorAction Stop
    $service.WaitForStatus(
        [System.ServiceProcess.ServiceControllerStatus]::Stopped,
        [TimeSpan]::FromSeconds(30)
    )
}

Set-Service -Name $service.Name -StartupType Disabled -ErrorAction Stop
Write-Output "Stopped the service if it was running and set its startup type to Disabled."
'@

$taskScript = @"
`$ErrorActionPreference = 'Stop'
try {
$workerScript
    exit 0
} catch {
    [Console]::Error.WriteLine(`$_.Exception.Message)
    exit 1
}
"@
$encodedTaskScript = [Convert]::ToBase64String(
    [Text.Encoding]::Unicode.GetBytes($taskScript)
)

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encodedTaskScript"
$trigger = New-ScheduledTaskTrigger `
    -AtStartup `
    -RandomDelay (New-TimeSpan -Seconds 30)
$principal = New-ScheduledTaskPrincipal `
    -UserId 'SYSTEM' `
    -LogonType ServiceAccount `
    -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Minutes 2) `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName $taskName `
    -Description 'At startup, stop AMD External Events Utility if running and disable its startup.' `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Force | Out-Null

try {
    & ([ScriptBlock]::Create($workerScript))
} catch {
    [Console]::Error.WriteLine("The startup task was registered, but applying the service settings now failed: $($_.Exception.Message)")
    exit 1
}

Write-Output "Installed task '$taskName' to enforce the service setting at startup."
