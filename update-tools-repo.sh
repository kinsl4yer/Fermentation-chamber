#!/bin/bash

unset CDPATH
myPath="$( cd "$( dirname "${BASH_SOURCE[0]}")" && pwd )"
cd "$myPath"

active_branch=$(git symbolic-ref -q HEAD)
active_branch=${active_branch##refs/heads/}

git fetch
changes=$(git log HEAD..origin/"$active_branch" --oneline)

if [ -z "$changes" ]; then
    # no changes
    echo "$myPath znajduje się w najnowszej wersji."
    exit 0
fi

echo "$myPath nie znajduje się w najnowszej wersji, aktualizacja..."
git pull;
if [ $? -ne 0 ]; then
    echo ""
    echo "BŁĄD: Podczas próby pobrania plików wystąpił nieoczekiwany błąd. Należy dokonać manualnej aktualizacji $myPath"
    echo  "Możliwe jest pobranie aktualizacji z adresu lokalnego poprzez użycie komend: cd $myPath; sudo git stash; sudo git pull"
    echo  ""
fi
exit 1

cd -
