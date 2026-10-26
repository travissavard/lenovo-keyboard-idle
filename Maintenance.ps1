# Shared by the administrator-only install and uninstall scripts.
function Assert-NoReparsePoint([string]$Path) {
    $current = [IO.Path]::GetFullPath($Path)
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            if ((Get-Item -LiteralPath $current -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
                throw "Refusing a symbolic link or junction: $current"
            }
        }
        $parent = [IO.Path]::GetDirectoryName($current)
        if ($parent -eq $current) { break }
        $current = $parent
    }
}
function Protect-AppDirectory([string]$Path) {
    Assert-NoReparsePoint $Path
    if (Test-Path -LiteralPath $Path) {
        Assert-TrustedDirectory $Path
        return
    }
    $acl = New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $admins = New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')
    $acl.SetOwner($admins)
    foreach ($sid in @('S-1-5-18','S-1-5-32-544','S-1-5-32-545')) {
        $identity = New-Object Security.Principal.SecurityIdentifier($sid)
        $rights = if ($sid -eq 'S-1-5-32-545') { 'ReadAndExecute' } else { 'FullControl' }
        $rule = New-Object Security.AccessControl.FileSystemAccessRule($identity,$rights,'ContainerInherit,ObjectInherit','None','Allow')
        $acl.AddAccessRule($rule)
    }
    # Set the DACL atomically at creation; do not adopt a racing existing path.
    if (-not ('KeyboardIdleSecureDirectory' -as [type])) {
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class KeyboardIdleSecureDirectory {
 [StructLayout(LayoutKind.Sequential)] struct ATTR { public int Length; public IntPtr Descriptor; public int Inherit; }
 [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateDirectory(string path, ref ATTR attributes);
 public static void Create(string path, byte[] descriptor) {
  var pin=GCHandle.Alloc(descriptor,GCHandleType.Pinned);
  try {
   var attributes=new ATTR{Length=Marshal.SizeOf(typeof(ATTR)),Descriptor=pin.AddrOfPinnedObject(),Inherit=0};
   if(!CreateDirectory(path,ref attributes)) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error());
  } finally {pin.Free();}
 }
}
'@
    }
    [KeyboardIdleSecureDirectory]::Create($Path,$acl.GetSecurityDescriptorBinaryForm())
    Assert-TrustedDirectory $Path
}
function Assert-TrustedDirectory([string]$Path) {
    Assert-NoReparsePoint $Path
    $acl = Get-Acl -LiteralPath $Path
    $trusted = @('S-1-5-18','S-1-5-32-544',[Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
    if ($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -notin $trusted) {
        throw "Refusing an existing directory owned by another user: $Path. Review and remove the old directory manually before installing."
    }
    $writeRights = [Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership
    foreach ($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        if ($rule.AccessControlType -eq 'Allow' -and $rule.IdentityReference.Value -notin $trusted -and ($rule.FileSystemRights -band $writeRights)) {
            throw "Refusing an existing directory writable by non-administrators: $Path. Review its permissions before installing."
        }
    }
}
