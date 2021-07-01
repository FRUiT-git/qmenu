#!/bin/sh

init() 
{

    [ -f /sh/shfunc ] && . /sh/shfunc

    MINOR="2 rev 5060"
    MAJOR=0
    MDATE="2011-05-06"
#    DEBUG=1

#    [ ! "$(locale | awk '/^LC_CTYPE.*UTF.*/')" ] && { local L="/" R="\\" V="|" H="-" ; }
    [ "$LANG" = "${LANG%UTF*}" ] && { local L="/" R="\\" V="|" H="-" ; }

    : ${EUL:=${L:-"┌"}}
    : ${EUR:=${R:-"┐"}}
    : ${EBL:=${R:-"└"}}
    : ${EBR:=${L:-"┘"}}
    : ${HBR:=${H:-"─"}}
    : ${VBR:=${V:-"│"}}
    : ${SBL:=${V:-"├"}}
    : ${SBR:=${V:-"┤"}}

    TOOLS="tput stty seq awk ls"
    for t in $TOOLS; do type $t >/dev/null 2>&1 || error 3 "$t not found"; done

    CO=${COLUMNS:-$(tput cols)}
    LI=${LINES:-$(tput lines)}

    [ $CO -lt 70 ] && error 1 "$CO column window is too narrow"
    [ $LI -lt 24 ] && error 1 "$LI line window is too narrow"

    : ${MID:=1}

    UP="$(printf "%b" "\033[A")"
    DN="$(printf "%b" "\033[B")"
    LE="$(printf "%b" "\033[D")"
    RI="$(printf "%b" "\033[C")"
    NL="$(printf "%b" "\r\n")"
    ES="$(printf "%b" "\033")"
    DL="$(printf "%b" "\033[3~")"
    F1="$(printf "%b" "\033OP")"
    F2="$(printf "%b" "\033OQ")"
    F3="$(printf "%b" "\033OR")"
    F4="$(printf "%b" "\033OS")"
    F5="$(printf "%b" "\033[15~")"
    F6="$(printf "%b" "\033[17~")"
    F7="$(printf "%b" "\033[18~")"
    F8="$(printf "%b" "\033[19~")"
    F9="$(printf "%b" "\033[20~")"

    C="$(clear_screen)"
    N="$(tput sgr0)"
    K="$(tput el)"
    S="$(tput smul)"
    TSL=$(tput cup $LI 0)

    : ${QCOLOR_NORM:="0;0"}
    : ${QCOLOR_HIGH:="7"}

    NCOL="$N\033[${QCOLOR_NORM}m"
    HCOL="$N\033[${QCOLOR_HIGH}m"

    case $TERM in screen) KL=1 ;; esac

    rm "${HOME}"/.qmenu/*_*_Profile.qmenu 2>/dev/null

    sttystate=$(stty -g)
    stty raw -icanon -echo

    tput -S <<EOF
        sc
        smcup
        civis
        csr 1 $(($LI-1))
EOF

    for Y in $(seq 0 14); do eval P$Y=\"$(tput cup $((6+$Y)) 4)\"; done

    HELP_page1="$( printf "%b" \
        "${P0}${S}Qmenu${NCOL} v$MAJOR.$MINOR by FRUiT" \
        "${P2}  A cute ncurses based menu for non-GUI computers to launch" \
        "${P3}  all your prefered apps." \
        "${P5}$HBR$HBR$HBR$HBR$HBR Keys $HBR$HBR$HBR$HBR$HBR" \
        "${P7}up|down [z|s]      Browse the current menu" \
        "${P8}left|right [q|d]   Navigate to previous / next menu" \
        "${P9}enter              Launch menu item / validate tool boxes" \
       "${P10}esc|ctrl-C|x       Exit Qmenu" \
       "${P12}$HBR$HBR$HBR$HBR$HBR Misc $HBR$HBR$HBR$HBR$HBR" \
       "${P14}Updated            $MDATE"
    )"

    HELP_page2="$( printf "%b" \
        "${P0}$HBR$HBR$HBR$HBR$HBR Function keys $HBR$HBR$HBR$HBR$HBR" \
        "${P2}F1 [h]   Get this help" \
        "${P3}F2 [n]   Create a new menu" \
        "${P4}F3 [r]   Remove a menu" \
        "${P5}F4 [m]   Move a menu to another position" \
        "${P6}F5       Rescan whole index" \
        "${P7}             (you shall not need to use this)"\
        "${P8}F6 [e]   Edit a menu" \
        "${P9}             Use e to quickly edit the menu you're curently in" \
       "${P10}F8 [p]   Show the profile manager menu" \
       "${P11}             Use del or k to remove profiles from this menu" \
       "${P12}F9 [u]   Update/regen a current/deleted Q system menu" \
    )"

    Q_MENU="$( printf "%s\n" \
        "Help§print_help" \
        "New menu...§create_menu" \
        "SEP" \
        "Edit menu...§edit_menu" \
        "Delete menu...§delete_menu" \
        "Move menu...§move_menu" \
        "SEP" \
        "Show profiles§profile_menu" \
        "SEP" \
        "Exit§exit_qmenu" \
    )"

    PROFILE_MODULE="$( printf "%s\n" \
        "SEP" \
        "New...§profile_new" \
        "Hide profiles§profile_hide" \
    )"

    DEF_MENU="$( printf "%b\n" \
        "# Qmenu input file example. You may put here any comments / newlines" \
        "# Synopsis :" \
        "#" \
        "#     item_name§/path/to/command --some-arg ARG[§]" \
        "# or  SEP" \
        "#" \
        "# Commands ending with a § sign will fall back to Qmenu" \
        "# Command may be any single shell command, or a comma separated list" \
        "# Put the word « SEP » on a blank line to generate a menu separator\n\n" \
        "Hit e to edit this menu...§echo \"This is an example command.\"" \
    )"

}

end() 
{

    rm "${HOME}"/.qmenu/*_*_Profile.qmenu 2>/dev/null
    re_index
    stty "$sttystate"
    status
    tput -S <<EOF
        sgr0
        rmcup
        csr 0 $(($LI-1))
        cnorm
        rc
EOF
    tput rmcup || printf "%b" "$TSL"
    return 0

}

integer() 
{

    [ "$1" -a $1 -eq $1 2>/dev/null ]

}

get_file() 
{

    local F="$(

        \ls "${HOME}"/.qmenu/${PROFILE}_$1_*.qmenu 2>/dev/null || \
        \ls "${HOME}"/.qmenu/${PROFILE}_*_$1.qmenu 2>/dev/null

    )"

    [ -f "$F" ] && printf "%s" "$F"

}

hash_menu() 
{

    [ -f "$1" ] || {

        unset FOUND_PATH FOUND_PROFILE FOUND_ID FOUND_NAME FOUND_EXT
        return 1

    }

    local TMP="${1%_*}"
    local TM2="${TMP##*/}"

    FOUND_EXT="${1##*.}"
    FOUND_NAME="${1%.$FOUND_EXT}" ; FOUND_NAME="${FOUND_NAME#${TMP}_}"
    FOUND_ID="${TMP##*_}"
    FOUND_PROFILE="${TM2%_*}"
    FOUND_PATH="${1%/*}"

}

check_sep() 
{

    eval case :"\${SL_$1}": in *:$2:*\) return 0 \;\; *\) return 1 \;\; esac

}

check_range() 
{

    integer $2 || return 1
    eval [ $2 -gt 0 -a $2 -le "\${HE_$1}" ]

}

show_menu_ids() 
{

    for ID in $(seq 1 $M_MAX); do

        eval tput cup 0 $\(\("\${RO_$ID}"-${#ID}\)\)
        printf "${HCOL}%g${NCOL}" "$ID"

    done

}

rm_cache() 
{

    [ "$1" = "+" ] && { local LOOP=1 ; shift ; }

    [ -f "/tmp/$$.${1##*/}" ] && {

        hash_menu "$1"

        [ "$LOOP" ] && for NEXT in $(seq $FOUND_ID $M_MAX); do

            local FILE="$(get_file $NEXT)"

            eval unset HE_$NEXT WI_$NEXT I_$NEXT_1 MB_$NEXT
            rm "/tmp/$$.${FILE##*/}" >/dev/null 2>&1

        done || {

            eval unset HE_${FOUND_ID} WI_${FOUND_ID} I_${FOUND_ID}_1 MB_${FOUND_ID}
            rm "/tmp/$$.${1##*/}" >/dev/null 2>&1

        }

        return

    } || rm /tmp/$$.*.qmenu >/dev/null 2>&1

}

re_cache() 
{

    menu_scan

    STATUS_MSG="$1"
    menu_launch

}

re_index() 
{

    ID=1

    for F in $(\ls -1 -v "${HOME}"/.qmenu/${PROFILE}_*.qmenu 2>/dev/null); do

        hash_menu "$F"

        if [ $FOUND_ID -ge ${2:-0} ]; then

            mv "$F" ${FOUND_PATH}/${PROFILE}_"$(($ID$1))"_${FOUND_NAME}.${FOUND_EXT} 2>/dev/null
            case $? in
                0)  status "Indexing : « $FOUND_NAME » to $(($ID$1))${1:+" ($1)"}" ;;
                *)  status "Keeping : « $FOUND_NAME » at $FOUND_ID (+0)"                    ;;
            esac

        else

            [ $FOUND_ID -eq $ID ] && status "Keeping « $FOUND_NAME » at $ID (+0)" || {

                mv "$F" ${FOUND_PATH}/${PROFILE}_${ID}_${FOUND_NAME}.${FOUND_EXT} 2>/dev/null
                status "Indexing : « $FOUND_NAME » to $ID (-$(($FOUND_ID-$ID)))"

            }

        fi

        ID=$(($ID+1))

    done

}

status() 
{

    printf "$TSL$N$K%${KL:+-$CO}b$TSL%-.${CO}b" " " " $1"

}

prompt_open() 
{

    stty -raw echo icanon
    tput cnorm

}

prompt_close() 
{

    stty raw -echo -icanon
    tput civis

}

clear_screen() 
{

    for i in $(seq 1 $(($LI-2))); do

        tput cup $i 0
        tput el

    done

    tput home

}

error() 
{

    printf "%b\n" "${0##*/} : Error : $2"
    exit $1

}

exit_qmenu() 
{
    rm_cache
    exit 0

}

menu_scan() 
{

    menu_cache() 
    {

        eval tput cup 0 $\(\("\${RO_$1}"-1\)\)
        eval printf "%b" "\${HCOL}\ \${MN_$1}\ \${NCOL}"

        eval [ \"\${I_$1_1}\" ] || return

        draw_sub "$EUL" "$EUR" $1 0

        for IND in $(eval seq 1 \"\${HE_$1}\"); do 

            check_sep $1 $IND && draw_sub "$SBL" "$SBR" $1 $IND || \
            {

                POS=$(eval tput cup $(($IND+1)) \"\${RA_$1}\")
                eval printf \"$POS%$\(\("\${WI_$1}"+1\)\)s${VBR:- }$POS%s\" \" \" \"${VBR:- } \${I_${1}_${IND}} \"

            }

        done

        draw_sub "$EBL" "$EBR" $1 $(($IND+1))

        printf "%b" "$N"

    }

    draw_sub() 
    {

        eval tput cup $(($4+1)) \"\${RA_$3}\"

        printf "%b" "${1:- }"
        printf "%.0b${HBR:- }" $(eval seq 1 \"\${WI_$3}\")
        printf "%b" "${2:- }"

    }

    menu_parse() 
    {

        SOURCE="/tmp/$$.${M_TARGET##*/}"

        [ -f "$SOURCE" ] || \
            awk '!/^#|^$/' "$M_TARGET" | \
            awk 'FNR==1{L=$0;next} !/^SEP/||!(L~/^SEP/) {print L} {L=$0} END{if ($0!="SEP") print $0}' | \
            awk 'FNR==1{if ($0~/^SEP/) next} {print}' \
        >"$SOURCE"

        [ -f "$SOURCE" ] || error 2 "Unable to create cache. Aborting."

        eval MF_$1="$M_TARGET"
        eval MN_$1="$FOUND_NAME"

        eval WI_$1=$(($(awk -F'§' '{ if (length($1)>L) L=length($1) } END { print L }' "$SOURCE")+3))
        eval HE_$1=$(awk 'END { print NR }' "$SOURCE")
        eval SL_$1=$(awk '/^SEP/ { printf("%s:",NR) }' "$SOURCE")

        eval local IID=\"\${IID_${FOUND_NAME}}\"

        check_range $1 $IID || IID=1
        check_sep $1 $IID && IID=$(($IID-1))
        eval IID_${FOUND_NAME}="\${IID}"

        eval local RO=\"\${RO_$1}\"  WI=\"\${WI_$1}\"
        [ $(($RO+$WI+2)) -gt $CO ] && RO=$(($CO-$WI-2))
        eval RA_$1="\${RO}"

        eval [ $\(\("\${HE_$1}"+4\)\) -gt $LI ] && eval HE_$1=$(($LI-4))

        eval unset I_$1_1

        for IND in $(eval seq 1 \"\${HE_$1}\"); do

            local NAME="$(awk -F'§' 'NR=='"$IND"' { print $1 }' "$SOURCE")"
            eval I_$1_$IND="\${NAME}"

        done

    }

    BAR=" "
    ID=1
    RO_1=2

    for M in $(\ls -1 -v "${HOME}"/.qmenu/${PROFILE}_*.qmenu 2>/dev/null); do

        [ -f "$M" ] || continue

        hash_menu "$M"
        M_TARGET="${FOUND_PATH}/${FOUND_PROFILE}_${ID}_${FOUND_NAME}.${FOUND_EXT}"

        status "Indexing : $(printf "%2s" "$ID") [ profile « $PROFILE » , menu « $FOUND_NAME » ]"

        [ "$M_TARGET" = "$M" ] || mv "$M" "$M_TARGET"

        eval RO_$(($ID+1))=$\(\("\${RO_$ID}"+${#FOUND_NAME}+2\)\)
        eval [ "\${RO_$(($ID+1))}" -gt $(($CO-4)) ] && break

        BAR="$BAR $FOUND_NAME "

        eval [ -f \"/tmp/\$\$.${M_TARGET##*/}\" \-a \"\${MB_$ID}\" ] || {

            menu_parse $ID
            eval MB_$ID="\$(menu_cache $ID)"

        }

        ID=$(($ID+1))

        M_MAX=$ID

    done

    [ "$M_MAX" ] || gen_default

}

menu_select() 
{

    eval local F=\"\${MF_$MID}\"
    SOURCE="/tmp/$$.${F##*/}"

    eval MN="\${MN_$MID}" ; eval IID="\${IID_$MN}"
}

draw_menu() 
{

    eval printf "%b" \"\${MB_$MID}\"
    draw_item $IID $HCOL

}

draw_bar() 
{

    printf "$N$C$NCOL$K%${KL:+-$CO}b" "$BAR"

}

draw_item() 
{

    eval [ \"\${I_${MID}_${1}}\" ] || return

    POS=$( eval tput cup $(($1+1)) $\(\("\${RA_$MID}"+1\)\) )
    eval printf \"$POS${2:-$NCOL}%\${WI_$MID}s$POS%s$NCOL\" \" \" \" \${I_${MID}_${1}} \"

}

draw_next() 
{

    check_range $MID $IID || IID=1

    [ $(eval printf "%g" "\${HE_$MID}") -eq 1 ] && return
    [ "$1" = "+" ] && eval local EDGE=$\(\("\${HE_$MID}"+1\)\)

    draw_item $IID $NCOL

    IID=$((${IID}${1}1))
    check_sep $MID $IID && IID=$((${IID}${1}1))

    [ $IID -eq ${EDGE:-0} ] && case $1 in +) IID=1 ;; -) eval IID="\${HE_$MID}" ;; esac

    draw_item $IID $HCOL

    eval MN="\${MN_$MID}" ; eval IID_$MN="\${IID}"

}

menu_next() 
{

    [ $M_MAX -gt 2 ] || return
    [ "$1" = "+" ] && local EDGE=$M_MAX

    MID=$((${MID}${1}1))
    [ $MID -eq ${EDGE:-0} ] && case $1 in +) MID=1 ;; -) MID=$(($M_MAX-1)) ;; esac

    menu_select

    check_sep $MID $IID && eval IID_\"\${MN_$MID}\"=1
    check_range $MID $IID || eval IID_\"\${MN_$MID}\"=1

    draw_bar
    draw_menu

}

draw_box() 
{

    draw_box_sub() 
    {

        printf "%b" "${1:- }"
        printf "%.0b${2:- }" $(seq 1 $4)
        printf "%b" "${3:- }"

    }

    [ "${3%% *}" = "Help" ] || status "Validate (enter) with no input to cancel dialog"

    BOX="$(

        printf "%b" "$NCOL"

        tput cup 4 0
        draw_box_sub "$EUL" "$HBR" "$EUR" $1

        for i in $(seq 1 $2); do

            tput cup $((4+$i)) 0
            draw_box_sub "$VBR" " " "$VBR" $1

        done

        tput cup $((5+$i)) 0
        draw_box_sub "$EBL" "$HBR" "$EBR" $1

        tput cup 4 2
        printf "%b" " $3 "

    )"

    printf "%s" "$BOX"

}

exec_cmd() 
{

    [ -f "$SOURCE" ] || re_cache "Cache files were unavailable, index rebuilt"

    eval local NAME=\"\${MN_$MID}\"
    eval local ID=\"\${IID_$NAME}\"

    cmd="$(awk -F'§' 'NR=='"$ID"' { print $2 }' "$SOURCE")"
    ret="$(awk -F'§' 'NR=='"$ID"' { print NF }' "$SOURCE")"

    [ "$cmd" ] && {

        case $cmd in create_menu|delete_menu|move_menu|edit_menu|print_help|profile_menu|profile_select|profile_hide|profile_new) ;; *) 
            unset STATUS_MSG
            end
            printf "%b\n" "\033[A\033[2K\rExecuting : ${cmd}" ;;
        esac

        eval "$cmd"
        tput sc

        [ $ret -eq 3 ] && { init ; re_cache ; } || {
            rm_cache
            tput csr 0 $(($LI-1))
            tput rmcup && tput rc || printf "%b" "$TSL"
            exit 0
        }

    } || menu_walker

}

create_menu() 
{

    draw_bar
    draw_box 37 5 "Create menu"

    tput cup 6 4
    printf "%b" "Please choose a menu name :"

    tput cup 7 4
    prompt_open
    read -p "> " REPLY NOSPACE
    prompt_close

    [ "$(get_file "$REPLY")" ] && {

        STATUS_MSG="Error : The menu « $REPLY » already exists"
        menu_launch

    }

    [ "${REPLY%_*}" = "$REPLY" ] || {

        STATUS_MSG="Error : Illegal character : underscore"
        menu_launch

    }

    [ "$REPLY" ] && {

        printf "%b" "$DEF_MENU" >"$HOME/.qmenu/${PROFILE}_${M_MAX}_${REPLY}.qmenu"

        STATUS_MSG="Menu « $REPLY » has been created at index $M_MAX"
        menu_scan

    }

    menu_launch

}

delete_menu() 
{

    [ $M_MAX -eq $((2${PM_STATE:++1})) ] && {

        STATUS_MSG="Error : You may not have less than one menu"
        menu_walker

    }

    draw_bar
    show_menu_ids
    draw_box 42 8 "Delete menu"

    tput cup 6 4
    printf "%b" "Please choose a menu to erase :"

    tput cup 10 4
    printf "%s" "You may choose either by ID or name"

    tput cup 7 4
    prompt_open
    read -p "> " REPLY
    prompt_close

    [ "$REPLY" ] && {

        TODEL="$(get_file $REPLY)"

        [ -f "$TODEL" ] && {

            rm_cache + "$TODEL"
            hash_menu "$TODEL"
            rm "$TODEL"
            eval unset IID_${FOUND_NAME}
            STATUS_MSG="Menu « $FOUND_NAME » has been removed from index $FOUND_ID"

        } || \

        {

            STATUS_MSG="Error : ID or name not found"
            menu_launch

        }

        menu_scan

    }

    menu_launch

}

move_menu() 
{

    stop() 
    {
        [ "$1" ] && STATUS_MSG="Error : ID or name not found"
        prompt_close
        menu_launch
    }

    check_move() 
    {

        [ $M_TARGET -eq $(($FOUND_ID+1)) -o $M_TARGET -eq $FOUND_ID ] && \
        return 1

        [ $FOUND_ID -ge $(($M_MAX-1)) -a $FOUND_ID -le $M_TARGET ] && \
        return 1

        return 0

    }

    [ $M_MAX -eq $((2${PM_STATE:++1})) ] && {

        STATUS_MSG="Error : A single menu may not move elsewhere"
        menu_walker

    }

    draw_bar
    show_menu_ids
    draw_box 42 11 "Move menu"

    tput cup 6 4
    printf "%b" "${NCOL}Please choose a menu to move :"

    tput cup 13 4
    printf "%s" "You may choose either by ID or name"

    tput cup 7 4
    prompt_open
    read -p "> " M_MENU

    [ "$(get_file "$M_MENU")" ] || stop "$M_MENU"

    tput cup 9 4
    printf "%b" "${NCOL}Select the new position :"

    tput cup 10 4
    read -p "> " M_TARGET

    prompt_close

    integer $M_TARGET || {

        [ "$(get_file "$M_TARGET")" ] || stop "$M_TARGET"
        hash_menu "$(get_file "$M_TARGET")" && M_TARGET=$FOUND_ID

    }

    hash_menu "$(get_file $MID)" && CNAME=$FOUND_NAME

    M_MOVE="$(get_file "$M_MENU")"
    hash_menu "$M_MOVE"

    check_move || {

        STATUS_MSG="Error : This would not really be a move"
        menu_launch

    }

    M_MOVE_EXT="$FOUND_EXT"
    M_MOVE_NAME="$FOUND_NAME"

    status "Found « $M_MOVE_NAME » from index ($M_MOVE)"

    if [ $FOUND_ID -lt $M_TARGET ]; then
        STEP=2
        rm_cache + "$M_MOVE"
    else
        STEP=1
        rm_cache + "$(get_file $M_TARGET)"
    fi

    hash_menu "$M_MOVE"

    mv ${M_MOVE} ${FOUND_PATH}/${FOUND_PROFILE}_$$

    re_index +$STEP ${M_TARGET}

    status "Moving : « $M_MOVE_NAME » to index $M_TARGET"
    mv ${FOUND_PATH}/${FOUND_PROFILE}_$$ \
       ${FOUND_PATH}/${FOUND_PROFILE}_${M_TARGET}_${M_MOVE_NAME}.${FOUND_EXT}

    menu_scan

    hash_menu "$(get_file "$CNAME")" && MID=$FOUND_ID
    STATUS_MSG="Menu « $M_MOVE_NAME » moved, index has been rebuilt"

    menu_launch

}

edit_menu() 
{

    draw_bar
    show_menu_ids
    draw_box 42 8 "Edit menu"

    tput cup 6 4
    printf "%b" "Please choose a menu to edit :"

    tput cup 10 4
    printf "%s" "You may choose either by ID or name"

    tput cup 7 4

    prompt_open
    read -p "> " REPLY
    prompt_close

    TOED="$(get_file "$REPLY")"

    [ "$TOED" ] && {
        end 
        rm_cache "$TOED"
        nano "$TOED"
        init
        re_cache "Menu « $(hash_menu "$TOED";echo $FOUND_NAME) » edited, index cached"
    }

    [ "$REPLY" ] && STATUS_MSG="Error : ID or name not found"
    menu_launch

}

quick_edit() 
{

    end
    eval local W_FILE=\"\${MN_$MID}\"

    rm_cache "$(get_file $MID)"

    eval nano "\${MF_$MID}"

    init
    re_cache "Menu « $W_FILE » edited, index cached"

}

print_help() 
{

    draw_bar
    prompt_close

    draw_box 68 17 "Help 1/2"
    printf "%b" "$HELP_page1"

    case $(dd bs=10 count=1 2>/dev/null) in "$ES"|x|q) menu_launch ;; esac

    draw_box 68 17 "Help 2/2"
    printf "%b" "$HELP_page2"

    dd bs=10 count=1 2>/dev/null

    menu_launch

}

profile_select() 
{

    eval local NEW=\"\${I_${MID}_${IID_Profile}}\"

    [ "$NEW" = "$PROFILE (current)" ] || {
        rm "${HOME}"/.qmenu/${PROFILE}_*_Profile.qmenu 2>/dev/null
        re_index
        PROFILE="$NEW"
        MID=1
        unset PM_STATE IID_Profile
        rm_cache
        re_cache
    }

    menu_walker

}

profile_hide() 
{

    unset PM_STATE IID_Profile STATUS_DEL STATUS_MSG
    MID=1
    rm "${HOME}"/.qmenu/${PROFILE}_*_Profile.qmenu 2>/dev/null
    rm_cache
    re_index
    re_cache

}

profile_menu() 
{

    [ "$PM_STATE" -a ! "$1" ] && menu_walker

    status "Building profile menu..."

    P="$(get_file "Profile")"
    : ${P:="$HOME/.qmenu/${PROFILE}_1_Profile.qmenu"}

    [ -f "$P" ] && rm "$P"

    re_index +1

    for F in "${HOME}"/.qmenu/*.qmenu; do

        hash_menu "$F"
        [ "$FOUND_PROFILE" = "$PROFILE" ] && CUR=1
        printf "%s\n" "$FOUND_PROFILE${CUR:+" (current)"}§profile_select" >>"$P"
        unset CUR

    done

    awk '!a[$0]++ { print > FILENAME }' "$P"

    printf "$PROFILE_MODULE" >>"$P"

    rm_cache
    MID=1 ; PM_STATE=1

    check_sep 1 ${IID_Profile} && IID_Profile=$((${IID_Profile}-1))

    re_cache "${STATUS_DEL:-"Hit ${S}del${N} or ${S}k${N} to remove the highlighted profile"}"

}

profile_remove() 
{

    eval local TODEL=\"\${I_${MID}_${IID_Profile}}\"
    hash_menu "$(get_file $MID)"

    [ ! "$TODEL" = "$PROFILE" -a "$FOUND_NAME" = "Profile" ] && {
        rm "${HOME}"/.qmenu/${TODEL}_*.qmenu 2>/dev/null
    } || return

    STATUS_DEL="Profile « $TODEL » has been removed"
    profile_menu scan

}

profile_new() 
{

    draw_bar
    draw_box 37 5 "Create profile"

    tput cup 6 4
    printf "%b" "Please choose a profile name :"

    tput cup 7 4
    prompt_open
    read -p "> " REPLY NOSPACE
    prompt_close

    [ "$REPLY" ] && {

        [ "$(\ls -1 "${HOME}"/.qmenu/${REPLY}_*.qmenu 2>/dev/null)" ] && {

            STATUS_MSG="This profile already exists"
            menu_launch

        }

        rm "${HOME}"/.qmenu/${PROFILE}_*_Profile.qmenu 2>/dev/null
        re_index

        status "Creating new profile :  « $REPLY »"
        PROFILE="${REPLY}"
        MID=1
        gen_default
        unset PM_STATE IID_Profile
        re_cache

    }

    menu_launch

}

gen_default() 
{

    local MENU="$(get_file "Q")"; : ${MENU:="$HOME/.qmenu/${PROFILE}_0_Q.qmenu"}

    [ -d "${MENU%/*}" ] || mkdir -p "${MENU%/*}"

    printf "%b" "$Q_MENU" >"$MENU"

    STATUS_MSG="Menu « Q » has been renewed / updated"
    MID=1
    DEF_MENU_GEN=true

}

menu_walker() 
{

    status "$STATUS_MSG"
    while :; do
        case $(dd bs=10 count=1 2>/dev/null) in

            "$UP"|z)     draw_next -                      ;;
            "$DN"|s)     draw_next +                      ;;
            "$LE"|q)     menu_next -                      ;;
            "$RI"|d)     menu_next +                      ;;
            "$NL")       exec_cmd ; break                 ;;
            e)           quick_edit                       ;;
            "$ES"||x)  rm_cache ; end ; exit 0          ;;
            "$F1"|h)     print_help                       ;;
            "$F2"|n)     create_menu                      ;;
            "$F3"|r)     delete_menu                      ;;
            "$F4"|m)     move_menu                        ;;
            "$F6"|E)     edit_menu                        ;;
            "$F5")       menu_refresh                     ;;
            "$F8"|p)     [ "$PM_STATE" ] || profile_menu  ;;
            "$DL"|k)     profile_remove                   ;;
            "$F9"|u)     gen_default ; menu_refresh       ;;

        esac
    done

}

menu_refresh() 
{

    rm_cache ; menu_scan ; menu_launch

}

menu_launch() 
{

    menu_select ; draw_bar ; draw_menu ; menu_walker

}

PROFILE="${1:-default}"

init

menu_scan; [ "$DEF_MENU_GEN" ] && { unset DEF_MENU_GEN ; menu_scan ; }
menu_launch

end
