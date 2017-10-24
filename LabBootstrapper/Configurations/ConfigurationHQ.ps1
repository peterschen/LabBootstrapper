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
        @{ModuleName="xWindowsUpdate";ModuleVersion="2.7.0.0"}

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node HQ
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
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

        $files = @(
            "dnsmgmt.mmc",
            "dnsmgr.dll",
            "en-US\dnsmgmt.mmc",
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
    }
}