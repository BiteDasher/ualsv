#!/bin/bash
[ "$(id -u)" == 0 ] && HOME="/home/$SUDO_USER"
### Useful Arch Linux Script Vault
LIB="/usr/local/share/ualsv"
source $LIB/checkutils.sh
DIR="$HOME/.ualsv"
SERVER=" "
if [ -f $DIR ]; then
	mkdir -p $DIR
	mkdir -p $DIR/local
	cd $DIR
	git clone "$SERVER" database
fi
user="$(whoami)"
isroot() {
	if [[ $(id -u) -ne 0 ]]; then
	die "This action requires superuser rights" $@
	fi
}
update_system() {
	sudo pacman -Syu
}
install_pkgs() {
	sudo pacman -S ${packages[@]} || die Failed to install packages
}
install_aurs() {
	yay -S ${aur[@]} || die Failed to install packages from AUR using yay
}
trapcom() {
	error "Process termination signal received"
	case "$__first_arg" in
		install|get*)
			rm -rf "$DIR"/local/"$__second_arg"/getdir
			[ "$restore" == true ] && restore
			[ "$restore_cleanup" == true ] && restore_cleanup
			;;
		list*|search|info)
			rm -f "$DIR"/.temp*
			;;
		restore*)
			:
			;;
	esac
}
trap trapcom SIGTERM SIGKILL SIGINT
get_files() {
	getdir="$CURDIR/getdir"
	[ -d "$getdir" ] || mkdir "$getdir"
	for get_ in ${get[@]}; do
	local source_get_mtd="$(echo $get_ | cut -d ":" -f 1)"
	local place="$(echo $get_ | cut -d ":" -f 2)"
	local address="$(echo $_get | cut -d ":" -f 3-)"
	if [ "$place" == "-" ] || [ -z "$place" ]; then
		local place="${address##*/}"
	fi
	[[ -e "$place" ]] && [[ "$source_get_mtd" -ne "git" ]] && continue
	[[ -e "$place" ]] && [[ "$source_get_mtd" -eq "git" ]] && rm -rf "$place"
	case "${source_get_mtd}" in
		wget) wget -O "$getdir"/"$place" "$address" -q --show-progress;;
		curl) curl -L -o "$getdir"/"$place" --progress-bar "$address";;
		git) git clone "$address" "$getdir"/"$place" 1>/dev/null;;
		esac
	done
}
update_scripts() {
	cd $DIR/database
	git pull --ff-only || die Failed to git pull scripts
}
list_scripts() {
	rm -f $DIR/.temp_list*; touch $DIR/.temp_list_{name,version,creator,status}
	for script in $DIR/database/*; do
		local name="$(basename "$script")"
		local version="$(grep -o "^version=.*" "$script"/script | cut -d "=" -f 2- | tr -d '"')"
		local creator="$(grep -o "^creator=.*" "$script"/script | cut -d "=" -f 2- | tr -d '"')"
			if [ -f "$DIR/local/$name/installed" ]; then
				local status="[X]"
			else
				local status="[.]"
			fi
		echo "$name" >> $DIR/.temp_list_name
		echo "$version" >> $DIR/.temp_list_version
		echo "$creator" >> $DIR/.temp_list_creator
		echo "$status" >> $DIR/.temp_list_status
	done
	awk 'BEGIN{ for(i=1; i<ARGC; i++) { 
              while( (getline<ARGV[i])>0) { 
                 nl[i]++; if(length>w[i]) w[i]=length; }
              w[i]++; close(ARGV[i])
              if(nl[i]>nr) nr=nl[i]; }
            for(r=1; r<=nr; r++) {
              for(f=1; f<ARGC; f++) {
                if(r<=nl[f]) getline<ARGV[f]; else $0=""  
                printf("%-"w[f]"s",$0); } 
              print "" } }
    ' $DIR/.temp_list_status $DIR/.temp_list_name $DIR/.temp_list_version $DIR/.temp_list_creator
    rm $DIR/.temp_list*
}
list_scripts_local() {
	rm -f $DIR/.temp_list*; touch $DIR/.temp_list_{name,version,creator,status}
	for script in $DIR/local/*; do
		local name="$(basename "$script")"
		local version="$(grep -o "^version=.*" "$script"/script | cut -d "=" -f 2- | tr -d '"')"
		local creator="$(grep -o "^creator=.*" "$script"/script | cut -d "=" -f 2- | tr -d '"')"
			if [ -f "$DIR/local/$name/installed" ]; then
				local status="[X]"
			else
				[ "$1" != q ] && continue || local status="[.]"
			fi
		echo "$name" >> $DIR/.temp_list_name
		echo "$version" >> $DIR/.temp_list_version
		echo "$creator" >> $DIR/.temp_list_creator
		echo "$status" >> $DIR/.temp_list_status
	done
    paste $DIR/.temp_list_status $DIR/.temp_list_name $DIR/.temp_list_version $DIR/.temp_list_creator | column -tc 4
    rm $DIR/.temp_list*
}
restore_backup() {
	isroot "(restore backup files)"
	### Better safe than sorry
	if [ -d "$DIR"/local/"$ARG"/backup_place ]; then
		cd "$DIR"/local/"$ARG"
		o_user="$(stat -c %u ./backup_place)"
		o_group="$(stat -c %g ./backup_place)"
		chown -R 0:0 ./backup_place
		
	else
		exit 1
	fi
	cd $DIR/local/$ARG/backup_place
	while read -r restore_file; do
		local mode="$(stat -c %a ".$restore_file")"
		local type="$(stat -c %f ".$restore_file")"
		case $type in
			a1ff) ln -s "$(readlink ".$restore_file")" "$restore_file" || error "$restore_file" ;;
			81a4) install -D -m $mode ".$restore_file" "$restore_file" || error "$restore_file" ;;
			41ed) install -d -m $mode "$restore_file" || error "$restore_file" ;;
		esac
	done < ../backup || { chown -R $o_user:$o_group "$DIR"/local/"$ARG"/backup_place; die Something went wrong; }
	success Done
	chown -R $o_user:$o_group "$DIR"/local/"$ARG"/backup_place
}
save_backup() {
	cd $DIR/local/$ARG/backup_place
	while read -r restore_file; do
		local type="$(stat -c %f "$restore_file")"
		local mode="$(stat -c %a "$restore_file")"
		case $type in
			41ed) install -d -m $mode ".$restore_file" || error "$restore_file" ;;
			a1ff) install -d "$(dirname ".$restore_file")"; ln -s "$(readlink "$restore_file")" ".$restore_file" || error "$restore_file" ;;
			81a4) install -D -m $mode "$restore_file" ".$restore_file" || error "$restore_file" ;;
		esac
	done < ../backup || die Something went wrong
	success Done
}
remove_script() {
	rm -rf $DIR/local/"$1" || return 1
}
__first_arg="$1"
__second_arg="$2"
case "$1" in
help)
	cat <<EOF
usage: ualsv [options] script

  Options:
	list		- Display information about scripts, their status, version and author
	list-local	- Shows all locally installed and applied scripts
	list-local-s	- Shows scripts that are just in the local database
	info		- Shows detailed information about the specified script
	search		- Searches for possible scripts using name and description
	get		- Download script and patch what is needed
	 install	- Same as get
	get-again	- Try to install a patch from a script that was installed locally, but not applied
	remove		- Removes the script from the local database and all its data
	restore		- Restores everything that the script touched during its work, as well as the installed status in the system
	update		- Downloads the latest scripts using the git repository
	clean		- Cleans folders of local script files from all foreign files
	force-update	- Deletes and re-fetches data from the git repository
	remove-force	- Removes the ualsv directory. All scripts will NOT be restored to backup

ualsv downloads and applies / installs patches for the Arch Linux distribution. In the form of executable bash scripts. It also has a system for recovering files that were saved before the patch.
EOF
;;
list)
	list_scripts
;;
list-local)
	list_scripts_local
;;
list-local-s)
	list_scripts_local q
;;
get|install|get-again)
	[ "$2" ] || die Enter the name of the script you want to apply
	[ -d "$DIR"/database/"$2" ] || die "No script found with name $2"
	out The process of getting and running script "$2" has begun
	if [[ "$1" == "get-again" ]]; then ####
		[ -f "$DIR"/local/"$2"/installed ] && die "Patch already applied :)"
	else
		if [ -f "$DIR"/local/"$2"/installed ]; then
			warning "The directory with script $2 already exists. Use the get-again parameter"
			YN=N user_read zero "This script has already been applied. Reinstall without restoring the backup?"
			case "$answer" in
				yes) remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
				no) exit 0 ;;
				*) die Unknown answer ;;
			esac
		fi
	cp -a -r "$DIR"/database/"$2" $DIR/local/
	fi ####
	cd "$DIR"/local/"$2"
	if [ -f ./backup ] && [ ! -f "$DIR"/local/"$2"/installed ]; then
		rm -rf backup_place
		mkdir backup_place
		ARG="$2" save_backup
		BACKUP=1
	fi
	[ ! -f ./script ] && cd ..
	source ./script
	CURDIR="$(pwd)"
	[ "$packages" ] && { out "Started downloading required packages using pacman"; install_pkgs || die "Something went wrong while receiving"; }
	[ "$aur" ] && { out "Started downloading required packages using yay (AUR)"; install_aurs || die "Something went wrong while receiving"; }
	[ "$get" ] && { out "Downloading the required files started"; get_files || die "Something went wrong while receiving"; }
	success "Step 1 - done"
	out "Checking possible functions has started"
	if [ "$(declare -f check 2>/dev/null)" ]; then
		process "Found function check"
		functions+=('check')
	fi
	if [ "$(declare -f build 2>/dev/null)" ]; then
		process "Found function build"
		functions+=('build')
	fi
	if [ "$(declare -f action 2>/dev/null)" ]; then
		process "Found function action"
		functions+=('action')
	else
		process "Function action not found!"
		die "Function action required for basic package actions not found"
	fi
	[ "$(declare -f cleanup 2>/dev/null)" ] && { process "Found function cleanup"; do_cleanup=true; }
	[ "$(declare -f restore 2>/dev/null)" ] && { process "Found function restore"; restore=true; }
	[ "$(declare -f restore_cleanup 2>/dev/null)" ] && { process "Found function restore_cleanup"; restore_cleanup=true; }
	success "Step 2 - done"
	for function in ${functions[@]}; do
		process "Executing $function"
		$function || { error "Something went wrong while $function"
				[ "$restore" == true ] && restore
				[ "$restore_cleanup" == true ] && restore_cleanup
				[ "$BACKUP" == 1 ] && warning "If you see this message, run command 'sudo $(basename $0) restore $2' after it"
				exit 1
			     }
	done
	[ "$do_cleanup" == true ] && { process "Executing cleanup"; cleanup; }
	success "Step 3 - done"
	touch "$DIR"/local/"$2"/installed
	success "$2 successfully applied!"
	exit 0
;;
info)
	[ "$2" ] || die Enter the name of the script you want to look at
	[ -d "$DIR"/database/"$2" ] || die "No script found with name $2"
	source "$DIR"/database/"$2"/script
	functions=('check' 'build' 'action' 'cleanup' 'restore' 'restore_cleanup')
	for function_ in ${functions[@]}; do
		declare -f $function_ &>/dev/null && found_functions+=("$function_")
	done
	rm -f $DIR/.temp_list*; touch $DIR/.temp_list_{1,2}
	echo "Name:" >> $DIR/.temp_list_1; echo "$(basename $2)" >> $DIR/.temp_list_2
	echo "Description:" >> $DIR/.temp_list_1; echo "$desc" >> $DIR/.temp_list_2
	echo "Version:" >> $DIR/.temp_list_1; echo "$version" >> $DIR/.temp_list_2
	echo "Creator:" >> $DIR/.temp_list_1; echo "$creator" >> $DIR/.temp_list_2
	[ "$packages" ] && { echo "Required official packages:" >> $DIR/.temp_list_1; echo "${packages[@]}" >> $DIR/.temp_list_2 ; }
	[ "$aur" ] && { echo "Required AUR packages:" >> $DIR/.temp_list_1; echo "${aur[@]}" >> $DIR/.temp_list_2 ; }
	[ "$get" ] && { echo "Links of files to be downloaded during the process:" >> $DIR/.temp_list_1; echo "$(echo ${get[@]} | cut -d ":" -f 3- | tr " " ";")" >> $DIR/.temp_list_2 ; }
	echo "Found functions:" >> $DIR/.temp_list_1; echo "${found_functions[@]}" >> $DIR/.temp_list_2
	awk 'FNR==1{f+=1;w++;}
     f==1{if(length>w) w=length; next;}
     f==2{printf("%-"w"s",$0); getline<f2; print;}
    ' f2=$DIR/.temp_list_2 $DIR/.temp_list_1 $DIR/.temp_list_1
	rm -f $DIR/.temp_list*
;;
search)
	[ "$2" ] || die Enter your search query
	for search in "$DIR"/database/*; do
		name="$(basename $search)"
		eval $(source "$search"/script; echo "desc=\"$desc\""; echo "version=\"$version\"")
		total+=("~$name $version% $desc")
	done
	echo ${total[@]} | tr "~" "\n" | grep -i "${@:2}" | sed "s/%/\n  /1"
;;
remove)
	[ "$2" ] || die Enter the name of the script you want to remove
	[ -d "$DIR"/database/"$2" ] || die "No script found with name $2"
		YN=N user_read zero "A directory with a backup copy was found for script "$2". Continue?"
		case "$answer" in
			yes) remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
			no) exit 0 ;;
			*) die Unknown answer ;;
		esac
	success "Script removed"
;;
restore)
	isroot "(restore backup files)"
	[ "$2" ] || die Enter the name of the script you want to remove
	[ -d "$DIR"/local/"$2" ] || die "No script found with name $2"
	[ -f "$DIR"/local/"$2"/installed ] || die "This patch is not applied"
	if source <(source "$DIR"/local/"$2"/script) && declare -f restore &>/dev/null; then
		source "$DIR"/local/"$2"/script
		restore || error "Failed to restore"
		declare -f restore_cleanup &>/dev/null && restore_cleanup
	fi
	[ -d "$DIR"/local/"$2"/backup_place ] || die "No backup folder found with name $2"
	ARG="$2" restore_backup || die "Failed to restore backup"
	rm $DIR/local/"$2"/installed
	success "Done!"
;;
update)
	update_scripts
;;
clean)
	for pkg in "$DIR"/local/*; do
		cd "$pkg"
		for file in ./*; do
			case "$file" in
				./script|./backup|./backup_place|./installed) : ;;
				*) rm -rf "$file" ;;
			esac
		done
	done
;;
force-update)
	rm -rf "$DIR"/database
	cd "$DIR"
	git clone "$SERVER" database || die "Failed to git clone"
	success "Done!"
;;
force-remove)
	read -p "Are you sure? (Click Enter) 1/3"
	read -p "Are you sure? (Click Enter) 2/3"
	read -p "Are you sure? (Click Enter) 3/3"
	sleep 5
	rm -rf "$DIR"
;;
*)
	die "Unknown argument. Use $0 help for more."
;;
esac
