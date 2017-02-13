branch_name()
{
	branch=$(git branch 2>/dev/null| grep '^*'| colrm 1 2)
	if [ -n $branch ]
	then
		echo "{$branch}"
	fi
}

get_pwd()
{
	PWD=$(pwd)
	echo "${PWD/$HOME/HOME}"
}

get_state()
{
	RAW_STATUS=$(git status 2> /dev/null)
	STATE=""
	if [ $( grep "CONFLICT" <<< $RAW_STATUS| wc -l) -ne 0 ]
	then
		STATE=$STATE'%'
	fi

	if [  $( grep "working directory clean" <<< $RAW_STATUS| wc -l) -ne 1 ]
	then
		STATE=$STATE'#'
	fi

	if [  $( grep "rebase in progress" <<< $RAW_STATUS| wc -l) -ne 0 ]
	then
		STATE=$STATE'^'
	fi
	echo $STATE
}

export PS1='\[\033[0;33m\]$(whoami):\[\033[0;92m\]$(get_pwd)\[\033[0;96m\]$(branch_name)\[\033[0;91m\]$(get_state)\[\033[0;93m\]$ \[\033[0m\]'
