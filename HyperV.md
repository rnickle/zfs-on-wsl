## Hyper-V Quick Create (Ubuntu 20.04)

* Search for 'Hyper-V Quick Create' in the Start menu
* Select Ubuntu 20.04 (approximately 2GiB download)
* Respond to Ubuntu installation prompts (machine name, username, password...)
* Start virtual machine and login
* Open a terminal
  * Update and upgrade VM, install _git_ and fix the default _tzdata_.
```bash
$ export DEBIAN_FRONTEND=noninteractive
$ apt-get update
$ apt-get upgrade -y
$ apt-get install -y tzdata git
```