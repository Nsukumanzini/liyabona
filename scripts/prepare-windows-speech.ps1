$ErrorActionPreference = 'Stop'

$ModelName = 'ggml-small.en-q5_1.bin'
$ModelRevision = 'e7c63091148293a457a91f9b127a86250683f6b9'
$ModelSha256 = 'bfdff4894dcb76bbf647d56263ea2a96645423f1669176f4844a1bf8e478ad30'
$ModelSize = 190098681L
$ModelDirectory = Join-Path $PSScriptRoot '..\windows\models'
$ModelPath = Join-Path $ModelDirectory $ModelName
$ModelSourceName = 'ggml-model-whisper-small.en-q5_1.bin'
$ModelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/$ModelRevision/$ModelSourceName?download=true"

New-Item -ItemType Directory -Force -Path $ModelDirectory | Out-Null
if (Test-Path $ModelPath) {
  $Existing = Get-Item $ModelPath
  $ExistingHash = (Get-FileHash -Algorithm SHA256 $ModelPath).Hash.ToLowerInvariant()
  if ($Existing.Length -ne $ModelSize -or $ExistingHash -ne $ModelSha256) {
    Remove-Item -Force $ModelPath
  }
}
if (-not (Test-Path $ModelPath)) {
  $PartialPath = "$ModelPath.partial"
  try {
    Write-Host 'Downloading the offline English speech model (about 180 MB)…'
    Invoke-WebRequest -Uri $ModelUrl -OutFile $PartialPath
    $Downloaded = Get-Item $PartialPath
    if ($Downloaded.Length -ne $ModelSize) {
      throw "The downloaded model has the wrong size ($($Downloaded.Length) bytes)."
    }
    $DownloadedHash = (Get-FileHash -Algorithm SHA256 $PartialPath).Hash.ToLowerInvariant()
    if ($DownloadedHash -ne $ModelSha256) {
      throw 'The downloaded model did not match the published SHA256 checksum.'
    }
    Move-Item -Force $PartialPath $ModelPath
  } finally {
    if (Test-Path $PartialPath) { Remove-Item -Force $PartialPath }
  }
}

$Hash = (Get-FileHash -Algorithm SHA256 $ModelPath).Hash
Write-Host "Offline speech model ready: $ModelPath"
Write-Host "SHA256: $Hash"
