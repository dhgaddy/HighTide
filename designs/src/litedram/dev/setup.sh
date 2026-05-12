#!/bin/bash
#
# Set up a Python venv for regenerating litedram_core.v.
# Mirrors designs/src/liteeth/dev/setup.sh — pinned pip + migen/litex/litedram
# commits to keep dev-mode RTL bit-reproducible.

set -e

echo "Starting Setup..."

export LITEDRAM_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/repo" && pwd)"
export LITEDRAM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$LITEDRAM_DIR" && echo "Working in directory: $(pwd)"

if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
fi

echo "Activating virtual environment..."
source .venv/bin/activate

check_package() {
    ! pip show "$1" &>/dev/null
}

install_git_package() {
    local package_name="$1"
    local repo_url="$2"
    local commit_hash="$3"

    echo "Installing $package_name (this may take a while)..."
    if pip install --no-cache-dir "git+${repo_url}@${commit_hash}" 2>/dev/null; then
        echo "Successfully installed $package_name"
        return 0
    fi
    echo "$package_name installation failed!" >&2
    return 1
}

if pip --version 2>/dev/null | grep -q "25.1.1"; then
    echo "Pip 25.1.1 is already installed, skipping upgrade..."
else
    echo "Installing/upgrading pip to 25.1.1..."
    pip install --upgrade pip==25.1.1 --no-cache-dir
fi

echo "Checking Python packages..."

if check_package PyYAML; then
    echo "Installing PyYAML..."
    pip install --no-cache-dir pyyaml==6.0.2
fi

if check_package migen; then
    install_git_package "MiGen" "https://github.com/m-labs/migen.git" "4c2ae8dfeea37f235b52acb8166f12acaaae4f7c"
fi

if check_package litex; then
    install_git_package "LiteX" "https://github.com/enjoy-digital/litex.git" "a25eeecd27309b2a04a9cf74a1d4849e38ff2090"
fi

# Install LiteDRAM from the submodule checkout so the version stays in lockstep
# with whatever sha .gitmodules + the submodule commit point at.
if check_package litedram; then
    echo "Installing LiteDRAM (editable) from $LITEDRAM_REPO ..."
    pip install --no-cache-dir -e "$LITEDRAM_REPO"
fi

REPO_LICENSE="$LITEDRAM_REPO/LICENSE"
PARENT_LICENSE="../LICENSE"

if [ ! -f "$PARENT_LICENSE" ]; then
    echo "Copying $REPO_LICENSE -> $(cd .. && pwd)/LICENSE"
    cp -u "$REPO_LICENSE" "$PARENT_LICENSE"
else
    echo "LICENSE file already exists at parent directory, skipping copy"
fi

echo "Finished Initial Setup"
