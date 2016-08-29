configuration ConfigurationDB
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
        @{ModuleName="xComputerManagement";ModuleVersion="1.8.0.0"} 

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node DB
    {
        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
        }

        xFirewall "F-FirewallSqlEngine"
        {
            Name = "SqlFirewallRule"
            DisplayName = "SQL Engine (tcp/1433)"
            Ensure = "Present"
            Enabled = "True"
            Profile = ("Domain", "Private")
            Direction = "InBound"
            LocalPort = "1433"
            Protocol = "TCP"
        }

        xFirewall "F-RemoteSvcAdmin-In-TCP"
        {
            Name = "RemoteSvcAdmin-In-TCP"
            Ensure = "Present"
            Enabled = "True"
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
            IPAddress = "$NetworkPrefix.20"
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