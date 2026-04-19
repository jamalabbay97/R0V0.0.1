$files = Get-ChildItem -Recurse -Include '*.dart' 'D:\R0V0.0.1\lib'
foreach ($file in $files) {
    if ($file.FullName -match 'l10n' -or $file.FullName -match '\.g\.dart') { continue }
    $lines = Get-Content $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        # Look for Text('...') or Text("...") but not if it contains a variable like Text('$var') or Text("${var}")
        # although sometimes hardcoded strings have interpolation.
        # Let's look for literals.
        if ($line -match "Text\s*\(\s*[`'`"]([A-Za-z][^`'`"\r\n]{3,})[`'`"]" `
            -and $line -notmatch "l10n\." `
            -and $line -notmatch "AppLocalizations" `
            -and $line -notmatch "//") {
            Write-Output ("{0}:{1}: {2}" -f $file.FullName, ($i + 1), $line.Trim())
        }
    }
}
