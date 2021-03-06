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

    Import-DscResource -ModuleName PSDesiredStateConfiguration, cpBase, `
        xActiveDirectory, xPSDesiredStateConfiguration, xNetworking;

    $domainPrefix = $DomainName.Split(".")[0];

    $features = @(
        "AD-Domain-Services",
        "Routing"
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
        @{Name = "s-dpm"; Path = "ou=Services,ou=Accounts,ou=$domainPrefix,dc=$domainPrefix,dc=lab"}
    );

    $groups = @(
        @{Name = "g-SqlAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator","$($userChristoph.Name)")},
        @{Name = "g-OmAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator", "$($userChristoph.Name)", "$($userOmMsaa.Name)")},
        @{Name = "g-DpmAdmins"; Path = "ou=Groups,ou=$domainPrefix,dc=$domainPrefix,dc=lab"; Members = @("Administrator", "$($userChristoph.Name)")},
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

        cpFirewall "Firewall"
        {
        }

        cpNetworking "Networking"
        {
            IpAddress = "$NetworkPrefix.10/24"
            DnsServer = "127.0.0.1"
            DependsOn = "[WindowsFeature]WF-AD-Domain-Services"
        }

        xADDomain "AD-FirstDC"
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $domainCredential
            SafemodeAdministratorPassword = $domainCredential
		    DependsOn = "[cpNetworking]Networking"
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
                PasswordNeverExpires = $true
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

        xFirewall "WindowsAdminCenter-HTTP-TCP6516"
        {
            Name = "Windows Admin Center (HTTP TCP/6516)"
            Profile = ("Domain", "Private", "Public")
            Direction = "Inbound"
            Ensure = "Present"
            Enabled = "True"
            LocalPort = "6516"
            Protocol = "Tcp"
        }

        Package "P-WindowsAdminCenter"
        {
            Ensure = "Present"
            Name = "Windows Admin Center"
            ProductId = "4FAE3A2E-4369-490E-97F3-0B3BFF183AB9"
            Path = "C:\LabBits\WindowsAdminCenter1809.5.msi"
            Arguments = ""
        }
    }
}