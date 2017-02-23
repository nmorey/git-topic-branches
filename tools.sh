#!/bin/bash

GITTOOLS_MATCHES=$(git config --get-regexp   devel-base | egrep '^devel-base\.' | sed -e 's/devel-base\.//')
gittools_match_branch()
{
	local branch=$1
	set -- $GITTOOLS_MATCHES
	while [ $# -ne 0 ]; do
		local regexp=$1
		local basename=$2
		if [[ "$branch" =~ "${regexp}/" ]]; then
			echo $basename
			return
		fi
		shift 2;
	done
	return 1
}

gittools_really_match_branch()
{
	gittools_match_branch $1 || \
		(echo -n "origin/"; echo $1 | sed -e 's/^aci\/[a-zA-Z0-9_-]*\///' -e 's/^user\/[a-zA-Z0-9_-]*\///')
}

gittools_curbranch()
{
	git rev-parse --abbrev-ref HEAD
}

gittools_prefix_opt()
{
	local branch=$(gittools_curbranch)
	pattern=$(echo ${branch} | sed -e "s/\(.*\/$(whoami)\/\)\?\([^\/]*\)\/.*/\2/")
	TITLE=$(git config --get patch.prefix.${pattern})
	if [ $? -eq 0 ]; then
			echo "--subject-prefix=${TITLE}"
	else
		echo "--subject-prefix=[PATCH]"
	fi
	return
}

gittools_match_curbranch()
{
	gittools_match_branch $(gittools_curbranch)
}

gittools_really_match_curbranch()
{
	gittools_really_match_branch $(gittools_curbranch)
}

gittools_get_patch_target_option()
{
	local target=$(git config --get patch.target)
	if [ "$target" != "" ]; then
		echo "--to $target"
	else
		echo "WARNING: No target --to specified in patch.target" >&2
	fi
}

gittools_gen_timestamp()
{
	date '+%Y/%m/%d/%H%M%S'
}

gittools_is_branch_checked_out()
{
	local bname=$1
	local top=$(readlink -f $(git rev-parse --show-toplevel))
	git worktree list  | awk '{ print $1 " " $NF}' | grep '\[' | sed -e 's/\[//' -e 's/]//' |\
		while read repo branch; do
			if [ "$(readlink -f $repo)" == "$top" ]; then
				continue
			fi;
			if [ "$branch" == "$bname" ]; then
				echo $repo
				return 0
			fi;
		done
	return 1
}
