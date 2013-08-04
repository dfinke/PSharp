function Find-VariableAssignment {
    param(
        $Name,
        [Parameter(ValueFromPipelineByPropertyName)]
        $Fullname
    )

    Process {

        $Ast = [System.Management.Automation.Language.Parser]::ParseFile( (Resolve-Path $FullName) , [ref]$null, [ref]$null)

        $(foreach($item in $ast.FindAll({ param($targetAst) $targetAst -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true)) {

            [PSCustomObject]@{
                Name      = $item.Left

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