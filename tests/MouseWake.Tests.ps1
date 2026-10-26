param([string]$Source=(Join-Path $PSScriptRoot '..\src\KeyboardIdleBacklight.ps1'))
$ErrorActionPreference='Stop'
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Source),[ref]$null,[ref]$null)
$fn=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Select-IdleMilliseconds'},$true)
if(-not $fn.Count){throw 'FAIL: keyboard-only input selection is missing.'}
Invoke-Expression $fn[0].Extent.Text
$script:mouseWakeEnabled=$false
if((Select-IdleMilliseconds 0 10000) -ne 10000){throw 'Mouse input incorrectly wakes keyboard when disabled.'}
if((Select-IdleMilliseconds 0 0) -ne 0){throw 'Keyboard input must wake when mouse disabled.'}
$script:mouseWakeEnabled=$true
if((Select-IdleMilliseconds 0 10000) -ne 0){throw 'Mouse input must wake when enabled.'}
'PASS: mouse disabled ignores mouse activity; keyboard works; mouse enabled accepts activity.'

