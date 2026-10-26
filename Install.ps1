#Requires -Version 5.1
#Requires -RunAsAdministrator
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Maintenance.ps1')

# Check capability before changing any installation or scheduled task.
$computer = Get-CimInstance Win32_ComputerSystem
if ($computer.Manufacturer -notmatch '^LENOVO$') { throw 'Only compatible Lenovo laptops are supported.' }
$device = Get-CimInstance -Namespace root/wmi -ClassName LENOVO_LIGHTING_METHOD
$status = Invoke-CimMethod -InputObject $device -MethodName Get_Lighting_Current_Status -Arguments @{ Lighting_ID = [byte]0 }
if (-not $status.ReturnValue -or $status.Current_Brightness_Level -notin 1,2,3) {
    throw 'The required Lenovo keyboard-lighting interface is unavailable.'
}
$files = @('KeyboardIdleBacklight.ps1','KeyboardActivityClock.cs','WakeKeyPolicy.cs')
foreach ($file in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot "src\$file") -PathType Leaf)) { throw "Missing source file: $file" }
}
$installPath = Join-Path ([Environment]::GetFolderPath('ProgramFiles')) 'KeyboardIdleBacklight'
$dataPath = Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KeyboardIdleBacklight'
Assert-NoReparsePoint $installPath
Assert-NoReparsePoint $dataPath
Protect-AppDirectory $installPath
Protect-AppDirectory $dataPath
$settingsPath = Join-Path $dataPath 'settings.json'
Assert-NoReparsePoint $settingsPath
$settings = @{ TimeoutSeconds = 10; OnBrightness = 2; MouseWakeEnabled = $true }
if (Test-Path -LiteralPath $settingsPath) {
    try {
        $old = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
        if ([int]$old.TimeoutSeconds -in 1,3,5,10,30,60,120,300) { $settings.TimeoutSeconds = [int]$old.TimeoutSeconds }
        if ([int]$old.OnBrightness -in 2,3) { $settings.OnBrightness = [int]$old.OnBrightness }
        if ($old.MouseWakeEnabled -is [bool]) { $settings.MouseWakeEnabled = $old.MouseWakeEnabled }
    } catch { Write-Warning 'Invalid settings will be replaced with defaults.' }
}
# Stop both the packaged task and the original prototype task on upgrade.
foreach ($taskName in @('Lenovo Keyboard Idle','Keyboard Backlight - 60 Second Idle')) {
    if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
        Stop-ScheduledTask -TaskName $taskName
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
    }
}
Start-Sleep -Seconds 1
foreach ($file in $files) {
    $target = Join-Path $installPath $file
    Assert-NoReparsePoint $target
    # Recreate files rather than following a preexisting hard link on overwrite.
    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Force }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot "src\$file") -Destination $target
}
foreach ($path in @($settingsPath,(Join-Path $dataPath 'activity.log'))) {
    Assert-NoReparsePoint $path
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
}
$settings | ConvertTo-Json | Set-Content -LiteralPath $settingsPath -Encoding UTF8
$executable = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$arguments = '-NoProfile -STA -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "' + (Join-Path $installPath 'KeyboardIdleBacklight.ps1') + '"'
$action = New-ScheduledTaskAction -Execute $executable -Argument $arguments -WorkingDirectory $installPath
$user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$taskSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName 'Lenovo Keyboard Idle' -Description 'Lenovo keyboard backlight idle timer with tray controls.' -Action $action -Trigger $trigger -Principal $principal -Settings $taskSettings | Out-Null
Start-ScheduledTask -TaskName 'Lenovo Keyboard Idle'
Write-Output "Installed for $user. Right-click the blue information icon near the clock."
