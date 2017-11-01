Configuration cpNetworking
{
    param
    (
        [string] $IpAddress,
        [string] $DnsServer
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"};

    xIPAddress "IP"
    {
        IPAddress = $IpAddress
        SubnetMask = 24
        InterfaceAlias = "Ethernet"
        AddressFamily = "IPv4"
    }

    xDnsServerAddress "DSA-DnsConfiguration"
    { 
        Address = $DnsServer
        InterfaceAlias = "Ethernet"
        AddressFamily = "IPv4"
        DependsOn = "[xIPAddress]IP"
    }
}