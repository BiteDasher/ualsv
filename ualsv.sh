#!/bin/bash
[ "$(id -u)" == 0 ] && HOME="/home/$SUDO_USER"
### Useful Arch Linux Script Vault
LIB="/usr/local/share/ualsv"
source $LIB/checkutils.sh
DIR="$HOME/.ualsv"
SERVER=" " ### Enter the address of your script repository here
if [ ! -d $DIR ]; then
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
	sudo pacman -S ${packages[@]} --asdeps --needed || die Failed to install packages
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
# Function for downloading files from array "get" #
get_files() {
	getdir="$CURDIR/getdir"
	[ -d "$getdir" ] || mkdir "$getdir"
	for get_ in ${get[@]}; do
	local source_get_mtd="$(echo $get_ | cut -d ":" -f 1)"
	local place="$(echo $get_ | cut -d ":" -f 2)"
	local address="$(echo $_get | cut -d ":" -f 3-)"
	# If instead of the destination file we have empty, or "-",
	# we use as the name everything that is after the last slash in the "address" column
	if [ "$place" == "-" ] || [ -z "$place" ]; then
		local place="${address##*/}"
	fi
	# If the file exists, do not download it again,
	# but if it is a git repository, delete the folder and clone it again
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
	cd "$DIR"/database
	git pull --ff-only || die Failed to git pull scripts
}
list_scripts() {
	# If SIGKILL was made and the process did not manage 
	# to delete all temporary files, we will try to delete them again,
	# if they are, of course.
	rm -f "$DIR"/.temp_list*; touch "$DIR"/.temp_list_{name,version,creator,status}
	for script in "$DIR"/database/*; do
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
	# Making beautiful column-like output #
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
				# If we decide to use list-local-s to show only 
				# locally installed scripts, we skip the not installed patch
				[ "$1" != q ] && continue || local status="[.]"
			fi
		echo "$name" >> "$DIR"/.temp_list_name
		echo "$version" >> "$DIR"/.temp_list_version
		echo "$creator" >> "$DIR"/.temp_list_creator
		echo "$status" >> "$DIR"/.temp_list_status
	done
	# Like awk, but a little easier
    paste "$DIR"/.temp_list_status "$DIR"/.temp_list_name "$DIR"/.temp_list_version "$DIR"/.temp_list_creator | column -tc 4
    rm "$DIR"/.temp_list*
}
after_pkg() {
[ "$1" ] && local place="$1" || local place=".."
[ -f "$place"/packages ] || return 0
[ -s "$place"/packages ] || return 0
free_pkgs="$(pacman -Qdtq)"
while read -u 3 -r pkg; do
	if [ "$(grep -x "$pkg" <<< "${free_pkgs}")" ]; then
		sudo pacman -Rs $pkg
	else
		process "$pkg skipped"
	fi
done 3< "$place"/packages
}
restore_backup() {
	isroot "(restore backup files)"
	### Better safe than sorry
	# If in some situation during this process the folder with the
	# script is deleted and the chown command is executed, it may
	# change the permissions on those files that it should not touch.
	# To isolate ourselves from this, let's check again
	if [ -d "$DIR"/local/"$ARG"/backup_place ]; then
		cd "$DIR"/local/"$ARG"
		o_user="$(stat -c %u ./backup_place)"
		o_group="$(stat -c %g ./backup_place)"
		chown -R 0:0 ./backup_place
		
	else
		[ "$restored" == 1 ] && return 0 || exit 1
	fi
	cd "$DIR"/local/"$ARG"/backup_place
	if [ -f ../packages ]; then
	out "Removing unnecessary packages"
	after_pkg
	fi
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
	cd "$DIR"/local/"$ARG"/backup_place
	while read -r restore_file; do
		local type="$(stat -c %f "$restore_file")"
		local mode="$(stat -c %a "$restore_file")"
		case $type in
			41ed) install -d -m $mode ".$restore_file" || error "$restore_file" ;;
			# If we come across a symbolic link, we will make a folder for it in advance
			a1ff) install -d "$(dirname ".$restore_file")"; ln -s "$(readlink "$restore_file")" ".$restore_file" || error "$restore_file" ;;
			81a4) install -D -m $mode "$restore_file" ".$restore_file" || error "$restore_file" ;;
		esac
	done < ../backup || die Something went wrong
	success Done
}
remove_script() {
	rm -rf "$DIR"/local/"$1" || return 1
}
# We add arguments, since trapcom must somehow get the
# current arguments from the running shell, instead of its own (in the function)
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
	cp -a -r "$DIR"/database/"$2" "$DIR"/local/
	fi ####
	cd "$DIR"/local/"$2"
	if [ -f ./backup ] && [ ! -f "$DIR"/local/"$2"/installed ]; then
		rm -rf backup_place
		mkdir backup_place
		ARG="$2" save_backup
		BACKUP=1
	fi
	# If the backup was not made, there was no move to the folder with it.
	# Let's check if we are in the correct catalog now
	[ ! -f ./script ] && cd ..
	source ./script
	CURDIR="$(pwd)"
	[ "$get" ] && { out "Downloading the required files started"; get_files || die "Something went wrong while receiving"; }
	if [ "$(declare -f check 2>/dev/null)" ]; then
		out "Found function check. Executing..."
		check; [ "$(echo $?)" == 5 ] && {
						rm -rf "$DIR"/local/"$2"
						exit 0
						}
	fi
	if [ "$packages" ]; then
		__cleaned_pkgs="$(grep -v -x -f <(pacman -Qsq) <(echo "${packages[@]}" | tr " " "\n"))"
	fi
	[ "$packages" ] && { out "Started downloading required packages using pacman"; install_pkgs || die "Something went wrong while receiving"; }
	[ "$aur" ] && { out "Started downloading required packages using yay (AUR)"; install_aurs || die "Something went wrong while receiving"; }
	success "Step 1 - done"
	out "Checking possible functions has started"
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
	[ "$__cleaned_pkgs" ] && echo "$__cleaned_pkgs" > "$DIR"/local/"$2"/packages
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
	rm -f "$DIR"/.temp_list*; touch "$DIR"/.temp_list_{1,2}
	echo "Name:" >> "$DIR"/.temp_list_1; echo "$(basename $2)" >> "$DIR"/.temp_list_2
	echo "Description:" >> "$DIR"/.temp_list_1; echo "$desc" >> "$DIR"/.temp_list_2
	echo "Version:" >> "$DIR"/.temp_list_1; echo "$version" >> "$DIR"/.temp_list_2
	echo "Creator:" >> "$DIR"/.temp_list_1; echo "$creator" >> "$DIR"/.temp_list_2
	[ "$packages" ] && { echo "Required official packages:" >> "$DIR"/.temp_list_1; echo "${packages[@]}" >> "$DIR"/.temp_list_2 ; }
	[ "$aur" ] && { echo "Required AUR packages:" >> "$DIR"/.temp_list_1; echo "${aur[@]}" >> "$DIR"/.temp_list_2 ; }
	[ "$get" ] && { echo "Links of files to be downloaded during the process:" >> "$DIR"/.temp_list_1; echo "$(echo ${get[@]} | cut -d ":" -f 3- | tr " " ";")" >> $DIR/.temp_list_2 ; }
	echo "Found functions:" >> "$DIR"/.temp_list_1; echo "${found_functions[@]}" >> "$DIR"/.temp_list_2
	awk 'FNR==1{f+=1;w++;}
     f==1{if(length>w) w=length; next;}
     f==2{printf("%-"w"s",$0); getline<f2; print;}
    ' f2="$DIR"/.temp_list_2 "$DIR"/.temp_list_1 "$DIR"/.temp_list_1
	rm -f "$DIR"/.temp_list*
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
			yes) after_pkg ""$DIR"/local/"$2""; remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
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
	source "$DIR"/local/"$2"/script
	if declare -f restore &>/dev/null; then
		restore && restored=1 || error "Failed to restore"
		declare -f restore_cleanup &>/dev/null && restore_cleanup
	fi
	[ -d "$DIR"/local/"$2"/backup_place ] || { [ "$restored" == 1 ] || die "No backup folder found with name $2"; }
	ARG="$2" restore_backup || die "Failed to restore backup"
	rm "$DIR"/local/"$2"/installed
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
				./script|./backup|./backup_place|./installed|./packages) : ;;
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
