configuration ConfigurationHQ
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

    Import-DscResource -ModuleName PSDesiredStateConfiguration, 
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"},
        @{ModuleName="xComputerManagement";ModuleVersion="1.8.0.0"},
        @{ModuleName="PackageManagementProviderResource";ModuleVersion="1.0.3"},
        @{ModuleName="xSCOM";ModuleVersion="1.3.3.0"},
        @{ModuleName="xWindowsUpdate";ModuleVersion="2.7.0.0"},
        @{ModuleName="xDismFeature";ModuleVersion="1.2.0.0"}        

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "Microsoft-Hyper-V-Tools-All"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node HQ
    {
        foreach($feature in $features)
        {
            xDismFeature "xDF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        xFirewall "F-FPS-NB_Datagram-In-UDP"
        {
            Name = "FPS-NB_Datagram-In-UDP"
            Ensure = "Present"
            Enabled = "True"
        }

        xFirewall "F-FPS-NB_Name-In-UDP"
        {
            Name = "FPS-NB_Name-In-UDP"
            Ensure = "Present"
            Enabled = "True"
        }

        xFirewall "F-FPS-NB_Session-In-TCP"
        {
            Name = "FPS-NB_Session-In-TCP"
            Ensure = "Present"
            Enabled = "True"
        }

        xFirewall "F-FPS-SMB-In-TCP"
        {
            Name = "FPS-SMB-In-TCP"
            Ensure = "Present"
            Enabled = "True"
        }

        xIPAddress "IA-Ip"
        {
            IPAddress = "$NetworkPrefix.253"
            SubnetMask = 24
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
        }

        xDnsServerAddress "DSA-DnsConfiguration"
        { 
            Address = "$NetworkPrefix.10"
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
            DependsOn = "[xIPAddress]IA-Ip"
        }

        xDefaultGatewayAddress "DGA-GatewayConfiguration"
        {
            Address = "$NetworkPrefix.10"
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
        }

        xComputer "C-JoinDomain"
        {
            Name = $Node.NodeName
            DomainName = $DomainName
            Credential = $domainCredential
            DependsOn = "[xDnsServerAddress]DSA-DnsConfiguration"
        }

        Group "G-Administrators"
        {
            GroupName = "Administrators"
            Credential = $domainCredential
            MembersToInclude = "$DomainName\g-LocalAdmins"
            DependsOn = "[xComputer]C-JoinDomain"
        }

        Group "G-RemoteDesktopUsers"
        {
            GroupName = "Remote Desktop Users"
            Credential = $domainCredential
            MembersToInclude = "$DomainName\g-RemoteDesktopUsers"
            DependsOn = "[xComputer]C-JoinDomain"
        }

        Group "G-RemoteManagementUsers"
        {
            GroupName = "Remote Management Users"
            Credential = $domainCredential
            MembersToInclude = "$DomainName\g-RemoteManagementUsers"
            DependsOn = "[xComputer]C-JoinDomain"
        }

        Package "P-SqlServerManagementStudio"
        {
            Ensure = "Present"
            Name = "Microsoft SQL Server Management Studio - 16.5"
            ProductID = ""
            Path = "C:\LabBits\SSMS-Setup-ENU.exe"
            Arguments = "/install /quiet"
        }

        Package "P-ReportViewer"
        {
            Ensure = "Present"
            Name = "Microsoft Report Viewer 2015 Runtime"
            ProductID = ""
            Path = "C:\LabBits\prereqs\ReportViewer.msi"
            Arguments = "ALLUSERS=2"
        }

        xSCOMConsoleSetup "SCS-Console"
        {
            Ensure = "Present"
            SourcePath = "C:\LabBits"
            SourceFolder = "Source"
            SetupCredential = $domainCredential
            DependsOn = "[xComputer]C-JoinDomain","[Package]P-ReportViewer"
        }

        xHotfix "H-RSAT"
        {
            Ensure = "Present"
            Path = "C:\LabBits\WindowsTH-RSAT_WS_1709-x64.msu"
            Id = "KB2693643"
        }

        # Workaround for the broken RSAT package which is missing the DNS configuration

        $files = @(
            "dnsmgmt.msc",
            "dnsmgr.dll",
            "en-US\dnsmgmt.msc",
            "en-US\dnsmgr.dll.mui"            
        )

        foreach($file in $files)
        {
            File "F-dnsrsat-$file"
            {
                DestinationPath = "C:\Windows\System32\$file"
                SourcePath = "C:\LabBits\DNS\$file"
                Ensure = "Present"
                Force = $true
                DependsOn = "[xHotfix]H-RSAT"
            }
        }

        File "F-dnsrsat-DNS.lnk"
        {
            DestinationPath = "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DNS.lnk"
            SourcePath = "C:\LabBits\DNS\DNS.lnk"
            Ensure = "Present"
            Force = $true
            DependsOn = "[xHotfix]H-RSAT"
        }

        Script "S-dnsrsat"
        {
            GetScript = { 
                $installDate = Get-Content (Join-Path -Path $env:SYSTEMDRIVE -ChildPath 'dnsrsat.txt')
                return @{ 'InstallDate' = "$installDate" }
            }
            TestScript = { 
                $state = $GetScript;
                
                if($state['InstallDate'] -eq "")
                {
                    Write-Verbose -Message "DNS snap-in not registered yet";
                    return $true;
                }

                Write-Verbose -Message ("DNS snap-in was registered on: {0}" -f $state["InstalldDate"]);
                return $false;
            }
            SetScript = {
                try
                {
                    $result = Start-Process -FilePath 'regsvr32.exe' -Args "/s c:\windows\system32\dnsmgr.dll" -Wait -NoNewWindow;
                    Set-Content -Path (Join-Path -Path $env:SYSTEMDRIVE -ChildPath 'dnsrsat.txt') -Value (Get-Date);
                }
                catch
                {
                    Write-Error -Message ("Could not register DNS snap-in: {0}" -f $_.Exception.Message);
                }
            }
            DependsOn = "[File]F-dnsrsat-dnsmgr.dll"
        }

        Environment "E-Path"
        {
            Name = "Path"
            Value = "$env:Path;C:\LabBits\tools"
            Ensure = "Present"
        }

        Environment "E-DockerHost"
        {
            Name = "DOCKER_HOST"
            Value = "app1"
            Ensure = "Present"
        }
    }
}