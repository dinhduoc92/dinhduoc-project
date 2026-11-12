param([string]$FixtureDirectory)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Issuer.Core.ps1')
function Assert($Condition, [string]$Message) { if (!$Condition) { throw $Message } }
[IO.Directory]::CreateDirectory($FixtureDirectory) | Out-Null
$keyFile=Join-Path $FixtureDirectory 'test-private.dpapi'
$rsa=Get-DDVSOwnerKey $keyFile
try {
    Assert ($rsa.KeySize -eq 3072) 'Expected RSA 3072'
    $public=Get-DDVSPublicKey $rsa
    $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $token=New-DDVSLicense -Rsa $rsa -Machine 'A1B2-C3D4-E5F6-0718' -Days 30 -Now $now -Note 'Test friend'
    $parts=$token.Split('.')
    $claims=[Text.Encoding]::UTF8.GetString((ConvertFrom-DDVSBase64Url $parts[1])) | ConvertFrom-Json
    Assert ($claims.exp - $claims.iat -eq (30L * 86400L)) 'Wrong timed expiry'
    Assert ($claims.machine -eq 'A1B2-C3D4-E5F6-0718') 'Wrong machine'
    Assert ($claims.product -eq 'vn.dinhduoc.voicestudio') 'Wrong product'
    Assert ($rsa.VerifyData([Text.Encoding]::UTF8.GetBytes('DDVS1.'+$parts[1]),(ConvertFrom-DDVSBase64Url $parts[2]),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) 'Invalid signature'
    $forever=New-DDVSLicense -Rsa $rsa -Machine '1122-3344-5566-7788' -Perpetual -Now $now
    $foreverClaims=[Text.Encoding]::UTF8.GetString((ConvertFrom-DDVSBase64Url $forever.Split('.')[1])) | ConvertFrom-Json
    Assert ($null -eq $foreverClaims.exp) 'Perpetual key must have null expiry'
    $longTerm=New-DDVSLicense -Rsa $rsa -Machine '1122-3344-5566-7788' -Days 36500 -Now $now
    $longClaims=[Text.Encoding]::UTF8.GetString((ConvertFrom-DDVSBase64Url $longTerm.Split('.')[1])) | ConvertFrom-Json
    Assert ($longClaims.exp - $longClaims.iat -eq (36500L * 86400L)) 'Expiry overflow'
    $lines=@(Read-DDVSMachineLines "a1b2-c3d4-e5f6-0718 First friend`r`n1122-3344-5566-7788 Second friend`r`na1b2-c3d4-e5f6-0718 duplicate")
    Assert ($lines.Count -eq 2) 'Duplicate or CRLF handling failed'
    Assert ($lines[0].note -eq 'First friend') 'Notes not preserved'
    $reopened=Get-DDVSOwnerKey $keyFile
    try { Assert ((Get-DDVSPublicKey $reopened).keyId -eq $public.keyId) 'Owner authority changed after reopening' } finally { $reopened.Dispose() }
    $raw=[IO.File]::ReadAllBytes($keyFile)
    Assert (!([Text.Encoding]::UTF8.GetString($raw)).Contains('RSAKeyValue')) 'Private XML was not protected'
    [IO.File]::WriteAllText((Join-Path $FixtureDirectory 'test-public.json'),($public | ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    [IO.File]::WriteAllText((Join-Path $FixtureDirectory 'test-license.txt'),$token,(New-Object Text.UTF8Encoding($false)))
    foreach ($invalid in @('', '1111-2222-3333', 'GGGG-2222-3333-4444')) {
        $failed=$false;try { $null=New-DDVSLicense -Rsa $rsa -Machine $invalid -Days 30 } catch { $failed=$true }
        Assert $failed 'Invalid machine was accepted'
    }
    foreach ($invalidDays in @(0,-1,36501)) {
        $failed=$false;try { $null=New-DDVSLicense -Rsa $rsa -Machine '1122-3344-5566-7788' -Days $invalidDays } catch { $failed=$true }
        Assert $failed 'Invalid duration was accepted'
    }
    $damaged=Join-Path $FixtureDirectory 'corrupt.dpapi';[IO.File]::WriteAllBytes($damaged,([byte[]]@(1,2,3)))
    $failed=$false;try { $null=Get-DDVSOwnerKey $damaged } catch { $failed=$true }
    Assert $failed 'Corrupted private key must fail closed'
    Assert (([IO.File]::ReadAllBytes($damaged)).Length -eq 3) 'Corrupted authority was silently replaced'
    Write-Host 'Issuer tests passed: DPAPI persistence, RSA signatures, notes, timed/perpetual keys, expiry range and invalid input.'
} finally { $rsa.Dispose() }
