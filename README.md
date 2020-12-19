# ualsv
Useful Arch Linux Script Vault

## What is it?
This is `ualsv`. a script that can apply patches to files, or restore them to their original state if necessary.

## How to use it?
Execute `./ualsv.sh help` for more information \
Do not forget execute `install -Dm755 checkutils.sh /usr/local/bin/checkutils.sh`

## How/where to download scripts for this thing? How do I write my own?
I'm still thinking about where I should store and whether I should store the script files for this program at all. But as soon as I do, I will definitely report it here. And at the expense of writing your script, I will now show you one of the examples:
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
get=('git:-:https://github.com/exa/mple.get'
     'curl:name_to_save:https://git.io/12345'
     'wget:-:https://git.io/wow')
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

## Recommendations:
The `check` function is executed BEFORE installing packages from the `$packages` and `$aur` arrays. \
If you want to list all the commands that the second `checkutils.sh` script provides, run `cat checkutils.sh | grep -o '^.*() {$' | cut -d "(" -f1` \


## Dependencies:
`gawk` \
`sed` \
`coreutils` \
`bash` \
`wget` \
`curl` \
`git` \
`grep` \
`pacman` \
`sudo` \
`yay (AUR)`
