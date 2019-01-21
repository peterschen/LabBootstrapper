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

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cpBase, `
        xSQLServer;

    $features = @(
        "NET-Framework-Core"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);
    $agentCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-sql-agent", $Credential.Password);
    $engineCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-sql-engine", $Credential.Password);
    $reportingCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-sql-reporting", $Credential.Password);

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

        cpFirewall "Firewall"
        {
            ExtraRules = @(
                "WMI-RPCSS-In-TCP",
                "WMI-WINMGMT-In-TCP"
            )
        }
        
        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.20/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        xSQLServerSetup "SSS-Default"
        {
            SourcePath = "C:\LabBits\SQL"
            Features = "SQLENGINE,FULLTEXT,RS"
            InstanceName = "MSSQLSERVER"
            SQLSysAdminAccounts = "$DomainName\g-SqlAdmins"
            SQLSvcAccount = $engineCredential
            AgtSvcAccount = $agentCredential
            RSSvcAccount = $reportingCredential
            DependsOn = "[WindowsFeature]WF-NET-Framework-Core","[cpDomainOnboarding]DomainOnboarding"
        }

        xSqlServerFirewall "SSF-Firewall"
        {
            SourcePath = "C:\LabBits\SQL"
            InstanceName = "MSSQLSERVER"
            Features = "SQLENGINE,FULLTEXT,RS"
            DependsOn = "[xSqlServerSetup]SSS-Default"
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
    }
}