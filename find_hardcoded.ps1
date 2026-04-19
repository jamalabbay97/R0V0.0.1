$files = Get-ChildItem -Recurse -Include '*.dart' 'D:\R0V0.0.1\lib\presentation'
foreach ($file in $files) {
    $lines = Get-Content $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "Text\s*\(\s*[`'`"][A-Za-z][^`'`"\r\n]{4,}[`'`"]" `
            -and $line -notmatch "l10n\." `
            -and $line -notmatch "AppLocalizations" `
            -and $line -notmatch "//") {
            Write-Output ("{0}:{1}: {2}" -f $file.Name, ($i + 1), $line.Trim())
        }
    }
}
