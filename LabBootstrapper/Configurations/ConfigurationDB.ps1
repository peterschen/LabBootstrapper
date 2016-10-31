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
        @{ModuleName="xComputerManagement";ModuleVersion="1.8.0.0"},
        @{ModuleName="xSQLServer";ModuleVersion="2.0.0.0"}

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "NET-Framework-Core"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-sql-agent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-sql-engine", $Credential.Password);

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

        xFirewall "F-WMI-RPCSS-In-TCP"
        {
            Name = "WMI-RPCSS-In-TCP"
            Ensure = "Present"
            Enabled = "True"
        }

        xFirewall "F-WMI-WINMGMT-In-TCP"
        {
            Name = "WMI-WINMGMT-In-TCP"
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

        xSQLServerSetup "SSS-Default"
        {
            SourcePath = "C:\LabBits\SQL"
            SetupCredential = $domainCredential
            Features = "SQLENGINE,FULLTEXT"
            InstanceName = "MSSQLSERVER"
            SQLSysAdminAccounts = "$DomainName\g-SqlAdmins"
            SQLSvcAccount = $engineCredential
            AgtSvcAccount = $agentCredential
            DependsOn = "[WindowsFeature]WF-NET-Framework-Core","[xComputer]C-JoinDomain"
        }

        xSqlServerFirewall "SSF-Firewall"
        {
            SourcePath = "C:\LabBits\SQL"
            InstanceName = "MSSQLSERVER"
            Features = "SQLENGINE,FULLTEXT"
            DependsOn = "[xSqlServerSetup]SSS-Default"
        }

        xSQLServerPowerPlan "SSPP-PowerConfiguration"
        {
            Ensure = "Present"
        }

        xSQLServerMemory "SSM-MemoryConfiguration"
        {
            Ensure = "Present"
            DynamicAlloc = $true
            SQLInstanceName = "MSSQLSERVER"
            DependsOn = "[xSqlServerSetup]SSS-Default"
        }

        xSQLServerMaxDop "SSMD-DopConfiguration"
        {
            Ensure = "Present"
            DynamicAlloc = $true
            SQLInstanceName = "MSSQLSERVER"
            DependsOn = "[xSqlServerSetup]SSS-Default"
        }

        Package "P-SqlServerManagementStudio"
        {
            Ensure = "Present"
            Name = "Microsoft SQL Server Management Studio - 16.5"
            ProductID = ""
            Path = "C:\LabBits\SSMS-Setup-ENU.exe"
            Arguments = "/install /quiet"
            DependsOn = "[xSQLServerSetup]SSS-Default"
        }
    }
}