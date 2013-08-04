$MainWindow=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Topmost="True"
        WindowStartupLocation="CenterScreen"
        Title="PSHarp" Height="350" Width="425">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="35" />
            <RowDefinition Height="*" />
        </Grid.RowDefinitions>

        <Button
            IsDefault="True" IsCancel="True"
            Background="Transparent" Margin="3"/>

        <TextBox x:Name="SearchBox" Grid.Row="0" Margin="5"></TextBox>
        <ListView x:Name="ResultsPane" Grid.Row="1" Margin="5" IsSynchronizedWithCurrentItem="True">
            <ListView.View>
            <GridView>
                <GridViewColumn Width="140" Header="Type" DisplayMemberBinding="{Binding Type}"/>
                <GridViewColumn Width="140" Header="Name" DisplayMemberBinding="{Binding Name}"/>
                <GridViewColumn Width="140" Header="FileName" DisplayMemberBinding="{Binding FileName}"/>
            </GridView>
            </ListView.View>
        </ListView>
    </Grid>
</Window>
'@

function New-ASTItem {
    param(
        $Type,
        $Name,
        $Extent,
        [Microsoft.PowerShell.Host.ISE.ISEFile]$ISEFile
    )

    [PSCustomObject]@{
        Type              = $Type
        Name              = $Name
        StartLineNumber   = $Extent.StartLineNumber
        StartColumnNumber = $Extent.StartColumnNumber
        EndLineNumber     = $Extent.EndLineNumber
        EndColumnNumber   = $Extent.EndColumnNumber
        FileName          = $ISEFile.DisplayName
        ISEFile           = $ISEFile
        #FullName          = $FullName
        #FileName          = Split-Path -Leaf $FullName -ErrorAction SilentlyContinue
    }
}

function Get-AstDetail {
    param(
        [string]$ScriptInput,
        [Microsoft.PowerShell.Host.ISE.ISEFile]$ISEFile
    )

    Begin {
        $FunctionDefinitionAst = [System.Management.Automation.Language.FunctionDefinitionAst]
        $VariableExpressionAst = [System.Management.Automation.Language.VariableExpressionAst]
        $CommandAst = [System.Management.Automation.Language.CommandAst]
        $ParameterAst = [System.Management.Automation.Language.ParameterAst]
    }

    Process {

        $fileAST=[System.Management.Automation.Language.Parser]::ParseInput($ScriptInput, [ref]$null, [ref]$null)

        $details = {
            param($ast)

            if($ast -is $FunctionDefinitionAst) { $ast}
            elseif ($ast -is $VariableExpressionAst) { $ast }
            elseif ($ast -is $CommandAst) { $ast }
            elseif ($ast -is $ParameterAst) { $ast }
        }

        $filteredAST = $fileAST.FindAll($details,$true)

        switch ($filteredAST) {
            {$_ -is $FunctionDefinitionAst} { New-ASTItem Function $_.name $_.extent -ISEFile $ISEFile }
            {$_ -is $CommandAst}            { New-ASTItem Command  $_.Extent.Text $_.extent -ISEFile $ISEFile }
            {$_ -is $VariableExpressionAst} { New-ASTItem Variable $_.extent.text $_.extent -ISEFile $ISEFile }
            {$_ -is $ParameterAst}          { New-ASTItem Parameter $_.extent.text $_.extent -ISEFile $ISEFile }
        }
    }
}

function Out-SearchView {
    param(
        $list,
        [ScriptBlock]$PreviewKeyUp,
        [ScriptBlock]$SelectionChanged
    )

    if(!$PreviewKeyUp) {
        $PreviewKeyUp = {
            param($sender, $info)

            if($info.key -eq 'down') {
                $ResultsPane.Focus()
                $ResultsPane.SelectedIndex=0

                return
            }

            try {
                DoParseSearch $SearchBox.Text
            } catch {}
        }
    }

    if(!$SelectionChanged) {
        $SelectionChanged = {
            param($sender, $data)
            if($data.AddedItems) {

                $Selected=$data.AddedItems

                $psISE.CurrentPowerShellTab.Files.SetSelectedFile($Selected.ISEFile)

                $psISE.CurrentFile.Editor.EnsureVisible($Selected.StartLineNumber)

                $Selected.ISEFile.Editor.Select(
                    $Selected.StartLineNumber,
                    $Selected.StartColumnNumber,
                    $Selected.EndLineNumber,
                    $Selected.EndColumnNumber
                )
            }
        }
    }

    $Window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$MainWindow)))
    $SearchBox=$Window.FindName("SearchBox")
    $ResultsPane=$Window.FindName("ResultsPane")

    $ResultsPane.ItemsSource=@($list)
    $ResultsPane.DisplayMemberPath="Name"

    [void]$SearchBox.Focus()

    $SearchBox.add_PreviewKeyUp($PreviewKeyUp)
    $ResultsPane.add_SelectionChanged($SelectionChanged)

    [void]$Window.ShowDialog()
}


$ShowIt = {

    $result = $(foreach($file in $psISE.CurrentPowerShellTab.Files) {
        Get-AstDetail $file.Editor.Text $file
    })

    Out-SearchView $result
}

function DoParseSearch ($search) {

    if(!$search) {return}

    $h=@{
        v='variable'
        f='function'
        c='command'
        p='parameter'
    }

    $whereBlock = {$_.name -match $search}
    if($search -and $search.IndexOf(':') -eq 1) {
        $type, $name = $search.split(':')
        $whereBlock = '{{ $_.type -eq "{0}" -and $_.name -match "{1}" }}' -f $h.$type, $name | Invoke-Expression
    }

    $ResultsPane.ItemsSource = @($list | Where $whereBlock)
}

function Get-ScriptItem {

    # Used/Refactored Get-CurrentToken from ISEPack
    $currentFile = $psise.CurrentFile.Editor
    $tokens = [Management.Automation.PSParser]::Tokenize($currentFile.Text, [ref]$null)
    $line   = $currentFile.CaretLine
    $column = $currentFile.CaretColumn

    foreach ($token in $tokens) {
        if ($token.StartLine -eq $line -and $token.EndLine -eq $line) {
            if ($token.StartColumn -le $column -and $token.EndColumn -ge $column) {
                $token
            }
        }
    }
}

function Find-DetailByType {
    $token = Get-ScriptItem

    $token.Type|Out-Host
    switch -regex ($token.Type) {
        "CommandArgument|Command" {
            $TokenType="Command|Function"
            $Name='\b{0}\b' -f $token.Content
        }

        "Variable" {
            $TokenType="Variable"
            $Name='\$' + $token.Content + '\b'
        }
    }

    $list  = Get-AstDetail | where {$_.Type -match $TokenType -and $_.Name -match $Name}
    Out-SearchView $list
}

function ConvertTo-CamelCase ([string]$target) {

    function transform ([string]$t) {
        $t[0].ToString().ToUpper() + $t.Substring(1)
    }

    if($target.IndexOf('-') -ge 0) {
        $verb, $noun = $target.ToLower().split('-')
        return "$(transform $verb)-$(transform $noun)"
    }

    "$(transform $target)"
}

function ConvertTo-Function {

    $psISE.CurrentFile.Editor.SelectCaretLine()
    $CaretLine = $psISE.CurrentFile.Editor.CaretLine
    $text = ConvertTo-CamelCase $psISE.CurrentFile.Editor.SelectedText
    $psISE.CurrentFile.Editor.InsertText("function {0} {{`r`n    `r`n}}`r`n" -f $text)
    $psISE.CurrentFile.Editor.SetCaretPosition(($CaretLine+1),5)
}

function Add-MenuItem {
    param([string]$DisplayName, $SB, $ShortCut)

    $menu=$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where {$_.DisplayName -Match $DisplayName}

    if($menu) {
        [void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Remove($menu)
    }

    [void]$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus.Add($DisplayName, $SB, $ShortCut)
}

function Add-SubMenuItem {
    param([string]$Root, $SubMenu, $SB, $ShortCut)

    $menu=$psISE.CurrentPowerShellTab.AddOnsMenu.Submenus | Where {$_.DisplayName -Match $Root}

    [void]$menu.Submenus.Add($SubMenu, $SB, $ShortCut)
}

Add-MenuItem "_PSharp" $null $null
Add-SubMenuItem "_PSharp" "Show _All" $ShowIt "CTRL+Shift+X"
Add-SubMenuItem "_PSharp" "_Find This" ([scriptblock]::Create((Get-Command Find-DetailByType).Definition)) "CTRL+Shift+T"
Add-SubMenuItem "_PSharp" "_Convert To Function" ([scriptblock]::Create((Get-Command ConvertTo-Function).Definition)) "CTRL+Shift+Alt+F"