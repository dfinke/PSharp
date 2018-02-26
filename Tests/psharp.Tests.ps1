$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$modulepath = Split-Path $here
import-module -name (join-path $modulepath "psharp.psm1")

$string = "get-process foreach-object blah"
$stringresult = "Get-Process Foreach-Object blah"
$nocamelstring = "should not be changed"

$multilinestring = @"
This is a multi-line test of foreach-object {
    blah |select-object |get-member
}
"@ 
$multilinestringresult = @"
This is a Multi-Line test of Foreach-Object {
    blah |Select-Object |Get-Member
}
"@

$multilinestring|ConvertTo-CamelCase
$multilinestring -split "`r`n" |ConvertTo-CamelCase
ConvertTo-CamelCase $string

$string |ConvertTo-CamelCase

Describe "ConvertTo-CamelCase" {
    $result = ConvertTo-CamelCase $string
    It "returns hyphenated CamelCase for cmdlet names on a single string" {
        $result | Should BeExactly $stringresult
    }

    $result = $string|ConvertTo-CamelCase 
    It "returns hyphenated CamelCase when used via the pipeline" {
        $result | Should BeExactly $stringresult
    }

    $result = ConvertTo-CamelCase $nocamelstring
    It "should not change a string that does not have a hyphenated cmdlet name" {
        $result |Should BeExactly $nocamelstring
    }

    $result = ConvertTo-CamelCase $multilinestring
    It "Should convert multiline strings" {
        $result |Should BeExactly $multilinestringresult
    }

    $result = ($multilinestring -split "`r`n" |ConvertTo-CamelCase) -join "`r`n"
    It "Should convert multiline strings via the pipeline" {
        $result |Should BeExactly $multilinestringresult
    }
}



