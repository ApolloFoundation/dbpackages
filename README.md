# DB Packages

This repository contains packaging scripts for the database engine used by Apollo blockchain

Linux and Windows scripts should be run on Linux. The script downloads official builds of MariaDB and re-packs it in the 
format tha is used by Apollo installers.

MariaDB does not provide official builds for MacOS, so MacOS script uses "Brew" to install MariaDB and then repacks it.
The script should be run on MacOS.

Stable branch is "master".

For more recent version please use "develop" branch


## Possible errors while using scripts

### Linux OR WSL
Note. Probably you will need sudo privileges

#### zip: command not found

> sudo apt-get install zip unzip -y

#### patchelf: command not found

If that error happens to you try to install it using [link](https://command-not-found.com/patchelf)

####  tar (child): zstd: Cannot exec: No such file or directory

> apt install zstd

