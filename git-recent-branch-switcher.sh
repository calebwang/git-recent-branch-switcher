#!/bin/bash
# set colors
normal_color="`echo -e '\r\033[0;0m'`" # normal
highlight_color="`echo -e '\r\033[1;7m'`" # reverse

# keys
mac_backspace=$'\x7f'
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
    echo "$1" | egrep -o " [a-zA-Z0-9/-]+" | cut -c 2-
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

    # figure out starting index
    initial_position=0
    i=0
    for i in "${!options[@]}"; do
        if [[ ${options[i]} == *'*'* ]]; then
            initial_position=$i
        fi
    done

    # instantiate input state and starting position
    number_input=""
    current_pos=$initial_position

    function print_menu {
        for i in `seq 0 $(($num_options - 1))`
        do

            echo -n "$normal_color"
            if [[ $current_pos == $i ]]; then
                echo -n "$highlight_color"
            fi
            lineno=$(($i + 1))
            printf "%2s ${options[i]}\n" $lineno
        done

    }

    function print_toolbar {
        if [[ $number_input ]]; then
            printf ":%-10d" $number_input
        else
            printf "          "
        fi
    }

    function go_up {
      number_input="" # clear lineno input
      current_pos=$(( current_pos - 1 ))
      if [[ $current_pos == -1 ]]; then
          current_pos=$(( $num_options - 1))
      fi
    }

    function go_down {
        number_input="" # clear lineno input
        current_pos=$(( current_pos + 1 ))
        if [[ $current_pos == $(( num_options )) ]]; then
               current_pos=0
        fi
    }

    function jump_to_line {
        current_pos=$1
    }

    function handle_digit_input {
        next_digit=$1

        # Don't process leading 0s
        if [[ -z "$number_input" && $next_digit -eq 0 ]]; then
            return
        fi

        number_input+=$next_digit

        # Append to the input and jump to the new position, if it is valid.
        # If the input would overflow, reset the input and start over with the new digit,
        # except if the next digit is 0, in which case just reset the input.
        # This might cause weird behavior sometimes, but generally allows
        # the user to quickly jump between positions without requiring more keystrokes.
        if [[ $number_input -ge 1 && $number_input -le $num_options ]]; then
            jump_to_line $(($number_input-1))
        elif [[ $next_digit -ne 0 ]]; then
            number_input=$next_digit
            jump_to_line $(($number_input-1))
        else
            number_input=""
            jump_to_line $initial_position
        fi
    }

    function handle_backspace {
        number_input=${number_input%?}
        if [[ $number_input -ge 1 && $number_input -le $num_options ]]; then
            jump_to_line $(($number_input-1))
        else
            # reset position if input is cleared or overflows
            jump_to_line $initial_position
        fi
    }

    function handle_input {
        read -sn 1 key
        if [[ "$key" == "$esc" ]]; then
            read -sn 2 k2
            key="$key$k2"
        elif [[ $key == "g" ]]; then
            read -sn 1 k2
            key="$key$k2"
        fi

        case "$key" in
            "$up_arrow"|k)
                go_up
                ;;

            "$down_arrow"|j)
                go_down
                ;;

            [0-9])
                handle_digit_input $key
                ;;

            gg)
                jump_to_line 0
                ;;

            G)
                jump_to_line $(($num_options-1))
                ;;

            "$mac_backspace")
                handle_backspace
                ;;

            "$enter")
                end=true;;
        esac
    }

    end=false

    while ! $end
    do
        print_menu
        print_toolbar

        handle_input

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
