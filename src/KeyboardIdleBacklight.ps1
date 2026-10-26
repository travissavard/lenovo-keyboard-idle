$ErrorActionPreference = 'Stop'
$mutex = New-Object Threading.Mutex($false, 'Local\LenovoKeyboardIdle60')
if (-not $mutex.WaitOne(0)) { exit }
$logPath = (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KeyboardIdleBacklight\activity.log')
function Write-Activity([string]$Text) {
 if ((Test-Path $logPath) -and (Get-Item $logPath).Length -gt 65536) { Set-Content $logPath '' }
 Add-Content $logPath ((Get-Date -Format o) + ' ' + $Text)
}
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class KeyboardIdleClock {
 [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
 [DllImport("user32.dll", SetLastError=true)] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);
 public static uint Milliseconds() {
  var info = new LASTINPUTINFO(); info.cbSize = (uint)Marshal.SizeOf(info);
  if (!GetLastInputInfo(ref info)) throw new System.ComponentModel.Win32Exception();
  return unchecked((uint)Environment.TickCount - info.dwTime);
 }
}
"@
$device = Get-CimInstance -Namespace root/wmi -ClassName LENOVO_LIGHTING_METHOD
function Read-Light {
 $s = Invoke-CimMethod -InputObject $device -MethodName Get_Lighting_Current_Status -Arguments @{Lighting_ID=[byte]0}
 if (-not $s.ReturnValue -or $s.Current_Brightness_Level -notin 1,2,3) { throw 'Unexpected keyboard lighting response.' }
 return $s
}
function Set-Light($Level, $State) {
 $r = Invoke-CimMethod -InputObject $device -MethodName Set_Lighting_Current_Status -Arguments @{Lighting_ID=[byte]0; Current_Brightness_Level=[byte]$Level; Current_State_Type=[byte]$State}
 # This Lenovo setter returns no ReturnValue, even when it succeeds.
 for ($attempt=0; $attempt -lt 5; $attempt++) {
  if ((Read-Light).Current_Brightness_Level -eq $Level) { return }
  Start-Sleep -Milliseconds 100
 }
 throw "Keyboard brightness did not reach requested level $Level."
}
$script:timeoutSeconds = 10
$script:onBrightness = 2
$script:mouseWakeEnabled = $true
$script:mode = $null
$script:applyRequested = $false
$configPath = (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'KeyboardIdleBacklight\settings.json')
if (Test-Path $configPath) {
 try {
  $settings = Get-Content $configPath -Raw | ConvertFrom-Json
  if ([int]$settings.TimeoutSeconds -in 1,3,5,10,30,60,120,300) { $script:timeoutSeconds = [int]$settings.TimeoutSeconds }
  if ($settings.MouseWakeEnabled -is [bool]) { $script:mouseWakeEnabled = $settings.MouseWakeEnabled }
  if ([int]$settings.OnBrightness -in 2,3) { $script:onBrightness = [int]$settings.OnBrightness }
 } catch {}
}
function Save-Settings {
 @{TimeoutSeconds=$script:timeoutSeconds;OnBrightness=$script:onBrightness;MouseWakeEnabled=$script:mouseWakeEnabled} | ConvertTo-Json | Set-Content -LiteralPath $configPath
}
function Select-IdleMilliseconds([uint32]$AllInputIdle, [uint32]$KeyboardInputIdle) {
 if ($script:mouseWakeEnabled) { return $AllInputIdle }
 return $KeyboardInputIdle
}
function Update-Backlight([uint32]$IdleMilliseconds) {
 $nextMode = if ($keyboardClock.IsHolding()) { 'Active' } elseif ($IdleMilliseconds -ge ($script:timeoutSeconds * 1000)) { 'Idle' } else { 'Active' }
 if ($script:mode -eq $nextMode -and -not $script:applyRequested) { return }
 $target = if ($nextMode -eq 'Idle') { 1 } else { $script:onBrightness }
 $current = Read-Light
 if ($current.Current_Brightness_Level -ne $target) { Set-Light $target $current.Current_State_Type }
 $keyboardClock.SetDark($target -eq 1)
 $script:mode = $nextMode
 $script:applyRequested = $false
 Write-Activity "Mode=$nextMode; brightness=$target; idle=$IdleMilliseconds ms."
}
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
Add-Type -Path @((Join-Path $PSScriptRoot 'WakeKeyPolicy.cs'),(Join-Path $PSScriptRoot 'KeyboardActivityClock.cs')) -ReferencedAssemblies System.Windows.Forms
$keyboardClock = New-Object KeyboardActivityClock
$script:exitRequested = $false
$tray = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = [System.Drawing.SystemIcons]::Information
$tray.Text = 'Keyboard backlight idle timer'
$menu = New-Object System.Windows.Forms.ContextMenuStrip
$label = $menu.Items.Add('Turn keyboard backlight off after:')
$label.Enabled = $false
$script:timingItems = @()
foreach ($option in @(@(1,'1 second'),@(3,'3 seconds'),@(5,'5 seconds'),@(10,'10 seconds'),@(30,'30 seconds'),@(60,'1 minute'),@(120,'2 minutes'),@(300,'5 minutes'))) {
 $item = New-Object System.Windows.Forms.ToolStripMenuItem
 $item.Text = [string]$option[1]
 $item.Tag = [int]$option[0]
 $item.Checked = ([int]$item.Tag -eq $script:timeoutSeconds)
 $item.add_Click({
  param($sender,$eventArgs)
  $script:timeoutSeconds = [int]$sender.Tag
  foreach ($entry in $script:timingItems) { $entry.Checked = ([int]$entry.Tag -eq $script:timeoutSeconds) }
  $script:applyRequested = $true
  try { Save-Settings; Write-Activity "Timeout changed: $script:timeoutSeconds seconds." } catch { Write-Activity $_.Exception.Message }
 })
 $script:timingItems += $item
 [void]$menu.Items.Add($item)
}
[void]$menu.Items.Add('-')
$brightnessMenu = New-Object System.Windows.Forms.ToolStripMenuItem('Back-on brightness')
$script:brightnessItems = @()
foreach ($option in @(@(2,'Low'),@(3,'High'))) {
 $item = New-Object System.Windows.Forms.ToolStripMenuItem
 $item.Text = [string]$option[1]
 $item.Tag = [int]$option[0]
 $item.Checked = ([int]$item.Tag -eq $script:onBrightness)
 $item.add_Click({
  param($sender,$eventArgs)
  $script:onBrightness = [int]$sender.Tag
  foreach ($entry in $script:brightnessItems) { $entry.Checked = ([int]$entry.Tag -eq $script:onBrightness) }
  $script:applyRequested = $true
  try { Save-Settings; Write-Activity "Back-on brightness changed: $script:onBrightness." } catch { Write-Activity $_.Exception.Message }
 })
 $script:brightnessItems += $item
 [void]$brightnessMenu.DropDownItems.Add($item)
}
[void]$menu.Items.Add($brightnessMenu)
[void]$menu.Items.Add('-')
$mouseItem = New-Object System.Windows.Forms.ToolStripMenuItem('Mouse wakes keyboard')
$mouseItem.CheckOnClick = $true
$mouseItem.Checked = $script:mouseWakeEnabled
$mouseItem.add_Click({
 param($sender,$eventArgs)
 $script:mouseWakeEnabled = $sender.Checked
 $script:applyRequested = $true
 try { Save-Settings; Write-Activity "Mouse wake enabled: $script:mouseWakeEnabled." } catch { Write-Activity $_.Exception.Message }
})
[void]$menu.Items.Add($mouseItem)
[void]$menu.Items.Add('-')
$exitItem = $menu.Items.Add('Exit')
$exitItem.add_Click({ $script:exitRequested = $true })
$tray.ContextMenuStrip = $menu
$tray.Visible = $true
$failures=0
Write-Activity "Started v5: timeout=$script:timeoutSeconds seconds; back-on brightness=$script:onBrightness; mouse wake=$script:mouseWakeEnabled; long-dark wake=15s, hold=15s."
try {
 while (-not $script:exitRequested) {
  [System.Windows.Forms.Application]::DoEvents()
  if ($script:exitRequested) { break }
  try {
   Update-Backlight (Select-IdleMilliseconds ([Math]::Min([KeyboardIdleClock]::Milliseconds(),$keyboardClock.Milliseconds())) ($keyboardClock.Milliseconds()))
   $failures=0
  } catch {
   Write-Activity ('Error: '+$_.Exception.Message)
   $failures++
   if($failures -ge 3){throw}
   Start-Sleep -Milliseconds 500
  }
  Start-Sleep -Milliseconds 100
 }
} finally {
 try { $current=Read-Light; Set-Light $script:onBrightness $current.Current_State_Type } catch {}
 Write-Activity 'Stopped; backlight restored and tray icon removed.'
 $tray.Visible=$false
 $tray.Dispose()
 $keyboardClock.Dispose()
 $menu.Dispose()
 $mutex.ReleaseMutex()
 $mutex.Dispose()
}



