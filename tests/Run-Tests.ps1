$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
foreach($file in Get-ChildItem $root -Filter '*.ps1' -Recurse){
 $tokens=$null;$errors=$null
 [System.Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors) | Out-Null
 if($errors.Count){throw ($errors | Out-String)}
}
$executable=Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
foreach($test in @('WakePolicy.Tests.ps1','Backlight.Tests.ps1','MouseWake.Tests.ps1','Maintenance.Tests.ps1')){
 & $executable -NoProfile -STA -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot $test)
 if($LASTEXITCODE -ne 0){throw "Test failed: $test"}
}
Add-Type -Path @((Join-Path $root 'src\WakeKeyPolicy.cs'),(Join-Path $root 'src\KeyboardActivityClock.cs')) -ReferencedAssemblies System.Windows.Forms
'PASS: all PowerShell syntax and tests; both C# sources compile. No hook installed by the test suite.'
