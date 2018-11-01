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

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cpBase,
        @{ModuleName="PackageManagement";ModuleVersion="1.1.6.0"},
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="7.0.0.0"}
    
    Import-DscResource -Name "PSModule" -ModuleName "PackageManagementProviderResource" -ModuleVersion "1.0.3";

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