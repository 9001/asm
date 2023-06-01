generate and place secureboot certificates into this folder; asm will autoconfigure secureboot with these certs on the target machine:

* pk.auth
* pk.esl
* kek.auth
* kek.esl
* db.auth
* db.esl

filenames must be lowercase and all 6 files are required

the same db cert + its privkey must be provided to build.sh when building the asm image; `-ek ~/keys/db.key -ec ~/keys/db.crt`

see the [parent readme](https://github.com/9001/asm/tree/hovudstraum/p/uki#secureboot-certs) for details
