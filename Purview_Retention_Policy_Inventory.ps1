<#
.SYNOPSIS
Microsoft Purview Retention Policy Inventory
#>

$OutputFolder = Read-Host "Enter the output folder path (press Enter for current folder)"
if ([string]::IsNullOrWhiteSpace($OutputFolder)) { $OutputFolder = (Get-Location).Path }

if (-not (Test-Path $OutputFolder)) {
    try { New-Item -Path $OutputFolder -ItemType Directory -Force -ErrorAction Stop | Out-Null }
    catch { Write-Host "Unable to create output folder: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Press Enter to close"; exit }
}

$TimeStamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$CsvPath = Join-Path $OutputFolder "Purview_Retention_Policy_Inventory_$TimeStamp.csv"
$CsvColumns = @("Policy Name","Policy Enabled","Policy Mode","Workloads / Locations","Rule Name","Rule Enabled","Retention Duration","Retention Action","Expiration Date Option","Relevant Configuration")

if (-not (Get-Module -ListAvailable ExchangeOnlineManagement)) {
    Write-Host "Installing ExchangeOnlineManagement module..." -ForegroundColor Yellow
    try { Install-Module ExchangeOnlineManagement -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop }
    catch { Write-Host "Module installation failed: $($_.Exception.Message)" -ForegroundColor Red; Read-Host "Press Enter to close"; exit }
}

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Write-Host "`nConnecting to Microsoft Purview..." -ForegroundColor Cyan
    Connect-IPPSSession -ErrorAction Stop
    Write-Host "Connected successfully." -ForegroundColor Green
} catch {
    Write-Host "Connection failed: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to close"; exit
}

$Required = @("Get-RetentionCompliancePolicy","Get-RetentionComplianceRule")
$Missing = @($Required | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })

if ($Missing.Count -gt 0) {
    Write-Host "`nRequired cmdlets are not available:" -ForegroundColor Red
    $Missing | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    Write-Host "`nCheck that the tenant is active and your account has the required Purview retention permissions." -ForegroundColor Yellow
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to close"; exit
}

try {
    Write-Host "`nRetrieving Retention Policies..." -ForegroundColor Cyan
    $Policies = @(Get-RetentionCompliancePolicy -ErrorAction Stop)
    Write-Host "Retention Policies found: $($Policies.Count)" -ForegroundColor Green
} catch {
    Write-Host "Failed to retrieve policies: $($_.Exception.Message)" -ForegroundColor Red
    Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    Read-Host "Press Enter to close"; exit
}

$Inventory = @()

foreach ($Policy in $Policies) {
    Write-Host "Processing: $($Policy.Name)" -ForegroundColor Cyan

    $LocationInfo = @()
    foreach ($PropertyName in @("ExchangeLocation","SharePointLocation","OneDriveLocation","TeamsChannelLocation","TeamsChatLocation")) {
        $Value = $Policy.$PropertyName
        if ($null -ne $Value -and @($Value).Count -gt 0) {
            $Text = (@($Value) -join "; ")
            $LocationInfo += "${PropertyName}: $Text"
        }
    }
    $Locations = $LocationInfo -join " | "
    if ([string]::IsNullOrWhiteSpace($Locations)) { $Locations = "Not specified" }

    try { $Rules = @(Get-RetentionComplianceRule -Policy $Policy.Name -ErrorAction Stop) }
    catch { Write-Host "  Could not retrieve rules: $($_.Exception.Message)" -ForegroundColor Yellow; $Rules = @() }

    if ($Rules.Count -eq 0) {
        $Inventory += [PSCustomObject][ordered]@{
            "Policy Name"=$Policy.Name
            "Policy Enabled"=$Policy.Enabled
            "Policy Mode"=$Policy.Mode
            "Workloads / Locations"=$Locations
            "Rule Name"="No rule found"
            "Rule Enabled"=""
            "Retention Duration"=""
            "Retention Action"=""
            "Expiration Date Option"=""
            "Relevant Configuration"="Policy exists but no associated rule was returned"
        }
        continue
    }

    foreach ($Rule in $Rules) {
        $Duration = ""
        if ($null -ne $Rule.RetentionDuration) {
            if ($Rule.RetentionDuration -eq 0) { $Duration = "Indefinite" }
            else { $Duration = "$($Rule.RetentionDuration) days" }
        }

        $Config = @()
        if ($Rule.RetentionComplianceAction) { $Config += "Action: $($Rule.RetentionComplianceAction)" }
        if ($Duration) { $Config += "Duration: $Duration" }
        if ($Rule.ExpirationDateOption) { $Config += "Expiration: $($Rule.ExpirationDateOption)" }
        if ($Rule.ApplyComplianceTag) { $Config += "Apply Label: $($Rule.ApplyComplianceTag)" }
        $Relevant = $Config -join " | "
        if ([string]::IsNullOrWhiteSpace($Relevant)) { $Relevant = "No additional configuration returned" }

        $Inventory += [PSCustomObject][ordered]@{
            "Policy Name"=$Policy.Name
            "Policy Enabled"=$Policy.Enabled
            "Policy Mode"=$Policy.Mode
            "Workloads / Locations"=$Locations
            "Rule Name"=$Rule.Name
            "Rule Enabled"=$Rule.Enabled
            "Retention Duration"=$Duration
            "Retention Action"=$Rule.RetentionComplianceAction
            "Expiration Date Option"=$Rule.ExpirationDateOption
            "Relevant Configuration"=$Relevant
        }
    }
}

try {
    if ($Inventory.Count -eq 0) {
        $Header = '"' + ($CsvColumns -join '","') + '"'
        Set-Content -Path $CsvPath -Value $Header -Encoding UTF8
        Write-Host "`nNo retention policies found. Header-only CSV created." -ForegroundColor Yellow
    } else {
        $Inventory | Select-Object $CsvColumns | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        Write-Host "`nRetention Policy Inventory exported successfully." -ForegroundColor Green
    }

    Write-Host "`n============================================"
    Write-Host "Retention Policy Inventory Completed" -ForegroundColor Green
    Write-Host "============================================"
    Write-Host "Policies Found    : $($Policies.Count)"
    Write-Host "Records Exported  : $($Inventory.Count)"
    Write-Host "CSV File          : $CsvPath"
} catch {
    Write-Host "CSV export failed: $($_.Exception.Message)" -ForegroundColor Red
}

Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
Read-Host "`nPress Enter to close this window"
