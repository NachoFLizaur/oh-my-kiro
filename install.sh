#!/bin/bash
# Oh-My-Kiro Installer
# Usage: ./install.sh [--global] [--force] [--help]
#   --global  Install to ~/.kiro/ (available in all projects)
#   --force   Overwrite existing files without prompting
#   --help    Show this help message
#
# To uninstall, remove the installed .kiro/ directory:
#   Local:  rm -rf .kiro/
#   Global: rm -rf ~/.kiro/

set -e

# ---------------------------------------------------------------------------
# Resolve source directory relative to this script's location
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SOURCE_DIR="${SCRIPT_DIR}/.kiro"

# ---------------------------------------------------------------------------
# Color helpers (disabled when stdout is not a terminal)
# ---------------------------------------------------------------------------
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    BOLD=''
    RESET=''
fi

info()  { printf "${BLUE}[info]${RESET}  %s\n" "$1"; }
ok()    { printf "${GREEN}[ok]${RESET}    %s\n" "$1"; }
warn()  { printf "${YELLOW}[warn]${RESET}  %s\n" "$1"; }
error() { printf "${RED}[error]${RESET} %s\n" "$1" >&2; }

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
GLOBAL_INSTALL=false
FORCE=false

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
while [ $# -gt 0 ]; do
    case "$1" in
        --global)
            GLOBAL_INSTALL=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help|-h)
            sed -n '2,11p' "$0" | sed 's/^#//' | sed 's/^ //'
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            error "Run './install.sh --help' for usage."
            exit 1
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Determine target directory
# ---------------------------------------------------------------------------
if [ "$GLOBAL_INSTALL" = true ]; then
    TARGET_DIR="${HOME}/.kiro"
else
    TARGET_DIR="${PWD}/.kiro"
fi

# ---------------------------------------------------------------------------
# Banner
# ---------------------------------------------------------------------------
printf "\n${BOLD}  Oh-My-Kiro Installer${RESET}\n"
printf "  Target: ${BOLD}%s${RESET}\n\n" "$TARGET_DIR"

# ---------------------------------------------------------------------------
# Pre-flight checks
# ---------------------------------------------------------------------------
preflight_ok=true

# 1. Check for kiro-cli
if command -v kiro-cli >/dev/null 2>&1; then
    ok "kiro-cli found: $(command -v kiro-cli)"
else
    warn "kiro-cli not found in PATH — Oh-My-Kiro requires Kiro to work."
    warn "Install Kiro first: https://kiro.dev"
    # Not fatal — user may install kiro-cli later
fi

# 2. Verify source files exist
if [ ! -d "$SOURCE_DIR" ]; then
    error "Source directory not found: ${SOURCE_DIR}"
    error "Are you running install.sh from the Oh-My-Kiro repository?"
    exit 1
fi

if [ ! -d "${SOURCE_DIR}/agents" ] || [ ! -d "${SOURCE_DIR}/prompts" ]; then
    error "Source directory is missing expected subdirectories (agents/, prompts/)."
    exit 1
fi

ok "Source directory verified: ${SOURCE_DIR}"

# 3. Check if target already has oh-my-kiro files
if [ -d "$TARGET_DIR" ] && [ "$FORCE" = false ]; then
    # Look for a known oh-my-kiro marker file
    if [ -f "${TARGET_DIR}/agents/prometheus.json" ] || \
       [ -f "${TARGET_DIR}/prompts/prometheus.md" ]; then
        warn "Existing Oh-My-Kiro files detected in ${TARGET_DIR}"
        printf "\n"
        printf "  Existing files will be backed up to *.bak before overwriting.\n"
        printf "  Use --force to skip this prompt.\n\n"
        printf "  Continue? [y/N] "
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) ;;
            *)
                info "Installation cancelled."
                exit 0
                ;;
        esac
    fi
fi

# ---------------------------------------------------------------------------
# File manifest — everything we install
# ---------------------------------------------------------------------------
AGENT_FILES="prometheus.json atlas.json sisyphus.json omk-explorer.json omk-metis.json omk-researcher.json omk-reviewer.json omk-sisyphus-jr.json"
PROMPT_FILES="prometheus.md atlas.md sisyphus.md omk-explorer.md omk-metis.md omk-researcher.md omk-reviewer.md omk-sisyphus-jr.md"
STEERING_FILES="product.md conventions.md plan-format.md architecture.md"
HOOK_FILES="agent-spawn.sh pre-tool-use.sh prometheus-read-guard.sh prometheus-write-guard.sh"
SKILL_DIRS="git-operations code-review frontend-ux"

# ---------------------------------------------------------------------------
# Helper: copy a file, backing up the target if it already exists
# ---------------------------------------------------------------------------
copy_file() {
    local src="$1"
    local dst="$2"

    if [ ! -f "$src" ]; then
        warn "Source file missing, skipping: ${src}"
        return 1
    fi

    # Backup existing file (unless --force)
    if [ -f "$dst" ] && [ "$FORCE" = false ]; then
        cp "$dst" "${dst}.bak"
    fi

    cp "$src" "$dst"
    return 0
}

# ---------------------------------------------------------------------------
# Installation
# ---------------------------------------------------------------------------
installed=0
skipped=0

# --- Agents ---
info "Installing agents..."
mkdir -p "${TARGET_DIR}/agents"
for f in $AGENT_FILES; do
    if copy_file "${SOURCE_DIR}/agents/${f}" "${TARGET_DIR}/agents/${f}"; then
        installed=$((installed + 1))
    else
        skipped=$((skipped + 1))
    fi
done

# --- Prompts ---
info "Installing prompts..."
mkdir -p "${TARGET_DIR}/prompts"
for f in $PROMPT_FILES; do
    if copy_file "${SOURCE_DIR}/prompts/${f}" "${TARGET_DIR}/prompts/${f}"; then
        installed=$((installed + 1))
    else
        skipped=$((skipped + 1))
    fi
done

# --- Steering ---
info "Installing steering files..."
mkdir -p "${TARGET_DIR}/steering/omk"
for f in $STEERING_FILES; do
    if copy_file "${SOURCE_DIR}/steering/omk/${f}" "${TARGET_DIR}/steering/omk/${f}"; then
        installed=$((installed + 1))
    else
        skipped=$((skipped + 1))
    fi
done

# --- Hooks ---
info "Installing hooks..."
mkdir -p "${TARGET_DIR}/hooks"
for f in $HOOK_FILES; do
    if copy_file "${SOURCE_DIR}/hooks/${f}" "${TARGET_DIR}/hooks/${f}"; then
        chmod +x "${TARGET_DIR}/hooks/${f}"
        installed=$((installed + 1))
    else
        skipped=$((skipped + 1))
    fi
done

# --- Skills ---
info "Installing skills..."
for skill in $SKILL_DIRS; do
    mkdir -p "${TARGET_DIR}/skills/${skill}"
    if copy_file "${SOURCE_DIR}/skills/${skill}/SKILL.md" "${TARGET_DIR}/skills/${skill}/SKILL.md"; then
        installed=$((installed + 1))
    else
        skipped=$((skipped + 1))
    fi
done

# --- Runtime directories ---
info "Creating runtime directories..."
mkdir -p "${TARGET_DIR}/plans"
mkdir -p "${TARGET_DIR}/notepads"
touch "${TARGET_DIR}/plans/.gitkeep"
touch "${TARGET_DIR}/notepads/.gitkeep"

# ---------------------------------------------------------------------------
# Post-install validation
# ---------------------------------------------------------------------------
printf "\n"
info "Validating installation..."

errors=0

# Check a representative file from each category
for check_file in \
    "agents/prometheus.json" \
    "prompts/prometheus.md" \
    "steering/omk/product.md" \
    "hooks/agent-spawn.sh" \
    "skills/git-operations/SKILL.md" \
    "plans/.gitkeep" \
    "notepads/.gitkeep"; do
    if [ -f "${TARGET_DIR}/${check_file}" ]; then
        ok "  ${check_file}"
    else
        error "  Missing: ${check_file}"
        errors=$((errors + 1))
    fi
done

# Verify hooks are executable
for f in $HOOK_FILES; do
    if [ -f "${TARGET_DIR}/hooks/${f}" ] && [ ! -x "${TARGET_DIR}/hooks/${f}" ]; then
        error "  Hook not executable: hooks/${f}"
        errors=$((errors + 1))
    fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
printf "\n"
if [ "$errors" -gt 0 ]; then
    error "Installation completed with ${errors} error(s)."
    printf "\n"
    exit 1
fi

printf "${GREEN}${BOLD}  Installation complete!${RESET}\n\n"
printf "  Files installed: ${BOLD}%d${RESET}\n" "$installed"
if [ "$skipped" -gt 0 ]; then
    printf "  Files skipped:   ${BOLD}%d${RESET} (source missing)\n" "$skipped"
fi
printf "  Target:          ${BOLD}%s${RESET}\n" "$TARGET_DIR"

printf "\n${BOLD}  Next steps:${RESET}\n"
if [ "$GLOBAL_INSTALL" = true ]; then
    printf "  1. Open any project in Kiro — Oh-My-Kiro agents are available globally.\n"
else
    printf "  1. Open this project in Kiro — Oh-My-Kiro agents are ready to use.\n"
fi
printf "  2. Start a conversation with the ${BOLD}Prometheus${RESET} agent for planning.\n"
printf "  3. Use ${BOLD}Sisyphus${RESET} for execution or ${BOLD}Atlas${RESET} for exploration.\n"
printf "\n  Docs: https://github.com/nflizaur/oh-my-kiro\n\n"
