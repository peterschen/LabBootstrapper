param
(
    [string] $LabPrefix,
    [string[]] $LabVms = @(
        "DC",
        "DB",
        "OM",
        "OR"
    ),
    [string] $VmPath,
    [string] $VhdPath,
    [string] $MasterVhdPath,
    [string] $BitsPath,
    [string] $HvSwitchName,
    [string] $OsProductKey = "WC2BQ-8NRM3-FDDYY-2BFGV-KHKQY",
    [string] $OsOrganization = $LabPrefix,
    [string] $OsOwner = $LabPrefix,
    [string] $OsTimezone = "W. Europe Standard Time",
    [string] $OsUiLanguage = "en-US",
    [string] $OsInputLanguage = "de-DE",
    [string] $OsPassword = "Admin123",
    [string] $NetworkPrefix = "10.4.0"
);

$ErrorActionPreference = "Stop";
$VerbosePreference = "Continue";

# Determine base path from invokation
$basePath = Split-Path -Parent $(Split-Path -Parent -Resolve $MyInvocation.MyCommand.Path);

# Source libraries
. "$basePath\Scripts\LibUnattend.ps1";

$Script:PATH_CONFIGURATIONS = "$basePath\Configurations"
$Script:PATH_ASSETS = "$basePath\Assets";
$Script:PATH_DSCMODULES = "$($Script:PATH_ASSETS)\DscModules";

$Script:PACKAGES = @{
    "xActiveDirectory" = "2.13.0.0"
    "xComputerManagement" = "1.8.0.0"
    "xNetworking" = "2.11.0.0"
    "xPSDesiredStateConfiguration" = "3.13.0.0"
    "xSQLServer" = "2.0.0.0"
    "xCredSSP" = "1.1.0.0"
    "xSCOM" = "1.3.3.0"
    "PackageManagementProviderResource" = "1.0.3"
};

$Script:PLACEHOLDER_COMPUTERNAME = "PLACEHOLDER_COMPUTERNAME";
$Script:PLACEHOLDER_PRODUCTKEY = "PLACEHOLDER_PRODUCTKEY";
$Script:PLACEHOLDER_ORGANIZATION = "PLACEHOLDER_ORGANIZATION";
$Script:PLACEHOLDER_OWNER = "PLACEHOLDER_OWNER";
$Script:PLACEHOLDER_TIMEZONE = "PLACEHOLDER_TIMEZONE";
$Script:PLACEHOLDER_UILANGUAGE = "PLACEHOLDER_UILANGUAGE";
$Script:PLACEHOLDER_INPUTLANGUAGE = "PLACEHOLDER_INPUTLANGUAGE";
$Script:PLACEHOLDER_PASSWORD = "PLACEHOLDER_PASSWORD";

function Test-Prerequisites
{
    param
    (
    );

    process
    {
        $VerbosePreference = "SilentlyContinue";
        Import-Module Hyper-V -ErrorAction SilentlyContinue;
        $VerbosePreference = "Continue";

        if(-not (Get-Module Hyper-V))
        {
            throw "Hyper-V PowerShell module could not be loaded";
        }

        if(-not (Test-Path -Path $MasterVhdPath))
        {
            throw "VHD path does not exists";
        }

        if(-not (Test-Path -Path $VmPath))
        {
            try
            {
                New-Item -Path $VhdPath -ItemType Directory | Out-Null;
            }
            catch [System.Exception]
            {
                throw "VM path does not exists and could not be created";
            }
        }

        if(-not (Test-Path -Path $Script:PATH_ASSETS))
        {
            throw "Assets could not be found";
        }

        if(-not (Get-VMSwitch -Name $HvSwitchName -ErrorAction SilentlyContinue))
        {
            throw "Hyper-V switch could not be found";
        }
    }
}

function Get-DscModules
{
    param
    (
    );

    process
    {
        foreach($package in $Script:PACKAGES.Keys)
        {
            $version = $Script:PACKAGES[$package];
            $path = "$($Script:PATH_DSCMODULES)\$($package)\$($version)";

            if(-not (Test-Path -Path $path))
            {
                Save-Package -Name $package -RequiredVersion $version -Path $Script:PATH_DSCMODULES;
            }

            if(-not (Get-InstalledModule -Name $package -RequiredVersion $version))
            {
                Install-Module -Name $package -RequiredVersion $version;
            }
        }
    }
}

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
        
        $unattendFile = New-Item -Path $Path -Name "unattend.xml" -ItemType File -Force;
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
        Copy-Item -Path "$($Script:PATH_DSCMODULES)\*" -Destination $Path -Recurse -Force;
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
        . "$($Script:PATH_CONFIGURATIONS)\ConfigurationLcm.ps1";

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
        . "$($Script:PATH_CONFIGURATIONS)\Configuration$ComputerName.ps1";

        $workDirectory = "$env:TEMP\LabBootstrapper";
        $credential = New-Object PSCredential "Administrator", (ConvertTo-SecureString -AsPlainText -Force $Password);
        $dscConfiguration = "Configuration$($vmName) -DomainName '$($LabPrefix.ToLower()).lab' -Credential `$credential -NetworkPrefix `$NetworkPrefix -OutputPath '$workDirectory' -ConfigurationData @{AllNodes =@(@{NodeName = '$vmName'; PSDscAllowPlainTextPassword = `$true; PSDscAllowDomainUser = `$true})}";
        $dscConfigurationScript = [scriptblock]::Create($dscConfiguration);
        Invoke-Command -ScriptBlock $dscConfigurationScript | Out-Null;

        Remove-Item -Path "$($Path)\Current.mof" -Force -ErrorAction SilentlyContinue;
        Copy-Item -Path "$($workDirectory)\$($ComputerName).mof" -Destination "$($Path)\Pending.mof" -Force;
    }
}

function Copy-Bits
{
    param
    (
        [string] $ComputerName,
        [string] $SourcePath,
        [string] $DestinationPath
    );

    process
    {
        if(Test-Path "$SourcePath\$ComputerName")
        {
            if(-not (Test-Path $DestinationPath))
            {
                New-Item -Path $DestinationPath -ItemType Directory | Out-Null;
            }

            Copy-Item -Path "$($SourcePath)\$($ComputerName)\*" -Destination $DestinationPath -Recurse -Force;
        }
    }
}

function Write-LogDebug
{
    param
    (
        [string] $Prefix,
        [string] $Message
    );

    process
    {
        Write-Debug -Message "[$($Prefix)] $($Message)";
    }
}

function Write-LogVerbose
{
    param
    (
        [string] $Prefix,
        [string] $Message
    );

    process
    {
        Write-Verbose -Message "[$($Prefix)] $($Message)";
    }
}

function Write-LogInformation
{
    param
    (
        [string] $Prefix,
        [string] $Message
    );

    process
    {
        Write-Information -Message "[$($Prefix)] $($Message)";
    }
}

function Write-LogWarning
{
    param
    (
        [string] $Prefix,
        [string] $Message
    );

    process
    {
        Write-Warning -Message "[$($Prefix)] $($Message)";
    }
}

try
{
    # Validation
    Test-Prerequisites;

    # Download required DSC modules
    Get-DscModules;

    $requireUnattend = $false;

    # Main processing loop
    foreach($vmName in $LabVms)
    {
        $proceed = $true;
        $newVhdPath = "$VhdPath\$($LabPrefix)-$($vmName).vhdx";
        
        Write-LogVerbose -Prefix $vmName -Message "Start processing";

        # Check if the VM exists
        $vm = Get-VM -Name "$($LabPrefix)-$($vmName)" -ErrorAction SilentlyContinue;
        if(-not $vm)
        {
            Write-LogVerbose -Prefix $vmName -Message "VM does not exists";

            # Test if the VHD exists
            if(-not (Test-Path -Path $newVhdPath))
            {
                $newVhd = New-VHD -ParentPath $MasterVhdPath -Path $newVhdPath -Differencing -SizeBytes 80GB;
                $newVhdPath = $newVhd.Path;

                $requireUnattend = $true;
            }
            else
            {
                Write-LogVerbose -Prefix $vmName -Message "VHD $($newVhdPath) already exists";
            }
            
            $vm = New-VM -Name "$($LabPrefix)-$($vmName)" -SwitchName $HvSwitchName -Path $VmPath -VHDPath $newVhdPath -MemoryStartupBytes 1GB -Generation 2;
            Set-VMMemory -VM $vm -DynamicMemoryEnabled $false;
        }
        else
        {
            Write-LogVerbose -Prefix $vmName -Message "Skipping VM creation for $($vmName) as it already exists";
        }

        if($proceed)
        {
            # Stop VM before mouting the VHD
            if($vm.State -ne "Off")
            {
                Write-LogVerbose -Prefix $vmName -Message "Shutting down running VM";
                Stop-VM -VM $vm;
            }

            try
            {
                Write-LogDebug -Prefix $vmName -Message "Mounting VHD $($newVhdPath)";

                # Mount VHD to inject unattend XML, copy DSC modules and copy DSC meta info and documents
                $mountPoint = (Get-Disk -Number (Mount-VHD -Path $newVhdPath -Passthru).DiskNumber | Get-Partition | Where-Object {$_.Type -eq "Basic"}).DriveLetter;

                if($requireUnattend)
                {
                    Write-LogVerbose -Prefix $vmName -Message "Copying unattend.xml";
                    Copy-UnattendFile -Path "$($mountPoint):\" -ComputerName $vmName -ProductKey $OsProductKey -Organization $OsOrganization `
                        -Owner $OsOwner -Timezone $OsTimezone -UiLanguage $OsUiLanguage -InputLanguage $OsInputLanguage -Password $OsPassword;
                }
            
                # Copy bits
                Write-LogVerbose -Prefix $vmName -Message "Copy bits";
                Copy-Bits -ComputerName $vmName -SourcePath $BitsPath -DestinationPath "$($mountPoint):\LabBits";

                # Copy DSC modules
                Write-LogVerbose -Prefix $vmName -Message "Copying DSC modules";
                Copy-DscModules -Path "$($mountPoint):\Program Files\WindowsPowerShell\Modules";

                # Build and copy DSC meta configuration
                Write-LogVerbose -Prefix $vmName -Message "Building and copying LCM configuration";
                Copy-DscMetaConfiguration -ComputerName $vmName -Path "$($mountPoint):\Windows\system32\Configuration";

                # Build vm specific DSC configuration
                Write-LogVerbose -Prefix $vmName -Message "Building and copying DSC configuration";
                Copy-DscConfiguration -ComputerName $vmName -Path "$($mountPoint):\Windows\system32\Configuration" -Password $OsPassword;
            }
            catch
            {
                $proceed = $false;
                throw $_;
            }
            finally
            {
                # Make sure we dismount the VHD in any case
                Dismount-VHD -Path $newVhdPath;
                Write-LogDebug -Prefix $vmName -Message "Dismounting VHD $($newVhdPath)";
            }
        }

        if($proceed)
        {
            Write-LogVerbose -Prefix $vmName -Message "Starting VM";

            # Start VM
            Start-VM -VM $vm -ErrorAction SilentlyContinue;
        }
    }
}
catch
{
    $line = $_.InvocationInfo.ScriptLineNumber;
    Write-Error "An error ocurred on line $($line): $($_)";
}