configuration ConfigurationWAC
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [pscredential] $Credential,

        [Parameter(Mandatory = $true)]
        [string] $NetworkPrefix,

	    [int] $RetryCount = 20,
        [int] $RetryInterval = 30
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cpBase, `
        xNetworking;

    Node WAC
    {
        cpFirewall "Firewall"
        {
        }

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.11/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        xFirewall "WindowsAdminCenter-HTTP-TCP80"
        {
            Name = "Windows Admin Center (HTTP TCP/80)"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            Ensure = "Present"
            Enabled = "True"
            LocalPort = "80"
            Protocol = "Tcp"
        }

        xFirewall "WindowsAdminCenter-HTTP-TCP443"
        {
            Name = "Windows Admin Center (HTTP TCP/443)"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            Ensure = "Present"
            Enabled = "True"
            LocalPort = "443"
            Protocol = "Tcp"
        }

        Package "P-WindowsAdminCenter"
        {
            Ensure = "Present"
            Name = "Windows Admin Center"
            ProductId = "4FAE3A2E-4369-490E-97F3-0B3BFF183AB9"
            Path = "C:\LabBits\WindowsAdminCenter1809.5.msi"
            Arguments = "RESTART_WINRM=0"
        }
    }
}