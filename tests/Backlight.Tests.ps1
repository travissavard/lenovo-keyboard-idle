param([string]$Source=(Join-Path $PSScriptRoot '..\src\KeyboardIdleBacklight.ps1'))
$ErrorActionPreference='Stop'
$text=Get-Content $Source -Raw
$keyboardClock=[pscustomobject]@{Hold=$false}
$keyboardClock | Add-Member ScriptMethod IsHolding {return $this.Hold}
$keyboardClock | Add-Member ScriptMethod SetDark {param($value)}
$script:level=1
$script:timeoutSeconds=5
$script:onBrightness=2
$script:mode=$null
$script:applyRequested=$false
function Read-Light { [pscustomobject]@{Current_Brightness_Level=$script:level;Current_State_Type=0} }
function Set-Light($Level,$State){$script:level=[int]$Level}
function Write-Activity($Text){}
$ast=[System.Management.Automation.Language.Parser]::ParseInput($text,[ref]$null,[ref]$null)
$fn=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Update-Backlight'},$true)
if($fn.Count){
 Invoke-Expression $fn[0].Extent.Text
 Update-Backlight 0
} else {
 $saved=$null;$idle=0
 $start=$text.IndexOf('   if ($idle -ge ')
 $end=$text.IndexOf('   $failures = 0',$start)
 Invoke-Expression $text.Substring($start,$end-$start)
}
if($script:level -ne 2){throw 'FAIL: starting dark with active input must turn on Low.'}
Update-Backlight 5000
if($script:level -ne 1){throw 'FAIL: idle must turn off.'}
Update-Backlight 0
if($script:level -ne 2){throw 'FAIL: activity must restore Low.'}
$script:onBrightness=3;$script:applyRequested=$true
Update-Backlight 0
if($script:level -ne 3){throw 'FAIL: High menu selection must apply.'}
Update-Backlight 5000
Update-Backlight 0
if($script:level -ne 3){throw 'FAIL: activity must restore High.'}
$keyboardClock.Hold=$true
Update-Backlight 60000
if($script:level -ne 3){throw 'FAIL: prolonged wake hold must override normal idle timeout.'}
$keyboardClock.Hold=$false
Update-Backlight 60000
if($script:level -ne 1){throw 'FAIL: normal timeout must resume after prolonged hold.'}
'PASS: startup, Low/High restore, prolonged hold overrides timeout, normal timeout resumes.'


