configuration ConfigurationHQ
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
        @{ModuleName="PackageManagementProviderResource";ModuleVersion="1.0.3"},
        @{ModuleName="xSCOM";ModuleVersion="1.3.3.0"},
        @{ModuleName="xWindowsUpdate";ModuleVersion="2.7.0.0"},
        @{ModuleName="xDismFeature";ModuleVersion="1.2.0.0"}        

    $features = @(
        "Microsoft-Hyper-V-Tools-All"
    );

    $domainCredential = New-Object System.Management.Automation.PSCredential ("$domainName\Administrator", $Credential.Password);

    Node HQ
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
            Path = "C:\LabBits\WindowsTH-RSAT_WS_1709-x64.msu"
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

        Package "P-WindowsAdminCenter"
        {
            Ensure = "Present"
            Name = "Windows Admin Center"
            ProductId = "464116A9-B010-48F5-A983-84063CE183E2"
            Path = "C:\LabBits\WindowsAdminCenter1809.msi"
            Arguments = ""
        }

        # Workaround for the broken RSAT package which is missing the DNS configuration
<#
        $files = @(
            "dnsmgmt.msc",
            "dnsmgr.dll",
            "en-US\dnsmgmt.msc",
            "en-US\dnsmgr.dll.mui"            
        )

        foreach($file in $files)
        {
            File "F-dnsrsat-$file"
            {
                DestinationPath = "C:\Windows\System32\$file"
                SourcePath = "C:\LabBits\DNS\$file"
                Ensure = "Present"
                Force = $true
                DependsOn = "[xHotfix]H-RSAT"
            }
        }

        File "F-dnsrsat-DNS.lnk"
        {
            DestinationPath = "C:\Users\All Users\Microsoft\Windows\Start Menu\Programs\Administrative Tools\DNS.lnk"
            SourcePath = "C:\LabBits\DNS\DNS.lnk"
            Ensure = "Present"
            Force = $true
            DependsOn = "[xHotfix]H-RSAT"
        }

        Script "S-dnsrsat"
        {
            GetScript = { 
                $installDate = Get-Content (Join-Path -Path $env:SYSTEMDRIVE -ChildPath 'dnsrsat.txt')
                return @{ 'InstallDate' = "$installDate" }
            }
            TestScript = { 
                $state = $GetScript;
                
                if($state['InstallDate'] -eq "")
                {
                    Write-Verbose -Message "DNS snap-in not registered yet";
                    return $true;
                }

                Write-Verbose -Message ("DNS snap-in was registered on: {0}" -f $state["InstalldDate"]);
                return $false;
            }
            SetScript = {
                try
                {
                    $result = Start-Process -FilePath 'regsvr32.exe' -Args "/s c:\windows\system32\dnsmgr.dll" -Wait -NoNewWindow;
                    Set-Content -Path (Join-Path -Path $env:SYSTEMDRIVE -ChildPath 'dnsrsat.txt') -Value (Get-Date);
                }
                catch
                {
                    Write-Error -Message ("Could not register DNS snap-in: {0}" -f $_.Exception.Message);
                }
            }
            DependsOn = "[File]F-dnsrsat-dnsmgr.dll"
        }
#>
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