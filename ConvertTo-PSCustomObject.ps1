function ConvertTo-PSCustomObject {

    $output = @()
    $txt = $psISE.CurrentFile.Editor.SelectedText

    function Get-NewToken {
        param($line)

        $result = (
                [System.Management.Automation.PSParser]::Tokenize($line, [ref]$null) |
                    where {
                        $_.Type -match 'variable|member' -and
                        $_.Content -ne "_"
                    }
             ).Content

        ConvertTo-CamelCase $result
    }

    if([string]::IsNullOrEmpty($txt)) {
        $psISE.CurrentFile.Editor.SelectCaretLine()
        $txt = $psISE.CurrentFile.Editor.SelectedText
        $Key = Get-NewToken $txt
        $output += "`t$Key=$txt"
    } else {

        $lines = $txt.split("`n")
        foreach($line in $lines) {

            $line=$line.trim()

            if([string]::IsNullOrEmpty($line)) {continue}

            $Key = Get-NewToken $line
            $output += "`t$Key=$line"
        }
    }

    if($output.Count -eq 0) {return}

    $t = @"
[PSCustomObject]@{
$($output -join "`r`n")
}

"@

    $psISE.CurrentFile.Editor.InsertText($t)
}