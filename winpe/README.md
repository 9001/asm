# bonus content

* how this could have been done based on windows instead of alpine
* unrelated to asm, moreover a bad idea

takes [winPE](https://docs.microsoft.com/en-us/windows-hardware/manufacture/desktop/winpe-intro) from a windows installation iso and produces an uefi-only, usb-only image which is scriptable at build-time by modifying [`./src/`](./src/)

some takeaways,
* boots MUCH SLOWER than asm
  * winpe 3.1 (from a win7 iso) boots in ~30sec under optimal conditions
  * winpe 10 (from a win10 iso) boots in ~45sec under optimal conditions, and does not have any progress indicators while booting


# is this legal?

no, or probably not, it's confusing
* apparently if it were to be based on winRE instead (which is just winPE with more stuff) then it would have been fine
