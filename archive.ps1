Param(
    [Parameter(HelpMessage = 'Path move CSV files from')]
    [string] $Path = '.\'
)

function CheckPath {
    param (
        [string] $Path
    )
    
    (Get-Item -Path "$_\*.csv").Count -gt 0
}

if (-not (Test-Path $Path -PathType Container)) {
    Throw 'The specified path does not exist'
}
if (-not (CheckPath($Path))) {
    throw 'There are no files to archive'
}

$TimeStamp = Get-Date -Format FileDate
$Destination = "$Path\$TimeStamp"
$SourceFilter = "$Path\*.csv"

if (-not(Get-Item -Path $SourceFilter)) {
    throw "No CSV files to archive"
}

New-Item -ItemType Directory -Path $Destination -ErrorAction Ignore
Move-Item -Destination $Destination -Path "$Path\*.csv"

Write-Host "Archived CSV Files: $Destination" -ForegroundColor DarkGreen