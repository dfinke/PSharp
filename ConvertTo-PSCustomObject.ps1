function ConvertTo-PSCustomObject {

    function New-ParamStmt {
        param($tokens)
        
        $newList = $tokens| ForEach {"`t`$"+$_}
@"
param(
$($newList -join ",`r`n")
)


"@
    }
    
    function New-PSCustomObject {
        param($tokens)

        $newList = $tokens| ForEach { "`t{0} = `${0}" -f $_ }

@"
[PSCustomObject]@{
$($newList -join "`r`n")
}


"@
    }
   
   function Get-NewToken {
        param($line)

        $results = (
                [System.Management.Automation.PSParser]::Tokenize($line, [ref]$null) |
                    where {
                        $_.Type -match 'variable|member|command' -and
                        $_.Content -ne "_"
                    }
             ).Content
        
        $(foreach($result in $results) { ConvertTo-CamelCase $result }) -join ''
    }

    function Get-EditorTokens {        
        $txt = $psISE.CurrentFile.Editor.SelectedText    
        if([string]::IsNullOrEmpty($txt)) {
            $psISE.CurrentFile.Editor.SelectCaretLine()
            $txt = $psISE.CurrentFile.Editor.SelectedText

            Get-NewToken $txt

        } else {

            $lines = $txt.split("`n")
            foreach($line in $lines) {
                $line=$line.trim()
                if([string]::IsNullOrEmpty($line)) {continue}

                Get-NewToken $line            
            }
        }
    }

    $EditorTokens=Get-EditorTokens
 
    
    $t = $(
        New-ParamStmt $EditorTokens
        New-PSCustomObject $EditorTokens
    )
    
    $psISE.CurrentFile.Editor.InsertText($t)
}