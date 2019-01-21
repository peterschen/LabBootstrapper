configuration ConfigurationPAW
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
        PackageManagementProviderResource, DismFeature, `
        xSCOM, xWindowsUpdate;
        
    $features = @(
        "Microsoft-Hyper-V-Tools-All"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node PAW
    {
        foreach($feature in $features)
        {
            xDismFeature "xDF-$feature" 
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
            IpAddress = "$NetworkPrefix.253/24"
            DnsServer = "$NetworkPrefix.10"
        }

        cpDomainOnboarding "DomainOnboarding"
        {
            NodeName = $Node.NodeName
            DomainName = $DomainName
            Credential = $Credential.Password
            DependsOn = "[cpNetworking]Networking"
        }

        Package "P-SqlServerManagementStudio"
        {
            Ensure = "Present"
            Name = "Microsoft SQL Server Management Studio - 16.5"
            ProductID = ""
            Path = "C:\LabBits\SSMS-Setup-ENU.exe"
            Arguments = "/install /quiet"
        }

        Package "P-ReportViewer"
        {
            Ensure = "Present"
            Name = "Microsoft Report Viewer 2015 Runtime"
            ProductID = ""
            Path = "C:\LabBits\prereqs\ReportViewer.msi"
            Arguments = "ALLUSERS=2"
        }

        xSCOMConsoleSetup "SOCS-Console"
        {
            Ensure = "Present"
            SourcePath = "C:\LabBits\OM"
            SourceFolder = "1801"
            SetupCredential = $domainCredential
            DependsOn = "[cpDomainOnboarding]DomainOnboarding","[Package]P-ReportViewer"
        }

        xHotfix "H-RSAT"
        {
            Ensure = "Present"
            Path = "C:\LabBits\WindowsTH-RSAT_WS_1803-x64.msu"
            Id = "KB2693643"
        }

        Package "P-DpmConsole"
        {
            Ensure = "Present"
            Name = "Microsoft System Center  DPM Remote Administration"
            ProductId = "E0E2D04F-B7ED-4DD6-916E-F6C66EAF9296"
            Path = "C:\LabBits\DPM\1801\DPM2012\dpmcli\dpmui.msi"
            Arguments = ""
        }

        Environment "E-Path"
        {
            Name = "Path"
            Value = "$env:Path;C:\LabBits\tools"
            Ensure = "Present"
        }

        Environment "E-DockerHost"
        {
            Name = "DOCKER_HOST"
            Value = "app1"
            Ensure = "Present"
        }
    }
}