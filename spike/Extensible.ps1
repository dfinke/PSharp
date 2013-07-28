function Select-Ast {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        $FullName,
        #[ValidateSet('AssignmentStatement','FunctionDefinition')]
        $ASTType='AssignmentStatement'
    )

    Process {
        
        $TargetType = "System.Management.Automation.Language.$($ASTType)Ast" -as [Type]
        $ast=[System.Management.Automation.Language.Parser]::ParseFile( (Resolve-Path $FullName) , [ref]$null, [ref]$null)
        
        foreach($item in $ast.FindAll({ param($p) $p -is $TargetType }, $true)) {
             & ("Process{0}" -f $item.gettype().name) $item
        }
    }
}

function ProcessAssignmentStatementAst ($AssignmentStatementAst){
    [PSCustomObject]@{
        Name=$item.Left
        File=$item.Extent.File
        Text=$item.Extent.Text
    }
}

function ProcessFunctionDefinitionAst ($item) {
    [PSCustomObject]@{
        Name=$item.Name
        Text=$item.Extent.Text
        File=$item.Extent.File
    }
}

function ProcessCommandAst ($item) {
    $item
}

cls

dir *.ps1 | Select-Ast -ASTType FunctionDefinition # Command