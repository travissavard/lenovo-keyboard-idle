#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param([switch]$RemoveSettings)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.ps1')
$installPath = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'KeyboardIdleBacklight'
$dataPath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KeyboardIdleBacklight'
Assert-NoReparsePoint $installPath
Assert-NoReparsePoint $dataPath
foreach ($taskName in @('Lenovo Keyboard Idle','Keyboard Backlight - 60 Second Idle')) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $taskName
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}
Start-Sleep -Seconds 1
# A forced task stop skips app cleanup, so leave the keyboard usable and lit.
try {
    $device = Get-CimInstance -Namespace root/wmi -ClassName LENOVO_LIGHTING_METHOD
    Invoke-CimMethod -InputObject $device -MethodName Set_Lighting_Current_Status -Arguments @{Lighting_ID=[byte]0;Current_State_Type=[byte]0;Current_Brightness_Level=[byte]2} | Out-Null
} catch { Write-Warning 'Could not restore the backlight. Use Fn + Space if needed.' }
# Delete only the known app files; never recurse through arbitrary directories.
foreach ($file in @('KeyboardIdleBacklight.ps1','KeyboardActivityClock.cs','WakeKeyPolicy.cs')) {
    $target = Join-Path $installPath $file
    Assert-NoReparsePoint $target
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
}
if ($RemoveSettings) {
    foreach ($file in @('settings.json','activity.log')) {
        $target = Join-Path $dataPath $file
        Assert-NoReparsePoint $target
        if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    }
}
Write-Output 'Removed the startup tasks and app files. Settings are retained unless -RemoveSettings was used.'
