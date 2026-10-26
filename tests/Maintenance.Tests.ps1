$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\Maintenance.ps1')
$testRoot=Join-Path ([IO.Path]::GetTempPath()) ('keyboard-idle-tests-'+[Guid]::NewGuid().ToString('N'))
try {
 New-Item -ItemType Directory -Path $testRoot | Out-Null
 Assert-NoReparsePoint $testRoot
 $target=Join-Path $testRoot 'target'
 New-Item -ItemType Directory -Path $target | Out-Null
 $link=Join-Path $testRoot 'redirect'
 New-Item -ItemType Junction -Path $link -Target $target | Out-Null
 $rejected=$false
 try{Assert-NoReparsePoint (Join-Path $link 'settings.json')}catch{$rejected=$true}
 if(-not $rejected){throw 'Reparse-point ancestor was accepted.'}
 Remove-Item -LiteralPath $link -Force
 Remove-Item -LiteralPath $target
 'PASS: ordinary paths allowed; junction ancestors rejected.'
}finally{
 # These exact, known paths are inside the newly created test directory. No recursion.
 if(Test-Path -LiteralPath (Join-Path $testRoot 'redirect')){Remove-Item -LiteralPath (Join-Path $testRoot 'redirect') -Force}
 if(Test-Path -LiteralPath (Join-Path $testRoot 'target')){Remove-Item -LiteralPath (Join-Path $testRoot 'target')}
 if(Test-Path -LiteralPath $testRoot){Remove-Item -LiteralPath $testRoot}
}
