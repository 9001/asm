# miniparty

boot straight into copyparty + r0c with dhcp

core features:

* `copyparty` - fileserver with resumable uploads
  * detects and shares all local drives during bootup
  * speaks http / https / webdav / ftp / tftp 
* `r0c` - telnet / netcat chatserver
* `sshd` - sftp fileserver / debug


## copyparty

the [portable fileserver](https://github.com/9001/copyparty/)

* `/sm/copyparty.conf` = the config that gets executed
* `/kit/copyparty-help.html` = more config options
* list folders with `curl hub.local/sda1/`
* download folders with `curl hub.local/sda1/?tar | tar -xv`
* upload from CLI using [/.cpr/a/u2c.py](/.cpr/a/u2c.py)
  * direct-download link: [/.cpr/a/u2c.py](/.cpr/a/u2c.py?mime=application/octet-stream)
* the `sm` folder is unmapped/inaccessible (it has the tls-cert and `asm.sh` with passwords)
* [kit/ping.html](kit/ping.html)


## r0c

the [telnet chatserver](https://github.com/9001/r0c), but you can also connect to a r0c-server at `10.1.2.51` using bash and only bash itself:

```bash
exec 97<>/dev/tcp/10.1.2.51/531;cat<&97&while IFS= read -rn1 x;do [ -z "$x" ]&&x=$'\n';printf %s "$x">&97;done
# if you need to disconnect, run this:
exec 97<&-; killall cat
```

the following clients can also be used to connect without telnet:

* on windows, [kit/r0c-client.ps1](kit/r0c-client.ps1)
* on linux/macos, [kit/r0c-client.sh](kit/r0c-client.sh)


# configuring

all of these are optional, and all of them can be done after building the image (if you don't mind the checksum-verifier complaining about the changes)

* change the sshd password near the top of `/sm/asm.sh`, specifically `pw=k`
* set a password on copyparty; bottom 4 lines of `/sm/copyparty.conf`
* change the https certificate by replacing `/sm/tls-cert.pem`
* disable multicast spam in `/sm/copyparty.conf` by removing the line that mentions stealth-mode


# SBOM

* https://github.com/9001/copyparty
* https://github.com/9001/r0c
* plus all the packages included from the alpine repos
