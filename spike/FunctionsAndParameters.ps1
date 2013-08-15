cls

$s = @'
function foo ([string]$p,$q) {}
#function bar {param($a,$b)}
#function baz {param($e,$f,$g,$h)}
'@

function New-FunctionAstItem {
    param( $FunctionName, $Param)

    $Param.Parameters | % {
        [PSCustomObject]@{
            FunctionName  = $FunctionName
            ParameterName = $_.Name.variablepath.userpath
            Type = $_.StaticType
        }
    }
}

$ast=[System.Management.Automation.Language.Parser]::ParseInput($s, [ref]$null, [ref]$null)
$r=$ast.FindAll({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]},1) 

[System.Management.Automation.Language.FunctionDefinitionAst]$fda=$null

$(foreach($fda in $r) {
    
    if($fda.Parameters) {
        New-FunctionAstItem $fda.name $fda
    } 

    if($fda.Body.ParamBlock) {
        New-FunctionAstItem $fda.name $fda.Body.ParamBlock
    }
}) | Ft -a