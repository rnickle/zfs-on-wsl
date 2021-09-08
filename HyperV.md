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
    $ apt-get install -y tzdata git openssh-server
    ```
  * Clone this repo:
    ```bash
    $ git clone https://github.com/rnickle/zfs-on-wsl
    ```
  * Add yourself to SSH:
    ```bash
    $ sudo -i
    # echo "AllowUsers myusername" >> /etc/sshd_config
    # systemctl restart sshd
    # exit
    $
    ```
  * Enable passwordless sudo for yourself:
    ```bash
    $ sudo -i
    # echo "myusername ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers.d/sudo_myusername
    # exit
    $
    ```
