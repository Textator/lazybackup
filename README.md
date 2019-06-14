# lazybackup
Backup with DISM batch script.

Has to be started from any winPE enviroment if you want to backup system (i.e. windows) partition.

A script, because I was to lazy to do regular backups of a whole partition with DISM. Lots of other backup programs didn't work for me, because they either had to installed or can't restore a working partition on different hatrdware or different sized partition.
DISM, included in windows, can do that.

lazyBackup looks for certain files:
- .DRIVETOBACKUP - put in root of drive to be backup, if not found lazyBackup asks for the drive letter to be backed up
- .BACKUPSTORE - put in root of drive to store the backup, if not found asks for the drive letter of drive to store the backup
- .USBBACKUPSTORE - put in root of any external drive (e.g. USB) to store the backup, if found it's prefered to drive with .BACKUPSTORE
