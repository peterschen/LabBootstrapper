configuration ConfigurationOMWC
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
        @{ModuleName="xCredSSP";ModuleVersion="1.1.0.0"}

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "Web-Default-Doc",
        "Web-Dir-Browsing",
        "Web-Http-Errors",
        "Web-Static-Content",
        "Web-Http-Logging",
        "Web-Request-Monitor",
        "Web-Stat-Compression",
        "Web-Windows-Auth",
        "Web-Asp-Net",
        "NET-Framework-45-ASPNET",
        "NET-WCF-HTTP-Activation45",
        "Web-Mgmt-Console",
        "Web-Metabase"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);
    $actionCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-msaa", $Credential.Password);
    $sdkCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-sdk", $Credential.Password);
    $drCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-datareader", $Credential.Password);
    $dwCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-datawriter", $Credential.Password);

    Node OMWC
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

        xFirewall "F-IIS-WebServerRole-HTTP-In-TCP"
        {
            Name = "IIS-WebServerRole-HTTP-In-TCP"
            Ensure = "Present"
            Enabled = "True"
        }

        xIPAddress "IA-Ip"
        {
            IPAddress = "$NetworkPrefix.80"
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
            MembersToInclude = @("$DomainName\g-LocalAdmins", "$DomainName\s-om-sdk", "$DomainName\s-om-msaa")
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

        Package "P-SqlServerClrTypes"
        {
            Ensure = "Present"
            Name = "Microsoft System CLR Types for SQL Server 2014"
            ProductId = ""
            Path = "C:\LabBits\prereqs\SQLSysClrTypes.msi"
            Arguments = "ALLUSERS=2"
        }

        Package "P-ReportViewer"
        {
            Ensure = "Present"
            Name = "Microsoft Report Viewer 2015 Runtime"
            ProductID = ""
            Path = "C:\LabBits\prereqs\ReportViewer.msi"
            Arguments = "ALLUSERS=2"
            DependsOn = "[Package]P-SqlServerClrTypes"
        }

        xCredSSP "CS-Server"
        {
            Ensure = "Present"
            Role = "Server"
        }

        xCredSSP "CS-Client"
        {
            Ensure = "Present"
            Role = "Client"
            DelegateComputers = $Node.NodeName
        }

        WaitForAll "WFA-DB"
        {
            NodeName = "DB"
            ResourceName = "[xSqlServerFirewall]SSF-Firewall"
            PsDscRunAsCredential = $domainCredential
            RetryCount = 720
            RetryIntervalSec = 5
        }
    }
}