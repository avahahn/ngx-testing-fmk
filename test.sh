#!/bin/bash

dirn=$(dirname "$0")
source $dirn/common.sh
source $dirn/virt.sh
source $dirn/nginx.sh

nginx_dir=""
otel_dir=""
tests_dir=""
while [ $# -gt 0 ]; do
	case $1 in
		-h | --help)
			log "test.sh: build and test code on many libvirt VMs at once"
			log "  -h, --help: show this help text"
			log "  -n <dir>, --nginx <dir>: specify an nginx directory"
			log "  -o <dir>, --otel <dir>:  specify an nginx-otel directory"
			log "  -t <dir>, --tests <dir>: specify an nginx-tests directory"
			exit 0
			;;

		-n | --nginx)
			[ -d $2 ] || ( \
				log "nginx flag requires valid dir" && \
				exit 1 )
			nginx_dir=$2
			;;

		-o | --otel)
			[ -d $2 ] || ( \
				log "otel flag requires valid dir" && \
				exit 1 )
			otel_dir=$2
			;;

		-t | --tests)
			[ -d $2 ] || ( \
				log "tests flag requires valid dir" && \
				exit 1 )
			[ $nginx_dir ] || [ $otel_dir ] || ( \
				log "must set nginx flag before tests flag" && \
				exit 1 )
			tests_dir=$2
			;;

		*)
			log "unknown argument: $1"
			exit 1
	esac

	shift
	shift
done

vm_nginx_dir=$(basename $nginx_dir)
vm_otel_dir=$(basename $otel_dir)
vm_tests_dir=$(basename $tests_dir)

section "script init..."
if [[ ! -d $test_log_dir ]]; then
	log "prepping new test log dir"
	ran=$((1+$RANDOM % 1000))
	test_log_dir=/tmp/nginx_autotest_fmk_$ran
	rm -rf $test_log_dir
	mkdir $test_log_dir
fi

log "tests logs dir: $test_log_dir"
log "nginx code dir: $nginx_dir"
log "nginx test dir: $tests_dir"
log "otel code dir:  $otel_dir"

function syncs() {
	sync_dir_to_vm $1 $nginx_dir
	sync_dir_to_vm $1 $tests_dir
	sync_dir_to_vm $1 $otel_dir
}

function build_nginx() {
	vm_shell $1 \
			"echo 'BEGIN BUILD'; set -ex; \
			$(typeset -f build_nginx_remote); \
			cd $vm_nginx_dir; \
			build_nginx_remote;"
	return $?
}

function build_otel() {
	vm_shell $1 \
			"echo 'BEGIN BUILD'; set -ex; \
			$(typeset -f build_otel_remote); \
			cd $vm_otel_dir; \
			build_otel_remote;"
	return $?
}

function test_nginx() {
	vm_shell $1 \
			"echo 'BEGIN TESTS'; set -ex; \
			$(typeset -f test_nginx_remote); \
			cd $vm_tests_dir; \
			test_nginx_remote;"
	return $?
}

function test_otel() {
	vm_shell $1 \
			"echo 'BEGIN TESTS'; set -ex; \
			$(typeset -f test_otel_remote); \
			cd $vm_otel_dir; \
			test_otel_remote;"
	return $?
}

function clean_nginx() {
	vm_shell $1 \
			"set -ex; \
			$(typeset -f clean_nginx_remote); \
			cd $vm_nginx_dir; \
			clean_nginx_remote;"
	return $?
}

function clean_otel() {
	vm_shell $1 \
			"set -ex; \
			$(typeset -f clean_otel_remote); \
			cd $vm_otel_dir; \
			clean_otel_remote;"
	return $?
}

function cleanup() {
	section "cleanup!"
	log "cleaning build directories"
	if ! parallel_invoke_and_wait \
			clean_nginx "$vm_list" "$test_log_dir/clean_nginx"; then
		error "Failed to clean NGINX build directory"
	fi

	if ! parallel_invoke_and_wait \
			clean_otel "$vm_list" "$test_log_dir/clean_otel"; then
		error "Failed to clean otel build directory"
	fi

	log "turning off VMs"
	parallel_invoke_and_wait \
		turn_off_vm \
		"$vm_list" \
		"$test_log_dir/off_"
}

section "launching VMs"
vms_avail
if [[ "$ret" == "" ]]; then
	log "no VMs available!"
	exit 1
fi
vm_list=$ret
ret=""

if ! parallel_invoke_and_wait \
		turn_on_vm_and_wait \
		"$vm_list" \
		"$test_log_dir/on_"; then
	error "Failed to turn on all VMs"
	cleanup
	exit 1
fi

section "syncing code to VMs"
if ! parallel_invoke_and_wait \
		syncs "$vm_list" "$test_log_dir/sync_"; then
	error "Failed to sync files to VMs"
	cleanup
	exit 1
fi

if [ $nginx_dir ]; then
	section "building NGINX"
	if ! parallel_invoke_and_wait \
			build_nginx "$vm_list" "$test_log_dir/build_nginx_"; then
		error "NGINX build failures detected"
		cleanup
		exit 1
	fi
fi

if [ $otel_dir ]; then
	section "building NGINX Otel module"
	if ! parallel_invoke_and_wait \
			build_otel "$vm_list" "$test_log_dir/build_otel_"; then
		error "Otel build failures detected"
		cleanup
		exit 1
	fi
fi

if [ $tests_dir ]; then
	if [ $nginx_dir ]; then
		section "testing NGINX"
		if ! parallel_invoke_and_wait \
				test_nginx "$vm_list" "$test_log_dir/test_nginx_"; then
			error "NGINX test failures detected"
			cleanup
			exit 1
		fi
	fi

	if [ $otel_dir ]; then
		section "testing NGINX Otel module"
		if ! parallel_invoke_and_wait \
				test_otel "$vm_list" "$test_log_dir/test_otel_"; then
			error "Otel test failures detected"
			cleanup
			exit 1
	fi
fi

# ------
cleanup
log "Finished :)"
