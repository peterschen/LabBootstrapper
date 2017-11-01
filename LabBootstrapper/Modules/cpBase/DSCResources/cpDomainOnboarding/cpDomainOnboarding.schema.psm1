Configuration cpDomainOnboarding
{
    param
    (
        [string] $NodeName,
        [string] $DomainName,
        [string[]] $ExtraAdmins = @(),
        [securestring] $Credential
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"},
        @{ModuleName="xComputerManagement";ModuleVersion="1.8.0.0"};

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential);
    
    $admins = $ExtraAdmins + @(
        "$DomainName\g-LocalAdmins"
    );

    xComputer "JoinDomain"
    {
        Name = $NodeName
        DomainName = $DomainName
        Credential = $domainCredential
    }

    Group "G-Administrators"
    {
        GroupName = "Administrators"
        Credential = $domainCredential
        MembersToInclude = $admins
        DependsOn = "[xComputer]JoinDomain"
    }

    Group "G-RemoteDesktopUsers"
    {
        GroupName = "Remote Desktop Users"
        Credential = $domainCredential
        MembersToInclude = "$DomainName\g-RemoteDesktopUsers"
        DependsOn = "[xComputer]JoinDomain"
    }

    Group "G-RemoteManagementUsers"
    {
        GroupName = "Remote Management Users"
        Credential = $domainCredential
        MembersToInclude = "$DomainName\g-RemoteManagementUsers"
        DependsOn = "[xComputer]JoinDomain"
    }
}