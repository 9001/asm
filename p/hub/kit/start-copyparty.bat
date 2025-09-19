if not exist python3\python.exe ( mkdir python3 & tar -xC python3 -f python-3.*.zip )

python3\python.exe copyparty-sfx.py -e2d -c ..\sm\copyparty.conf   -v ..\:thehub:A   -v C:\Users\Harald:myhome:A

pause

REM you can add more -v entries, for example -v E:\:edrive:A to share all of E:\ as URL /edrive

REM the uppercase A in C:\Users\Harald:myhome:A gives everyone read-write-move-delete; you can replace A with r for read-only, rw for read-write

REM if you enable passwords in copyparty.conf then you need to append ,u to the end of each -v thing, so for example -v C:\Users\Harald:myhome:A,u
