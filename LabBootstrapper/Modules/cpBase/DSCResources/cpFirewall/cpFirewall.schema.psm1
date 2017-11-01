Configuration cpFirewall
{
    param
    (
        [string[]] $ExtraRules = @()
    );

    Import-DscResource -ModuleName PSDesiredStateConfiguration,
        @{ModuleName="xNetworking";ModuleVersion="2.11.0.0"};

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
}