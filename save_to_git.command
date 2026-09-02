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

commit_message="${1:-Update PipelinedRV32IM}"

echo "Saving changes in: $PWD"
git add -A

if git diff --cached --quiet; then
	echo "No new changes to commit."
else
	echo "Creating commit: $commit_message"
	git commit -m "$commit_message"
fi

echo "Syncing with GitHub..."
git pull --rebase
git push

echo
echo "Project saved to GitHub successfully."
