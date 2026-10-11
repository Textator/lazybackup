$cs = Get-CimInstance Win32_ComputerSystem

if (
    $cs.Model -match 'Virtual|VMware|VirtualBox|KVM|QEMU|Hyper-V' -or
    $cs.Manufacturer -match 'VMware|VirtualBox|Parallels'
) {
    exit
}

$BatchFile = "$env:ProgramData\Programme_portable\Sicherheit\lazybackup\install lazyBackup to Boot Menu BCD\lazyBackup_BootIntegration.bat"

& $BatchFile

