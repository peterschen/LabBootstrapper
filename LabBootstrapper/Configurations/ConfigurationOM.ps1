configuration ConfigurationOM
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

    Import-DscResource -ModuleName cpBase, PSDesiredStateConfiguration, `
        xCredSSP, xSCOM;

    $domainPrefix = $DomainName.Split(".")[0];

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);
    $actionCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-msaa", $Credential.Password);
    $sdkCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-sdk", $Credential.Password);
    $drCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-datareader", $Credential.Password);
    $dwCredential = New-Object System.Management.Automation.PSCredential ("$domainName\s-om-datawriter", $Credential.Password);

    Node OM
    {
        cpFirewall "Firewall"
        {
        }

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.30/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            ExtraAdmins = @("$DomainName\s-om-sdk", "$DomainName\s-om-msaa")
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }
        
        Package "P-SqlServerClrTypes"
        {
            Ensure = "Present"
            Name = "Microsoft System CLR Types for SQL Server 2014"
            ProductId = ""
            Path = "C:\LabBits\prereqs\SQLSysClrTypes.msi"
            Arguments = "ALLUSERS=2"
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

        xSCOMManagementServerSetup "SMSS-ManagementServer"
        {
            Ensure = "Present"
            SourcePath = "C:\LabBits\Source"
            SourceFolder = "1801"
            SetupCredential = $domainCredential
            ManagementGroupName = "$domainPrefix"
            FirstManagementServer = $true
            ActionAccount = $actionCredential
            DASAccount = $sdkCredential
            DataReader = $drCredential
            DataWriter = $dwCredential
            SqlServerInstance = "DB"
            DwSqlServerInstance = "DB"
            DependsOn = "[cpDomainOnboarding]DomainOnboarding", "[xCredSSP]CS-Server", "[xCredSSP]CS-Client", "[Package]P-SqlServerClrTypes", "[WaitForAll]WFA-DB"
        }
    }
}