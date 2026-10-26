$ErrorActionPreference='Stop'
$source=Get-Content (Join-Path $PSScriptRoot '..\src\KeyboardIdleBacklight.ps1') -Raw
$testSettingsPath=Join-Path ([IO.Path]::GetTempPath()) ('keyboard-idle-settings-'+[Guid]::NewGuid().ToString('N')+'.json')
try {
 $start=$source.IndexOf('$script:timeoutSeconds = 10')
 $end=$source.IndexOf('function Save-Settings',$start)
 $load=$source.Substring($start,$end-$start)
 $load=[regex]::Replace($load,'(?m)^\$configPath = .*$', '$configPath = $testSettingsPath')
 @{TimeoutSeconds=3;OnBrightness=3;MouseWakeEnabled=$false;SuppressFirstWakeKey=$false;ProlongedWakeHold=$false} | ConvertTo-Json | Set-Content $testSettingsPath
 Invoke-Expression $load
 if($script:suppressFirstWakeKey -or $script:prolongedWakeHold -or $script:mouseWakeEnabled){throw 'Saved false preference lost.'}
 if($script:timeoutSeconds -ne 3 -or $script:onBrightness -ne 3){throw 'Existing preferences lost.'}
 $ast=[System.Management.Automation.Language.Parser]::ParseInput($source,[ref]$null,[ref]$null)
 $fn=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Save-Settings'},$true)[0]
 Invoke-Expression $fn.Extent.Text
 Save-Settings
 $saved=Get-Content $testSettingsPath -Raw | ConvertFrom-Json
 if($saved.SuppressFirstWakeKey -isnot [bool] -or $saved.ProlongedWakeHold -isnot [bool] -or $saved.SuppressFirstWakeKey -or $saved.ProlongedWakeHold){throw 'False switches not saved as Booleans.'}
 @{TimeoutSeconds=5;OnBrightness=2;MouseWakeEnabled=$false} | ConvertTo-Json | Set-Content $testSettingsPath
 Invoke-Expression $load
 if(-not $script:suppressFirstWakeKey -or -not $script:prolongedWakeHold){throw 'Legacy settings did not retain enabled behavior.'}
 'PASS: false switches survive load/save; legacy settings preserve previous behavior.'
}finally{if(Test-Path -LiteralPath $testSettingsPath){Remove-Item -LiteralPath $testSettingsPath}}
