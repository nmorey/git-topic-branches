#!/bin/bash

GITTOOLS_MATCHES=$(git config --get-regexp   devel-base | egrep '^devel-base\.' | sed -e 's/devel-base\.//' -e 's/---/\//g')
GITTOOLS_STABLE_MATCHES=$(git config --get-regexp   stable-base | egrep '^stable-base\.' | sed -e 's/stable-base\.//' -e 's/---/\//g')
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

gittools_match_stable()
{
	local branch=$1
	set -- $GITTOOLS_STABLE_MATCHES
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
		echo "--subject-prefix=PATCH"
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
gittools_match_curstable()
{
	gittools_match_stable $(gittools_curbranch)
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

gittools_check_work()
{
	set +e
	git rev-parse -q --verify $1 > /dev/null
	if [ $? -ne 0 ]; then
		echo "Ref $1 does not exists" >&2
		exit 1
	fi
	git rev-parse  -q --verify $2 > /dev/null
	if [ $? -ne 0 ]; then
		echo "Ref $2 does not exists" >&2
		exit 1
	fi
	set -e
	if [ $(git rev-parse $1) == $(git rev-parse $2) ]; then
		echo "No commit on this branch. Nothing to do..."
		exit 0
	fi
}

gittools_check_config_set()
{
	local config=$1
	git config $1 > /dev/null
	if [ $? -ne 0 ]; then
		echo "ERROR: $1 needs to be set int .git/config" >&2
		exit 1
	fi
}

gittools_commit_in_tree()
{
	fullhash=$(git rev-parse $1)
	# This might happen if someone pointed to a commit that doesn't exist in our
	# tree.
	if [ "$?" -gt "0" ]; then
		return 1
	fi

	# Hope for the best, same commit is/isn't in the current branch
	if [ "$(git merge-base $fullhash HEAD)" = "$fullhash" ]; then
		return 0
	fi

	# Grab the subject, since commit sha1 is different between branches we
	# have to look it up based on subject.
	subj=$(git log -1 --pretty="%s" $1)
	if [ $? -gt 0 ]; then
		return 1
	fi

	# Try and find if there's a commit with given subject the hard way
	STABLE_BASE=${2:-$(gittools_match_curstable)}
	if [ "$STABLE_BASE" == "" ]; then
		echo "ERROR: Could not find a stable base"
		exit 1
	fi
	for i in $(git log --pretty="%H" -F --grep "$subj" $STABLE_BASE..HEAD); do
		cursubj=$(git log -1 --format="%s" $i)
		if [ "$cursubj" = "$subj" ]; then
			return 0
		fi
	done
	return 1
}

gittools_show_missing_iter()
{
	STABLE_BASE=$(gittools_match_curstable)
	for i in $(git log --no-merges --format="%H" $1 | tac); do
		gittools_commit_in_tree $i $STABLE_BASE
		if [ "$?" = "1" ]; then
			$2 $i
		fi
	done
}

gittools_deps()
{
	local maxdeps=$2

	((maxdeps--))
	if [ $maxdeps -eq 0 ]; then
		exit 1
	fi

	stable commit-in-tree $1
	if [ $? -eq 1 ]; then
		return
	fi

	echo $1
	for i in $(stable-deps.py $1); do
		gittools_deps $i $maxdeps
	done
}

gittools_make_pretty()
{
	cmt=$(git rev-parse $1)

	if [ "$2" != "" ]; then
		msg=$2
	else
		msg=$cmt
	fi

	msg=$(git log -1 --format="%s%n%n[ Upstream commit $msg ]%n%n%b" $cmt)
	git commit -s --amend -m "$msg"
}

gittools_blacklisted()
{
	local cmt=$1
	local branch=$(gittools_curbranch)

	BLACKLIST=$
	for br in $(git notes show $cmt 2> /dev/null); do
		if [ "$br" == "$branch" ]; then
			return 0
		fi
	done

	return 1
}

gittools_add_blacklist()
{
	local cmt=$1
	local branch=$(gittools_curbranch)

	git notes append -m "$branch" $1
}

gittools_check_relevant()
{
	local cmt=$1

	# Let's grab the commit that this commit fixes (if exists (based on the "Fixes:" tag)).
	fixescmt=`git log -1 $cmt | grep -i "fixes:" | head -n 1 | sed -e 's/^[ \t]*//' | cut -f 2 -d ':' | sed -e 's/^[ \t]*//' | cut -f 1 -d ' '`

	# If this commit fixes anything, but the broken commit isn't in our branch we don't
	# need this commit either.
	if [ "$fixescmt" != "" ]; then
		gittools_commit_in_tree $fixescmt
		if [ $? -eq 0 ]; then
			return 0
		else
			return 1
		fi
	fi

	if [ "$(git show $1 | grep -i 'stable@' | wc -l)" -eq 0 ]; then
		return 1
	fi

	# Let's see if there's a version tag in this commit
	full=$(git show $cmt | grep -i 'stable@')
	full=$(echo ${full##* })

	# Sanity check our extraction
	if [ "$(echo ${full##* } | grep 'stable' | wc -l)" -gt "0" ]; then
		return 1
	fi

	# Make sure our branch contains this version
	fullhash=$(git rev-parse HEAD)
	if [ "$(git merge-base $fullhash $full)" = "$full" ]; then
		return 0
	fi

	# Tag is not in history, ignore
	return 1
}
