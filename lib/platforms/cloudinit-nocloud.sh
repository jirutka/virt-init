# vim: set ts=4 sw=4:

. /usr/share/virt-init/utils.sh

DEFAULT_USERDATA_MAPPING="
	hostname=SET_HOSTNAME
	fqdn=FQDN
	timezone=TIMEZONE
	user=ADMIN_USER
	ssh_authorized_keys/*=ADMIN_SSH_KEYS
	users/1/name=ADMIN_USER
	users/1/groups/1=ADMIN_GROUP
	users/1/shell=ADMIN_SHELL
	users/1/ssh_authorized_keys/*=ADMIN_SSH_KEYS
	"

CIDATA_MOUNT_DIR='/tmp/virt-init-cidata'

: ${cloudinit_volume_label:="cidata"}
: ${cloudinit_volume_fstype:="iso9660"}

read_params() {
	try_enable_pipefail

	_mount_cidata || return 1
	_check_cidata || return 1

	set -f  # disable globbing

	local kv key var val
	for kv in $(_get_mapping); do
		key=${kv%%=*}
		var=${kv#*=}

		if is_protected_var "$var"; then
			echo "WARN: Ignoring protected variable name: $var" >&2
			continue
		fi
		if val=$(_cidata_get 'user-data' "$key") || val=$(_cidata_get 'meta-data' "$key"); then
			printf "export %s='%s'\n" "$var" "$(_escape "$val")"
		fi
	done

	_umount_cidata || return 1
}

_mount_cidata() {
	local device="$(blkid -l -t LABEL="$cloudinit_volume_label" -o device)"
	if [ -z "$device" ]; then
		local label2="$(echo "$cloudinit_volume_label" | tr '[a-z]' '[A-Z]')"
		device="$(blkid -l -t LABEL="$label2" -o device)" || :
	fi
	if [ -z "$device" ]; then
		echo "ERROR: Device with label $cloudinit_volume_label does not exist" >&2
		return 1
	fi

	mkdir -p "$CIDATA_MOUNT_DIR"
	mount -t "$cloudinit_volume_fstype" -o ro "$device" "$CIDATA_MOUNT_DIR"
}

_umount_cidata() {
	umount "$CIDATA_MOUNT_DIR"
	rmdir "$CIDATA_MOUNT_DIR" 2>/dev/null
}

_check_cidata() {
	if ! [ -f "$CIDATA_MOUNT_DIR/meta-data" ]; then
		echo "ERROR: File $CIDATA_MOUNT_DIR/meta-data does not exist or not readable" >&2
		return 1
	fi

	local header
	header=$(head -n1 "$CIDATA_MOUNT_DIR/user-data") || {
		echo "ERROR: File $CIDATA_MOUNT_DIR/user-data does not exist or not readable" >&2
		return 1
	}
	case "${header%% *}" in
		'#cloud-config') return 0;;
		'#!'*) echo 'ERROR: user-data of type script is not supported' >&2; return 1;;
		*) echo 'ERROR: Unknown user-data type' >&2; return 1;;
	esac
}

_get_mapping() {
	set +f  # disable globbing

	local kv; for kv in ${cloudinit_userdata_mapping:-"+default"}; do
		if [ "$kv" = '+default' ]; then
			printf '%s\n' $DEFAULT_USERDATA_MAPPING
		else
			printf '%s\n' "$kv"
		fi
	done
}

_cidata_get() {
	local file="$CIDATA_MOUNT_DIR/$1"
	local keypath="$2"

	if [ "${keypath%/\*}" != "$keypath" ]; then
		keypath="$(printf %s "${keypath%/\*}" | tr / ' ')"

		local keys="$(yx -f "$file" $keypath 2>/dev/null)"
		[ "$keys" ] || return 1

		local key; for key in $keys; do
			yx -f "$file" $keypath $key
			echo ''
		done
	else
		yx -f "$file" $(printf %s "$keypath" | tr / ' ') 2>/dev/null
	fi
}

_escape() {
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
}
