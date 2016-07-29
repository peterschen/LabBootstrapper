configuration ConfigurationDC
{
    param 
    ( 
        [Parameter(Mandatory = $true)]
        [string] $DomainName,

        [Parameter(Mandatory = $true)]
        [pscredential] $Credential,

	    [int] $RetryCount = 20,
        [int] $RetryInterval = 30
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking, xActiveDirectory, xPSDesiredStateConfiguration;

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "DNS",
        "RSAT-DNS-Server",
        "AD-Domain-Services",
        "RSAT-AD-PowerShell",
        "RSAT-ADDS-Tools"
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
        @{Name = "Administrators"; Members =@("$($userChristoph.Name)")}
        @{Name = "g-sql-Admins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("$($userChristoph.Name)")}
        @{Name = "g-om-Admins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("$($userChristoph.Name)", "$($userOmMsaa.Name)")}
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

        xDnsServerAddress "DSA-DnsConfiguration"
        { 
            Address = "127.0.0.1"
            InterfaceAlias = "Ethernet"
            AddressFamily = "IPv4"
            DependsOn = "[WindowsFeature]WF-DNS"
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
                DomainAdministratorCredential = $domainCredential
                UserName = $_.Name
                Password = $domainCredential
                Ensure = "Present"
                Path = $_.Path
                DependsOn = "[xADOrganizationalUnit]ADOU-Services","[xADOrganizationalUnit]ADOU-Users"
            }
        }

        $groups | ForEach-Object {
            if($_.Name -eq "Administrators")
            {
                xADGroup "ADG-$($_.Name)"
                {
                    GroupName = $_.Name
                    GroupScope = "DomainLocal"
                    Ensure = "Present"
                    Path = $_.Path
                    MembersToInclude = $_.Members
                    DomainController = "$($Node.NodeName).$($DomainName)"
                    DependsOn = "[xADUser]ADU-christoph", "[xADUser]ADU-s-om-msaa"
                }
            }
            else
            {
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
        }
    }
}