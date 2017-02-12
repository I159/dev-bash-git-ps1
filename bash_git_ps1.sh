#!/bin/bash

#-----------------------------------------------------------------------------------------------
# Developer's Bash-GIT PS1 Integration
#-----------------------------------------------------------------------------------------------
#
# Description:
#   Provides simple information about git repository for the bash terminal
#
#   Customed by:
#     Pekelny "I159" Ilya
#
#   Originally authored by:
#     Erik Johnson (xtrementl)
#
# Installation:
#   Add the following line to your .bashrc:
#       . ~/.bash_git_ps1.sh
#
# Flags. To use the options set an environment variables listed below
# PS_FULPATH - show full path to the current dir in PS1
# GIT_BRANCH_FULL - show full branch name with slashes (OpenStack Gerrit specific)
#-----------------------------------------------------------------------------------------------


# colors
case "$TERM" in
    xterm*|rxvt*|screen*)
        ESC="\033"
        RED="\[$ESC[01;31m\]"
        LIGHT_RED="\[$ESC[1;31m\]"
        GREEN="\[$ESC[01;32m\]"
        LIGHT_GREEN="\[$ESC[1;32m\]"
        GREY="\[$ESC[0;37m\]"
        CYAN="\[$ESC[01;36m\]"
        YELLOW="\[$ESC[0;33m\]"
        LIGHT_VIOLET="\[$ESC[1;35m\]"
        RESET="\[$ESC[0m\]"
    ;;
    *)
        ESC=""
        RED=""
        LIGHT_RED=""
        GREEN=""
        LIGHT_GREEN=""
        GREY=""
        CYAN=""
        YELLOW=""
        LIGHT_VIOLET=""
        RESET=""
    ;;
esac

# prints path to git directory
__git_dirname() {
    local dirname
    if [ -d .git ]; then
        dirname=".git"
    else
        dirname="$(git rev-parse --git-dir 2>/dev/null)"
    fi
    echo "$dirname"
}

# gets the branching state of the repository
# optional arg: path to git directory
__git_branching_state() {
    local gitdir="$1" || "$(__git_dirname)"
    local state

    if [ -f "$gitdir/rebase-merge/interactive" ]; then
        state="rebase-i"
    elif [ -d "$gitdir/rebase-merge" ]; then
        state="rebase-m"
    else
        if [ -d "$gitdir/rebase-apply" ]; then
            if [ -f "$gitdir/rebase-apply/rebasing" ]; then
                state="rebase"
            elif [ -f "$gitdir/rebase-apply/applying" ]; then
                state="am"
            else
                state="am/r"
            fi
        elif [ -f "$gitdir/MERGE_HEAD" ]; then
            state="merge" # merging
        elif [ -f "$gitdir/BISECT_LOG" ]; then
            state="bisect" # bisecting
        fi
    fi
    echo "$state"
}

# prints the working directory state of the repository using symbols
# these could be expensive.. would make sense to have configs to turn off
# * - modified / + - staged / ^ - stashed / % - untracked
__git_working_dir_symbols() {
    local symbols

    # in working dir
    if [ true = "$(git rev-parse --is-inside-work-tree 2>/dev/null)" ]; then
        git diff --no-ext-diff --quiet --exit-code || symbols=" ✪"
        if git rev-parse --quiet --verify HEAD >/dev/null; then
            git diff-index --cached --quiet HEAD -- || symbols="${symbols} ✎"
        fi
    fi

    # stashed
    git rev-parse --verify refs/stash >/dev/null 2>&1 && symbols="${symbols} ✂"

    # untracked files
    if [ -n "$(git ls-files --others --exclude-standard)" ]; then
        symbols="${symbols} ⚒"
    fi
    if [ -d "$(__git_dirname)/rebase-merge" ]; then
        symbols="${symbols} ☠"
    fi
    echo "$symbols"
}

# prints current / parent branch name
# optional arg: 'parent' -- returns a limited guess of the parent
# optional arg: path to git directory
__git_branch_name() {
    # current branch name
    local branch
    local gitdir="$2" || "$(__git_dirname)"
    branch="$(git symbolic-ref HEAD 2>/dev/null)" || {
        branch="$(git describe --contains --all HEAD 2>/dev/null)" ||
            branch="$(cut -c1-7 "$gitdir/HEAD" 2>/dev/null)..." ||
                branch="unknown"

        branch="${branch##remotes/}"
        branch="($branch)"
    }
    branch="${branch##refs/heads/}"

    # parent branch name
    if [ parent = "$1" ]; then
        if [ master = "$branch" ]; then
            local refs="$(git for-each-ref --format="%(refname:short)")"
            case "$refs" in
                *git-svn*) # git-svn repo
                    branch='git-svn' ;;
                *origin*) # remote clone
                    branch='origin' ;;
                *)
                    branch='HEAD' ;; # same repo
            esac
        else
            # TODO.. would be nice to improve this to determine the actual
            # merge base (git merge-base) and compare against that instead of
            # always assuming master. In this way a 'topic/feature' branch
            # would show the diff counts for its parent 'next/develop' branch
            # rather than those plus those on the 'next/develop' branch.
            # I don't think we want to loop over the refs comparing ... that's
            # fuzzy.
            branch='master' # on a branch
        fi
    fi
    echo "$branch"
}

__git_disp_branch_name() {
    local branch="$(__git_branch_name)"
    if [ -n "$GIT_BRANCH_FULL" ]
    then
        echo "$branch"
    else
        IFS='/' read -ra ADDR <<< "$branch"
        echo "${ADDR}"
    fi
}


# prints number of commits that are available on ref B but not ref A
# arg1: reference A
# arg2: reference B
__git_commit_diff_count() {
    echo "$(git rev-list $1..$2 2>/dev/null | awk 'END {print NR}')"
}

# build combined (+/-) counts for related commits
__git_count_str() {
    local str
    local parent="$(__git_branch_name parent)"
    local ahead_count="$(__git_commit_diff_count $parent HEAD)"
    local behind_count="$(__git_commit_diff_count HEAD $parent)"

    if [ 0 -lt "$ahead_count" ]; then
        str="${GREEN}+${ahead_count}${RESET}"
    fi

    if [ 0 -lt "$behind_count" ]; then
        [ -n "$str" ] && str="$str/"
        str="${str}${RED}-${behind_count}${RESET}"
    fi

    [ -n "$str" ] && str="($str)"
    echo "$str"
}

__python_env_name() {
    local env="$VIRTUAL_ENV"
    local name="$(basename \ ${env})"
    if [ -n "$VIRTUAL_ENV" ]
    then
        echo "${YELLOW}{${name}}"
    fi
}

# install git integration into PS1
__git_prompt() {
    local last_exit="$?" # keep here.. so we get the last command

    # setup PS1
    local user="${GREY}\u:${RESET}"
    if [ -n "$PS_FULLPATH" ]
    then
        local dir="${CYAN}\$PWD${RESET}"
    else
        local dir="${CYAN}\W${RESET}"
    fi
    PS1="$user$dir"

    # when in git repository
    local gitdir="$(__git_dirname)"
    if [ -n "$gitdir" ]; then
        local branch
        local extras

        branch="~$(echo $in_gitdir | tr "[:lower:]" "[:upper:]")~"
        local branch="$(__git_disp_branch_name current ${gitdir})"
        # extras (count strings, working dir symbols)
        local countstr="$(__git_count_str)"
        local wd_syms="${LIGHT_VIOLET}$(__git_working_dir_symbols)"
        extras="${countstr}${wd_syms}"
        branch="[${YELLOW}${branch}${RESET}]"

        # update PS1
        PS1="${PS1}${branch}${extras}"
    fi
    # Determine env name
    local env_name="$(__python_env_name)"
    # setup marker that acts off of last exit code
    local marker
    if [ 0 -eq "$last_exit" ]; then
        marker="$GREY"
    else
        marker="$RED"
    fi
    marker="${marker} »${RESET}"
    PS1="${env_name}${PS1}${marker} "
}
PROMPT_COMMAND=__git_prompt
