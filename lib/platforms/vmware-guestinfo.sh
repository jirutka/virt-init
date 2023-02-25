# vim: set ts=4 sw=4:

. /usr/share/virt-init/utils.sh

DEFAULT_GUESTINFO_MAPPING="
	admin-group=ADMIN_GROUP
	admin-shell=ADMIN_SHELL
	admin-ssh-keys=ADMIN_SSH_KEYS
	admin-user=ADMIN_USER
	fqdn=FQDN
	hostname=SET_HOSTNAME
	root-ssh-keys=ROOT_SSH_KEYS
	timezone=TIMEZONE
	"

read_params() {
	try_enable_pipefail

	local kv key var val cnt=0
	for kv in $(_get_mapping); do
		key=${kv%%=*}
		var=${kv#*=}

		if is_protected_var "$var"; then
			echo "WARN: Ignoring protected variable name: $var" >&2
			continue
		fi
		if val=$(vmware-rpctool "info-get guestinfo.$key") 2>/dev/null; then
			printf "export %s='%s'\n" "$var" "$(_escape "$val")"
			cnt=$(( cnt + 1 ))
		fi
	done

	if [ "$cnt" -eq 0 ]; then
		echo 'ERROR: No guestinfo parameters found' >&2
		return 1
	fi

	return 0
}

_get_mapping() {
	local kv; for kv in ${vmware_guestinfo_mapping:-"+default"}; do
		if [ "$kv" = '+default' ]; then
			printf '%s\n' $DEFAULT_GUESTINFO_MAPPING
		else
			printf '%s\n' "$kv"
		fi
	done
}

_escape() {
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
}
