configuration ConfigurationEX
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

    Import-DscResource -ModuleName @{ModuleName="PSDesiredStateConfiguration";ModuleVersion="3.12.0.0"},
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"},
        @{ModuleName="xComputerManagement";ModuleVersion="1.7.0.0"} 

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "AS-HTTP-Activation",
        "Desktop-Experience",
        "NET-Framework-45-Features",
        "RPC-over-HTTP-proxy",
        "RSAT-Clustering",
        "RSAT-Clustering-CmdInterface",
        "RSAT-Clustering-Mgmt",
        "RSAT-Clustering-PowerShell",
        "Web-Mgmt-Console",
        "WAS-Process-Model",
        "Web-Asp-Net45",
        "Web-Basic-Auth",
        "Web-Client-Auth",
        "Web-Digest-Auth",
        "Web-Dir-Browsing",
        "Web-Dyn-Compression",
        "Web-Http-Errors",
        "Web-Http-Logging",
        "Web-Http-Redirect",
        "Web-Http-Tracing",
        "Web-ISAPI-Ext",
        "Web-ISAPI-Filter",
        "Web-Lgcy-Mgmt-Console",
        "Web-Metabase",
        "Web-Mgmt-Service",
        "Web-Net-Ext45",
        "Web-Request-Monitor",
        "Web-Server",
        "Web-Stat-Compression",
        "Web-Static-Content",
        "Web-Windows-Auth",
        "Web-WMI",
        "Windows-Identity-Foundation",
        "RSAT-ADDS"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node EX
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
            IPAddress = "$NetworkPrefix.50"
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
    }
}