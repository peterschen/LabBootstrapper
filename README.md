# Intro
This repository contains resources which can be used to quickly and easily hydrate a new lab environment based on Windows Server 2012 R"or Windows Server 2016.

# Overview
The hydration process consists of a main script which controls the creation of required VHDs and VMs. All configuration in the VMs is done by PowerShell Desired State Configuration which is injected into the respective VHD. The script can be run even after the initial deployment when the DSC configuration has changed to adapt an existing setup instead of creating a new one from scratch.

The overall process has the following steps:

1. Stop VM
2. Create VHD
3. Create VM
4. Copy unattend.xml, DSC modules, LCM configuration, DSC configuration
5. Start VM

# Prerequisites
The hydration process uses a parent VHD to create differencing disk. You can use ``Convert-WindowsImage.ps1`` to create an appropriate parent disk.

## Examples
**Windows Server 2012 R2 (including KB3172614 and KB3066437):**

``Convert-WindowsImage -SourcePath "Windows Server 2012 R2 x64.iso" -Edition Standard -VHDPath "server2012r2.vhdx" -SizeBytes 80GB -DiskLayout UEFI -Package Windows8.1-KB3172614-x64.msu,Win8.1AndW2K12R2-KB3066437-x64.msu -Verbose;``

**Windows Server 2016 TP5 (including KB3158987):**

``Convert-WindowsImage -SourcePath "Windows Server 2016 TP5 x64.iso" -Edition Standard -VHDPath "server2012r2.vhdx" -SizeBytes 80GB -DiskLayout UEFI -Package AMD64-all-windows10.0-kb3158987-x64_6b363d8ecc6ac98ca26396daf231017a258bfc94.msu -Verbose;``

# Running the Bootstrapper
The Bootstrapper comes with some parameters of which most are predefined and can be used as-is. If you want to customize your lab refer to the following table for available parameters.

Parameter | Required | Description | Default Value
--------- | -------- | ----------- | -------------
LabPrefix | Yes | Prefix used for VM creation and domain name | -
LabVms | No | Name of the VMs to create | @("DC", "DB", "OM", "OR")
VhdPath | Yes | Path of the parent VHD | -
VmPath | Yes | Path where the VHDs and VMs should be placed | -
HvSwitchName | Yes | Hyper-V switch name to use | -
OsProductKey | No | Product key for the OS customization (defaults to Windows Server 2016 TP5 KMS activation key | MFY9F-XBN2F-TYFMP-CCV49-RMYVH
OsOrganization | No | Organization used for OS customization | $LabPrefix
OsOwner | No | Owner used for OS customization | $LabPrefix
OsTimezone | No  | Timezone used for OS customization | W. Europe Standard Time
OsUiLanguage | No | UI language used for OS customization | en-US
OsInputLanguage | No | Input language used for OS customization | de-DE
OsPassword | No | Password used for OS customization and account creation | Admin123
NetworkPrefix | No | Network prefix used for VMs | 10.4.0

**Create a lab with Windows Server 2012 R2:**

``Invoke-LabBootstrapper.ps1 -LabPrefix Test -VhdPath "server2012r2.vhdx' -VmPath C:\ -HvSwitchName "LAB" -OsProductKey "D2N9P-3P6X9-2R39C-7RTCD-MDVJX";``

**Create a lab with Windows Server 2016 Tp5:**

``Invoke-LabBootstrapper.ps1 -LabPrefix Test -VhdPath "server2016tp5.vhdx' -VmPath C:\ -HvSwitchName "LAB";``

# Configuration Signature
[Parameter(Mandatory = $true)]
[string] $DomainName,

[Parameter(Mandatory = $true)]
[pscredential] $Credential,

[Parameter(Mandatory = $true)]
[string] $NetworkPrefix,
