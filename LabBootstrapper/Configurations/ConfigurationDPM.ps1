configuration ConfigurationDPM
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
        xCredSSP, xSCDPM;

    $domainPrefix = $DomainName.Split(".")[0];
    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);
    $credential = New-Object System.Management.Automation.PSCredential ("$domainName\s-dpm", $Credential.Password);

    $features = @(
        "Hyper-V-PowerShell"
    );

    Node DPM
    {
        cpFirewall "Firewall"
        {
        }

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.50/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        foreach($feature in $features)
        {
            WindowsFeature "WF-$feature" 
            { 
                Name = $feature
                Ensure = "Present"
            }
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

        Package "P-SqlServerManagementStudio"
        {
            Ensure = "Present"
            Name = "Microsoft SQL Server Management Studio - 16.5"
            ProductID = ""
            Path = "C:\LabBits\SSMS-Setup-ENU.exe"
            Arguments = "/install /quiet"
        }

        WaitForAll "WFA-DB"
        {
            NodeName = "DB"
            ResourceName = "[xSqlServerFirewall]SSF-Firewall"
            PsDscRunAsCredential = $domainCredential
            RetryCount = 720
            RetryIntervalSec = 5
        }
        
        xSCDPMServerSetup "DPM"
        {
            Ensure = "Present"
            SourcePath = "C:\LabBits\Source"
            SetupCredential = $domainCredential
            YukonMachineName = "DB"
            YukonInstanceName = "MSSQLSERVER"
            ReportingMachineName = "DB"
            ReportingInstanceName = "MSSQLSERVER"
            YukonMachineCredential = $domainCredential
            ReportingMachineCredential = $domainCredential
            DependsOn = "[cpDomainOnboarding]DomainOnboarding", "[xCredSSP]CS-Server", "[xCredSSP]CS-Client", "[Package]P-SqlServerManagementStudio", "[WaitForAll]WFA-DB"
        }
    }
}