function under_bash () {
	[[ "`ps -p $$ | tail -1|awk '{print $NF}'`" == "-bash" ]] 2>&1 && return
	return 1
}

function under_zsh () {
	[[ "`ps -p $$ | tail -1|awk '{print $NF}'`" == "-zsh" ]] 2>&1 && return
	return 1
}

msrp_color_red=$'\e[31m'
msrp_color_yellow=$'\e[33m'
msrp_color_green=$'\e[32m'
msrp_color_cyan=$'\e[36m'
msrp_color_blue=$'\e[34m'
msrp_color_magenta=$'\e[35m'
msrp_color_white=$'\e[37m'
msrp_color_bold_red=$'\e[31;1m'
msrp_color_bold_yellow=$'\e[33;1m'
msrp_color_bold_green=$'\e[36;1m'
msrp_color_bold_cyan=$'\e[32;1m'
msrp_color_bold_blue=$'\e[34;1m'
msrp_color_bold_magenta=$'\e[35;1m'
msrp_color_bold_white=$'\e[37;1m'
msrp_reset_color=$'\e[37m'

# edit colours and characters here
#############################################
if under_bash; then
	# msrp_user_color=$msrp_color_green - change the user to green
	msrp_user_color=$msrp_color_cyan
	msrp_host_color=$msrp_color_yellow
	msrp_root_color=$msrp_color_green
	msrp_repo_color=$msrp_color_red
	msrp_branch_color=$msrp_color_white
	msrp_dirty_color=$msrp_color_red
	msrp_preposition_color=$msrp_color_white
	msrp_promptchar_color=$msrp_color_magenta
elif under_zsh; then
	msrp_user_color=$msrp_color_magenta
	msrp_host_color=$msrp_color_yellow
	msrp_root_color=$msrp_color_green
	msrp_repo_color=$msrp_color_red
	msrp_branch_color=$msrp_color_white
	msrp_dirty_color=$msrp_color_red
	msrp_preposition_color=$msrp_color_white
	msrp_promptchar_color=$msrp_color_cyan
fi
msrp_promptchar_bash='$'
msrp_promptchar_zsh='%%' # the % character is special in zsh - escape with a preceding %
msrp_promptchar_git='±'
msrp_promptchar_hg='☿'
#############################################

function in_git_repo {
	git branch > /dev/null 2>&1 && return
	return 1
}

function in_mercurial_repo {
	hg root > /dev/null 2>&1 && return
	return 1
}

function in_repo {
	(in_git_repo || in_mercurial_repo) && return
	return 1
}

function prompt_char {
	in_git_repo && echo -ne $msrp_promptchar_git && return
	in_mercurial_repo && echo -ne $msrp_promptchar_hg && return
	if under_bash; then
		echo $msrp_promptchar_bash
	elif under_zsh; then
		echo $msrp_promptchar_zsh
	fi
}

function location_title {
	if in_repo; then
		local root=$(get_repo_root)
		local uroot="$(get_unversioned_repo_root)/"
		echo "${root/$uroot/} ($(get_repo_type))"
	else
		echo "${PWD/$HOME/~}"
	fi
}

function get_repo_type {
	in_git_repo && echo -ne "git" && return
	in_mercurial_repo && echo -ne "hg" && return
	return 1
}

function get_repo_branch {
	in_git_repo && echo $(git branch | grep '*' | cut -d ' ' -f 2) && return
	in_mercurial_repo && echo $(hg sum | grep 'branch:' | awk '{print $2}') && return
	return 1
}

function get_main_branch_name () {
	in_git_repo && echo "master" && return
	in_mercurial_repo && echo "default" && return
	return 1
}

function get_repo_status {
	in_git_repo && git status --porcelain && return
	in_mercurial_repo && hg status -S && return
	return 1
}

function get_repo_root {
	in_git_repo && echo $(git rev-parse --show-toplevel) && return
	in_mercurial_repo && echo $(hg root) && return
	return 1
}

function get_unversioned_repo_root {
	local lpath="$1"
	local cPWD=`echo $PWD`
	
	# see if $lpath is non-existent or empty, and if so, assign
	if test ! -s "$lpath"; then
		local lpath=`echo $PWD`
	fi
	
	cd "$lpath" &> /dev/null
	local repo_root="$(get_repo_root)"

	# see if $repo_root is non-existent or empty, and if so, assign
	if test ! -s "$repo_root"; then
	    echo $lpath
	else
		local parent="${lpath%/*}"
		get_unversioned_repo_root "$parent"
	fi

    cd "$cPWD" &> /dev/null
}

# display current path
function ps_status {
	in_repo && repo_status && return
	echo -e "$msrp_root_color${PWD/#$HOME/~} $msrp_reset_color"
}

function repo_status {
	# set locations
	local here="$PWD"
	local user_root="$HOME"
	local repo_root="$(get_repo_root)"
	local root="`get_unversioned_repo_root`/"
	local lpath="${here/$root/}"
	if [[ "`echo $root`" =~ ^$user_root ]]; then
		root=`echo "$root" | sed "s:^$user_root:~:g"`
	fi

	# get branch information - empty if no (or default) branch
	local branch=$(get_repo_branch)

	# underline branch name
	if [[ $branch != '' ]]; then
		if under_zsh; then
			local branch=" on %{\033[4m%}${branch}%{\033[0m%}"
		elif under_bash; then
			local branch=" on \033[4m${branch}\033[0m"
		fi
	fi

	# status of current repo
	if in_git_repo; then
		local lstatus="`get_repo_status | sed 's/^ */g/'`"
	elif in_mercurial_repo; then
		local lstatus="`get_repo_status | sed 's/^ */m/'`"
	else
		local lstatus=''
	fi

	local status_count=`echo "$lstatus" | wc -l | awk '{print $1}'`
	
	# if there's anything to report on...
	if [[ "$status_count" -gt 0 ]]; then

		local changes=""

		# modified file count
		local modified="$(echo "$lstatus" | grep -c '^[gm]M')"
		if [[ "$modified" -gt 0 ]]; then
			changes="$modified changed"
		fi
		
		# added file count
		local added="$(echo "$lstatus" | grep -c '^[gm]A')"
		if [[ "$added" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${added} added"
		fi
		
		# removed file count
		local removed="$(echo "$lstatus" | grep -c '^(mR|gD)')"
		if [[ "$removed" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${removed} removed"
		fi
		
		# renamed file count
		local renamed="$(echo "$lstatus" | grep -c '^gR')"
		if [[ "$renamed" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${removed} renamed"
		fi
		
		# missing file count
		local missing="$(echo "$lstatus" | grep -c '^m!')"
		if [[ "$missing" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${missing} missing"
		fi
		
		# untracked file count
		local untracked="$(echo "$lstatus" | grep -c '^[gm]?')"
		if [[ "$untracked" -gt 0 ]]; then
			if [[ "$changes" != "" ]]; then
				changes="${changes}, "
			fi
			changes="${changes}${untracked} untracked"
		fi
		
		if [[ "$changes" != "" ]]; then
			changes=" (${changes})"
		fi
	fi

	echo -e "$msrp_root_color$root$msrp_repo_color$lpath$msrp_branch_color$branch$msrp_dirty_color$update$changes"
}

function construct_prompt () {
	echo -e "$msrp_user_color$USER ${msrp_preposition_color}at $msrp_host_color`hostname -s` ${msrp_preposition_color}in $(ps_status)$msrp_promptchar_color\n$(prompt_char)"
}

if under_bash; then
	export PS1='$(construct_prompt)\[$msrp_reset_color\] '
elif under_zsh; then
	PROMPT='$(construct_prompt)%{$msrp_reset_color%} '
fi