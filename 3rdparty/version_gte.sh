#!/usr/bin/env zsh

[[ $# == 2 ]] || { echo "requires two args"; exit 1 }

vergte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -rV | head -n1`" ]
}

vergte $@ && exit 0 || exit 1

