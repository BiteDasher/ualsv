# ualsv
Useful Arch Linux Script Vault

## What is it?
This is `ualsv`. a script that can apply patches to files, or restore them to their original state if necessary.

## How to use it?
Execute `./ualsv.sh help` for more information

## How/where to download scripts for this thing? How do I write my own?
I'm still thinking about where I should store and whether I should store the script files for this program at all. But as soon as I do, I will definitely report it here. And at the expense of writing your script, I will now show you one of the examples: \
```
test --- script
    \___ backup
```
```
desc="test"
version="1-1"
creator="Artemii (BiteDasher)"
packages=('systemd')
aur=('git-git')
check() {
echo check
}
action() {
echo action
}
restore() {
echo restore commands
}
cleanup() {
:
}
restore_cleanup() {
rm -r /tmp/trashcan
}
```
```
/etc/backup.example
/etc/backup.folder
/etc/backup.symlink
```

## Dependencies:
`gawk` \
`sed` \
`coreutils` \
`bash` \
`wget` \
`curl` \
`git` \
`grep` \
`pacman`
