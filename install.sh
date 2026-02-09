#!/bin/bash
# Oh-My-Kiro Installer
# Usage: ./install.sh [--global] [--force] [--uninstall] [--help]
#   --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
#   --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
#   --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
#   --help       Show this help message

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
UNINSTALL=false

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
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --help|-h)
            printf "Oh-My-Kiro Installer\n"
            printf "Usage: ./install.sh [--global] [--force] [--uninstall] [--help]\n"
            printf "  --global     Install/uninstall to/from ~/.kiro/ (available in all projects)\n"
            printf "  --force      Overwrite existing files without prompting (or skip confirmation on uninstall)\n"
            printf "  --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)\n"
            printf "  --help       Show this help message\n"
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
# File manifest — everything we install (shared by install and uninstall)
# ---------------------------------------------------------------------------
AGENT_FILES="prometheus.json atlas.json sisyphus.json omk-explorer.json omk-metis.json omk-researcher.json omk-reviewer.json omk-sisyphus-jr.json"
PROMPT_FILES="prometheus.md atlas.md sisyphus.md omk-explorer.md omk-metis.md omk-researcher.md omk-reviewer.md omk-sisyphus-jr.md"
STEERING_FILES="product.md conventions.md plan-format.md architecture.md"
HOOK_FILES="agent-spawn.sh pre-tool-use.sh prometheus-read-guard.sh prometheus-write-guard.sh"
SKILL_DIRS="git-operations code-review frontend-ux"

# ---------------------------------------------------------------------------
# Uninstall logic
# ---------------------------------------------------------------------------
if [ "$UNINSTALL" = true ]; then
    printf "\n${BOLD}  Oh-My-Kiro Uninstaller${RESET}\n"
    printf "  Target: ${BOLD}%s${RESET}\n\n" "$TARGET_DIR"

    # Check if target directory exists at all
    if [ ! -d "$TARGET_DIR" ]; then
        warn "Target directory does not exist: ${TARGET_DIR}"
        info "Nothing to uninstall."
        exit 0
    fi

    # Confirmation prompt (unless --force)
    if [ "$FORCE" = false ]; then
        printf "  This will remove Oh-My-Kiro files from %s. Continue? [y/N] " "$TARGET_DIR"
        read -r answer
        case "$answer" in
            [yY]|[yY][eE][sS]) ;;
            *)
                info "Uninstall cancelled."
                exit 0
                ;;
        esac
        printf "\n"
    fi

    removed=0
    not_found=0

    # Helper: remove a single file, count result
    remove_file() {
        if [ -f "$1" ]; then
            rm -f "$1"
            removed=$((removed + 1))
            return 0
        fi
        not_found=$((not_found + 1))
        return 1
    }

    # Helper: remove directory if it exists and is empty
    remove_dir_if_empty() {
        if [ -d "$1" ] && [ -z "$(ls -A "$1" 2>/dev/null)" ]; then
            rmdir "$1"
            return 0
        fi
        return 1
    }

    # --- Agents ---
    info "Removing agents..."
    for f in $AGENT_FILES; do
        remove_file "${TARGET_DIR}/agents/${f}" || true
        remove_file "${TARGET_DIR}/agents/${f}.bak" || true
    done

    # --- Prompts ---
    info "Removing prompts..."
    for f in $PROMPT_FILES; do
        remove_file "${TARGET_DIR}/prompts/${f}" || true
        remove_file "${TARGET_DIR}/prompts/${f}.bak" || true
    done

    # --- Steering (entire omk/ directory is ours) ---
    info "Removing steering files..."
    if [ -d "${TARGET_DIR}/steering/omk" ]; then
        rm -rf "${TARGET_DIR}/steering/omk"
        removed=$((removed + 1))
    else
        not_found=$((not_found + 1))
    fi

    # --- Hooks ---
    info "Removing hooks..."
    for f in $HOOK_FILES; do
        remove_file "${TARGET_DIR}/hooks/${f}" || true
        remove_file "${TARGET_DIR}/hooks/${f}.bak" || true
    done

    # --- Skills (entire skill directories are ours) ---
    info "Removing skills..."
    for skill in $SKILL_DIRS; do
        if [ -d "${TARGET_DIR}/skills/${skill}" ]; then
            rm -rf "${TARGET_DIR}/skills/${skill}"
            removed=$((removed + 1))
        else
            not_found=$((not_found + 1))
        fi
    done

    # --- Runtime .gitkeep files ---
    info "Removing runtime files..."
    remove_file "${TARGET_DIR}/plans/.gitkeep" || true
    remove_file "${TARGET_DIR}/notepads/.gitkeep" || true

    # --- Clean up empty directories (bottom-up) ---
    info "Cleaning up empty directories..."
    dirs_removed=0
    for dir in \
        "${TARGET_DIR}/agents" \
        "${TARGET_DIR}/prompts" \
        "${TARGET_DIR}/steering" \
        "${TARGET_DIR}/hooks" \
        "${TARGET_DIR}/skills" \
        "${TARGET_DIR}/plans" \
        "${TARGET_DIR}/notepads"; do
        if remove_dir_if_empty "$dir"; then
            dirs_removed=$((dirs_removed + 1))
        fi
    done

    # --- Summary ---
    printf "\n"
    printf "${GREEN}${BOLD}  Uninstall complete!${RESET}\n\n"
    printf "  Files/dirs removed: ${BOLD}%d${RESET}\n" "$removed"
    if [ "$not_found" -gt 0 ]; then
        printf "  Already absent:     ${BOLD}%d${RESET}\n" "$not_found"
    fi
    if [ "$dirs_removed" -gt 0 ]; then
        printf "  Empty dirs cleaned: ${BOLD}%d${RESET}\n" "$dirs_removed"
    fi

    # Check what's left
    if [ -d "$TARGET_DIR" ]; then
        remaining=$(ls -A "$TARGET_DIR" 2>/dev/null)
        if [ -n "$remaining" ]; then
            printf "\n  ${YELLOW}Remaining items in %s:${RESET}\n" "$TARGET_DIR"
            for item in $remaining; do
                printf "    - %s\n" "$item"
            done
            printf "\n  These are not Oh-My-Kiro files and were left untouched.\n"
        else
            printf "\n  %s is now empty (but preserved).\n" "$TARGET_DIR"
        fi
    fi
    printf "\n"

    exit 0
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
