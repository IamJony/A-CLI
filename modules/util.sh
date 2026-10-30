#!/bin/bash

_CLAVE=42


char_to_ascii() {
    local char="$1"
    local octal_val
    octal_val=$(printf '%03o' "'$char")
    echo $((8#$octal_val))
}


ascii_to_char() {
    local dec="$1"
    printf "\\$(printf '%03o' "$dec")"
}

o() {
    local input="$1"
    local output=""
    local i char dec xored
    for (( i=0; i<${#input}; i++ )); do
        char="${input:$i:1}"
        dec=$(char_to_ascii "$char")
        xored=$(( dec ^ _CLAVE ))
        output+="$xored "
    done
    # Quitamos el espacio final
    echo "${output% }"
}

d() {
    local input="$1"
    local output=""
    local i dec xored
    for dec in $input; do
        xored=$(( dec ^ _CLAVE ))
        output+=$(ascii_to_char "$xored")
    done
    echo "$output"
}

