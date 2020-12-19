#!/bin/bash

__unset="unset -f __redirect"
isfe() {
	[ "$2" ] && __redirect() { cat &>/dev/null; } || __redirect() { cat -; }
	if [ ! -f "$1" ]; then
		warning File "$1" does not exists | __redirect
		return 1
	else
		return 0
	fi
}
isde() {
	[ "$2" ] && __redirect() { cat &>/dev/null; } || __redirect() { cat -; }
	if [ ! -d "$1" ]; then
		warning Directory "$1" does not exists | __redirect; $__unset
		return 1
	else
		$__unset
		return 0
	fi
}
isee() {
	[ "$2" ] && __redirect() { cat &>/dev/null; } || __redirect() { cat -; }
	if [ ! $1 "$2" ]; then
		warning "$1" does not exists | __redirect; $__unset
		return 1
	else
		$__unset
		return 0
	fi
}
grepfile() {
	if grep -Eo "$1" "$2" &>/dev/null; then
		return 0
	else
		return 1
	fi
}
user_read() {
	[ "$YN" == Y ] && { local arg="[Y/n] "; enter=yes; } || [ "$YN" == N ] && { local arg="[y/N] "; enter=no; } || arg=""
	read -rp "${@:2}: $arg" "$1"
	if [ "$YN" ]; then case $(eval echo \$${1}) in
		Y*|y*) export answer=yes ;;
		N*|n*) export answer=no ;;
		"") export answer=$enter ;;
		*) export answer=invalid ;;
	esac
	fi
}
out() {
	echo "===> "$@""
}
die() {
	echo -e "\e[0;31m===>\e[0m ERROR: "$@""
	[ "$1" ] && exit 1
}
warning() {
	echo -e "\e[0;33m===>\e[0m WARNING "$@""
}
error() {
	echo -e "\e[0;31m===>\e[0m ERROR: "$@""
}
success() {
	echo -e "\e[0;32m--->\e[0m "$@""
}
process() {
	echo -e "\t>>> "$@"..."
}
sendnull() {
	$@ &>/dev/null
}
mktempd() {
	export MKTEMPDIR="$(mktemp -d)"
}
rmtempd() {
	[ "$MKTEMPDIR" ] && rm -rf $MKTEMPDIR; unset MKTEMPDIR
}
exitcheck() {
	echo -e "\e[0;36m>>>\e[0m The 'check' function could not find the required lines for the patch. Exiting the script..."
	return 5
}
install_service() {
	if [ -f "/etc/systemd/system/"$1"" ]; then
		warning Service file "$1" already exists
		return 1
	else
		sudo install -m 755 "$1" /etc/systemd/system/"$1"
	fi
}
remove_service() {
	sudo rm -rf /etc/systemd/system/"$1"
}
enable_service() {
	[ "$2" ] && local redirect="--now" || local redirect=""
	sudo systemctl enable $redirect "$1"
}
disable_service() {
	[ "$2" ] && local redirect="--now" || local redirect=""
	sudo systemctl disable $redirect "$1"
}
redirect() {
	[ "$2" ] && local redirect="sudo" || local redirect=""
	[ "$text" ] || error Variable text not set
	echo -e "$text" | $redirect tee "$1" 1>/dev/null
}
redirect_a() {
	[ "$2" ] && local redirect="sudo" || local redirect=""
	[ "$text" ] || error Variable text not set
	echo -e "$text" | $redirect tee -a "$1" 1>/dev/null
}
cat_redirect() {
	[ "$2" ] && local redirect="sudo" || local redirect=""
	$redirect tee "$1" 1>/dev/null
}
cat_redirect_a() {
	[ "$2" ] && local redirect="sudo" || local redirect=""
	$redirect tee -a "$1" 1>/dev/null
}
ispe() {
	[ "$2" ] && __redirect() { cat &>/dev/null; } || __redirect() { cat -; }
	if pacman -Qsq | grep -x "$1" &>/dev/null; then
		$__unset
		return 0
	else
		warning Package "$1" does not exists | __redirect; $__unset
		return 1
	fi
}
instpkg() {
	sudo pacman -S $@ --noconfirm
}
instaur() {
	yay -S $@ --noconfirm
}
rmpkg() {
	[[ "$1" != ":"* ]] && { local pkgs="$@"; opt=; } || { local pkgs="${@:2}"; opt="${1##:}"; }
	sudo pacman -R$opt $pkgs
}
