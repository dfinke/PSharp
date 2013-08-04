function Select-Ast {
    param(
        [Parameter(ValueFromPipelineByPropertyName)]
        $FullName,
        #[ValidateSet('AssignmentStatement','FunctionDefinition')]
        #$ASTType='AssignmentStatement'
        $ASTType
    )

    Process {
        
        $TargetType = "System.Management.Automation.Language.$($ASTType)Ast" -as [Type]
        $ast=[System.Management.Automation.Language.Parser]::ParseFile( (Resolve-Path $FullName) , [ref]$null, [ref]$null)
        
        foreach($item in $ast.FindAll({ param($p) $p -is $TargetType }, $true)) {
             & ("Process{0}" -f $item.gettype().name) $item
        }
    }
}

function Get-ExtentInfo ($targetExtent) {
    [PSCustomObject]@{
        Line              = $targetExtent.Extent.Text
        StartLineNumber   = $targetExtent.Extent.StartLineNumber  
        StartColumnNumber = $targetExtent.Extent.StartColumnNumber
        EndLineNumber     = $targetExtent.Extent.EndLineNumber
        EndColumnNumber   = $targetExtent.Extent.EndColumnNumber
        FileName          = Split-Path -Leaf $targetExtent.Extent.File
        FullName          = $targetExtent.Extent.File
    }
}

function ProcessFunctionDefinitionAst ($item) {
    [PSCustomObject]@{
        Name     = $item.Name
        Text     = $item.Extent.Text
        FullName = $item.Extent.File
        Type     = "Function"
    }
}

function ProcessCommandAst ($item) {
    $item
}

function Find-Function {
    param(
        $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        $FullName
    )

    Process {
        Select-Ast $FullName -ASTType FunctionDefinition | Where { $_.Name -match $Name}
    }
}

function Find-FunctionUsage {
    param(
        $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        $Fullname
    )

    Process {
        Select-Ast -FullName $FullName -ASTType Command | 
            Where {$_.CommandElements.Extent.Text -match $Name} |
            ForEach {
                [PSCustomObject]@{
                    Line              = $_.Extent.Text
                    StartLineNumber   = $_.Extent. StartLineNumber  
                    StartColumnNumber = $_.Extent.StartColumnNumber
                    EndLineNumber     = $_.Extent.EndLineNumber
                    EndColumnNumber   = $_.Extent.EndColumnNumber
                    FileName          = Split-Path -Leaf $_.Extent.File
                    FullName          = $_.Extent.File
                }
            }
    }
}

function Find-VariableAssignment {
    param(
        $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        $Fullname
    )

    Process {
        Select-Ast -FullName $FullName -ASTType AssignmentStatement |
            Where {$_.VariableName -match $Name}
    }
}

function ProcessAssignmentStatementAst ($item){
    Get-ExtentInfo $item | 
        Add-Member -PassThru -MemberType NoteProperty VariableName $item.Left
}

function Find-Variable {
    param(
        $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        $Fullname
    )

    Process {
        Select-Ast -FullName $FullName -ASTType VariableExpression | ? {$_.VariableName -match $Name}
    }
}

function ProcessVariableExpressionAst ($item){
    Get-ExtentInfo $item |
        Add-Member -PassThru -MemberType NoteProperty VariableName $item.VariablePath
}

cls

#dir . -r  *.ps1 | Find-Function select | Find-Usage
#dir . -r  *.ps1 | Find-Usage Add-MenuItem | ft -a
#dir . -r  *.ps1 | Find-FunctionUsage select-ast| ft -a

dir . -r  *.ps1 | Find-Variable name| select v*name, *number | ft -a
''
dir . -r  *.ps1 | Find-VariableAssignment name| select v*name, *number, line, filename | ft -a
