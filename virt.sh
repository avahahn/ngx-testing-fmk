#!/bin/bash

dirn=$(dirname "$0")
source $dirn/common.sh

if [[ ! -f $dirn/SECRET.sh ]]; then
	error "need to create SECRET.sh... see Readme"
	exit 1
fi

source $dirn/SECRET.sh

# set in SECRET.sh
if [[ ! $USERN ]]; then
	error "\$USERN not set"
	exit 1
fi

# set in SECRET.sh
if [[ ! $PASSP ]]; then
	error "\$PASSP not set"
	exit 1
fi

function vms_avail() {
	ret=$(sudo virsh list --all --name | sort)
}

function vms_on() {
	ret=$(sudo virsh list --name | sort)
}

function vms_off() {
	ret=$(sudo virsh list --inactive --name | sort)
}

function get_vm_ip() {
	vms_avail
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 doesnt exist"
		ret=""
		return 1
	fi

	vms_on
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 already off"
		ret=""
		return 1
	fi

	ret=$(sudo virsh net-dhcp-leases default | grep $1 | awk '{print $5}' | rev | cut -c 4- | rev)
}

function turn_on_vm_and_wait() {
	if [[ ! $1 ]]; then
		log "no VM specified"
		ret=""
		return 1
	fi

	vms_avail
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 doesnt exist"
		ret=""
		return 1
	fi

	vms_off
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 already on"
		ret=""
		return 0
	fi

	sudo virsh start $1 >/dev/null
	log "Started VM $1. Please standby"


	# wait for an IP
	ret=""
	while [[ "$ret" == "" ]]; do
		get_vm_ip $1
		sleep 0.5
	done
	log "Got IP for VM $1"

	# wait for successful ssh
	# ret set by get_vm_ip above
	while ! sshpass -p $PASSP \
		ssh -o PreferredAuthentications=password \
			-o StrictHostKeyChecking=no $USERN@$ret \
			exit; do
				sleep 0.1
			done
	log "Got SSH on VM $1"
}

function vm_shell() {
	vms_avail
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 doesnt exist"
		ret=""
		return 1
	fi

	vms_on
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 is off"
		ret=""
		return 1
	fi

	if [[ "$2" == "" ]]; then
		log "wont execute empty command"
		ret=""
		return 1
	fi

	# wait for an IP
	ret=""
	while [[ "$ret" == "" ]]; do
		get_vm_ip $1
		sleep 0.5
	done

	# wait for successful ssh
	# ret set by get_vm_ip above
	sshpass -p $PASSP \
		ssh -o PreferredAuthentications=password \
			-o StrictHostKeyChecking=no \
			$USERN@$ret "$2"
	return $?
}

function turn_off_vm() {
	if [[ ! $1 ]]; then
		log "no VM specified"
		ret=""
		return 1
	fi

	vms_avail
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 doesnt exist"
		ret=""
		return 1
	fi

	vms_on
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 already off"
		ret=""
		return 1
	fi

	ret=$(sudo virsh shutdown $1)
}

function sync_dir_to_vm(){
	if [ ! -d $2 ]; then
		log "directory $2 does not exist."
		ret=""
		return 1
	fi

	vms_avail
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 doesnt exist"
		ret=""
		return 1
	fi

	vms_on
	if ! [[ $ret =~ $1 ]]; then
		log "VM $1 is off"
		ret=""
		return 1
	fi

	# wait for an IP
	ret=""
	while [[ "$ret" == "" ]]; do
		get_vm_ip $1
		log "waiting for ip"
		sleep 0.5
	done

	sshpass -p $PASSP \
		rsync -avze "ssh -o PreferredAuthentications=password -o StrictHostKeyChecking=no" \
		$2 $USERN@$ret:
	return $?
}

# boots vm, enters SSH, shuts down VM
function vsh() {
	# takes care of error cases
	if ! turn_on_vm_and_wait $1; then
		exit 1
	fi

	get_vm_ip $1
	sshpass -p $PASSP \
		ssh -o PreferredAuthentications=password \
			-o StrictHostKeyChecking=no \
			$USERN@$ret

	turn_off_vm $1
}
