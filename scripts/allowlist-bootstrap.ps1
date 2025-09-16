param(
  [string]$Api = 'https://rei8kjm2yg.execute-api.us-east-1.amazonaws.com/Prod'
)

Write-Host "API: $Api"

try {
  $macRaw = (Get-NetAdapter | Where-Object {$_.Status -eq 'Up'} | Select-Object -First 1 -ExpandProperty MacAddress)
} catch {
  $macRaw = $null
}
if (-not $macRaw) {
  Write-Error "Could not determine MAC address from active adapters"
  exit 1
}
$mac = $macRaw -replace '-',':'
$mac = $mac.ToLower()
Write-Host "Using MAC: $mac"

# Allowlist this device
$allowBody = @{ mac = $mac } | ConvertTo-Json -Compress
$allowResp = Invoke-RestMethod -Method Post -Uri "$Api/allowlist/add" -ContentType 'application/json' -Body $allowBody
Write-Host "Allowlist response: " ($allowResp | ConvertTo-Json -Compress)

# Bootstrap admin (idempotent); returns credentials on first run, 409 on subsequent
try {
  $bootstrapResp = Invoke-RestMethod -Method Post -Uri "$Api/auth/bootstrap" -ContentType 'application/json' -Body '{}' -ErrorAction Stop
  Write-Host "Bootstrap response: " ($bootstrapResp | ConvertTo-Json -Compress)
} catch {
  if ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 409) {
    Write-Host "Bootstrap response: {\"success\":false,\"error\":\"admin-exists\"}"
  } else {
    throw
  }
}

# Check status again
$statusResp = Invoke-RestMethod -Method Get -Uri "$Api/device/status/$mac"
Write-Host "Status response: " ($statusResp | ConvertTo-Json -Compress)
