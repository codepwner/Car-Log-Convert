Param(
    [Parameter(Mandatory, HelpMessage = 'Path to CSV file to convert')]
    [string] $Path,

    [Parameter(HelpMessage = 'Should sample data be shown?')]    
    [switch] $ShowSampleData
)

function Get-Bits ([uint] $value, [uint] $bits = 8, [int] $shift) {
    $mask = [uint] ([math]::Pow(2, $bits) - 1) -shl $shift
    [int](($value -band $mask) -shr $shift)
}

If (-not (Test-Path $Path))
{
    Throw 'The specified path does not exist'
}

$csv = Import-Csv $path
$startingTime = $csv[0].time
$timestamp = Get-ItemPropertyValue $Path -Name LastWriteTime

foreach ($record in $csv) {
    $record | Add-Member -Force -MemberType NoteProperty -Name "LogEntrySeconds" -Value $($record.time - $startingTime)  
    $record | Add-Member -Force -MemberType NoteProperty -Name "LogEntryDate" -Value $(Get-Date -Format "d")     
    $record | Add-Member -Force -MemberType NoteProperty -Name "LogEntryTime" -Value $($timestamp.AddSeconds($record.LogEntrySeconds) | Get-Date -Format "HH:mm:ss.f")
    $record | Add-Member -Force -MemberType NoteProperty -Name "FuelCut" -Value $($record.IDC -eq 0)
    $record | Add-Member -Force -MemberType NoteProperty -Name "AFR_Delta" -Value $(($record.FuelCut) ? 0 : $record.AFR_O2_WB_ADC - $record.AFR_Map)
    $record | Add-Member -Force -MemberType NoteProperty -Name "LogID" -Value $record.sample

    if ($null -ne $record.RAX_A){     
        $RAX_Data = [uint] $record.RAX_A
        $record | Add-Member -Force -MemberType NoteProperty -Name "FuelTrim_ST" -Value $((Get-Bits -value $RAX_Data -shift 24) * 0.1953125 - 25)
        $record | Add-Member -Force -MemberType NoteProperty -Name "FuelTrim_LT" -Value $((Get-Bits -value $RAX_Data -shift 16) * 0.1953125 - 25)
        $record | Add-Member -Force -MemberType NoteProperty -Name "FuelTrim_LT_Idle" -Value $((Get-Bits -value $RAX_Data -shift 8) * 0.1953125 - 25)
        $record | Add-Member -Force -MemberType NoteProperty -Name "FuelTrim_LT_Cruise" -Value $((Get-Bits -value $RAX_Data -shift 0) * 0.1953125 - 25)
    }

    if ($null -ne $record.RAX_B){     
        $RAX_Data = [uint] $record.RAX_B
        $record | Add-Member -Force -MemberType NoteProperty -Name "Load" -Value $((Get-Bits -value $RAX_Data -shift 24) * 1.5625)
        $record | Add-Member -Force -MemberType NoteProperty -Name "IPW" -Value $((Get-Bits -value $RAX_Data -shift 16) * 0.1)
        $record | Add-Member -Force -MemberType NoteProperty -Name "AFR_Map" -Value $(14.7 * 128 / (Get-Bits -value $RAX_Data -shift 8))
        $record | Add-Member -Force -MemberType NoteProperty -Name "AFR_O2_Rear" -Value $((Get-Bits -value $RAX_Data -shift 0) * 0.1953125)
    }

    if ($null -ne $record.RAX_C){
        $RAX_Data = [uint] $record.RAX_C
        $record | Add-Member -Force -MemberType NoteProperty -Name "Timing_Load" -Value ((Get-Bits -value $RAX_Data -shift 24) * 1.5625)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Timing_Adv" -Value ((Get-Bits -value $RAX_Data -shift 17 -bits 7) - 20)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Knock_Sum" -Value ((Get-Bits -value $RAX_Data -shift 11 -bits 6))
        $record | Add-Member -Force -MemberType NoteProperty -Name "RPM" -Value $((Get-Bits -value $RAX_Data -bits 11) * 7.8125)
    }

    if ($null -ne $record.RAX_B -and $null -ne $record.RAX_C){
        $record | Add-Member -Force -MemberType NoteProperty -Name "IDC" -Value ($record.IPW * $record.RPM / 1200)
    }

    if ($null -ne $record.RAX_D){
        $RAX_Data = [uint] $record.RAX_D
        $MAP = (Get-Bits -value $RAX_Data -shift 23 -bits 9) * 0.0964869
        $Baro = ((Get-Bits -value $RAX_Data -shift 16 -bits 7) + 90) * 0.07251887
        $record | Add-Member -Force -MemberType NoteProperty -Name "MAP" -Value $MAP
        $record | Add-Member -Force -MemberType NoteProperty -Name "Baro" -Value $Baro
        $record | Add-Member -Force -MemberType NoteProperty -Name "Boost" -Value ($MAP - $Baro)
        $record | Add-Member -Force -MemberType NoteProperty -Name "WGDC_Active" -Value ((Get-Bits -value $RAX_Data -shift 8) * 0.5)
        $record | Add-Member -Force -MemberType NoteProperty -Name "MAF_Voltage" -Value ((Get-Bits -value $RAX_Data -shift 0) * 0.019608)
    }

    if ($null -ne $record.RAX_E){
        $RAX_Data = [uint] $record.RAX_E
        $record | Add-Member -Force -MemberType NoteProperty -Name "InVVT_Target" -Value $(((Get-Bits -value $RAX_Data -shift 24) - 16) * 0.15623)
        $record | Add-Member -Force -MemberType NoteProperty -Name "ExVVT_Target" -Value $((Get-Bits -value $RAX_Data -shift 16) * 0.15623)
        $record | Add-Member -Force -MemberType NoteProperty -Name "InVVT_Actual" -Value $(((Get-Bits -value $RAX_Data -shift 8) - 16) * 0.15623)
        $record | Add-Member -Force -MemberType NoteProperty -Name "ExVVT_Actual" -Value $((Get-Bits -value $RAX_Data -shift 0) * 0.15623)
    }

    if ($null -ne $record.RAX_F){
        $RAX_Data = [uint] $record.RAX_F
        $record | Add-Member -Force -MemberType NoteProperty -Name "WGDC_Corr" -Value $((Get-Bits -value $RAX_Data -shift 0) * 0.5 - 64)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Temp_Intake" -Value $(((Get-Bits -value $RAX_Data -shift 8) - 40) * 1.8 + 32)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Accelerator" -Value $(((Get-Bits -value $RAX_Data -shift 16) - 32) * (129 / 255.0))
        $record | Add-Member -Force -MemberType NoteProperty -Name "TPS" -Value $((Get-Bits -value $RAX_Data -shift 24) * (100 / 255.0))
    }

    if ($null -ne $record.RAX_G){
        $RAX_Data = [uint] $record.RAX_G
        $record | Add-Member -Force -MemberType NoteProperty -Name "Speed" -Value $((Get-Bits -value $RAX_Data -shift 24) * 1.243)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Battery" -Value $((Get-Bits -value $RAX_Data -shift 16) * 0.07333)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Temp_Coolant" -Value $((Get-Bits -value $RAX_Data -shift 8) * 1.8 - 40)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Temp_Manifold_Air" -Value $((Get-Bits -value $RAX_Data -shift 0) * 1.8 - 40)
    }

    if ($null -ne $record.RAX_H){
        $RAX_Data = [uint] $record.RAX_H
        $record | Add-Member -Force -MemberType NoteProperty -Name "Load_MAP" -Value $((Get-Bits -value $RAX_Data -shift 24) * 1.5625)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Load_IMAP" -Value $((Get-Bits -value $RAX_Data -shift 16) * 1.5625)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Load_MAF" -Value $((Get-Bits -value $RAX_Data -shift 8) * 1.5625)
        $record | Add-Member -Force -MemberType NoteProperty -Name "Load_Chosen" -Value $((Get-Bits -value $RAX_Data -shift 0) * 1.5625)
    }
}

if ($ShowSampleData) {
    $csv | Select-Object -skip 20 -first 20 | Format-Table -AutoSize -Wrap -Property *
}
$csv | Export-Csv -Path $Path -UseQuotes AsNeeded

Write-Host "Converted CSV File: $Path" -ForegroundColor DarkGreen

