configuration ConfigurationAPP1
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [pscredential] $Credential,

        [Parameter(Mandatory = $true)]
        [string] $NetworkPrefix
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cpBase, `
        PackageManagement, xPSDesiredStateConfiguration, xNetworking;
    Import-DscResource -Name "PSModule" -ModuleName "PackageManagementProviderResource" -ModuleVersion "1.0.3";

    $features = @(
        "Containers",
        "Hyper-V",
        "Hyper-V-PowerShell"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node APP1
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        cpFirewall "Firewall"
        {
        }

        xFirewall "F-Docker"
        {
            Name = "Docker"
            DisplayName = "Docker (tcp/2375)"
            Ensure = "Present"
            Enabled = "True"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            LocalPort = 2375
            Protocol = "tcp"
        }

        xFirewall "F-Docker-lcow"
        {
            Name = "Docker LCOW"
            DisplayName = "Docker LCOW (tcp/12375)"
            Ensure = "Present"
            Enabled = "True"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            LocalPort = 12375
            Protocol = "tcp"
        }

        xFirewall "F-DockerSwarmMaster"
        {
            Name = "DockerSwarmMaster"
            DisplayName = "Docker Swarm Master (tcp/3375)"
            Ensure = "Present"
            Enabled = "True"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            LocalPort = 3375
            Protocol = "tcp"
        }

        for($i = 0; $i -lt 101; $i++)
        {
            $port = 50000 + $i;
            xFirewall "F-Container-$port"
            {
                Name = "Container-$port"
                DisplayName = "Container (tcp/$port)"
                Ensure = "Present"
                Enabled = "True"
                Profile = ("Domain", "Private", "Public")
                Direction = "Inbound"
                LocalPort = $port
                Protocol = "tcp"
            }
        }

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.70/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        PSModule "PM-DockerProvider"
        {
            Ensure = "Present"
            Name = "DockerMsftProvider"
            InstallationPolicy = "trusted"
            Repository = "PSGallery"
        }

        PackageManagement "PM-Docker"
        {
            Ensure = "Present"
            Name = "docker"
            ProviderName = "DockerMsftProvider"
            DependsOn = "[PSModule]PM-DockerProvider"
        }

        Registry "R-DockerServiceConfiguration"
        {
            Ensure = "Present"
            Key = "HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Services\Docker"
            ValueName = "ImagePath"
            ValueData = "C:\Program Files\Docker\dockerd.exe --run-service -H tcp://0.0.0.0:2375 -H npipe://"
            DependsOn = "[PackageManagement]PM-Docker"
        }

        Script "S-RebootDocker"
        {
            GetScript = { @{ Result = "" } }
            SetScript = {
                New-Item -Path "C:\LabBits\reboot-docker.txt" -Type File -Force;
                $global:DSCMachineStatus = 1;
            }
            TestScript = {
                return (Test-Path C:\LabBits\reboot-docker.txt)
            }
            DependsOn = "[Registry]R-DockerServiceConfiguration"
        }

        File "F-LinuxContainers"
        {
            DestinationPath = "$env:ProgramFiles\Linux Containers"
            Ensure = "Present"
            Type = "Directory"
        }

        File "F-docker-kernel"
        {
            DestinationPath = "$env:ProgramFiles\Linux Containers\bootx64.efi"
            SourcePath = "C:\LabBits\lcow-kernel"
            Ensure = "Present"
            DependsOn = "[File]F-LinuxContainers"
        }

        File "F-docker-initrd"
        {
            DestinationPath = "$env:ProgramFiles\Linux Containers\initrd.img"
            SourcePath = "C:\LabBits\lcow-initrd.img"
            Ensure = "Present"
            DependsOn = "[File]F-LinuxContainers"
        }

        File "F-docker-dockerd.exe"
        {
            DestinationPath = "$env:ProgramFiles\Linux Containers\dockerd.exe"
            SourcePath = "C:\LabBits\dockerd.exe"
            Ensure = "Present"
            DependsOn = "[File]F-LinuxContainers"
        }

        Environment "E-LCOW_SUPPORTED"
        {
            Name = "LCOW_SUPPORTED"
            Value = "1"
            Ensure = "Present"
        }

        Environment "E-LCOW_API_PLATFORM_IF_OMITTED"
        {
            Name = "LCOW_API_PLATFORM_IF_OMITTED"
            Value = "linux"
            Ensure = "Present"
        }

        xService "xS-docker-lcow"
        {
            Name = "docker-lcow"
            Ensure = "Present"
            StartupType = "Automatic"
            Path = "$env:ProgramFiles\Linux Containers\dockerd.exe --run-service --experimental -H tcp://0.0.0.0:12375 -H npipe:////./pipe/lcow --data-root C:\lcow"
            DependsOn = "[File]F-docker-dockerd.exe","[Environment]E-LCOW_SUPPORTED","[Environment]E-LCOW_API_PLATFORM_IF_OMITTED"
        }
    }
}