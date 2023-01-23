# vim: set ts=4 sw=4:

. /usr/share/virt-init/utils.sh

DEFAULT_OVF_MAPPING="
	hostname=SET_HOSTNAME
	"

: ${vmware_ovf_mapping:=}

read_params() {
	try_enable_pipefail

	local err
	if ! err="$(vmware-rpctool 'info-get guestinfo.ovfEnv' 2>&1 >/dev/null)"; then
		echo "ERROR: Failed to get guestinfo.ovfEnv: $err" >&2
		return 1
	fi

	vmware-rpctool 'info-get guestinfo.ovfEnv' \
		| sed -En 's|.*<Property oe:key="([^"]+)".*oe:value="([^"]+)".*/>.*|'"\1=\2|p" \
		| while read kv; do
			key=$(_remap_key "${kv%%=*}")

			if ! is_protected_var "$key"; then
				printf "export %s='%s'\n" "$key" "$(_xml_decode "${kv#*=}")"
			fi
		done
}

_remap_key() {
	local key="$1"

	local kv; for kv in ${vmware_ovf_mapping:-} $DEFAULT_OVF_MAPPING; do
		if [ "${kv%%=*}" = "$key" ]; then
			echo "${kv#*=}"
			return 0
		fi
	done

	normalize_var_name "$key"
}

_xml_decode() {
	printf '%s\n' "$1" | sed "s/&amp;/\&/g; s/&lt;/\</g; s/&gt;/\>/g; s/&quot;/\"/g; s/&apos;/'\"'\"'/g; s/&#10;/\n/g"
}
