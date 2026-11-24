$ErrorActionPreference = 'Stop'
$root = Join-Path $PSScriptRoot '..'
$destination = Join-Path $root 'windows/ai-runtime'
New-Item -ItemType Directory -Force $destination | Out-Null
function DownloadVerified($url, $path, $hash) {
  if (-not (Test-Path $path)) { Invoke-WebRequest $url -OutFile $path }
  if ((Get-FileHash $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $hash) {
    Remove-Item $path -Force
    throw "Checksum mismatch: $path"
  }
}
$archive = Join-Path $env:RUNNER_TEMP 'llama-b5721.zip'
DownloadVerified 'https://github.com/ggml-org/llama.cpp/releases/download/b5721/llama-b5721-bin-win-cpu-x64.zip' $archive '4c36e4bc60b25da10bfec3d8c161360c942effa02401522965acafe014e46b80'
Expand-Archive $archive $destination -Force
$source = Join-Path $env:RUNNER_TEMP 'Qwen3-0.6B-Q8_0.gguf'
DownloadVerified 'https://huggingface.co/Qwen/Qwen3-0.6B-GGUF/resolve/23749fefcc72300e3a2ad315e1317431b06b590a/Qwen3-0.6B-Q8_0.gguf' $source '9465e63a22add5354d9bb4b99e90117043c7124007664907259bd16d043bb031'
$quantizer = (Get-ChildItem $destination -Filter llama-quantize.exe -Recurse | Select-Object -First 1).FullName
if (-not $quantizer) { throw 'Quantizer missing' }
$model = Join-Path $destination 'Qwen3-0.6B-Q4_K_M.gguf'
& $quantizer $source $model Q4_K_M
if ($LASTEXITCODE -ne 0) { throw 'Quantisation failed' }
(Get-FileHash $model -Algorithm SHA256).Hash.ToLowerInvariant() | Set-Content "$model.sha256"
