$en_path = "D:\R0V0.0.1\lib\l10n\app_en.arb"
$fr_path = "D:\R0V0.0.1\lib\l10n\app_fr.arb"

function Get-ArbKeys($path) {
    $content = Get-Content $path -Raw | ConvertFrom-Json
    $keys = $content.PSObject.Properties.Name | Where-Object { $_ -notmatch '^@' -and $_ -ne '@@locale' }
    return $keys
}

$en_keys = Get-ArbKeys $en_path
$fr_keys = Get-ArbKeys $fr_path

$only_en = Compare-Object $en_keys $fr_keys | Where-Object { $_.SideIndicator -eq '<=' } | Select-Object -ExpandProperty InputObject
$only_fr = Compare-Object $en_keys $fr_keys | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject

Write-Output "Keys only in EN: $($only_en.Count)"
foreach ($k in $only_en) { Write-Output "  - $k" }

Write-Output "`nKeys only in FR: $($only_fr.Count)"
foreach ($k in $only_fr) { Write-Output "  - $k" }
