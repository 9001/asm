# this file will autoexecute when an uefi-shell (shell.efi) is launched;
# its primary purpose is switching to filesystem "fs0:" (the bootdisk)

@echo " "
@echo "cheatsheet: 'map' shows disks, 'reset' is reboot, 'reset -s' is shutdown,"
@echo "  'exit',  'edit some.txt',  ls/cd/mv/rm/...  see 'help' and shift-PgUp"
@echo " "

fs0:
