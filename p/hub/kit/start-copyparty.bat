if not exist py\python.exe ( mkdir py & tar -xC py -f python3.zip )

py\python.exe copyparty-sfx.py -e2d -c ..\sm\copyparty.conf   -v ..\:thehub:A

pause

REM you can add more -v entries, for example:
REM   -v E:\:edrive:A to share all of E:\ as URL /edrive
REM   -v C:\Users:homes:A to share all of C:\Users as URL /homes
REM
REM the uppercase A gives everyone read-write-move-delete; you can replace A with r for read-only, rw for read-write
REM
REM if you enable passwords in copyparty.conf then you need to append ,u to
REM  the end of each -v thing, so for example -v C:\Users\Harald:myhome:A,u
