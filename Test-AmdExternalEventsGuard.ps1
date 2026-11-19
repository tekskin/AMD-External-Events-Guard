#Requires -Version 5.1
#Requires -RunAsAdministrator

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

$taskName = 'Enforce AMD External Events Utility Disabled'
$serviceDisplayName = 'AMD External Events Utility'
$service = Get-CimInstance -ClassName Win32_Service -Filter "DisplayName='$serviceDisplayName'" -ErrorAction Stop
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue

if (-not $service) {
    [Console]::Error.WriteLine("The service '$serviceDisplayName' was not found.")
    exit 1
}

if (-not $task) {
    [Console]::Error.WriteLine("The scheduled task '$taskName' was not found. Run the installer as administrator.")
    exit 1
}

$taskInfo = Get-ScheduledTaskInfo -TaskName $taskName -ErrorAction Stop
$hasStartupTrigger = @(
    $task.Triggers |
        Where-Object { $_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger' }
).Count -gt 0
$result = [pscustomobject]@{
    ServiceName       = $service.Name
    ServiceState      = $service.State
    ServiceStartup    = $service.StartMode
    TaskName          = $task.TaskName
    TaskState         = $task.State
    TaskRunAs         = $task.Principal.UserId
    TaskRunsAtStartup = $hasStartupTrigger
    TaskLastRun       = $taskInfo.LastRunTime
    TaskLastResult    = $taskInfo.LastTaskResult
}
$result | Format-List

if ($service.State -ne 'Stopped' -or
    $service.StartMode -ne 'Disabled' -or
    $task.Principal.UserId -ne 'SYSTEM' -or
    -not $hasStartupTrigger -or
    $task.State -eq 'Disabled') {
    [Console]::Error.WriteLine('The service or scheduled task does not match the expected configuration.')
    exit 1
}

Write-Output 'The service is stopped and disabled, and the startup task is enabled.'
