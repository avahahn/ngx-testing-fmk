#!/bin/bash

RED='\033[1;31m'
GRN='\033[1;32m'
YEL='\033[1;33m'
BLU='\033[1;34m'
WHT='\033[1;37m'
MGT='\033[1;95m'
CYA='\033[1;96m'
END='\033[0m'

function section() {
	echo ""
	log "***** Section: ${MGT}$1${END} *****"; 
	echo ""
}

function log() { >&2 printf "${WHT}#${END} $1\n"; }

function error() { >&2 printf "${WHT}#${END} ${RED}$1${END}\n"; }

# takes a function and many inputs, runs function on each input in parallel
# inputs should be stored deliniated by newlines in $2
# if $3 exists it will be a stub for logging filename
function parallel_invoke_and_wait() {
	local procedure=$1
	local pids=()
	local rets=()

	if [[ ! $1 ]]; then
		log "failed to invoke null procedure"
		return 1
	fi

	if [[ ! $2 ]]; then
		log "failed to invoke procedure on 0 inputs"
		return 1
	fi

	IFS=$'\n'
	for input in $2; do
		log "invoking procedure with input $input"
		if [[ $3 ]]; then
			$procedure $input &>${3}${input}.log &
		else
			$procedure $input &
		fi
		pids+=("$input/$!")
	done

	cf="true"
	for pid in ${pids[*]}; do
		local p=$(basename $pid)
		local input=$(dirname $pid)
		wait $p
		local code=$?
		log "procedure with input $input returned $code"
		if [[ $3 && ! $code == 0 ]]; then # needs to catch code==2, etc
			log "tail of related logs..."
			tail ${3}${input}.log
			log "see more in ${3}${input}.log"
			cf="false"
		fi
	done

	if [[ $cf == "false" ]]; then 
		return 1
	else
		return 0
	fi
}
