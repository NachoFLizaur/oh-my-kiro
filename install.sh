#!/bin/bash
# Oh-My-Kiro Installer
# Usage: ./install.sh [--global] [--force] [--uninstall] [--update] [--dry-run] [--help]
#   --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
#   --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
#   --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
#   --update     Smart update: install new, update changed, skip user-modified files
#   --dry-run    Show what --update would do without making changes
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
UPDATE=false
DRY_RUN=false

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
        --update)
            UPDATE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            printf "Oh-My-Kiro Installer\n"
            printf "Usage: ./install.sh [--global] [--force] [--uninstall] [--update] [--dry-run] [--help]\n"
            printf "  --global     Install/uninstall to/from ~/.kiro/ (available in all projects)\n"
            printf "  --force      Overwrite existing files without prompting (or skip confirmation on uninstall)\n"
            printf "  --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)\n"
            printf "  --update     Smart update: install new, update changed, skip user-modified files\n"
            printf "  --dry-run    Show what --update would do without making changes\n"
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
# Validate flag combinations
# ---------------------------------------------------------------------------
if [ "$DRY_RUN" = true ] && [ "$UPDATE" = false ]; then
    error "--dry-run can only be used with --update"
    exit 1
fi

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
AGENT_FILES="prometheus.json atlas.json sisyphus.json omk-explorer.json omk-metis.json omk-researcher.json omk-reviewer.json omk-sisyphus-jr.json omk-momus.json omk-oracle.json"
PROMPT_FILES="prometheus.md atlas.md sisyphus.md omk-explorer.md omk-metis.md omk-researcher.md omk-reviewer.md omk-sisyphus-jr.md omk-momus.md omk-oracle.md"
STEERING_FILES="product.md conventions.md plan-format.md architecture.md"
HOOK_FILES="agent-spawn.sh pre-tool-use.sh prometheus-read-guard.sh prometheus-write-guard.sh"
SKILL_DIRS="git-operations code-review frontend-ux"

# ---------------------------------------------------------------------------
# Hash helper — SHA-256 (macOS + Linux compatible)
# ---------------------------------------------------------------------------
hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | cut -d' ' -f1
    else
        openssl dgst -sha256 "$file" | awk '{print $NF}'
    fi
}

# ---------------------------------------------------------------------------
# Manifest generation — writes .omk-manifest.json to target directory
# ---------------------------------------------------------------------------
generate_manifest() {
    local target_dir="$1"
    local version="$2"
    local install_mode="$3"
    local installed_at="$4"
    local manifest_file="${target_dir}/.omk-manifest.json"
    local now
    now=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    # Use provided installedAt or default to now
    if [ -z "$installed_at" ]; then
        installed_at="$now"
    fi

    # Start JSON
    printf '{\n' > "$manifest_file"
    printf '  "version": "%s",\n' "$version" >> "$manifest_file"
    printf '  "installedAt": "%s",\n' "$installed_at" >> "$manifest_file"
    printf '  "updatedAt": "%s",\n' "$now" >> "$manifest_file"
    printf '  "installMode": "%s",\n' "$install_mode" >> "$manifest_file"
    printf '  "files": {\n' >> "$manifest_file"

    local first=true
    local hash

    # Helper to add a file entry
    add_manifest_entry() {
        local rel_path="$1"
        local full_path="${target_dir}/${rel_path}"
        if [ -f "$full_path" ]; then
            hash=$(hash_file "$full_path")
            if [ "$first" = true ]; then
                first=false
            else
                printf ',\n' >> "$manifest_file"
            fi
            printf '    "%s": { "hash": "sha256:%s", "version": "%s" }' "$rel_path" "$hash" "$version" >> "$manifest_file"
        fi
    }

    # Add all file categories
    for f in $AGENT_FILES; do add_manifest_entry "agents/$f"; done
    for f in $PROMPT_FILES; do add_manifest_entry "prompts/$f"; done
    for f in $STEERING_FILES; do add_manifest_entry "steering/omk/$f"; done
    for f in $HOOK_FILES; do add_manifest_entry "hooks/$f"; done
    for skill in $SKILL_DIRS; do add_manifest_entry "skills/$skill/SKILL.md"; done

    printf '\n  }\n}\n' >> "$manifest_file"
}

# ---------------------------------------------------------------------------
# Manifest reading helpers — extract fields without jq
# ---------------------------------------------------------------------------
get_manifest_hash() {
    local manifest="$1"
    local rel_path="$2"
    # Extract hash for a specific file path from manifest JSON
    grep "\"${rel_path}\"" "$manifest" 2>/dev/null | sed 's/.*"hash": *"sha256:\([a-f0-9]*\)".*/sha256:\1/' | head -1
}

get_manifest_field() {
    local manifest="$1"
    local field="$2"
    # Extract a top-level string field from manifest JSON
    grep "\"${field}\"" "$manifest" 2>/dev/null | head -1 | sed 's/.*: *"\(.*\)".*/\1/'
}

# Get all file paths listed in the old manifest
get_manifest_files() {
    local manifest="$1"
    # Extract lines that look like file entries: "path/to/file": { "hash": ...
    grep '"hash"' "$manifest" 2>/dev/null | sed 's/^ *"\([^"]*\)".*/\1/'
}

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

    # --- Manifest ---
    remove_file "${TARGET_DIR}/.omk-manifest.json" || true

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
# Update logic (--update flag)
# ---------------------------------------------------------------------------
if [ "$UPDATE" = true ]; then
    MANIFEST_FILE="${TARGET_DIR}/.omk-manifest.json"
    NEW_VERSION=$(grep '"version"' "${SCRIPT_DIR}/package.json" | head -1 | sed 's/.*: *"\(.*\)".*/\1/')

    if [ ! -f "$MANIFEST_FILE" ]; then
        warn "No manifest found at ${MANIFEST_FILE}. Running full install instead."
        UPDATE=false
        # Fall through to normal install below
    fi

    if [ "$UPDATE" = true ]; then
        OLD_VERSION=$(get_manifest_field "$MANIFEST_FILE" "version")
        OLD_INSTALLED_AT=$(get_manifest_field "$MANIFEST_FILE" "installedAt")

        printf "\n${BOLD}  Oh-My-Kiro Update${RESET}\n"
        printf "  Target: ${BOLD}%s${RESET}\n" "$TARGET_DIR"
        printf "  Version: ${BOLD}%s${RESET} → ${BOLD}%s${RESET}\n\n" "$OLD_VERSION" "$NEW_VERSION"

        # Collect all new source file relative paths
        NEW_SOURCE_FILES=""
        for f in $AGENT_FILES; do NEW_SOURCE_FILES="$NEW_SOURCE_FILES agents/$f"; done
        for f in $PROMPT_FILES; do NEW_SOURCE_FILES="$NEW_SOURCE_FILES prompts/$f"; done
        for f in $STEERING_FILES; do NEW_SOURCE_FILES="$NEW_SOURCE_FILES steering/omk/$f"; done
        for f in $HOOK_FILES; do NEW_SOURCE_FILES="$NEW_SOURCE_FILES hooks/$f"; done
        for skill in $SKILL_DIRS; do NEW_SOURCE_FILES="$NEW_SOURCE_FILES skills/$skill/SKILL.md"; done

        # Categorize files using the 6-case decision matrix
        FILES_INSTALL=""
        FILES_REPLACE=""
        FILES_SKIP_CURRENT=""
        FILES_SKIP_MODIFIED=""
        FILES_DELETE=""
        FILES_SKIP_DELETED=""

        count_install=0
        count_replace=0
        count_current=0
        count_modified=0
        count_delete=0
        count_skip_deleted=0

        # Check each file in the new source
        for rel_path in $NEW_SOURCE_FILES; do
            src_file="${SOURCE_DIR}/${rel_path}"
            dst_file="${TARGET_DIR}/${rel_path}"
            old_hash=$(get_manifest_hash "$MANIFEST_FILE" "$rel_path")

            if [ -z "$old_hash" ]; then
                # Case 1: Not in old manifest → NEW file
                FILES_INSTALL="$FILES_INSTALL $rel_path"
                count_install=$((count_install + 1))
            elif [ -f "$dst_file" ]; then
                disk_hash="sha256:$(hash_file "$dst_file")"
                new_hash="sha256:$(hash_file "$src_file")"

                if [ "$disk_hash" = "$new_hash" ]; then
                    # Case 3: Disk matches new → already up to date
                    FILES_SKIP_CURRENT="$FILES_SKIP_CURRENT $rel_path"
                    count_current=$((count_current + 1))
                elif [ "$disk_hash" = "$old_hash" ]; then
                    # Case 2: Disk matches old, differs from new → safe to replace
                    FILES_REPLACE="$FILES_REPLACE $rel_path"
                    count_replace=$((count_replace + 1))
                else
                    # Case 4: Disk differs from both → user modified
                    FILES_SKIP_MODIFIED="$FILES_SKIP_MODIFIED $rel_path"
                    count_modified=$((count_modified + 1))
                fi
            else
                # File in manifest but missing from disk → treat as new install
                FILES_INSTALL="$FILES_INSTALL $rel_path"
                count_install=$((count_install + 1))
            fi
        done

        # Check for files in old manifest but NOT in new source (cases 5 & 6)
        OLD_MANIFEST_FILES=$(get_manifest_files "$MANIFEST_FILE")
        for old_rel_path in $OLD_MANIFEST_FILES; do
            # Check if this file is still in the new source
            in_new=false
            for new_rel_path in $NEW_SOURCE_FILES; do
                if [ "$old_rel_path" = "$new_rel_path" ]; then
                    in_new=true
                    break
                fi
            done

            if [ "$in_new" = false ]; then
                dst_file="${TARGET_DIR}/${old_rel_path}"
                old_hash=$(get_manifest_hash "$MANIFEST_FILE" "$old_rel_path")

                if [ -f "$dst_file" ]; then
                    disk_hash="sha256:$(hash_file "$dst_file")"
                    if [ "$disk_hash" = "$old_hash" ]; then
                        # Case 5: Removed upstream, unmodified → delete
                        FILES_DELETE="$FILES_DELETE $old_rel_path"
                        count_delete=$((count_delete + 1))
                    else
                        # Case 6: Removed upstream, user modified → skip
                        FILES_SKIP_DELETED="$FILES_SKIP_DELETED $old_rel_path"
                        count_skip_deleted=$((count_skip_deleted + 1))
                    fi
                fi
                # If file doesn't exist on disk, nothing to do
            fi
        done

        # Display human-readable summary
        info "Update summary:"
        printf "\n"

        if [ "$count_install" -gt 0 ]; then
            printf "  ${GREEN}New files (will install):${RESET}\n"
            for f in $FILES_INSTALL; do
                printf "    ${GREEN}+${RESET} %s\n" "$f"
            done
            printf "\n"
        fi

        if [ "$count_replace" -gt 0 ]; then
            printf "  ${BLUE}Updated files (will replace, backup to *.bak):${RESET}\n"
            for f in $FILES_REPLACE; do
                printf "    ${BLUE}~${RESET} %s\n" "$f"
            done
            printf "\n"
        fi

        if [ "$count_current" -gt 0 ]; then
            printf "  Already up to date:\n"
            for f in $FILES_SKIP_CURRENT; do
                printf "    = %s\n" "$f"
            done
            printf "\n"
        fi

        if [ "$count_modified" -gt 0 ]; then
            printf "  ${YELLOW}Skipped (user modified):${RESET}\n"
            for f in $FILES_SKIP_MODIFIED; do
                printf "    ${YELLOW}!${RESET} %s (local changes detected)\n" "$f"
            done
            printf "\n"
        fi

        if [ "$count_delete" -gt 0 ]; then
            printf "  ${RED}Removed files (will delete, backup to *.bak):${RESET}\n"
            for f in $FILES_DELETE; do
                printf "    ${RED}-${RESET} %s\n" "$f"
            done
            printf "\n"
        fi

        if [ "$count_skip_deleted" -gt 0 ]; then
            printf "  ${YELLOW}Removed upstream but user modified (keeping):${RESET}\n"
            for f in $FILES_SKIP_DELETED; do
                printf "    ${YELLOW}!${RESET} %s (local changes detected)\n" "$f"
            done
            printf "\n"
        fi

        total_skipped=$((count_modified + count_skip_deleted))
        printf "  Summary: ${BOLD}%d${RESET} new, ${BOLD}%d${RESET} updated, ${BOLD}%d${RESET} current, ${BOLD}%d${RESET} skipped, ${BOLD}%d${RESET} removed\n\n" \
            "$count_install" "$count_replace" "$count_current" "$total_skipped" "$count_delete"

        # Dry run: show summary and exit
        if [ "$DRY_RUN" = true ]; then
            info "Dry run — no changes applied."
            exit 0
        fi

        # Nothing to do?
        changes=$((count_install + count_replace + count_delete))
        if [ "$changes" -eq 0 ]; then
            ok "Everything is up to date. No changes needed."
            exit 0
        fi

        # Confirmation prompt (unless --force)
        if [ "$FORCE" = false ]; then
            printf "  Proceed? [y/N] "
            read -r answer
            case "$answer" in
                [yY]|[yY][eE][sS]) ;;
                *)
                    info "Update cancelled."
                    exit 0
                    ;;
            esac
            printf "\n"
        fi

        # Apply changes
        update_errors=0

        # Install new files
        for rel_path in $FILES_INSTALL; do
            src_file="${SOURCE_DIR}/${rel_path}"
            dst_file="${TARGET_DIR}/${rel_path}"
            dst_dir=$(dirname "$dst_file")
            mkdir -p "$dst_dir"
            if cp "$src_file" "$dst_file"; then
                # Make hooks executable
                case "$rel_path" in hooks/*) chmod +x "$dst_file" ;; esac
                ok "  Installed: ${rel_path}"
            else
                error "  Failed to install: ${rel_path}"
                update_errors=$((update_errors + 1))
            fi
        done

        # Replace updated files (backup first)
        for rel_path in $FILES_REPLACE; do
            src_file="${SOURCE_DIR}/${rel_path}"
            dst_file="${TARGET_DIR}/${rel_path}"
            if [ -f "$dst_file" ]; then
                cp "$dst_file" "${dst_file}.bak"
            fi
            if cp "$src_file" "$dst_file"; then
                case "$rel_path" in hooks/*) chmod +x "$dst_file" ;; esac
                ok "  Updated: ${rel_path}"
            else
                error "  Failed to update: ${rel_path}"
                update_errors=$((update_errors + 1))
            fi
        done

        # Delete removed files (backup first)
        for rel_path in $FILES_DELETE; do
            dst_file="${TARGET_DIR}/${rel_path}"
            if [ -f "$dst_file" ]; then
                cp "$dst_file" "${dst_file}.bak"
                rm -f "$dst_file"
                ok "  Removed: ${rel_path} (backed up to ${rel_path}.bak)"
            fi
        done

        # Write updated manifest
        INSTALL_MODE="local"
        [ "$GLOBAL_INSTALL" = true ] && INSTALL_MODE="global"
        generate_manifest "$TARGET_DIR" "$NEW_VERSION" "$INSTALL_MODE" "$OLD_INSTALLED_AT"
        ok "Manifest updated"

        # Summary
        printf "\n"
        if [ "$update_errors" -gt 0 ]; then
            error "Update completed with ${update_errors} error(s)."
            exit 1
        fi

        printf "${GREEN}${BOLD}  Update complete!${RESET}\n\n"
        printf "  Version: ${BOLD}%s${RESET} → ${BOLD}%s${RESET}\n" "$OLD_VERSION" "$NEW_VERSION"
        printf "  Files installed: ${BOLD}%d${RESET}\n" "$count_install"
        printf "  Files updated:   ${BOLD}%d${RESET}\n" "$count_replace"
        printf "  Files removed:   ${BOLD}%d${RESET}\n" "$count_delete"
        if [ "$total_skipped" -gt 0 ]; then
            printf "  Files skipped:   ${BOLD}%d${RESET} (user modified)\n" "$total_skipped"
        fi
        printf "\n"

        exit 0
    fi
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
# Write manifest after fresh install
# ---------------------------------------------------------------------------
info "Writing manifest..."
VERSION=$(grep '"version"' "${SCRIPT_DIR}/package.json" | head -1 | sed 's/.*: *"\(.*\)".*/\1/')
INSTALL_MODE="local"
[ "$GLOBAL_INSTALL" = true ] && INSTALL_MODE="global"
generate_manifest "$TARGET_DIR" "$VERSION" "$INSTALL_MODE" ""
ok "Manifest written: .omk-manifest.json"

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
printf "\n  Docs: https://github.com/NachoFLizaur/oh-my-kiro\n\n"
