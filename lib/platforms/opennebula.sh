# vim: set ts=4 sw=4:

. /usr/share/virt-init/utils.sh

DEFAULT_CONTEXT_MAPPING="
	SSH_PUBLIC_KEY=ADMIN_SSH_KEYS
	USERNAME=ADMIN_USER
	"

CONTEXT_MOUNT_DIR='/tmp/virt-init-context'

: ${opennebula_volume_label:="CONTEXT"}
: ${opennebula_volume_fstype:="iso9660"}

read_params() {
	try_enable_pipefail

	_mount_context || return 1
	_check_context || return 1

	set -f  # disable globbing

	local key var val
	for key in $(_context_keys); do
		var="$(_remap_key "$key")"

		if is_protected_var "$var"; then
			echo "WARN: Ignoring protected variable name: $var" >&2
			continue
		fi

		val="$(
			. "$CONTEXT_MOUNT_DIR"/context.sh
			eval "printf '%s\n' \$$key"
		)" >/dev/null
		printf "export %s='%s'\n" "$var" "$(_escape "$val")"
	done

	_umount_context || return 1
}

_mount_context() {
	local device="$(blkid -l -t LABEL="$opennebula_volume_label" -o device)"
	if [ -z "$device" ]; then
		echo "ERROR: Device with label $opennebula_volume_label does not exist" >&2
		return 1
	fi

	mkdir -p "$CONTEXT_MOUNT_DIR"
	mount -t "$opennebula_volume_fstype" -o ro "$device" "$CONTEXT_MOUNT_DIR"
}

_umount_context() {
	umount "$CONTEXT_MOUNT_DIR"
	rmdir "$CONTEXT_MOUNT_DIR" 2>/dev/null
}

_check_context() {
	if ! [ -f "$CONTEXT_MOUNT_DIR/context.sh" ]; then
		echo "ERROR: File $CONTEXT_MOUNT_DIR/context.sh does not exist or not readable" >&2
		return 1
	fi
	if ! sh -n "$CONTEXT_MOUNT_DIR/context.sh" 2>/dev/null; then
		echo "ERROR: File $CONTEXT_MOUNT_DIR/context.sh is not a valid shell script" >&2
		return 1
	fi
}

# Prints names of variables declared in the context.sh.
_context_keys() {
	env -i sh -ea <<-EOF
		. "$CONTEXT_MOUNT_DIR"/context.sh
		awk 'BEGIN { for (v in ENVIRON) print v }' \
			| grep -Ev '^PWD|SHLVL|AWKPATH|AWKLIBPATH$'
	EOF
}

_remap_key() {
	local key="$1"

	local kv; for kv in ${opennebula_context_mapping:-} $DEFAULT_CONTEXT_MAPPING; do
		if [ "${kv%%=*}" = "$key" ]; then
			echo "${kv#*=}"
			return 0
		fi
	done

	normalize_var_name "$key"
}

_escape() {
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
}
