param
(
    [switch] $SkipVmCreation,
    [string] $Prefix,
    [string] $VhdPath,
    [string] $VmPath,
    [string] $HvSwitchName,
    [string] $OsProductKey = "D2N9P-3P6X9-2R39C-7RTCD-MDVJX",
    [string] $OsOrganization = $Prefix,
    [string] $OsOwner = $Prefix,
    [string] $OsTimezone = "W. Europe Standard Time",
    [string] $OsUiLanguage = "en-US",
    [string] $OsInputLanguage = "de-DE",
    [string] $OsPassword = "Admin123"
);

$ErrorActionPreference = "Stop";

# Source libraries
. ".\UnattendLib.ps1";

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
)

# 0. Validation
# - Do we have Hyper-V?
# - VHD path valid?
# - VM path valid?

if(-not $SkipVmCreation)
{
    Import-Module Hyper-V -ErrorAction SilentlyContinue;
    if(-not (Get-Module Hyper-V))
    {
        Write-Error "Hyper-V PowerShell module could not be loaded";
        exit;
    }

    if(-not (Test-Path -Path $VhdPath))
    {
        Write-Error "VHD path does not exists";
        exit;
    }

    if(-not (Test-Path -Path $VmPath))
    {
        Write-Error "VM path does not exists";
        exit;
    }

    if(-not (Get-VMSwitch -Name $HvSwitchName -ErrorAction SilentlyContinue))
    {
        Write-Error "Hyper-V switch could not be found";
        exit;
    }
}

# 1. Create VMs
if(-not $SkipVmCreation)
{
    # Prepare unattend.xml content with generic parameters
    $unattend = $unattend -replace $Script:PLACEHOLDER_PRODUCTKEY, $OsProductKey;
    $unattend = $unattend -replace $Script:PLACEHOLDER_ORGANIZATION, $OsOrganization;
    $unattend = $unattend -replace $Script:PLACEHOLDER_OWNER, $OsOwner;
    $unattend = $unattend -replace $Script:PLACEHOLDER_TIMEZONE, $OsTimezone;
    $unattend = $unattend -replace $Script:PLACEHOLDER_LANGUAGE, $OsLanguage;
    $unattend = $unattend -replace $Script:PLACEHOLDER_PASSWORD, $OsPassword;

    foreach($vmName in $Script:Vms)
    {
        $newVhdPath = "$VmPath\$($Prefix)-$($vmName).vhdx";

        if(-not (Test-Path -Path $newVhdPath))
        {
            $newVhd = New-VHD -ParentPath $VhdPath -Path $newVhdPath -Differencing;
            $newVhdPath = $newVhd.Path;

            # Prepare unattend.xml content with VM specific parameters
            $unattend = $unattend -replace $Script:PLACEHOLDER_COMPUTERNAME, $vmName;

            # Mount VHD to inject unattend XML
            $mountPoint = (Get-Disk -Number (Mount-VHD -Path $newVhdPath -Passthru).DiskNumber | Get-Partition | Where-Object {$_.Type -eq "Basic"}).DriveLetter;
            $unattendFile = New-Item -Path "$($mountPoint):\Windows\Panther" -Name "unattend.xml" -ItemType File;
            Add-Content -Path $unattendFile.FullName -Value $unattend;
            Dismount-VHD -Path $newVhdPath;
        }

        $vm = Get-VM -Name "$($Prefix)-$($vmName)" -ErrorAction SilentlyContinue;
        if(-not $vm)
        {
            $vm = New-VM -Name "$($Prefix)-$($vmName)" -SwitchName $HvSwitchName -Path $VmPath -VHDPath $newVhdPath -MemoryStartupBytes 1GB -Generation 2;
            Set-VMMemory -VM $vm -DynamicMemoryEnabled $false;
        }

        # Start VM
        Start-VM -VM $vm -ErrorAction SilentlyContinue;
    }
}