Intro
=
This repository contains resources which can be used to quickly and easily hydrate a new lab environment based on Windows Server 2012, Windows Server 2012 R2 or Windows Server 2016.

Overview
=
The hydration process consists of a main script which controls the creation of required VHDs and VMs. All configuration in the VMs is done by PowerShell Desired State Configuration which is injected into the respective VHD. The script can be run even after the initial deployment when the DSC configuration has changed to adapt an existing setup instead of creating a new one from scratch.

The overall process has the following steps:
1. Create VHD
2. Create VM
3. Copy unattend.xml, DSC modules, LCM configuration, DSC configuration
4. Start VM

Prerequisites
=
The hydration process uses a parent VHD to create differencing disk. You can use ``Convert-WindowsImage.ps1`` to create an appropriate parent disk.

Examples
==
Windows Server 2012 R2 (including KB3172614 and KB3066437)
``Convert-WindowsImage -SourcePath "Windows Server 2012 R2 x64.iso" -Edition Standard -VHDPath "server2012r2.vhdx" -SizeBytes 80GB -DiskLayout UEFI -Package Windows8.1-KB3172614-x64.msu,Win8.1AndW2K12R2-KB3066437-x64.msu -Verbose;``

Windows Server 2016 TP5 (including KB3158987)
``Convert-WindowsImage -SourcePath "Windows Server 2016 TP5 x64.iso" -Edition Standard -VHDPath "server2012r2.vhdx" -SizeBytes 80GB -DiskLayout UEFI -Package AMD64-all-windows10.0-kb3158987-x64_6b363d8ecc6ac98ca26396daf231017a258bfc94.msu -Verbose;``

Running the Bootstrapper
=

``Invoke-LabBootstrapper.ps1 -LabPrefix Test -VhdPath "server2012r2.vhdx' -VmPath C:\ -HvSwitchName "LAB";``

Configuration Signature
=

[Parameter(Mandatory = $true)]
[string] $DomainName,

[Parameter(Mandatory = $true)]
[pscredential] $Credential,

[Parameter(Mandatory = $true)]
[string] $NetworkPrefix,
