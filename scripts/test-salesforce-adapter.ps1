param(
  [string]$FunctionBase = $(if ($env:SUPABASE_FUNCTIONS_URL) { $env:SUPABASE_FUNCTIONS_URL } else { "http://127.0.0.1:54321/functions/v1" }),
  [string]$WebhookSecret = $env:SALESFORCE_WEBHOOK_SECRET,
  [string]$OrganizationId = $(if ($env:SALESFORCE_TEST_ORG_ID) { $env:SALESFORCE_TEST_ORG_ID } else { $env:UAT_ORGANIZATION_ID }),
  [string]$BearerToken = $(if ($env:SUPABASE_ANON_KEY) { $env:SUPABASE_ANON_KEY } else { "" })
)

$ErrorActionPreference = "Stop"

function ConvertTo-HmacSha256Hex {
  param(
    [Parameter(Mandatory = $true)][string]$Value,
    [Parameter(Mandatory = $true)][string]$Secret
  )

  $keyBytes = [System.Text.Encoding]::UTF8.GetBytes($Secret)
  $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
  $hmac = [System.Security.Cryptography.HMACSHA256]::new($keyBytes)
  try {
    $hashBytes = $hmac.ComputeHash($valueBytes)
    return (($hashBytes | ForEach-Object { $_.ToString("x2") }) -join "")
  } finally {
    $hmac.Dispose()
  }
}

function Invoke-JsonRequest {
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$Body,
    [Parameter(Mandatory = $true)][hashtable]$Headers
  )

  try {
    $response = Invoke-WebRequest -Uri $Uri -Method POST -Body $Body -Headers $Headers -ContentType "application/json" -UseBasicParsing
    return @{
      StatusCode = [int]$response.StatusCode
      Body = if ($response.Content) { $response.Content | ConvertFrom-Json } else { $null }
    }
  } catch {
    $statusCode = [int]$_.Exception.Response.StatusCode
    $reader = [System.IO.StreamReader]::new($_.Exception.Response.GetResponseStream())
    try {
      $content = $reader.ReadToEnd()
      return @{
        StatusCode = $statusCode
        Body = if ($content) { $content | ConvertFrom-Json } else { $null }
      }
    } finally {
      $reader.Dispose()
    }
  }
}

if (-not $WebhookSecret -or $WebhookSecret.Length -lt 16) {
  throw "SALESFORCE_WEBHOOK_SECRET must be set to run the adapter verification."
}

if (-not $OrganizationId) {
  throw "SALESFORCE_TEST_ORG_ID or UAT_ORGANIZATION_ID must be set."
}

$eventId = "evt_sf_$([Guid]::NewGuid().ToString("N"))"
$payloadObject = [ordered]@{
  event_id = $eventId
  event_type = "Lead_Captured"
  organization_id = $OrganizationId
  timestamp = (Get-Date).ToUniversalTime().ToString("o")
  data = [ordered]@{
    salesforce_lead_id = "00QTEST$($eventId.Substring(7, 8))"
    organization_id = $OrganizationId
    alias = "SF Lead $($eventId.Substring(7, 6))"
    area = "Whitefield"
    city = "Bengaluru"
    budget = 8500000
    contact_phone = "+919876543210"
  }
}

$payload = $payloadObject | ConvertTo-Json -Depth 8 -Compress
$validSignature = ConvertTo-HmacSha256Hex -Value $payload -Secret $WebhookSecret
$webhookUri = "$FunctionBase/salesforce-webhook"

$baseHeaders = @{
  "X-API-Version" = "1"
}

$forged = Invoke-JsonRequest -Uri $webhookUri -Body $payload -Headers ($baseHeaders + @{
  "X-Salesforce-Signature" = "sha256=0000000000000000000000000000000000000000000000000000000000000000"
})

if ($forged.StatusCode -ne 401) {
  throw "Forged signature check failed. Expected 401, got $($forged.StatusCode)."
}

$valid = Invoke-JsonRequest -Uri $webhookUri -Body $payload -Headers ($baseHeaders + @{
  "X-Salesforce-Signature" = "sha256=$validSignature"
})

if ($valid.StatusCode -ne 201 -and $valid.StatusCode -ne 200) {
  throw "Valid webhook check failed. Expected 200/201, got $($valid.StatusCode)."
}

if (-not $valid.Body.ok) {
  throw "Valid webhook did not return ok=true."
}

$duplicate = Invoke-JsonRequest -Uri $webhookUri -Body $payload -Headers ($baseHeaders + @{
  "X-Salesforce-Signature" = "sha256=$validSignature"
})

if ($duplicate.StatusCode -ne 200 -or $duplicate.Body.reason -ne "duplicate_skipped") {
  throw "Idempotency check failed. Expected duplicate_skipped."
}

if ($BearerToken -and $valid.Body.lead_id) {
  $processorPayload = @{
    dry_run = $true
    payload = @{
      sync_kind = "lead_lock"
      lead_id = $valid.Body.lead_id
      organization_id = $OrganizationId
    }
  } | ConvertTo-Json -Depth 8 -Compress

  $processor = Invoke-JsonRequest -Uri "$FunctionBase/salesforce-sync-processor" -Body $processorPayload -Headers ($baseHeaders + @{
    "Authorization" = "Bearer $BearerToken"
  })

  if ($processor.StatusCode -ne 200 -or -not $processor.Body.ok) {
    throw "Outbound dry-run check failed. Expected ok=true."
  }

  $json = $processor.Body.outbound_payload | ConvertTo-Json -Depth 8 -Compress
  if ($json -match "\+?\d[\d\s-]{7,}\d") {
    throw "Outbound payload leaked restricted contact data."
  }
}

Write-Output "Salesforce adapter verification passed."
