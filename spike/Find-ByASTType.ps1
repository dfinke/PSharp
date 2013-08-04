function Find-ByASTType {
    param(
        [string]$Name,
        [string]$TargetType,
        [string[]]$Fullname,
        [scriptblock]$ExtractName
    )

    Process {

        $Ast = [System.Management.Automation.Language.Parser]::ParseFile( (Resolve-Path $FullName) , [ref]$null, [ref]$null)
        
        $TargetType = $TargetType -AS [Type]
        
        $(foreach($item in $ast.FindAll({ param($targetAst) $targetAst -is $TargetType }, $true)) {
            [PSCustomObject]@{
                Name              = &$ExtractName $Item
                Line              = $item.Extent.Text
                StartLineNumber   = $item.Extent.StartLineNumber  
                StartColumnNumber = $item.Extent.StartColumnNumber
                EndLineNumber     = $item.Extent.EndLineNumber
                EndColumnNumber   = $item.Extent.EndColumnNumber
                FileName          = Split-Path -Leaf $item.Extent.File
                FullName          = $item.Extent.File
            }
        }) | Where Name -Match $Name
    }
}

function Find-VariableAssignment {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process {

        Find-ByASTType $Name 'System.Management.Automation.Language.AssignmentStatementAst' $Fullname {$args[0].Left} 
    }
}

function Find-Function {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process {

        Find-ByASTType $Name 'System.Management.Automation.Language.FunctionDefinitionAst' $Fullname {$args[0].Name} 
    }
}

function Find-Parameter {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process {
        
        Find-ByASTType $Name 'System.Management.Automation.Language.ParameterAst' $Fullname {$args[0].Name}
    }
}

function Find-ForEach {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process {
        
        Find-ByASTType $Name 'System.Management.Automation.Language.ForEachStatementAst' $Fullname {"ForEach"}
    }
}

function Find-CommandAST {
    param(
        [string]$Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]]$Fullname
    )

    Process {        
        
        Find-ByASTType $Name 'System.Management.Automation.Language.CommandAst' $Fullname {$args[0].CommandElements[0].Value} 
    }
}

cls

#Write-Host -ForegroundColor Cyan "Variableassignment"
#dir *.ps1 | Find-Variableassignment name| ft
#Write-Host -ForegroundColor Cyan "function"
#dir *.ps1 | Find-Function  | ft

#dir *.ps1 | Find-Parameter | ft
#dir *.ps1 | Find-ForEach | ft
dir *.ps1 | Find-CommandAST select| ft