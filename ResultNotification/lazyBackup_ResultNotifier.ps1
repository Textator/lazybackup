$ErrorActionPreference = 'SilentlyContinue'
$statusFile = Join-Path $env:ProgramData 'lazyBackup\LastOperation.ini'
if (-not (Test-Path -LiteralPath $statusFile)) { exit 0 }
$data = @{}
Get-Content -LiteralPath $statusFile | ForEach-Object { if ($_ -match '^([^=]+)=(.*)$') { $data[$matches[1]] = $matches[2] } }
if ($data['DISPLAYED'] -eq '1') { exit 0 }
$operation = $data['OPERATION']; $result = $data['RESULT']; $image = $data['IMAGE']
$log = Join-Path $env:ProgramData 'lazyBackup\LastOperation.dism.log'
$dismExit = $data['DISM_EXIT']; $verifyExit = $data['VERIFY_EXIT']; $date = $data['DATE']; $computer = $data['COMPUTER']
if ($data['WRITE_EVENTLOG'] -eq 'Y') {
 $type = if ($result -eq 'SUCCESS') { 'Information' } else { 'Error' }
 $id = if ($result -eq 'SUCCESS') { 1000 } else { 1001 }
 $message = "Operation: $operation`r`nResult: $result`r`nComputer: $computer`r`nDate: $date`r`nImage: $image`r`nDISM exit: $dismExit`r`nVerification exit: $verifyExit`r`nLog: $log"
 Write-EventLog -LogName Application -Source lazyBackup -EntryType $type -EventId $id -Message $message
}
if (($result -ne 'SUCCESS') -and ($data['CREATE_DESKTOP_NOTICE'] -eq 'Y')) {
 $desktop = [Environment]::GetFolderPath('Desktop')
 @"
lazyBackup reported a failure.

Operation: $operation
Computer: $computer
Date: $date
DISM exit code: $dismExit
Verification exit code: $verifyExit
Image: $image
Log: $log
"@ | Set-Content -LiteralPath (Join-Path $desktop 'lazyBackup FAILED.txt') -Encoding UTF8
}
if (($result -eq 'SUCCESS') -and ($data['SHOW_SUCCESS_MESSAGE'] -eq 'Y')) {
 Add-Type -AssemblyName System.Windows.Forms
 [System.Windows.Forms.MessageBox]::Show("lazyBackup $operation completed successfully.`r`n`r`nImage:`r`n$image",'lazyBackup','OK','Information') | Out-Null
} elseif (($result -ne 'SUCCESS') -and ($data['SHOW_FAILURE_DIALOG'] -eq 'Y')) {
 $dialog = Join-Path $PSScriptRoot 'lazyBackup_Result.hta'
 if (Test-Path -LiteralPath $dialog) {
  $env:LAZYBACKUP_STATUS_FILE = $statusFile
  Start-Process "$env:SystemRoot\System32\mshta.exe" -ArgumentList ('"' + $dialog + '"') -Wait
 }
}
$lines = Get-Content -LiteralPath $statusFile | Where-Object { $_ -notmatch '^DISPLAYED=' }
$lines += 'DISPLAYED=1'
$lines | Set-Content -LiteralPath $statusFile -Encoding ASCII
if ($result -eq 'SUCCESS') { Remove-Item -LiteralPath $statusFile -Force }
exit 0
