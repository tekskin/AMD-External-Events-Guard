# Keep AMD External Events Utility Disabled

These files install a Windows scheduled task that checks the **AMD External Events Utility** at startup. If the service is running, the task stops it and sets its startup type to **Disabled**. This re-applies the setting if a Windows or AMD driver update changes it.

The installer also stops and disables the service immediately. The scheduled task runs as `SYSTEM`, so it can manage the service whether or not a user is signed in.

## Requirements

- Windows 11 with the AMD External Events Utility installed.
- An account that can approve elevation and run PowerShell as an administrator.
- The included PowerShell scripts.

The installer looks up the service by its exact display name, `AMD External Events Utility`. If an AMD driver update renames or removes the service, the installer reports that it could not find it. The startup task's check is embedded in the installer, so update the display-name filters there and reinstall the task if the service has been renamed.

## Install

1. Copy `Install-AmdExternalEventsGuard.ps1` to the Windows 11 computer. Keep the file in a location available to the administrator account.
2. Open **Start**, search for **Windows PowerShell**, right-click it, and select **Run as administrator**. Approve the User Account Control prompt.
3. In the elevated PowerShell window, change to the folder containing the script. For example:

   ```powershell
   Set-Location 'C:\Users\YourName\Downloads\AmdExternalEventsGuard'
   ```

4. Run the installer:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Install-AmdExternalEventsGuard.ps1
   ```

   `-ExecutionPolicy Bypass` applies only to this PowerShell process; it does not change the computer's execution policy.

The installer registers a task named **Enforce AMD External Events Utility Disabled** to run at system startup as `SYSTEM`, then applies the service settings immediately. If a task with that name already exists, the installer replaces it with this task's configuration.

## Verify

Run the verification script from an elevated PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Test-AmdExternalEventsGuard.ps1
```

It reports the service state and startup type, the scheduled task's state and run-as account, and the task's last result. The expected service state is **Stopped** and **Disabled**; the task should run as `SYSTEM`.

To check or run the task manually, use **Task Scheduler**:

1. Open Start and search for **Task Scheduler**.
2. Select **Task Scheduler Library**.
3. Find **Enforce AMD External Events Utility Disabled**.
4. Right-click it and select **Run** to perform an immediate check.

The task may not be visible to a non-administrator account. Use an elevated PowerShell window when verifying or inspecting it.

## Remove

Run the removal script from an elevated PowerShell window:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Remove-AmdExternalEventsGuard.ps1
```

Removal deletes the scheduled task only. It intentionally does not re-enable or start the service. To restore the service manually after removing the task, run the following in elevated PowerShell:

```powershell
Set-Service -Name 'AMD External Events Utility' -StartupType Automatic
Start-Service -Name 'AMD External Events Utility'
```

## Troubleshooting

- **The service was not found:** Confirm the AMD driver/software is installed and that the service's display name is still `AMD External Events Utility`. You can inspect installed services with:

  ```powershell
  Get-CimInstance Win32_Service |
      Where-Object DisplayName -Like '*AMD*External*Events*' |
      Select-Object Name, DisplayName, State, StartMode
  ```

- **Access denied:** Reopen PowerShell using **Run as administrator**, then rerun the script.
- **The service is running again after startup:** Run the verification script elevated and run the scheduled task manually. In Task Scheduler, inspect the task's **History** tab for errors. The service could start briefly before the startup task runs.
- **A driver update changes the service name:** Update the display-name filter in `Install-AmdExternalEventsGuard.ps1` and reinstall the task.

## Files

- `Install-AmdExternalEventsGuard.ps1` — registers or updates the startup task and applies the service settings now.
- `Test-AmdExternalEventsGuard.ps1` — reports whether the service and task are configured as expected.
- `Remove-AmdExternalEventsGuard.ps1` — removes the startup task without changing the service's current configuration.
