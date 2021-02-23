#!/bin/bash
LIB="/usr/local/share/ualsv"
source $LIB/checkutils.sh
if [ "$(id -u)" == 0 ]; then
	if [ -n "$U_HOME" ]; then
		export HOME="$U_HOME"
	else
		if [ -n "$SUDO_USER" ]; then
			export HOME="$(getent passwd $SUDO_USER | cut -d ":" -f 6)"
		else
			die "The script was run without sudo. Unable to get the real user's home directory. Run the script with the variable U_HOME=\"home/directory/location\""
		fi
	fi
fi
### Useful Arch Linux Script Vault
DIR="$HOME/.ualsv"
SERVER="https://github.com/BiteDasher/ualsv_db.git" ### Enter the address of your script repository here
_chown="$(stat -c %u:%g $HOME)"
[ "$1" != "--pacman" ] && if [ ! -d "$DIR" ]; then
	mkdir -p "$DIR"
	mkdir -p "$DIR"/local
	cd "$DIR"
	git clone "$SERVER" database
	chown -R $_chown "$DIR"
fi
user="$(whoami)"
isroot() {
	if [[ $(id -u) -ne 0 ]]; then
	die "This action requires superuser rights" $*
	fi
}
abortroot() {
	if [[ $(id -u) -eq 0 ]]; then
	die "It is highly undesirable to run this command from root. $*. Please, use your regular user account (i.e. not sudo/su)"
	fi
}
update_system() {
	sudo pacman -Syu
}
install_pkgs() {
	sudo pacman -S ${packages[@]} --needed || die Failed to install packages
}
install_aurs() {
	yay -S --answerclean y --answeredit n --answerupgrade y --removemake ${aur[@]} || die Failed to install packages from AUR using yay
}
trapcom() {
	error "Process termination signal received"
	case "$__first_arg" in
		install|get*)
			rm -rf "$DIR"/local/"$__second_arg"/getdir
			[ "$restore" == true ] && restore
			[ "$restore_cleanup" == true ] && restore_cleanup
			exit 0
			;;
		list*|search|info)
			rm -f "$DIR"/.temp*
			exit 0
			;;
		restore*)
			:
			;;
	esac
}
trap trapcom SIGTERM SIGKILL SIGINT
# Function for downloading files from array "get" #
get_files() {
	export getdir="$CURDIR/getdir"
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
	[[ -e "$getdir"/"$place" ]] && [[ "$source_get_mtd" == "git" ]] && rm -rf "$getdir"/"$place"
	[[ -e "$getdir"/"$place" ]] && [[ "$source_get_mtd" != "git" ]] && continue
	case "${source_get_mtd}" in
		wget) wget -O "$getdir"/"$place" "$address" -q --show-progress;;
		curl) curl -L -o "$getdir"/"$place" --progress-bar "$address";;
		git) place="${place%.git*}"; git clone "$address" "$getdir"/"$place" 1>/dev/null;;
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
	[ -z "$(find "$DIR"/database -mindepth 1)" ] && return 0
	for script in "$DIR"/database/*; do
		if [[ ! -f "$script"/script && -f "$script"/framework ]]; then
			prefix=framework
		else
			prefix=script
		fi
		local name="$(basename "$script")"
		local version="$(grep -o "^version=.*" "$script"/$prefix | cut -d "=" -f 2- | tr -d \'\")"
		local creator="$(grep -o "^creator=.*" "$script"/$prefix | cut -d "=" -f 2- | tr -d \'\")"
			if [ -f "$DIR/local/$name/installed" ]; then
				local status="[X]"
			else
				local status="[.]"
			fi
		echo "$name" >> "$DIR"/.temp_list_name
		echo "$version" >> "$DIR"/.temp_list_version
		echo "$creator" >> "$DIR"/.temp_list_creator
		echo "$status" >> "$DIR"/.temp_list_status
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
    ' "$DIR"/.temp_list_status "$DIR"/.temp_list_name "$DIR"/.temp_list_version "$DIR"/.temp_list_creator
    rm "$DIR"/.temp_list*
}
list_scripts_local() {
	rm -f "$DIR"/.temp_list*; touch "$DIR"/.temp_list_{name,version,creator,status}
	[ -z "$(find "$DIR"/local -mindepth 1)" ] && return 0
	for script in "$DIR"/local/*; do
		if [[ ! -f "$script"/script && -f "$script"/framework ]]; then
			prefix=framework
		else
			prefix=script
		fi
		local name="$(basename "$script")"
		local version="$(grep -o "^version=.*" "$script"/$prefix | cut -d "=" -f 2- | tr -d \'\")"
		local creator="$(grep -o "^creator=.*" "$script"/$prefix | cut -d "=" -f 2- | tr -d \'\")"
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
    ' "$DIR"/.temp_list_status "$DIR"/.temp_list_name "$DIR"/.temp_list_version "$DIR"/.temp_list_creator
    rm "$DIR"/.temp_list*
}
after_pkg() {
[ "$1" ] && local place="$1" || local place=".."
[ -f "$place"/packages ] || return 0
[ -s "$place"/packages ] || return 0
free_pkgs="$(pacman -Qtq)"
while read -u 3 -r pkg; do
	if [ "$(grep -x "$pkg" <<< "${free_pkgs}")" ]; then
		sudo pacman -Rs $pkg
	else
		process "$pkg skipped"
	fi
done 3< "$place"/packages
}
restore_backup() {
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
		[ "$restored" == 1 ] && return 0 || return 1
	fi
	cd "$DIR"/local/"$ARG"/backup_place
	while read -r restore_file; do
		[[ ! -e ".$restore_file" ]] && continue
		local mode="$(stat -c %a ".$restore_file")"
		local type="$(stat -c %f ".$restore_file")"
		case $type in
			a1*) ln -s "$(readlink ".$restore_file")" "$restore_file" || error "$restore_file" ;;
			81*) install -D -m $mode ".$restore_file" "$restore_file" || error "$restore_file" ;;
			41*) install -d -m $mode "$restore_file" || error "$restore_file" ;;
		esac
	done < ../backup || { chown -R $o_user:$o_group "$DIR"/local/"$ARG"/backup_place; die Something went wrong; }
	success Done
	chown -R $o_user:$o_group "$DIR"/local/"$ARG"/backup_place
}
save_backup() {
	cd "$DIR"/local/"$ARG"/backup_place
	while read -r restore_file; do
		[[ -e "$restore_file" ]] || { smallw "Skipping $restore_file since it doesn't exists"; continue; }
		local type="$(stat -c %f "$restore_file")"
		local mode="$(stat -c %a "$restore_file")"
		case $type in
			41*) install -d -m $mode ".$restore_file" || error "$restore_file" ;;
			# If we come across a symbolic link, we will make a folder for it in advance
			a1*) install -d "$(dirname ".$restore_file")"; ln -s "$(readlink "$restore_file")" ".$restore_file" || error "$restore_file" ;;
			81*) install -D -m $mode "$restore_file" ".$restore_file" || error "$restore_file" ;;
		esac
	done < ../backup || die Something went wrong
	success Backup done
}
apply_patches() {
	cd "$DIR"/local/"$ARG"/files
	_all_count="$(cat patch.conf | wc -l)"
	_count=0
	while read -r patch; do
		((_count++))
		case "${patch}" in
			+*)
			sudopatch=sudo
			patch="${patch#+}" ;;
			*)
			sudopatch= ;;
		esac
		p_name="${patch%%:*}"
		p_dest="$(eval echo "${patch##*:}")"
		process "[$_count/$_all_count] Applying $p_name"
		if [ ! -e "$p_dest" ]; then
			smallw "Skipping $p_name, because the file that is needed for the patch is not found"
			continue
		fi
		$sudopatch patch --quiet -N -p 0 "$p_dest" ./"$p_name" || warning "Something went wrong while patching $p_dest"
	done < ./patch.conf
}
remove_script() {
	rm -rf "$DIR"/local/"$1" || return 1
}
backdir() {
	cd "$CURDIR"
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
	info/show	- Shows detailed information about the specified script
	search		- Searches for possible scripts using name and description
	install/get	- Download script and patch what is needed
	fw/framework	- Execute the script from the patch
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
	abortroot "Many scripts may start working incorrectly"
	[ "$2" ] || die Enter the name of the script you want to apply
	[ -d "$DIR"/database/"$2" ] || die "No script found with name $2"
	out The process of getting and running script "$2" has begun
	if [[ "$1" == "get-again" ]]; then ####
		[ -f "$DIR"/local/"$2"/installed ] && die "Patch already applied :)"
		[ -d "$DIR"/local/"$2" ] || die "The directory does not exist. Install the script using the get parameter instead of get-again"
	else
		if [ -f "$DIR"/local/"$2"/installed ]; then
			warning "The \"$2\" script has already been installed."
			YN=N user_read zero "This script has already been applied. Reinstall without restoring the backup?"
			case "$answer" in
				yes) remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
				no) exit 0 ;;
				*) die Unknown answer ;;
			esac
		fi
		if [ -f "$DIR"/local/"$2"/restored ]; then
			warning "The \"$2\" script has already been installed and restored."
			YN=Y user_read zero "This script has already been restored. Reinstall it again?"
			case "$answer" in
				yes) remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
				no) exit 0 ;;
				*) die Unknown answer ;;
			esac
		fi
		[ -d "$DIR"/local/"$2" ] && rm -rf "$DIR"/local/"$2"
		cp -ax "$DIR"/database/"$2" "$DIR"/local/
	fi ####
	[[ ! -f "$DIR"/local/"$2"/script && ! -f "$DIR"/local/"$2"/backup ]] && { touch "$DIR"/local/"$2"/installed; success "Framework $2 installed!"; exit 0; }
	CURDIR="$DIR/local/$2"
	backdir #
	if [ -f ./backup ] && [ ! -f "$DIR"/local/"$2"/installed ]; then
		rm -rf backup_place
		mkdir backup_place
		ARG="$2" save_backup
		BACKUP=1
	fi
	# If the backup was not made, there was no move to the folder with it.
	backdir #
	source ./script
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
	[ -f ./files/patch.conf ] && { out Appllying patches; ARG="$2" apply_patches; }; backdir #
	[ "$__cleaned_pkgs" ] && echo "$__cleaned_pkgs" > "$DIR"/local/"$2"/packages
	for function in ${functions[@]}; do
		process "Executing $function"
		$function || { error "Something went wrong while $function"
				[ "$restore" == true ] && restore; backdir #
				[ "$restore_cleanup" == true ] && restore_cleanup; backdir #
				[ "$BACKUP" == 1 ] && warning "If you see this message, run command 'sudo $(basename $0) restore $2' after it"
				exit 1
			     }
		backdir #
	done
	[ "$do_cleanup" == true ] && { process "Executing cleanup"; cleanup; }
	success "Step 3 - done"
	touch "$DIR"/local/"$2"/installed
	[ -f "$DIR"/local/"$2"/restored ] && rm "$DIR"/local/"$2"/restored
	success "$2 successfully applied!"
	exit 0
;;
fw|framework)
	[ "$2" ] || die Enter the name of the framework you want to look at
	if [ -f "$DIR"/local/"$2"/framework ]; then
		source "$DIR"/local/"$2"/framework
	else
		if [[ ! -f "$DIR"/database/"$2"/script && ! -f "$DIR"/database/"$2"/backup && -f "$DIR"/database/"$2"/framework ]]; then
			msg "The patch is not installed locally, but there is no script and backup files in the remote repository. I use the framework from the repository(for local installation, install it manually)"
			source "$DIR"/database/"$2"/framework
		else
			[ -d "$DIR"/local/"$2" ] || die "No locally installed script found with name $2"
			[ -f "$DIR"/local/"$2"/framework ] || die "No locally installed framework found in $2"
			source "$DIR"/local/"$2"/framework
		fi
	fi
	shift 2
	if [ -n "$possible_args" ]; then
		while read -r arg_line; do
			fw_arg="\$${arg_line%:*}"
			fw_args="${arg_line##*:}"
			eval case "$fw_arg" in "$fw_args"\) : \;\; \*\) error "\$fw_arg: Unknown argument: $fw_arg"\; [ "$(command -v print_help)" ] \&\& print_help\; exit 1 \;\; esac
		done < <(echo "${possible_args[@]}" | tr ' ' '\n')
	fi
	framework "$@"
;;
info|show)
	[ "$2" ] || die Enter the name of the script you want to look at
	[ -d "$DIR"/database/"$2" ] || die "No script found with name $2"
	if [[ ! -f "$DIR"/database/"$2"/script && -f "$DIR"/database/"$2"/framework ]]; then
		source "$DIR"/database/"$2"/framework
		echo "Framework name:" >> "$DIR"/.temp_list_1; echo "$(basename $2)" >> "$DIR"/.temp_list_2
		echo "Description:" >> "$DIR"/.temp_list_1; echo "$desc" >> "$DIR"/.temp_list_2
		echo "Version:" >> "$DIR"/.temp_list_1; echo "$version" >> "$DIR"/.temp_list_2
		echo "Creator:" >> "$DIR"/.temp_list_1; echo "$creator" >> "$DIR"/.temp_list_2
		awk 'FNR==1{f+=1;w++;}
	     f==1{if(length>w) w=length; next;}
	     f==2{printf("%-"w"s",$0); getline<f2; print;}
	   ' f2="$DIR"/.temp_list_2 "$DIR"/.temp_list_1 "$DIR"/.temp_list_1
		rm -f "$DIR"/.temp_list*
		exit 0
	fi
	source "$DIR"/database/"$2"/script
	functions=('check' 'build' 'action' 'cleanup' 'restore' 'restore_cleanup')
	for function_ in ${functions[@]}; do
		declare -f $function_ &>/dev/null && found_functions+=("$function_")
	done
	[ -f "$DIR"/database/"$2"/files/patch.conf ] && patches="$(cat "$DIR"/database/"$2"/files/patch.conf | cut -d ":" -f 1 | tr "\n" " " | tr -d "+")"
	rm -f "$DIR"/.temp_list*; touch "$DIR"/.temp_list_{1,2}
	echo "Name:" >> "$DIR"/.temp_list_1; echo "$(basename $2)" >> "$DIR"/.temp_list_2
	echo "Description:" >> "$DIR"/.temp_list_1; echo "$desc" >> "$DIR"/.temp_list_2
	echo "Version:" >> "$DIR"/.temp_list_1; echo "$version" >> "$DIR"/.temp_list_2
	echo "Creator:" >> "$DIR"/.temp_list_1; echo "$creator" >> "$DIR"/.temp_list_2
	[ "$packages" ] && { echo "Required official packages:" >> "$DIR"/.temp_list_1; echo "${packages[@]}" >> "$DIR"/.temp_list_2 ; }
	[ "$aur" ] && { echo "Required AUR packages:" >> "$DIR"/.temp_list_1; echo "${aur[@]}" >> "$DIR"/.temp_list_2 ; }
	[ "$get" ] && { echo "Links of files to be downloaded during the process:" >> "$DIR"/.temp_list_1; echo "$(for gets in ${get[@]}; do echo "$gets" | cut -d ":" -f 3-; done)" | tr "\n" ";" >> $DIR/.temp_list_2 ; }
	echo "Found functions:" >> "$DIR"/.temp_list_1; echo "${found_functions[@]}" >> "$DIR"/.temp_list_2
	[ -f "$DIR"/database/"$2"/framework ] && framework=yes || framework=no
	echo "Framework:" >> "$DIR"/.temp_list_1; echo "$framework" >> "$DIR"/.temp_list_2
	[ "$patches" ] && { echo "Found patches:" >> "$DIR"/.temp_list_1; echo "${patches}" >> "$DIR"/.temp_list_2 ; }
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
		if [[ ! -f "$search"/script && -f "$search"/framework ]]; then
			eval $(source "$search"/framework; echo "desc=\"$desc\""; echo "version=\"$version\"")
			total+=("~( \e[0;33m$name\e[0m ) $version% $desc")
			continue
		fi
		eval $(source "$search"/script; echo "desc=\"$desc\""; echo "version=\"$version\"")
		total+=("~[ \e[0;32m$name\e[0m ] $version% $desc")
	done
	echo -e ${total[@]} | tr "~" "\n" | grep -i "${@:2}" | sed "s/%/\n  /1"
;;
remove)
	[ "$2" ] || die Enter the name of the script you want to remove
	[ -d "$DIR"/local/"$2" ] || die "No script found with name $2"
		if [ -d "$DIR"/local/"$2"/backup ] && [ -f "$DIR"/local/"$2"/installed ]; then
		YN=N user_read zero "A directory with a backup copy was found for script "$2". Continue?"
		case "$answer" in
			yes) remove_script "$2" || error "Something went wrong while deleting the script folder from the local database" ;;
			no) exit 0 ;;
			*) die Unknown answer ;;
		esac
		else
			remove_script "$2"
		fi
	success "Script removed"
;;
restore)
	isroot "(restore backup files)"
	[ "$2" ] || die Enter the name of the script you want to remove
	[ -d "$DIR"/local/"$2" ] || die "No script found with name $2"
	#[ -f "$DIR"/local/"$2"/installed ] || die "This patch is not applied"
	if [ -f "$DIR"/local/"$2"/restored ]; then
	YN=N user_read q_restore "This script has already been restored. You can remove it using '$(basename $0) remove $2'. Restore it again?"
	case "$answer" in
		yes) rm "$DIR"/local/"$2"/restored ;;
		no) exit 0 ;;
	*) die Unknown answer ;;
	esac
	fi
	if [ ! -f "$DIR"/local/"$2"/script ]; then
		smallw "This patch does not have a script file. Most likely, it's just a framework"
		exit 0
	fi
	CURDIR="$DIR/local/$2"
	source "$DIR"/local/"$2"/script
	if declare -f restore &>/dev/null; then
		restore && restored=1 || error "Failed to restore"; backdir #
		declare -f restore_cleanup &>/dev/null && restore_cleanup; backdir #
	fi
	out "Removing unnecessary packages"
	after_pkg "$DIR/local/$2"
	[ -d "$DIR"/local/"$2"/backup_place ] || { [ "$restored" == 1 ] || die "No backup folder found with name $2"; }
	ARG="$2" restore_backup || die "Failed to restore backup"
	rm -f "$DIR"/local/"$2"/installed
	touch "$DIR"/local/"$2"/restored
	success "Done!"
;;
update)
	abortroot "Incorrect directory permissions may be overwritten during the update"
	update_scripts
;;
clean)
	for pkg in "$DIR"/local/*; do
		cd "$pkg"
		for file in ./*; do
			case "$file" in
				./restored|./script|./backup|./backup_place|./installed|./packages|./files|./framework) : ;;
				*) rm -rf "$file" ;;
			esac
		done
	done
;;
force-update)
	abortroot "Incorrect directory permissions may be written during the update"
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
--pacman)
	case "$2" in
		init)
		if [ ! -d "$DIR" ]; then
		mkdir -p "$DIR"
		mkdir -p "$DIR"/local
		cd "$DIR"
		git clone "$SERVER" database
		chown -R $_chown "$DIR"
		fi
		;;
		hook)
		update_scripts
		;;
	esac
;;
*)
	die "Unknown argument. Use $(basename $0) help for more."
;;
esac
