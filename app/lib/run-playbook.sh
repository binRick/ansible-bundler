#!/usr/bin/env bash
#
# This is the entry point for the playbook bundle. It has a hard dependency on Python. It will try
# to look for an already existing installation of Ansible, and will try to install it if not found.
#
# Then, it will run the playbook.yml locally file using ansible.

main() {
	export PIP_ROOT_PATH; PIP_ROOT_PATH="$(realpath "${BASEDIR:-.}/python-deps")"
	export PATH="${PIP_ROOT_PATH}/usr/bin:${PIP_ROOT_PATH}${HOME}/.local/bin:${PATH}"

	ensure_python_is_installed
	install_ansible

	# Export the right paths so we can run python binaries installed on non-default paths
	export PYTHONPATH; PYTHONPATH="$(echo "${PIP_ROOT_PATH}"/usr/lib/*/site-packages:"${PIP_ROOT_PATH}${HOME}"/.local/lib/*/site-packages)"

	run_playbook "$@"
}

ensure_python_is_installed() {
	if ! command -v python > /dev/null 2>&1 && ! command -v python3 > /dev/null 2>&1; then
		echo "Error: Python is not installed!"
		exit 1
	fi

	if ! command -v pip > /dev/null 2>&1 && ! command -v pip3 > /dev/null 2>&1; then
		echo "Error: Python pip is not found!"
		exit 1
	fi
}

pip() {
	if command -v pip3 > /dev/null 2>&1; then
		command pip3 "$@"
	else
		command pip "$@"
	fi
}

# Install ansible if needed
install_ansible() {
	command -v ansible-playbook > /dev/null 2>&1 && return

	echo "Installing ansible..."
	# Here we need to pass the absolute path to --root because there's a weird bug on PIP prevent
	# installing the bin directory when you just pass the relative path.
	pip install --root="$PIP_ROOT_PATH" ansible; local status=$?

	if [ $status -ne 0 ]; then
		echo "Error: Ansible could not be installed."
		exit 1
	fi
}

run_playbook() {
	local extra_params=()

	# Add bundled extra-vars parameter if existent
	test -r "$BASEDIR/vars.yml" && extra_params+=("--extra-vars=@$BASEDIR/vars.yml")

	# Then add runtime extra-vars, if passed
	while [ $# -gt 0 ]; do
		case "$1" in
			-e|--extra-vars)
				extra_params+=("--extra-vars" "$2")
				shift 2
				;;
			--extra-vars=*)
				extra_params+=("--extra-vars" "${1#*=}")
				shift 1
				;;
		esac
	done

	# Run the playbook
	ansible-playbook --inventory="localhost," --connection=local "${extra_params[@]}" \
		"$BASEDIR/playbook.yml"
}

main "$@"
