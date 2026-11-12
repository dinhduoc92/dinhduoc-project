Set-StrictMode -Version 2
$script:DDVSProduct = 'vn.dinhduoc.voicestudio'
$script:DDVSEntropy = [Text.Encoding]::UTF8.GetBytes('DinhDuocVoiceStudio.Issuer.v1')
function ConvertTo-DDVSBase64Url([byte[]]$Bytes) {
    return [Convert]::ToBase64String($Bytes).TrimEnd('=').Replace('+','-').Replace('/','_')
}
function ConvertFrom-DDVSBase64Url([string]$Text) {
    $value = $Text.Replace('-','+').Replace('_','/')
    switch ($value.Length % 4) { 2 { $value += '==' }; 3 { $value += '=' }; 1 { throw 'Invalid base64url' } }
    return ,([Convert]::FromBase64String($value))
}
function Get-DDVSPublicKey($Rsa) {
    $parameters = $Rsa.ExportParameters($false)
    $n = ConvertTo-DDVSBase64Url $parameters.Modulus
    $e = ConvertTo-DDVSBase64Url $parameters.Exponent
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $kid = ([BitConverter]::ToString($hash.ComputeHash([Text.Encoding]::UTF8.GetBytes($n + '.' + $e)))).Replace('-','').Substring(0,16).ToLowerInvariant() }
    finally { $hash.Dispose() }
    return [ordered]@{ schema=1; product=$script:DDVSProduct; algorithm='RS256'; keyId=$kid; publicKey=[ordered]@{ kty='RSA'; n=$n; e=$e } }
}
function Save-DDVSPrivateKey($Rsa, [string]$Path) {
    $directory = Split-Path -Parent $Path
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    $private = [Text.Encoding]::UTF8.GetBytes($Rsa.ToXmlString($true))
    try { $protected = [Security.Cryptography.ProtectedData]::Protect($private, $script:DDVSEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser) }
    finally { [Array]::Clear($private,0,$private.Length) }
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $stream.Write($protected,0,$protected.Length); $stream.Flush($true) } finally { $stream.Dispose() }
}
function Get-DDVSOwnerKey([string]$Path) {
    Add-Type -AssemblyName System.Security
    if (Test-Path -LiteralPath $Path) {
        $private = [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes($Path), $script:DDVSEntropy, [Security.Cryptography.DataProtectionScope]::CurrentUser)
        $rsa = [Security.Cryptography.RSA]::Create()
        try { $rsa.FromXmlString([Text.Encoding]::UTF8.GetString($private)) }
        catch { $rsa.Dispose(); throw }
        finally { [Array]::Clear($private,0,$private.Length) }
        return $rsa
    }
    $rsa = [Security.Cryptography.RSA]::Create()
    $rsa.KeySize = 3072
    try { Save-DDVSPrivateKey $rsa $Path } catch { $rsa.Dispose(); throw }
    return $rsa
}
function ConvertTo-DDVSMachine([string]$Text) {
    $code = $Text.Trim().ToUpperInvariant()
    if ($code -notmatch '^[A-F0-9]{4}(-[A-F0-9]{4}){3}$') { throw 'Mã máy phải có dạng A1B2-C3D4-E5F6-0718.' }
    return $code
}
function New-DDVSLicense($Rsa, [string]$Machine, [int]$Days=30, [switch]$Perpetual, [string]$Note='', [long]$Now=0) {
    $machine = ConvertTo-DDVSMachine $Machine
    if (!$Perpetual -and ($Days -lt 1 -or $Days -gt 36500)) { throw 'Số ngày phải từ 1 đến 36500.' }
    if ($Note.Length -gt 200) { throw 'Ghi chú quá dài (tối đa 200 ký tự).' }
    if ($Now -eq 0) { $Now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    $public = Get-DDVSPublicKey $Rsa
    $expiry = $null
    if (!$Perpetual) { $expiry = $Now + ([long]$Days * 86400) }
    $payload = [ordered]@{ v=1; product=$script:DDVSProduct; kid=$public.keyId; machine=$machine; iat=$Now; exp=$expiry; note=$Note; nonce=[Guid]::NewGuid().ToString('N') }
    $encoded = ConvertTo-DDVSBase64Url ([Text.Encoding]::UTF8.GetBytes(($payload | ConvertTo-Json -Compress)))
    $signed = [Text.Encoding]::UTF8.GetBytes('DDVS1.' + $encoded)
    $signature = $Rsa.SignData($signed, [Security.Cryptography.HashAlgorithmName]::SHA256, [Security.Cryptography.RSASignaturePadding]::Pkcs1)
    return ('DDVS1.' + $encoded + '.' + (ConvertTo-DDVSBase64Url $signature))
}
function Read-DDVSMachineLines([string]$Text) {
    $result = @(); $seen = @{}
    foreach ($line in ($Text -split '\r?\n|\r')) {
        if (!$line.Trim()) { continue }
        if ($line.Trim() -notmatch '^([A-Fa-f0-9]{4}(?:-[A-Fa-f0-9]{4}){3})(?:\s+(.*))?$') { throw "Dòng mã máy không hợp lệ: $line" }
        $code = ConvertTo-DDVSMachine $Matches[1]
        $note = ''; if ($Matches.ContainsKey(2)) { $note = $Matches[2].Trim() }
        if ($note.Length -gt 200) { throw "Ghi chú quá dài: $code" }
        if (!$seen.ContainsKey($code)) { $result += [pscustomobject]@{ machine=$code; note=$note }; $seen[$code]=$true }
    }
    if (!$result.Count) { throw 'Hãy dán ít nhất một mã máy.' }
    return $result
}
