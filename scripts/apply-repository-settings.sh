#!/usr/bin/env bash
# Applies this account's repository settings to one repository.
#
# Settings are decisions, and a decision nobody wrote down cannot be reviewed
# and quietly drifts. This is where they are written down. Idempotent: running
# it again puts back a setting changed by hand.
#
# Run it with no arguments and it asks which repository and which settings.
# Pass --repo and --only and it asks nothing, which is what a script calling
# this one wants.
#
#   scripts/apply-repository-settings.sh
#   scripts/apply-repository-settings.sh --repo me/project
#   scripts/apply-repository-settings.sh --repo me/project --only merges,labels
#
# Some settings are not available on every repository — private vulnerability
# reporting is a public-repository feature, secret scanning and an
# environment's required reviewers need a plan that includes them. Those
# report as skipped rather than failed: a repository that cannot have a
# feature is not one configured wrongly.
set -euo pipefail

SETTING_GROUPS=(merges security ruleset labels release)

group_title() {
	case "$1" in
	merges) echo "Merges" ;;
	security) echo "Security" ;;
	ruleset) echo "Branch ruleset" ;;
	labels) echo "Labels" ;;
	release) echo "Release gate" ;;
	esac
}

group_summary() {
	case "$1" in
	merges) echo "rebase only, head branch deleted, issues and discussions on" ;;
	security) echo "Dependabot, secret scanning, private vulnerability reporting, CodeQL" ;;
	ruleset) echo "pull request required, CI green, conversations resolved, linear history" ;;
	labels) echo "the labels automation opens issues with" ;;
	release) echo "the 'release' environment publishing is gated by, and immutable releases" ;;
	esac
}

# Only the labels the generated project's own automation opens issues and
# pull requests with: how a maintainer triages by hand is theirs to decide,
# not the template's. Color and description are part of the definition — a
# label created on the fly by `gh issue create --label` gets neither.
LABELS=(
	"release|5319e7|Opened by release-plz to prepare a version"
	"template-update|5319e7|The project template moved ahead of this repository"
)

# The branch protection, as a ruleset rather than the older branch-protection
# API: rulesets are what GitHub documents going forward, and they read back as
# one object instead of a scatter of flags.
#
# No required approvals — a rule demanding a review a lone maintainer cannot
# give gets bypassed rather than followed. Required instead: the pull request
# itself, so every change has a place to be discussed, and that nothing
# merges over an open conversation.
#
# And that CI passed. Without this the gate is advice: every workflow can be
# red and the merge button stays green.
#
# The checks named are the ones that report on a branch push as well as on a
# pull request. A pull request opened by automation with GITHUB_TOKEN gets no
# `pull_request` run, so requiring a check that only runs on that event would
# leave the release pull request permanently unmergeable. The DCO and
# Conventional Commit checks are exactly such checks: they read `base..head`
# and exist only for a pull request. They still block a human's merge through
# the pull request's own status; a required rule that deadlocks is a rule
# someone disables.
#
# The five platforms are listed individually because that is what claiming to
# support them means: a change that breaks aarch64 Windows does not merge.
#
# `strict: false` — a required rebase onto main before every merge serializes
# the queue for a guarantee that a linear history already mostly provides.
#
# Only the checks every generated project reports are named. `linux-musl` and
# `package` exist for some answers and not others, and `coverage` runs on the
# default branch alone — requiring a check that never reports on a pull
# request blocks every merge, so those three block nothing and are read.
#
# The checks required also depend on which repository this is: the template
# itself reports only its test suite and the workflow audit. A copier.yml at
# the root is what tells them apart — only the template carries one.
ruleset_payload() {
	local repo="$1" contexts
	if gh api --silent "repos/$repo/contents/copier.yml" >/dev/null 2>&1; then
		contexts='{ "context": "template" },
          { "context": "Workflow syntax" }'
	else
		contexts='{ "context": "lint" },
          { "context": "features" },
          { "context": "test" },
          { "context": "linux-aarch64" },
          { "context": "macos-aarch64" },
          { "context": "macos-x86_64" },
          { "context": "windows-aarch64" },
          { "context": "windows-x86_64" },
          { "context": "Workflow syntax" }'
	fi
	cat <<-JSON
		{
		  "name": "default branch",
		  "target": "branch",
		  "enforcement": "active",
		  "conditions": { "ref_name": { "include": ["~DEFAULT_BRANCH"], "exclude": [] } },
		  "rules": [
		    { "type": "deletion" },
		    { "type": "non_fast_forward" },
		    { "type": "required_linear_history" },
		    {
		      "type": "pull_request",
		      "parameters": {
		        "required_approving_review_count": 0,
		        "dismiss_stale_reviews_on_push": false,
		        "require_code_owner_review": false,
		        "require_last_push_approval": false,
		        "required_review_thread_resolution": true,
		        "allowed_merge_methods": ["rebase"]
		      }
		    },
		    {
		      "type": "required_status_checks",
		      "parameters": {
		        "strict_required_status_checks_policy": false,
		        "do_not_enforce_on_create": false,
		        "required_status_checks": [
		          $contexts
		        ]
		      }
		    }
		  ]
		}
	JSON
}

note() { printf '  %s\n' "$*"; }
skipped() { printf '  skipped: %s\n' "$*"; }
die() {
	printf 'error: %s\n' "$*" >&2
	exit 1
}

# Runs a `gh` call whose failure means "this repository cannot have that",
# not "this script is broken".
optional() {
	local description="$1"
	shift
	if output="$("$@" 2>&1)"; then
		note "$description"
	else
		skipped "$description — ${output##*$'\n'}"
	fi
}

# ---------------------------------------------------------------- the work

apply_merges() {
	local repo="$1"
	# Rebase only, and the ruleset below allows nothing else either.
	#
	# The required linear history already rules out a merge commit, so the
	# choice is rebase or squash. Rebase, because everything else here is
	# addressed to the individual commit: each is asked to be atomic and to
	# pass the gate on its own, and each carries the Conventional Commit
	# subject the changelog is built from and the sign-off CI checks. A
	# squash would land one commit whose message came from the pull request
	# form, and none of that would survive.
	gh repo edit "$repo" \
		--enable-rebase-merge \
		--enable-squash-merge=false \
		--enable-merge-commit=false \
		--delete-branch-on-merge \
		--enable-issues \
		--enable-discussions \
		--enable-wiki=false >/dev/null
	note "rebase-only merges, head branch deleted, issues and discussions on"
}

apply_security() {
	local repo="$1" visibility="$2"

	optional "Dependabot alerts" \
		gh api --silent -X PUT "repos/$repo/vulnerability-alerts"
	optional "Dependabot security updates" \
		gh api --silent -X PUT "repos/$repo/automated-security-fixes"

	if [ "$visibility" = "public" ]; then
		optional "private vulnerability reporting" \
			gh api --silent -X PUT "repos/$repo/private-vulnerability-reporting"
	else
		skipped "private vulnerability reporting — public repositories only"
	fi

	optional "secret scanning with push protection" \
		gh repo edit "$repo" --enable-secret-scanning --enable-secret-scanning-push-protection

	# The one static analysis in the set that follows data rather than reading
	# configuration: CodeQL traces untrusted input to the places it can do
	# harm. Default setup rather than a workflow here, so GitHub keeps the
	# query packs current instead of this repository pinning them. Rust is a
	# supported language since October 2025; free on public repositories.
	optional "CodeQL default setup" \
		gh api --silent -X PATCH "repos/$repo/code-scanning/default-setup" \
		-f state=configured
}

apply_ruleset() {
	local repo="$1" existing

	existing="$(gh api "repos/$repo/rulesets" --jq '.[] | select(.name == "default branch") | .id' 2>/dev/null || true)"
	if [ -n "$existing" ]; then
		ruleset_payload "$repo" | gh api --silent -X PUT "repos/$repo/rulesets/$existing" --input - >/dev/null
		note "ruleset updated: pull request required, conversations resolved, linear history, rebase only"
	else
		ruleset_payload "$repo" | gh api --silent -X POST "repos/$repo/rulesets" --input - >/dev/null
		note "ruleset created: pull request required, conversations resolved, linear history, rebase only"
	fi
}

apply_labels() {
	local repo="$1" label name color description
	for label in "${LABELS[@]}"; do
		IFS='|' read -r name color description <<<"$label"
		gh label create "$name" --repo "$repo" --color "$color" \
			--description "$description" --force >/dev/null
	done
	note "${#LABELS[@]} labels"
}

apply_release() {
	local repo="$1" reviewer_id reviewer_login
	reviewer_login="$(gh api user --jq .login)"
	reviewer_id="$(gh api user --jq .id)"

	# The environment named by the generated release workflow, whichever kind
	# of project it is. Its reviewer is what makes the gate stop — without one
	# the job runs straight through, and neither a published version nor a
	# pushed tag is meant to be taken back.
	#
	# For a library it is also part of the identity crates.io checks under
	# Trusted Publishing: a publisher is a repository, a workflow file and an
	# environment together, so a token minted anywhere else cannot publish.
	gh api --silent -X PUT "repos/$repo/environments/release" >/dev/null
	optional "release environment, held for review by @$reviewer_login" \
		gh api --silent -X PUT "repos/$repo/environments/release" \
		-F "reviewers[][type]=User" -F "reviewers[][id]=$reviewer_id" \
		-F "deployment_branch_policy=null"

	# A release that can be edited after publication is a release nobody can
	# verify: the attestation signed at build time keeps naming assets that
	# may no longer be the ones attached. Immutability closes that — once
	# published, a release's tag and assets cannot be moved, replaced or
	# deleted.
	optional "immutable releases" \
		gh api --silent -X PUT "repos/$repo/immutable-releases"
}

apply_group() {
	case "$1" in
	merges) apply_merges "$2" ;;
	security) apply_security "$2" "$3" ;;
	ruleset) apply_ruleset "$2" ;;
	labels) apply_labels "$2" ;;
	release) apply_release "$2" ;;
	esac
}

# ---------------------------------------------------------------- asking

contains() {
	local needle="$1" item
	shift
	for item in "$@"; do
		[ "$item" = "$needle" ] && return 0
	done
	return 1
}

ask_repository() {
	local owner repositories=() choice index=1

	owner="$(gh api user --jq .login)"
	mapfile -t repositories < <(gh repo list "$owner" --limit 30 --json nameWithOwner --jq '.[].nameWithOwner')

	printf 'Which repository?\n\n' >&2
	for repository in "${repositories[@]}"; do
		printf '  %2d  %s\n' "$index" "$repository" >&2
		index=$((index + 1))
	done
	printf '\nPick a number, or type owner/repo: ' >&2
	read -r choice

	if [[ "$choice" =~ ^[0-9]+$ ]]; then
		[ "$choice" -ge 1 ] && [ "$choice" -le ${#repositories[@]} ] ||
			die "there is no repository $choice in that list"
		printf '%s' "${repositories[$((choice - 1))]}"
	else
		[ -n "$choice" ] || die "no repository given"
		printf '%s' "$choice"
	fi
}

ask_groups() {
	local selected=("${SETTING_GROUPS[@]}") reply index group mark

	while true; do
		printf '\nWhich settings?\n\n' >&2
		index=1
		for group in "${SETTING_GROUPS[@]}"; do
			if contains "$group" "${selected[@]+"${selected[@]}"}"; then mark="x"; else mark=" "; fi
			printf '  [%s] %d  %-15s %s\n' "$mark" "$index" "$(group_title "$group")" "$(group_summary "$group")" >&2
			index=$((index + 1))
		done
		printf '\nPress Enter to apply the settings marked [x]. Numbers toggle one, "a" marks all, "n" none: ' >&2
		read -r reply

		case "$reply" in
		"")
			[ ${#selected[@]} -gt 0 ] || die "nothing selected"
			printf '%s\n' "${selected[@]}"
			return
			;;
		a | A) selected=("${SETTING_GROUPS[@]}") ;;
		n | N) selected=() ;;
		*)
			for choice in $reply; do
				# Anything unrecognised gets said so, because a menu that
				# silently redraws reads as a menu that ignored you.
				if ! [[ "$choice" =~ ^[0-9]+$ ]]; then
					printf '  "%s" is not an option — a number, "a", "n", or Enter to apply.\n' "$choice" >&2
					continue
				fi
				if ! { [ "$choice" -ge 1 ] && [ "$choice" -le ${#SETTING_GROUPS[@]} ]; }; then
					printf '  there is no setting %s — numbers run 1 to %d.\n' "$choice" ${#SETTING_GROUPS[@]} >&2
					continue
				fi
				group="${SETTING_GROUPS[$((choice - 1))]}"
				if contains "$group" "${selected[@]+"${selected[@]}"}"; then
					local kept=()
					for item in "${selected[@]}"; do
						[ "$item" = "$group" ] || kept+=("$item")
					done
					selected=("${kept[@]+"${kept[@]}"}")
				else
					selected+=("$group")
				fi
			done
			;;
		esac
	done
}

usage() {
	cat <<-'TEXT'
		Applies this account's repository settings to one repository.

		  --repo OWNER/NAME   the repository; asked for when absent
		  --only A,B          which settings to apply; asked for when absent
		  --help              this

		Settings: merges, security, ruleset, labels, release
	TEXT
}

main() {
	local repo="" only="" selected=() group visibility

	while [ $# -gt 0 ]; do
		case "$1" in
		--repo | -r)
			repo="${2:-}"
			shift 2
			;;
		--only | -o)
			only="${2:-}"
			shift 2
			;;
		--help | -h)
			usage
			return 0
			;;
		*) die "unknown argument: $1" ;;
		esac
	done

	command -v gh >/dev/null || die "the GitHub CLI (gh) is not installed"
	gh auth status >/dev/null 2>&1 || die "not signed in — run 'gh auth login'"

	if [ -z "$repo" ]; then
		[ -t 0 ] || die "no --repo given, and nothing here to ask"
		repo="$(ask_repository)"
	fi

	if [ -n "$only" ]; then
		IFS=',' read -r -a selected <<<"$only"
		for group in "${selected[@]}"; do
			contains "$group" "${SETTING_GROUPS[@]}" || die "there is no setting called '$group'"
		done
	elif [ -t 0 ]; then
		mapfile -t selected < <(ask_groups)
	else
		selected=("${SETTING_GROUPS[@]}")
	fi

	# Lower-cased: the field comes back as PUBLIC/PRIVATE.
	visibility="$(gh repo view "$repo" --json visibility --jq '.visibility | ascii_downcase')" ||
		die "cannot read $repo — check the name and that you have access"

	printf '\n%s (%s)\n' "$repo" "$visibility"
	for group in "${selected[@]}"; do
		apply_group "$group" "$repo" "$visibility"
	done
	printf '\nDone.\n'
}

main "$@"
