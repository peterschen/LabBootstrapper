configuration ConfigurationFILE
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
        PackageManagement, xPSDesiredStateConfiguration;

    $features = @(
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node FILE
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

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.80/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        Package "P-StorageSyncAgent"
        {
            Ensure = "Present"
            Name = "Storage Sync Agent"
            ProductId = ""
            Path = "C:\LabBits\StorageSyncAgent_WS2016.msi"
            Arguments = ""
        }
    }
}