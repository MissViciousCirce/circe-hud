[CmdletBinding(SupportsShouldProcess=$true)]
param([Parameter(Mandatory=$true)][string]$GamePath)
$ErrorActionPreference = 'Stop'
if (@(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -like '*Subnautica*' }).Count) {
    throw 'Save and close Subnautica 2 before switching HUD mods.'
}
$gameRoot = (Resolve-Path -LiteralPath $GamePath).Path
$loaderRoot = Join-Path $gameRoot 'Subnautica2\Binaries\Win64\ue4ss'
if (-not (Test-Path -LiteralPath (Join-Path $loaderRoot 'UE4SS.dll') -PathType Leaf)) { throw 'Compatible UE4SS installation not found.' }
$modsRoot = Join-Path $loaderRoot 'Mods'
$destinationRoot = [IO.Path]::GetFullPath((Join-Path $modsRoot 'CirceHUD'))
$manifest = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'manifest.json') -Raw | ConvertFrom-Json
$operations = @()
foreach ($file in $manifest.Files) {
    if ($file.Path -notmatch '^(Scripts/[a-z_]+\.lua|Assets/pointer\.png\.lua|enabled\.txt)$') { throw 'Unexpected package path.' }
    $source = Join-Path (Join-Path $PSScriptRoot 'CirceHUD') $file.Path
    $destination = [IO.Path]::GetFullPath((Join-Path $destinationRoot $file.Path))
    if (-not $destination.StartsWith($destinationRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Package path escaped mod directory.' }
    if ((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -ne $file.SHA256) { throw "Package checksum failed: $($file.Path)" }
    $operations += [pscustomobject]@{ Path=$destination; Data=[IO.File]::ReadAllBytes($source); Remove=$false }
}
$modsFile = Join-Path $modsRoot 'mods.txt'
$oldMarker = Join-Path $modsRoot 'SubnauticaMapMod\enabled.txt'
$oldText = if (Test-Path -LiteralPath $modsFile) { [IO.File]::ReadAllText($modsFile) } else { '' }
$newText = $oldText
foreach ($setting in @(@('SubnauticaMapMod','0'),@('CirceHUD','1'))) {
    $pattern = '(?im)^\s*' + [regex]::Escape($setting[0]) + '\s*:\s*[01][^\r\n]*$'
    $line = $setting[0] + ' : ' + $setting[1]
    if ([regex]::IsMatch($newText,$pattern)) { $newText = [regex]::Replace($newText,$pattern,$line) }
    else { $newText = $newText.TrimEnd() + "`r`n" + $line + "`r`n" }
}
$operations += [pscustomobject]@{ Path=$modsFile; Data=[Text.Encoding]::UTF8.GetBytes($newText); Remove=$false }
if (Test-Path -LiteralPath $oldMarker -PathType Leaf) {
    $operations += [pscustomobject]@{ Path=$oldMarker; Data=$null; Remove=$true }
}
if (-not $PSCmdlet.ShouldProcess($modsRoot,'Install standalone Circe HUD and disable the previous minimap')) { return }
$backup = Join-Path $loaderRoot ('mod-backups\CirceHUD-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff'))
New-Item -ItemType Directory -Path $backup | Out-Null
$snapshots = @()
foreach ($op in $operations) {
    $exists = Test-Path -LiteralPath $op.Path -PathType Leaf
    $name = '{0:D2}-{1}' -f $snapshots.Count,(Split-Path -Leaf $op.Path)
    if ($exists) { [IO.File]::WriteAllBytes((Join-Path $backup $name),[IO.File]::ReadAllBytes($op.Path)) }
    $snapshots += [pscustomobject]@{ Path=$op.Path; Existed=$exists; File=$(if($exists){$name}else{$null}) }
}
ConvertTo-Json -InputObject @($snapshots) -Depth 3 | Set-Content -LiteralPath (Join-Path $backup 'restore-manifest.json') -Encoding UTF8
try {
    foreach ($op in $operations) {
        if ($op.Remove) { Remove-Item -LiteralPath $op.Path }
        else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $op.Path) -Force | Out-Null
            [IO.File]::WriteAllBytes($op.Path,$op.Data)
            $written = [IO.File]::ReadAllBytes($op.Path)
            if ([Convert]::ToBase64String($written) -ne [Convert]::ToBase64String($op.Data)) { throw 'Installed file verification failed.' }
        }
    }
} catch {
    foreach ($saved in $snapshots) {
        if ($saved.Existed) { [IO.File]::WriteAllBytes($saved.Path,[IO.File]::ReadAllBytes((Join-Path $backup $saved.File))) }
        elseif (Test-Path -LiteralPath $saved.Path -PathType Leaf) { Remove-Item -LiteralPath $saved.Path }
    }
    throw
}
Write-Output 'Circe HUD alpha installed. Previous minimap disabled; its files and exploration data were preserved.'
Write-Output "Backup: $backup"
