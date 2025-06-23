# My FreeBSD home server Ansible playbooks

This repository describes my home server setup with Ansible. The server machine is an Intel N150 based mini-PC with two wired network interfaces and four M.2 NVMe slots. The NVMe slots are fitted with 1TB drives.

## Manual installer setup

1. Download a recent FreeBSD release. Tested with https://download.freebsd.org/releases/amd64/amd64/ISO-IMAGES/14.3/FreeBSD-14.3-RELEASE-amd64-memstick.img.
2. Run the installer off a USB drive. During installation, configure:

   - a Finnish keymap
   - hostname "pursotin"
   - an Auto-ZFS setup with Root-on-ZFS, pool name "zroot"
   - RAID10: a stripe of two mirrors
   - 4K sectors
   - root encrypted (GELI), GPT (BIOS+UEFI)
   - 8GB of non-mirrored, encrypted swap (times four for a total of 32GB)
   - install base, kernel, src, ports, handbook
   - set up IPv4 (DHCP) and v6 (SLAAC) with DNS 192.168.0.1 and 8.8.8.8
   - services: sshd, ntpd, ntpd sync on start, powerd

3. After install, open a shell in the chroot env and temporarily allow in `/etc/ssh/sshd_config`:

```
PasswordAuthentication yes
PermitRootLogin yes
```

4. Reboot.
5. Install SSH keys with `ssh-copy-id`.
6. You can now run the playbook.

## Running the playbook

Use an [.envrc file](https://direnv.net/) to provide secrets through the shell environment. Required variables are listed in `playbook.yml`.

```shell
ansible-playbook -i inventory playbook.yml
```

## Author

Jan Tuomi, \<jan at jantuomi.fi\>.
