# vim: set ts=4 sw=4:
# Utility functions for provisioning scripts.
# https://github.com/jirutka/virt-init

# Prints value of the specified variable, or the given default if the variable
# is empty or not defined.
#
# $1: Name of the variable to print.
# $2: Default value.
getval() {
	local var_name="$1"
	local default="${2:-}"

	eval "printf '%s\n' \${$var_name:-$default}"
}

# Returns 0 if $1 is a protected variable name (e.g. PATH, PWD, RC_*),
# 1 otherwise.
is_protected_var() {
	case "$1" in
		EINFO_* | PATH | PWD | RC_* | SHLVL | SVCNAME) return 0;;
		*) return 1;;
	esac
}

# Normalizes $1 to be a valid shell variable name and converts it to
# SCREAMING_CASE.
normalize_var_name() {
	printf %s "$1" | tr '[a-z]' '[A-Z]' | sed 's/[^A-Z0-9_]/_/g'
}

# Enables the pipefail option in the current shell, if supported.
try_enable_pipefail() {
	if ( set -o pipefail 2>/dev/null ); then
		set -o pipefail
	fi
	return 0
}

# Creates, updates or deletes generated section with the given content in the
# specified configuration file. If the content is empty string, then the
# generated section (start/end tags and everything between) is removed.
#
# $1: Path of the file to modify.
# $2: Content to be inserted into the file; reads from STDIN if not provided.
update_config() {
	local conf_file="$1"
	local content="${2-"$(cat -)"}"  # if $3 is *not set*, read from STDIN

	local start_tag='# BEGIN generated'
	local end_tag='# END generated'

	[ -z "$content" ] || content=$(
		cat <<-EOF

			$start_tag by virt-init
			# Do not modify this block, any modifications will be lost after reboot!
			$content
			$end_tag
		EOF
	)

	if [ -f "$conf_file" ] && grep -q "^$start_tag" "$conf_file"; then

		if [ "$content" ]; then
			content=${content//$'\n'/\\$'\n'}  # escape \n, busybox sed doesn't like them
			sed -ni "/^$start_tag/ {
					a\\$content
					# read and discard next line and repeat until $end_tag or EOF
					:a; n; /^$end_tag/!ba; n
				}; p" "$conf_file"
		else
			# Remove start/end tags and everything between them.
			sed -i "/^$start_tag/,/^$end_tag/d" "$conf_file"
		fi

	elif [ "$content" ]; then
		printf '%s\n' "$content" >> "$conf_file"
	fi
}

# Returns 0 if $1 is "yes" (case insensitive), 1 otherwise.
yesno() {
	case "$1" in
		[yY][eE][sS]) return 0;;
		*) return 1;;
	esac
}
