[DSCLocalConfigurationManager()]
configuration ConfigurationLcm
{
    param
    (
        [ValidateNotNullOrEmpty()] 
        [string] $ComputerName
    );

    Node $ComputerName
    {
        Settings
        {
            ConfigurationModeFrequencyMins = 2
            RefreshFrequencyMins = 10
            RebootNodeIfNeeded = $true
            ConfigurationMode = "ApplyAndAutoCorrect"            
            ActionAfterReboot = "ContinueConfiguration"
            RefreshMode = "Push"
            DebugMode = "All"
        }
    }
}