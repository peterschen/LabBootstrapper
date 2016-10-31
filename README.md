# Intro
This repository contains resources which can be used to quickly and easily hydrate a new lab environment based on Windows Server 2012 R2 or Windows Server 2016.

# Overview
The hydration process consists of a main script which controls the creation of required VHDs and VMs. All configuration in the VMs is done by PowerShell Desired State Configuration which is injected into the respective VHD. The script can be run even after the initial deployment when the DSC configuration has changed to adapt an existing setup instead of creating a new one from scratch.

The overall process has the following steps:

1. Stop VM
2. Create VHD
3. Create VM
4. Customization
  1. Copy unattend.xml
  2. Copy assets/bits required for this node
  3. Copy DSC modules
  4. Build and copy LCM configuration
  5. Build and copy DSC configuration
5. Start VM

# Prerequisites
The hydration process uses a parent VHD to create differencing disk. You can use ``Convert-WindowsImage.ps1`` to create an appropriate parent disk. Additionally when available the process copies sources to the target machine which will be installed by DSC during configuration. Currently the following sources are supported:

* SQL Server 2016
* SQL Server Management Studio 16.5
* System Center Operations Manager 2016

## Create Parent VHD
**Windows Server 2012 R2 (including KB3172614 and KB3066437):**

``Convert-WindowsImage -SourcePath "Windows Server 2012 R2 x64.iso" -Edition "ServerStandard" -VHDPath "server2012r2.vhdx" -SizeBytes 80GB -Package Windows8.1-KB3172614-x64.msu,Win8.1AndW2K12R2-KB3066437-x64.msu -Verbose;``

**Windows Server 2016 (including KB3197954):**

``Convert-WindowsImage -SourcePath "Windows Server 2016 x64.iso" -Edition "ServerStandard" -VHDPath "server2016.vhdx" -SizeBytes 80GB -Package AMD64-all-windows10.0-kb3197954-x64_74819c01705e7a4d0f978cc0fbd7bed6240642b0.msu -Verbose;``

## Source preparation
In order for the bootstrapper to copy the sources to the respective disk they need to be provided as follows:

<pre>&lt;LabBootstrapper root&gt;
 |_ Assets
 |__ Bits
 |___ DB
 |___ SSMS-Setup.ENU.exe (http://go.microsoft.com/fwlink/?linkid=832812)
 |____ SQL
 |_____ Source
 |______ (extract SQL Server 2016 iso here)
 |___ OM
 |____ prereqs
 |_____ ReportViewer.msi (http://go.microsoft.com/fwlink/?LinkId=816564)
 |_____ SQLSysClrTypes.msi (https://www.microsoft.com/en-us/download/details.aspx?id=42295)
 |____ Source
 |_____ (extract Operations Manager iso here)</pre>

# Running the Bootstrapper
The Bootstrapper comes with some parameters of which most are predefined and can be used as-is. If you want to customize your lab refer to the following table for available parameters.

Parameter | Required | Description | Default Value
--------- | -------- | ----------- | -------------
LabPrefix | Yes | Prefix used for VM creation and domain name | -
LabVms | No | Name of the VMs to create | @("DC", "DB", "OM", "OR")
VhdPath | Yes | Path of the parent VHD | -
VmPath | Yes | Path where the VHDs and VMs should be placed | -
HvSwitchName | Yes | Hyper-V switch name to use | -
OsProductKey | No | Product key for the OS customization (defaults to Windows Server 2016 KMS activation key | WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY
OsOrganization | No | Organization used for OS customization | $LabPrefix
OsOwner | No | Owner used for OS customization | $LabPrefix
OsTimezone | No  | Timezone used for OS customization | W. Europe Standard Time
OsUiLanguage | No | UI language used for OS customization | en-US
OsInputLanguage | No | Input language used for OS customization | de-DE
OsPassword | No | Password used for OS customization and account creation | Admin123
NetworkPrefix | No | Network prefix used for VMs | 10.4.0

**Create a lab with Windows Server 2012 R2:**

``Invoke-LabBootstrapper.ps1 -LabPrefix Test -VhdPath "server2012r2.vhdx' -VmPath C:\ -HvSwitchName "LAB" -OsProductKey "D2N9P-3P6X9-2R39C-7RTCD-MDVJX";``

**Create a lab with Windows Server 2016:**

``Invoke-LabBootstrapper.ps1 -LabPrefix Test -VhdPath "server2016.vhdx' -VmPath C:\ -HvSwitchName "LAB";``

# Node LCM configuration
Each nodes' LCM is configured to the following:

```
ConfigurationModeFrequencyMins = 15
RebootNodeIfNeeded = $true
ConfigurationMode = "ApplyAndAutoCorrect"            
ActionAfterReboot = "ContinueConfiguration"
RefreshMode = "Push"
DebugMode = "All"
```

# Node DSC Configuration
Each node which is to be created needs a DSC configuration. By default the nodes ``DC``, ``DB``, ``OM`` and ``OR``are created and already have a configuration. The configuration for the domain controller contains the creation of the domain, appropriate users and groups.

If you want to add additional nodes to your lab, make sure that a configuration exists. The signature of the configuration needs to adhere to the following:

```
[Parameter(Mandatory = $true)]
[string] $DomainName,
[Parameter(Mandatory = $true)]
[pscredential] $Credential,
[Parameter(Mandatory = $true)]
[string] $NetworkPrefix,
```
