param
(
    [string] $Prefix,
    [string] $VhdPath,
    [string] $VmPath,
    [string] $HvSwitchName,
    [string] $OsProductKey = "MFY9F-XBN2F-TYFMP-CCV49-RMYVH",
    [string] $OsOrganization = $Prefix,
    [string] $OsOwner = $Prefix,
    [string] $OsTimezone = "W. Europe Standard Time",
    [string] $OsUiLanguage = "en-US",
    [string] $OsInputLanguage = "de-DE",
    [string] $OsPassword = "Admin123"
);

$ErrorActionPreference = "Stop";

# Source libraries
. ".\LibUnattend.ps1";

function Copy-UnattendFile
{
    param
    (
        [string] $Path,
        [string] $ComputerName,
        [string] $ProductKey,
        [string] $Organization,
        [string] $Owner,
        [string] $Timezone,
        [string] $UiLanguage,
        [string] $InputLanguage,
        [string] $Password

    );

    process
    {
        $unattend = $unattend -replace $Script:PLACEHOLDER_COMPUTERNAME, $ComputerName;
        $unattend = $unattend -replace $Script:PLACEHOLDER_PRODUCTKEY, $ProductKey;
        $unattend = $unattend -replace $Script:PLACEHOLDER_ORGANIZATION, $Organization;
        $unattend = $unattend -replace $Script:PLACEHOLDER_OWNER, $Owner;
        $unattend = $unattend -replace $Script:PLACEHOLDER_TIMEZONE, $Timezone;
        $unattend = $unattend -replace $Script:PLACEHOLDER_UILANGUAGE, $UiLanguage;
        $unattend = $unattend -replace $Script:PLACEHOLDER_INPUTLANGUAGE, $InputLanguage;
        $unattend = $unattend -replace $Script:PLACEHOLDER_PASSWORD, $Password;
        
        $unattendFile = New-Item -Path $Path -Name "unattend.xml" -ItemType File;
        Add-Content -Path $unattendFile.FullName -Value $unattend;
    }
}

function Copy-DscModules
{
    param
    (
        [string] $Path,
        [string[]] $Modules

    );

    process
    {
        foreach($module in $Modules)
        {
            Copy-Item -Path ".\Assets\DscModules\$module" -Destination $Path -Recurse;
        }
    }
}

function Copy-DscMetaConfiguration
{
    param
    (
        [string] $ComputerName,
        [string] $Path
    );

    process
    {
        # dot-source DSC meta configuration if not done yet
        . ".\ConfigurationLcm.ps1";

        $workDirectory = "$env:TEMP\LabBootstrapper";
        ConfigurationLcm -ComputerName $ComputerName -OutputPath $workDirectory | Out-Null;
        Copy-Item -Path "$($workDirectory)\$($ComputerName).meta.mof" -Destination "$($Path)\Metaconfig.mof" -Force;
    }
}

function Copy-DscConfiguration
{
    param
    (
        [string] $ComputerName,
        [string] $Path,
        [string] $Password
    );

    process
    {
        # dot-source DSC configuration if not done yet
        . ".\Configuration$ComputerName.ps1";

        $workDirectory = "$env:TEMP\LabBootstrapper";
        $credential = New-Object System.Management.Automation.PSCredential "Administrator", (ConvertTo-SecureString -AsPlainText -Force $Password);
        $dscConfiguration = "Configuration$($vmName) -DomainName '$($Prefix.ToLower()).lab' -Credential `$credential -OutputPath '$workDirectory' -ConfigurationData @{AllNodes =@(@{NodeName = '$vmName'; PSDscAllowPlainTextPassword = `$true; PSDscAllowDomainUser = `$true})}";
        $dscConfigurationScript = [scriptblock]::Create($dscConfiguration);
        Invoke-Command -ScriptBlock $dscConfigurationScript | Out-Null;

        Remove-Item -Path "$($Path)\Current.mof" -Force -ErrorAction SilentlyContinue;
        Copy-Item -Path "$($workDirectory)\$($ComputerName).mof" -Destination "$($Path)\Pending.mof" -Force;
    }
}

$Script:PLACEHOLDER_COMPUTERNAME = "PLACEHOLDER_COMPUTERNAME";
$Script:PLACEHOLDER_PRODUCTKEY = "PLACEHOLDER_PRODUCTKEY";
$Script:PLACEHOLDER_ORGANIZATION = "PLACEHOLDER_ORGANIZATION";
$Script:PLACEHOLDER_OWNER = "PLACEHOLDER_OWNER";
$Script:PLACEHOLDER_TIMEZONE = "PLACEHOLDER_TIMEZONE";
$Script:PLACEHOLDER_UILANGUAGE = "PLACEHOLDER_UILANGUAGE";
$Script:PLACEHOLDER_INPUTLANGUAGE = "PLACEHOLDER_INPUTLANGUAGE";
$Script:PLACEHOLDER_PASSWORD = "PLACEHOLDER_PASSWORD";

$Script:Vms = @(
    "DC"#,
    #"DB",
    #"OM",
    #"OR"
);

$Script:dscModules = @(
    "xNetworking", 
    "xActiveDirectory", 
    "xPSDesiredStateConfiguration"
);

<#
    0. Validation
    1. Create VMs
    2. Inject DSC configuration into VM
    3. Start VM
#>

# 0. Validation
Import-Module Hyper-V -ErrorAction SilentlyContinue;
if(-not (Get-Module Hyper-V))
{
    throw "Hyper-V PowerShell module could not be loaded";
}

if(-not (Test-Path -Path $VhdPath))
{
    throw "VHD path does not exists";
}

if(-not (Test-Path -Path $VmPath))
{
    throw "VM path does not exists";
}

if(-not (Test-Path -Path ".\Assets"))
{
    throw "Assets could not be found";
}

if(-not (Get-VMSwitch -Name $HvSwitchName -ErrorAction SilentlyContinue))
{
    throw "Hyper-V switch could not be found";
}


$requireUnattend = $false;
$requireDscModules = $false;

# 1. Create VMs
foreach($vmName in $Script:Vms)
{
    $proceed = $true;
    $newVhdPath = "$VmPath\$($Prefix)-$($vmName).vhdx";

    # Check if the VM exists
    $vm = Get-VM -Name "$($Prefix)-$($vmName)" -ErrorAction SilentlyContinue;
    if(-not $vm)
    {
        # Test if the VHD exists
        if(-not (Test-Path -Path $newVhdPath))
        {
            $newVhd = New-VHD -ParentPath $VhdPath -Path $newVhdPath -Differencing -SizeBytes 80GB;
            $newVhdPath = $newVhd.Path;

            $requireUnattend = $true;
            $requireDscModules = $true;
        }
        else
        {
            Write-Warning "VHD already exists";
        }
            
        $vm = New-VM -Name "$($Prefix)-$($vmName)" -SwitchName $HvSwitchName -Path $VmPath -VHDPath $newVhdPath -MemoryStartupBytes 1GB -Generation 2;
        Set-VMMemory -VM $vm -DynamicMemoryEnabled $false;
    }
    else
    {
        Write-Warning "Skipping VM creation for $($vmName) as it already exists";
    }

    if($proceed)
    {
        # Stop VM before mouting the VHD
        if($vm.State -ne "Off")
        {
            Stop-VM -VM $vm;
        }

        try
        {
            # Mount VHD to inject unattend XML, copy DSC modules and copy DSC meta info and documents
            $mountPoint = (Get-Disk -Number (Mount-VHD -Path $newVhdPath -Passthru).DiskNumber | Get-Partition | Where-Object {$_.Type -eq "Basic"}).DriveLetter;

            if($requireUnattend)
            {
                Copy-UnattendFile -Path "$($mountPoint):\" -ComputerName $vmName -ProductKey $OsProductKey -Organization $OsOrganization `
                    -Owner $OsOwner -Timezone $OsTimezone -UiLanguage $OsUiLanguage -InputLanguage $OsInputLanguage -Password $OsPassword;
            }
            
            if($requireDscModules)
            {
                Copy-DscModules -Path "$($mountPoint):\Program Files\WindowsPowerShell\Modules" -Modules $Script:dscModules;
            }

            # Build and copy DSC meta configuration
            Copy-DscMetaConfiguration -ComputerName $vmName -Path "$($mountPoint):\Windows\system32\Configuration";

            # Build vm specific DSC configuration
            Copy-DscConfiguration -ComputerName $vmName -Path "$($mountPoint):\Windows\system32\Configuration" -Password $OsPassword;
        }
        catch
        {
            throw $_;
        }
        finally
        {
            # Make sure we dismount the VHD in any case
            Dismount-VHD -Path $newVhdPath;
            $proceeed = $false;
        }
    }

    if($proceed)
    {
        # Start VM
        Start-VM -VM $vm -ErrorAction SilentlyContinue;
    }
}