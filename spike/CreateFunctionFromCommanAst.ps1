cls

$s=@'
#add-contact john 1 a 1.1 'a','b',1 @() @{} {} 
add-contact -Name john -Address somewhere -City ny -State ny -Zip 10017 
#add-contact john somewhere ny ny 10017 
'@

[ref]$tokens=$null
$ast=[System.Management.Automation.Language.Parser]::ParseInput($s, $tokens, [ref]$null)

$ce = $ast.FindAll({$args[0] -is [System.Management.Automation.Language.CommandAst]},1).CommandElements 

$parameterNames=($ce | where parametername).parametername
$dataTypes=($ce | where {!$_.parametername} | select -Skip 1).statictype.name

function ZipList {

    param(
        $dataTypes,
        $parameterNames    
    )

    if($parameterNames.Length -eq 0) {        
        $parameterNames = 1..($dataTypes.Count) | ForEach { "p$_"}
    }

    $count = $dataTypes.Count
    for($idx=0; $idx -lt $count; $idx+=1) {
        [PSCustomObject]@{
            DataType= $DataTypes[$Idx]
            ParameterName = $ParameterNames[$Idx]
        }
    }    
}

function New-ParamStmt {
    param(
        [Parameter(ValueFromPipeLine)]
        $Item
    )
    
    Begin   { $Params = @() }
    Process { $Params += "[{0}] {1}" -f $Item.DataType, $Item.ParameterName }
    End     { $Params -join ",`r`n" }
}

filter New-ParamStmt {
    begin   { $Params = @() }
    process { $Params += "[{0}] {1}" -f $_.DataType, $_.ParameterName }
    end     { $Params -join ",`r`n" }
}

ZipList $dataTypes $parameterNames | New-ParamStmt