#!/bin/bash
# set colors
normal_color="`echo -e '\r\033[0;0m'`" # normal
highlight_color="`echo -e '\r\033[1;7m'`" # reverse

# keys
up_arrow="`echo -e '\033[A'`" # arrow up
down_arrow="`echo -e '\033[B'`" # arrow down
esc="`echo -e '\033'`"   # escape
enter="`echo -e '\n'`"   # newline

function git-recent-branch-switcher {
    num_results=20
    if [ "$1" ]; then
        num_results=$1
    fi

    result=$(git for-each-ref --color --count="$num_results" --sort=-authordate:iso8601 refs/heads/ --format='%(color:yellow)%(HEAD) %(refname:short)')

    branch=$(menu "$result")
    branch=$(extract_branch "$branch")
    current_branch=$(git rev-parse --abbrev-ref HEAD)
    if [[ $current_branch != $branch ]]; then
        git checkout $branch
    fi
}

function extract_branch {
    echo "$1" | egrep -o " [a-zA-Z0-9-]+" | cut -c 2-
}

# thanks for https://bbs.archlinux.org/viewtopic.php?id=105732 for providing a baseline
function menu {
    IFS=$'\n' read -ra options -d '' <<< "$1"

    num_options="${#options[@]}" # total number of items

    { # capture stdout to stderr

    tput civis # hide cursor
    stty -echo

    function ctrl_c() {
        tput cnorm
        tput cuu 1
        echo -n "$normal_color" # normal colors
        exit
    }

    trap ctrl_c INT

    current_pos=0 # current position

    function go_up() {
      current_pos=$(( current_pos - 1 ))
      if [[ $current_pos == -1 ]]; then
          current_pos=$(( $num_options - 1))
      fi
    }

    function go_down() {
        current_pos=$(( current_pos + 1 ))
        if [[ $current_pos == $(( num_options )) ]]; then
               current_pos=0
          fi
    }

    # figure out starting index
    i=0
    for i in "${!options[@]}"; do
        if [[ ${options[i]} == *'*'* ]]; then
            current_pos=$i
        fi
    done

    end=false

    while ! $end
    do

        for i in `seq 0 $(($num_options - 1))`
        do

            echo -n "$normal_color"
            if [[ $current_pos == $i ]]; then
                echo -n "$highlight_color"
            fi
            lineno=$(($i + 1))
            printf "%-2s ${options[i]}\n" $lineno
        done

        read -sn 1 key
        if [[ "$key" == "$esc" ]]; then
           read -sn 2 k2
           key="$key$k2"
        fi

        case "$key" in
           "$up_arrow"|k)
                go_up
                ;;

           "$down_arrow"|j)
                go_down
                ;;

           "$enter")
                end=true;;
       esac

       tput cuu $num_options

    done

    stty echo
    tput cud $(( num_options ))
    tput cnorm # unhide cursor
    echo -n "$normal_color" # normal colors

    } >&2 # end capture

    echo "${options[current_pos]}"
}

git-recent-branch-switcher $@
