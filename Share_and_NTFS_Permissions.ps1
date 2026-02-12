$ShareName = "Noi_PreferredPatch"   # change this

# Get share info
$share = Get-SmbShare -Name $ShareName -ErrorAction Stop
$path  = $share.Path

# Collect share permissions
$sharePerms = Get-SmbShareAccess -Name $ShareName | Select-Object `
    @{n='ShareName';e={$ShareName}},
    @{n='Path';e={$path}},
    @{n='Account';e={$_.AccountName}},
    @{n='PermissionType';e={'Share'}},
    @{n='Rights';e={$_.AccessRight}},
    @{n='Access';e={$_.AccessControlType}}

# Collect NTFS permissions
$ntfsPerms = (Get-Acl $path).Access | Select-Object `
    @{n='ShareName';e={$ShareName}},
    @{n='Path';e={$path}},
    @{n='Account';e={$_.IdentityReference}},
    @{n='PermissionType';e={'NTFS'}},
    @{n='Rights';e={$_.FileSystemRights}},
    @{n='Access';e={$_.AccessControlType}}

# Combine
$final = $sharePerms + $ntfsPerms

# Display
$final | Format-Table -AutoSize
