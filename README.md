# ualsv
Useful Arch Linux Script Vault

## What is it?
This is `ualsv`. a script that can apply patches to files, or restore them to their original state if necessary.

## How to use it?
Execute `./ualsv.sh help` for more information \
Do not forget execute `install -Dm755 checkutils.sh /usr/local/bin/checkutils.sh`

## Updates
The [ualsv_db](https://github.com/BiteDasher/ualsv_db.git) repository is available, from which all packages will now be downloaded. If you would like to post your patch, please send me a Merge Request

## How/where to download scripts for this thing? How do I write my own?
~~I'm still thinking about where I should store and whether I should store the script files for this program at all. But as soon as I do, I will definitely report it here.~~  And at the expense of writing your script, I will now show you one of the examples:
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
**You can also look at the `example` folder, which contains a script to turn off tearing on Intel embedded**

## Recommendations:
The `check` function is executed BEFORE installing packages from the `$packages` and `$aur` arrays. \
If you want to list all the commands that the second `checkutils.sh` script provides, run `sed -n 's/^\([^(]\+\)()\s{$/\1/p' checkutils.sh`


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

## Function scheme from file `checkutils.sh`
`isfe` : Checks if file `$1` exists. \
`    ` | Add. arguments : `($2):null` - redirect warning to /dev/null

`isde` : Checks if directory `$1` exists. \
`    ` | Add. arguments : `($2):null` - redirect warning to /dev/null

`isee` : Checks if -`$1` `$2` exists. \
`    ` | Add. arguments : `($3):null` - redirect warning to /dev/null

`grepfile` : grep pattern `$1` from file `$2`

`user_read` : Reads user variable `$1` with prompt `${@:2}` \
`         ` | Add. arguments : Run with variable `$YN=Y(or)N` to ask a question and give the user an answer

`out` : echo ===> $\*

`die` : echo (die function) and exit 1

`warning` : echo yellow ===> and WARNING: $\*

`smallw` : echo yellow -> and $\*

`msg` : echo bold cyan >>> and $\*

`msg2` : echo -> and $\*

`error` : echo red ===> and ERROR: $\*

`success` : echo green ---> and $\*

`process` : echo \t(tab) and $\*

`sendnull` : Execute command with redirection &\>/dev/null

`mktempd` : Creates a temporary directory with `mktemp -d`, then exports it as `MKTEMPDIR` variable

`rmtempd` : Removes a temporaru directory and unset `MKTEMPDIR` variable

`exitcheck` : (see file)

`install_service` : Installs file `$1` to `/etc/systemd/system`, or, if file exists, returns warning and `return 1`

`remove_service` : Removes file `$1` from `/etc/systemd/system`

`enable_service` : Enables `$1` using `systemctl enable` \
`              ` | Add. arguments : `($2):--now` - executes `systemctl enable --now`

`disable_service` : Disables `$1` using `systemctl disable` \
`               ` | Add. arguments : `($2):--now` - executes `systemctl disable --now`

`redirect` : Redirects the contents of the variable `$text` to the specified file `($1)` \
`        ` | Add. arguments : `($2):sudo` - executes `sudo tee` instead of `tee`

`redirect_a` : like `redirect`, but `tee -a`

`cat_redirect` : like `redirect`, but reads `stdout`

`cat_redirect_a` : like `cat_redirect`, but `tee -a`

`dline` : `sed "/$1/d" -i "$2"` \
`     ` | Add. arguments : `($3):sudo` - executes as sudo

`dlinex` : `sed "/^$1\$/d" -i "$2"` \
`      ` | Add. arguments : `($3):sudo` - executes as sudo

`ialine` : `sed "/$1/a $2" -i "$3"` \
`      ` | Add. arguments : `($4):sudo` - executes as sudo

`ibline` : `sed "/$1/i $2" -i "$3"` \
`      ` | Add. arguments : `($4):sudo` - executes as sudo

`ibetween` : `sed -e "/$1/,/$2/c\\$1\n$3\n$2" -i "$4"` \
`        ` | Add. arguments : `($5):sudo` - executes as sudo

`cline` : `sed -e "/$1/ s/$2/$3/" -i "$4"` \
`     ` | Add. arguments : `($5):sudo` - executes as sudo

`ispe` : Checks if package `$1` is installed locally \
`    ` | Add. arguments: `($2):null` - redirect warning to /dev/null

`instpkg` : Installs packages `$@`

`instaur` : Installs packages `$@` using `yay`

`rmpkg` : Removes packages `$@` \
`     ` | Add. arguments : `($1)` - If you want to run `pacman -R` with additional arguments (for example `ns`), enter: `ns` as the first argument. If in the first argument the first character is not `:`, packages will be installed from `1` to the `last` argument
