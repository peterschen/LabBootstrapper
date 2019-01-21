Configuration cpFirewall
{
    param
    (
        [string[]] $ExtraRules = @()
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration, xNetworking;

    $rules = $ExtraRules + @(
        "FPS-NB_Datagram-In-UDP",
        "FPS-NB_Name-In-UDP",
        "FPS-NB_Session-In-TCP",
        "FPS-SMB-In-TCP",
        "RemoteFwAdmin-In-TCP",
        "RemoteFwAdmin-RPCSS-In-TCP",
        "RemoteEventLogSvc-In-TCP",
        "RemoteEventLogSvc-NP-In-TCP",
        "RemoteEventLogSvc-RPCSS-In-TCP",
        "RemoteSvcAdmin-In-TCP",
        "RemoteSvcAdmin-NP-In-TCP",
        "RemoteSvcAdmin-RPCSS-In-TCP"
    );

    foreach($rule in $rules)
    {
        xFirewall "$rule"
        {
            Name = "$rule"
            Ensure = "Present"
            Enabled = "True"
        }
    }
        
    xFirewall "DPM-Agent-DPMRA.exe"
    {
        Name = "DPM Agent (DPMRA.exe)"
        Profile = ("Domain", "Private", "Public")
        Direction = "Inbound"
        Program = "%PROGRAMFILES%\Microsoft Data Protection Manager\DPM\bin\DPMRA.exe"
        Ensure = "Present"
        Enabled = "True"
    }

    xFirewall "DPM-Agent-DCOM-TCP135"
    {
        Name = "DPM Agent (DCOM TCP/135)"
        Profile = ("Domain", "Private", "Public")
        Direction = "Inbound"
        Ensure = "Present"
        Enabled = "True"
        LocalPort = "135"
        Protocol = "Tcp"
    }
}