#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$taskName = 'Enforce AMD External Events Utility Disabled'

$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if (-not $task) {
    Write-Output "The scheduled task '$taskName' is not installed; nothing was removed."
    exit 0
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction Stop
Write-Output "Removed task '$taskName'. The service's startup type and state were not changed."
