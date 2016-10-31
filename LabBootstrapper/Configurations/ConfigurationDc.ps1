configuration ConfigurationDC
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

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"},
        @{ModuleName="xComputerManagement";ModuleVersion="1.8.0.0"},
        @{ModuleName="xActiveDirectory";ModuleVersion="2.13.0.0"}
        @{ModuleName="xPSDesiredStateConfiguration";ModuleVersion="3.13.0.0"}

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "AD-Domain-Services",
        "RSAT-AD-PowerShell",
        "RSAT-ADDS-Tools",
        "RSAT-DNS-Server"
    );
    
    $ous = @(
        @{Name = $domainPrefix; Path = "dc=$domainPrefix,dc=lab"},
        @{Name = "Groups"; Path = "ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "Accounts"; Path = "ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "Services"; Path = "ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "Users"; Path = "ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"}
    );

    $userChristoph = @{Name = "christoph"; Path = "ou=Users,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"};
    $userOmMsaa = @{Name = "s-om-msaa"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"};

    $users = @(
        $userChristoph,
        @{Name = "s-sql-agent"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "s-sql-engine"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "s-sql-reporting"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "s-om-datareader"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        @{Name = "s-om-datawriter"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"},
        $userOmMsaa,
        @{Name = "s-om-sdk"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"}
    );

    $groups = @(
        @{Name = "g-SqlAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator","$($userChristoph.Name)")},
        @{Name = "g-OmAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator", "$($userChristoph.Name)", "$($userOmMsaa.Name)")},
        @{Name = "g-OrAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator", "$($userChristoph.Name)")},
        @{Name = "g-LocalAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("$($userChristoph.Name)")}
        @{Name = "g-RemoteDesktopUsers"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("$($userChristoph.Name)")}
        @{Name = "g-RemoteManagementUsers"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("$($userChristoph.Name)")}
    );

    $builtinGroups = @(
        @{Name = "Administrators"; Members =@("g-LocalAdmins")},
        @{Name = "Remote Desktop Users"; Members =@("g-RemoteDesktopUsers")}
        @{Name = "Remote Management Users"; Members =@("g-RemoteManagementUsers")}
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("Administrator", $Credential.Password);

    Node DC
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

        xIPAddress "IA-Ip"
        {
            IPAddress = "$NetworkPrefix.10"
            SubnetMask = 24
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
        }

        xDnsServerAddress "DSA-DnsConfiguration"
        { 
            Address = "127.0.0.1"
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
            DependsOn = "[xIPAddress]IA-Ip", "[WindowsFeature]WF-AD-Domain-Services"
        }

        xADDomain "AD-FirstDC"
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
		    DependsOn = "[WindowsFeature]WF-AD-Domain-Services", "[xDnsServerAddress]DSA-DnsConfiguration"
        }

        xWaitForADDomain "WFAD-FirstDC"
        {
            DomainName = $DomainName
            DomainUserCredential = $domainCredential
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryInterval
            DependsOn = "[xADDomain]AD-FirstDC"
        }

        $ous | ForEach-Object {
            xADOrganizationalUnit "ADOU-$($_.Name)"
            {
                Name = $_.Name
                Path = $_.Path
                Ensure = "Present"
                DependsOn = "[xWaitForADDomain]WFAD-FirstDC"
            }
        }

        $users | ForEach-Object {
            xADUser "ADU-$($_.Name)"
            {
                DomainName = $DomainName
                UserPrincipalName = "$($_.Name)@$($DomainName)"
                DomainAdministratorCredential = $domainCredential
                UserName = $_.Name
                Password = $domainCredential
                Ensure = "Present"
                Path = $_.Path
                DependsOn = "[xADOrganizationalUnit]ADOU-Services","[xADOrganizationalUnit]ADOU-Users"
            }
        }

        $groups | ForEach-Object {
            xADGroup "ADG-$($_.Name)"
            {
                GroupName = $_.Name
                GroupScope = "Global"
                Ensure = "Present"
                Path = $_.Path
                MembersToInclude = $_.Members
                DomainController = "$($Node.NodeName).$($DomainName)"
                DependsOn = "[xADUser]ADU-christoph", "[xADUser]ADU-s-om-msaa"
            }
        }

        $builtinGroups | ForEach-Object {
            xADGroup "ADG-$($_.Name)"
            {
                GroupName = $_.Name
                GroupScope = "DomainLocal"
                Ensure = "Present"
                Path = $_.Path
                MembersToInclude = $_.Members
                DomainController = "$($Node.NodeName).$($DomainName)"
                DependsOn = "[xADUser]ADU-christoph", "[xADUser]ADU-s-om-msaa", "[xADGroup]ADG-g-RemoteDesktopUsers", "[xADGroup]ADG-g-RemoteManagementUsers"
            }
        }
    }
}