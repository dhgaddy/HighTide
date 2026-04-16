#!/bin/bash
# Sync the ORFS Docker image/sha256 in MODULE.bazel with the pinned
# bazel-orfs commit's LATEST_ORFS_IMAGE. Optionally bump bazel-orfs
# to HEAD first.
#
# Usage:
#   ./tools/bump_orfs.sh             # sync image to match pinned bazel-orfs
#   ./tools/bump_orfs.sh --latest    # bump bazel-orfs to main HEAD, then sync
#   ./tools/bump_orfs.sh --check     # verify sync, exit 1 on mismatch (for CI)
#
# Requires: gh CLI authenticated to github.com.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
MODULE="$REPO_DIR/MODULE.bazel"
BAZEL_ORFS_REPO="The-OpenROAD-Project/bazel-orfs"

MODE="sync"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --latest) MODE="latest"; shift ;;
        --check)  MODE="check"; shift ;;
        -h|--help)
            sed -n '2,/^$/s/^# \{0,1\}//p' "$0"
            exit 0
            ;;
        *) echo "ERROR: unknown argument: $1" >&2; exit 1 ;;
    esac
done

# Extract current pinned commit from MODULE.bazel
current_commit=$(grep -oP 'commit\s*=\s*"\K[0-9a-f]{40}' "$MODULE" | head -1)
if [[ -z "$current_commit" ]]; then
    echo "ERROR: could not find bazel-orfs commit in $MODULE" >&2
    exit 1
fi

if [[ "$MODE" == "latest" ]]; then
    echo "Fetching latest bazel-orfs main..."
    target_commit=$(gh api "repos/$BAZEL_ORFS_REPO/commits/main" --jq '.sha')
else
    target_commit="$current_commit"
fi

echo "bazel-orfs commit: $target_commit"

# Read extension.bzl at the target commit and extract image constants
ext_bzl=$(gh api "repos/$BAZEL_ORFS_REPO/contents/extension.bzl?ref=$target_commit" \
    --jq '.content' | base64 -d)

target_image=$(echo "$ext_bzl" | grep -oP 'LATEST_ORFS_IMAGE\s*=\s*"\K[^"]+')
target_sha256=$(echo "$ext_bzl" | grep -oP 'LATEST_ORFS_SHA256\s*=\s*"\K[^"]+')

if [[ -z "$target_image" || -z "$target_sha256" ]]; then
    echo "ERROR: could not extract LATEST_ORFS_IMAGE/SHA256 from bazel-orfs@$target_commit" >&2
    echo "This commit may be too old — bump bazel-orfs with --latest first." >&2
    exit 1
fi

echo "Image:  $target_image"
echo "Sha256: $target_sha256"

# Current values in MODULE.bazel
current_image=$(grep -oP 'image\s*=\s*"\K[^"]+' "$MODULE" | head -1)
current_sha256=$(grep -oP 'sha256\s*=\s*"\K[0-9a-f]{64}' "$MODULE" | head -1)

if [[ "$MODE" == "check" ]]; then
    ok=true
    if [[ "$current_commit" != "$target_commit" ]]; then
        echo "MISMATCH: bazel-orfs commit $current_commit != $target_commit" >&2
        ok=false
    fi
    if [[ "$current_image" != "$target_image" ]]; then
        echo "MISMATCH: image $current_image != $target_image" >&2
        ok=false
    fi
    if [[ "$current_sha256" != "$target_sha256" ]]; then
        echo "MISMATCH: sha256 $current_sha256 != $target_sha256" >&2
        ok=false
    fi
    if $ok; then
        echo "OK: MODULE.bazel in sync with bazel-orfs@$target_commit"
        exit 0
    fi
    exit 1
fi

# Apply updates in-place
if [[ "$current_commit" != "$target_commit" ]]; then
    sed -i "s|$current_commit|$target_commit|" "$MODULE"
fi
if [[ "$current_image" != "$target_image" ]]; then
    sed -i "s|$current_image|$target_image|" "$MODULE"
fi
if [[ "$current_sha256" != "$target_sha256" ]]; then
    sed -i "s|$current_sha256|$target_sha256|" "$MODULE"
fi

if git -C "$REPO_DIR" diff --quiet -- "$MODULE"; then
    echo "MODULE.bazel already up-to-date."
else
    echo "MODULE.bazel updated. Review with: git diff MODULE.bazel"
fi
