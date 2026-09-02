#!/bin/zsh

set -e

cd "${0:A:h}"

pause_before_exit() {
	if [[ -t 0 ]]; then
		echo
		read -k 1 "?Press any key to close..."
	fi
}
trap pause_before_exit EXIT

echo "Updating project from GitHub: $PWD"
git pull --rebase --autostash

echo
echo "Project updated successfully."
