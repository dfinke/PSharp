function Edit-Live {
    param(
        [Parameter(Mandatory)]
        [string]$Name
    )

    $Definition = (Get-Command $Name -ErrorAction SilentlyContinue ).Definition

    if($Definition) {
        $ISEFile=$psISE.CurrentPowerShellTab.Files.Add()
        $psISE.CurrentPowerShellTab.Files.SetSelectedFile($ISEFile)
        $ISEFile.Editor.Text = $Definition
    }
}
