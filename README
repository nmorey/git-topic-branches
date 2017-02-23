git-topic-branches is a set of scripts to ease working with multiple branches to be contributed upstream

It allows developer to create topic branches targeting an upstream branch, keep them up to date,
 check and validate them, and then submitting them to mailing lists.

# Configuration

A little configuration is needed first. Everything is done using git config

* Setup the target mailing list
```
git config patch.target ml@domain.com
```

* Setup namespaces to target upstream branches
```
git config devel-base.dev origin/master
git config devel-base.dev-next official/dev-next
```
This will allow the scripts to know which branch to rebase against.
All branches named dev/<topic> will be rebased against origin/master, and dev-next/<topic>
 against official/dev-next
Note that it also supports branches prefixed by user/$(whoami) or aci/$(whoami) for user working
 in a multi user repo

* Custom commands for checks and validation

git-topic-branches allows to run check or validation on a patch series to make sure the content
 is valid for upstreaming.
Usually checks are simply to verifiy patch formatting, while validation is run for each commit
 in the topic branch to make sure they work individually.

Checking a series will run foreach commit in the topic branch:
```
 git cmd-check <sha1>
```

Validating a series will run one
```
git cmd-prep
```
And then for each commit
```
git cmd-clean
git cmd-build
git cmd-check <sha1>
```

Those can be configured with git config by creating the associated aliases.
For example
```
git config alias.cmd-check '!f() { git format-patch $1~1..$1 --stdout | checkpatch.pl - ;}; f'
git config alias.cmd-clean 'make dist-clean || true'
git config alias.cmd-prep  './configure'
git config alias.cmd-buid  'make all && make valid'
```

* Sending emails

By default, git imap-send is used to send the pre formatted patch to your imap account for a final review before sending the paches.
This is an example configuration
```
git config imap.folder Drafts
git config imap.host imaps://mymail.server.com
git config imap.user nmorey
```
This way patches end up in the Drafts folder of my mail account and can be reviewed (or edited) before sending.

# Using it

Let's build a quick scenario where I want to propose a set of patch from an upstream master.
We assume the devel-base for this branch is dev.

Here's how it works
```
$ git checkout -B dev/my-patches origin/master
```
Here you get some work done
```
$ git commit -m "First patch"
```
Let's check the patch format
```
$ /path/to/topic-branches/branch-check
Checking patch from official/master to dev/my-patches
========== Checking commit dba26707966bec8eda04d6b6022b8bff322915ad First patch ================
ERROR: trailing whitespace
#17: FILE: main.c:1:
+int *toto; $

ERROR: Missing Signed-off-by: line(s)

total: 2 errors, 0 warnings, 0 checks, 1 lines checked

NOTE: whitespace errors detected, you may wish to use scripts/cleanpatch or
      scripts/cleanfile

NOTE: Ignored message types: BIT_MACRO COMPARISON_TO_NULL DEPRECATED_VARIABLE NEW_TYPEDEFS SPLIT_STRING SSCANF_TO_KSTRTO

Your patch has style problems, please review.

If any of these errors are false positives, please report
them to the maintainer, see CHECKPATCH in MAINTAINERS.
========== FAILED ================
```
Fix the glitch
```
$ git commit --amend
$ /path/to/topic-branches/branch-check
Checking patch from official/master to dev/my-patches
========== Checking commit 80a3051156df9b0a90a00bf3e26bb9901f0d5273 First patch ================
========== SUCCESS ================
```
A tag is added to avoid re running the check on the same SHA1
```
$ /path/to/topic-branches/branch-check
Series already checked (checked/2017/02/23/102031/dev/my-patches)
```
Do some more patches and commit/check every one
Now time to validate the series
```
$ /path/to/topic-branches/branch-validate
Validating patch from official/master to dev/my-patches
[....]
80a3051156df9b0a90a00bf3e26bb9901f0d5273 First patch
[....]
========== SUCCESS ================
Switched to branch 'dev/my-patches'
$ /path/to/topic-branches/branch-validate
Series already checked (validated/2017/02/23/102614/dev/my-patches)
```

Now let's make sure we are rabsed on the latest upstream branch.
Be careful, this command will rebase ALL your branches
```
$ /path/to/topic-branches/branches-autorebase
REBASING: dev/my-patches on official/master
INTEGRATED UPSTREAM: dev/previous-patch made it into official/master
REBASING FAILURE: dev/topic2 on official/master
```

After that:
* dev/my-patches was successfully rebased on official/master
* dev/previous-patches was rebased on official/master but all of its commits were contained in master already.
  This means this branch was integrated and can be deleted
* dev/topic2 could not be rebased. Conflicts needs to be fixed manually before pushing upstream.

Now we are ready to post our diffs to the mailing list.
```
$ /path/to/topic-branches/branch-submit
Resolving mymail.server.com... ok
Connecting to [127.0.0.1]:993... ok
Logging in...

(gnome-ssh-askpass:6774): Gtk-WARNING **: cannot open display: 
error: unable to read askpass response from '/usr/libexec/openssh/gnome-ssh-askpass'
Password for 'imaps://nmorey@mymail.server.com': 
sending 1 message
 100% (1/1) done

```

