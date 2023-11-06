# Check if PowerShell version is 7.0 or higher and if not, warn the user and exit
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Host "This script requires PowerShell 7.0 or higher. Please update your PowerShell version and try again." -ForegroundColor Red
    exit
}

# Set the CSV file to be created in your script location
$MyPath = $PSScriptRoot
$MyCSVPath = Join-Path $MyPath "MySecureScores.csv"
$MyAzPath = Join-Path $MyPath "tenants.txt"

# Connect with the identity for which you would like to check Secure Score
Connect-AzAccount

$MyAzTenants = Get-Content -Path $MyAzPath

foreach ($MyAzTenant in $MyAzTenants) {
    Write-Output "Checking tenant: $MyAzTenant"
    $MyAzSubscriptions = Get-AzSubscription -TenantId $MyAzTenant | Where-Object -Property State -NE 'Disabled'
    $TenantName = (Get-AzTenant -TenantId $MyAzTenant).Name

    foreach ($MyAzSubscription in $MyAzSubscriptions) {
        Write-Output "Checking subscription: $($MyAzSubscription.SubscriptionId)"
        Set-AzContext -Subscription $MyAzSubscription.SubscriptionId -TenantId $MyAzTenant
        
        $check = @(Get-AzResourceProvider -ProviderNamespace 'Microsoft.Security' | Where-Object -Property RegistrationState -EQ 'Registered').Count
        
        if ($check -gt 0) {
            $MyAzSecureScores = Get-AzSecuritySecureScore
            
            foreach ($score in $MyAzSecureScores) {
                try {
                    # Try to get the security tasks
                    $securityTasks = Get-AzSecurityTask
                    $MyAzRecommendedActions = ($securityTasks | ForEach-Object { $_.RecommendationType }) -join " | "
                } catch {
                    Write-Warning "An error occurred while fetching security tasks: $_"
                    $MyAzRecommendedActions = "Error fetching tasks"
                }
                
                $MyCSVRow = [pscustomobject]@{
                    Date = (Get-Date).Date
                    TenantName = $TenantName
                    SubscriptionID = $MyAzSubscription.SubscriptionId
                    SubscriptionName = $MyAzSubscription.Name
                    SecureScore = $score.Percentage
                    Weight = $score.Weight
                    Actions = $MyAzRecommendedActions
                }
                
                $MyCSVRow | Export-Csv -Path $MyCSVPath -NoTypeInformation -Append
            }
        }
    }
}

# Note: Ensure that you have the necessary permissions and the Microsoft.Security provider is registered.