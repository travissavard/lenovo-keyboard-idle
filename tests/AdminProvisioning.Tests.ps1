#Requires -Version 5.1
#Requires -RunAsAdministrator
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\Maintenance.ps1')
$parent=[Environment]::GetFolderPath('CommonApplicationData')
$path=Join-Path $parent ('KeyboardIdle-ProvisioningTest-'+[Guid]::NewGuid().ToString('N'))
try {
 Protect-AppDirectory $path
 Assert-TrustedDirectory $path
 $raced=$false
 try { [KeyboardIdleSecureDirectory]::Create($path,(Get-Acl $path).GetSecurityDescriptorBinaryForm()) } catch { $raced=$true }
 if(-not $raced){throw 'Atomic creation adopted an existing directory.'}
 $acl=Get-Acl $path
 $users=New-Object Security.Principal.SecurityIdentifier('S-1-5-32-545')
 $rule=New-Object Security.AccessControl.FileSystemAccessRule($users,'Write','ContainerInherit,ObjectInherit','None','Allow')
 $acl.AddAccessRule($rule)
 Set-Acl -LiteralPath $path -AclObject $acl
 $rejected=$false
 try {Protect-AppDirectory $path}catch{$rejected=$true}
 if(-not $rejected){throw 'Untrusted writable directory was accepted.'}
 'PASS: protected atomic creation, existing-path race refusal, untrusted-directory refusal.'
} finally {
 # This exact generated directory is directly beneath ProgramData and is empty.
 if([IO.Path]::GetDirectoryName([IO.Path]::GetFullPath($path)) -ne $parent){throw 'Cleanup path escaped test parent.'}
 if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path}
}
