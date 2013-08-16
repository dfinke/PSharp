function New-FunctionFromSelectedText 
{
    function Get-VariableExtentText
    {
        param (
            [parameter(ValueFromPipeline)]
            [System.Management.Automation.Language.Ast]
            $ast
        )
        begin
        {
            $VariablesToExclude = '$_', '$true', '$false', '$?', '$$', '${', 
                '{', '$PSCmdlet', '$PSScriptRoot'
        }
        process
        {
            $variableType = [System.Management.Automation.Language.VariableExpressionAst]
            $ast.FindAll({$args[0] -is $variableType }, $false).Extent.Text |
                foreach {$_ -replace '@', '$' } |
                where {($VariablesToExclude -notcontains $_) }  |
                sort -Unique
        }
    }

    function Get-UnAssignedVariable
    {
        param ($Scriptblock)

        $ScriptblockAst = [scriptblock]::Create($Scriptblock).Ast
    
        $AllVariables = $ScriptblockAst | Get-VariableExtentText

        $Assignments = $ScriptblockAst.FindAll({$args[0] -is [System.Management.Automation.Language.AssignmentStatementAst]},$false)
        if ($Assignments)
        {
            $AssignedToVariable = $Assignments.left | Get-VariableExtentText
            Compare-Object $AssignedToVariable $AllVariables  | 
            where {$_.sideindicator -like '=>'} | 
            select -ExpandProperty InputObject
        }
        else
        {
            $AllVariables
        }
    }


    $SourceFile = $psISE.CurrentFile
    $Scriptblock = $SourceFile.Editor.SelectedText
    $Parameters = Get-UnAssignedVariable $Scriptblock 

    $Definition = "Function Name `n{"
    $Definition += "`n`t param (`n"
    
    $OFS = ",`n`t`t"
    $Definition += "`t`t$Parameters"
    
    $Definition += "`n`t)`n"
    $Definition += $Scriptblock
    $Definition += "`n}"    
    
    $SourceFile.Editor.Text = $SourceFile.editor.text -replace [regex]::Escape($SourceFile.Editor.SelectedText)

    $ISEFile=$psISE.CurrentPowerShellTab.Files.Add()
    $psISE.CurrentPowerShellTab.Files.SetSelectedFile($ISEFile)   
    $ISEFile.Editor.Text = $Definition    
    $ISEFile.Editor.Select(1,10,1,14)
}