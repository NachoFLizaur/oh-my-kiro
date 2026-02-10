#!/usr/bin/env node

// Oh-My-Kiro CLI Installer
// Usage: npx oh-my-kiro [--global] [--force] [--uninstall] [--update] [--dry-run] [--help]
//   --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
//   --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
//   --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
//   --update     Smart update: install new files, update changed files, skip user-modified files
//   --dry-run    Show what --update would do without making changes
//   --help       Show this help message

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
import crypto from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';
import readline from 'node:readline/promises';

// ---------------------------------------------------------------------------
// Resolve source directory relative to this script's location
// ---------------------------------------------------------------------------
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const SOURCE_DIR = path.resolve(__dirname, '..', '.kiro');

// ---------------------------------------------------------------------------
// Color helpers (disabled when stdout is not a terminal)
// ---------------------------------------------------------------------------
const isTTY = process.stdout.isTTY;
const RED = isTTY ? '\x1b[0;31m' : '';
const GREEN = isTTY ? '\x1b[0;32m' : '';
const YELLOW = isTTY ? '\x1b[0;33m' : '';
const BLUE = isTTY ? '\x1b[0;34m' : '';
const BOLD = isTTY ? '\x1b[1m' : '';
const RESET = isTTY ? '\x1b[0m' : '';

const info = (msg) => process.stdout.write(`${BLUE}[info]${RESET}  ${msg}\n`);
const ok = (msg) => process.stdout.write(`${GREEN}[ok]${RESET}    ${msg}\n`);
const warn = (msg) => process.stdout.write(`${YELLOW}[warn]${RESET}  ${msg}\n`);
const error = (msg) => process.stderr.write(`${RED}[error]${RESET} ${msg}\n`);

// ---------------------------------------------------------------------------
// Defaults
// ---------------------------------------------------------------------------
let globalInstall = false;
let force = false;
let uninstall = false;
let update = false;
let dryRun = false;

// ---------------------------------------------------------------------------
// Argument parsing
// ---------------------------------------------------------------------------
const args = process.argv.slice(2);

for (const arg of args) {
  switch (arg) {
    case '--global':
      globalInstall = true;
      break;
    case '--force':
      force = true;
      break;
    case '--uninstall':
      uninstall = true;
      break;
    case '--update':
      update = true;
      break;
    case '--dry-run':
      dryRun = true;
      break;
    case '--help':
    case '-h':
      process.stdout.write(`Oh-My-Kiro Installer
Usage: npx oh-my-kiro [--global] [--force] [--uninstall] [--update] [--dry-run] [--help]
  --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
  --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
  --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
  --update     Smart update: install new files, update changed files, skip user-modified files
  --dry-run    Show what --update would do without making changes
  --help       Show this help message
`);
      process.exit(0);
      break;
    default:
      error(`Unknown option: ${arg}`);
      error("Run 'npx oh-my-kiro --help' for usage.");
      process.exit(1);
  }
}

// Validate flag combinations
if (dryRun && !update) {
  error('--dry-run can only be used with --update');
  process.exit(1);
}

// ---------------------------------------------------------------------------
// Determine target directory
// ---------------------------------------------------------------------------
const TARGET_DIR = globalInstall
  ? path.join(os.homedir(), '.kiro')
  : path.join(process.cwd(), '.kiro');

// ---------------------------------------------------------------------------
// Shared file lists (used by install, update, and uninstall)
// ---------------------------------------------------------------------------
const AGENT_FILES = [
  'phantom.json',
  'revenant.json',
  'wraith.json',
  'ghost-explorer.json',
  'ghost-analyst.json',
  'ghost-validator.json',
  'ghost-researcher.json',
  'ghost-reviewer.json',
  'ghost-implementer.json',
  'ghost-oracle.json',
];

const PROMPT_FILES = [
  'phantom.md',
  'revenant.md',
  'wraith.md',
  'ghost-explorer.md',
  'ghost-analyst.md',
  'ghost-validator.md',
  'ghost-researcher.md',
  'ghost-reviewer.md',
  'ghost-implementer.md',
  'ghost-oracle.md',
];

const STEERING_FILES = ['product.md', 'conventions.md', 'plan-format.md', 'architecture.md'];

const HOOK_FILES = [
  'agent-spawn.sh',
  'pre-tool-use.sh',
  'phantom-read-guard.sh',
  'phantom-write-guard.sh',
];

const SKILL_DIRS = ['git-operations', 'code-review', 'frontend-ux'];

// ---------------------------------------------------------------------------
// Hashing helper
// ---------------------------------------------------------------------------
function hashFile(filePath) {
  const content = fs.readFileSync(filePath);
  return 'sha256:' + crypto.createHash('sha256').update(content).digest('hex');
}

// ---------------------------------------------------------------------------
// Manifest helpers
// ---------------------------------------------------------------------------

/**
 * Build a list of all trackable file entries: { relPath, dir, file }
 * relPath uses forward slashes for cross-platform consistency.
 */
function getAllFileEntries() {
  const entries = [];
  const categories = [
    { dir: 'agents', files: AGENT_FILES },
    { dir: 'prompts', files: PROMPT_FILES },
    { dir: path.join('steering', 'omk'), files: STEERING_FILES },
    { dir: 'hooks', files: HOOK_FILES },
  ];
  for (const cat of categories) {
    for (const f of cat.files) {
      entries.push({ relPath: `${cat.dir.replace(/\\/g, '/')}/${f}` });
    }
  }
  for (const skill of SKILL_DIRS) {
    entries.push({ relPath: `skills/${skill}/SKILL.md` });
  }
  return entries;
}

/**
 * Generate a manifest object from the files currently on disk in targetDir.
 */
function generateManifest(targetDir, version, installMode) {
  const now = new Date().toISOString();
  const manifest = {
    version,
    installedAt: now,
    updatedAt: now,
    installMode,
    files: {},
  };

  for (const entry of getAllFileEntries()) {
    const filePath = path.join(targetDir, entry.relPath);
    if (fs.existsSync(filePath)) {
      manifest.files[entry.relPath] = {
        hash: hashFile(filePath),
        version,
      };
    }
  }

  return manifest;
}

/**
 * Compute a "source manifest" — what the new package would install.
 * Hashes are computed from SOURCE_DIR files.
 */
function computeSourceManifest(sourceDir, version) {
  const files = {};
  for (const entry of getAllFileEntries()) {
    const filePath = path.join(sourceDir, entry.relPath);
    if (fs.existsSync(filePath)) {
      files[entry.relPath] = {
        hash: hashFile(filePath),
        version,
      };
    }
  }
  return files;
}

/**
 * Compare old manifest, new source files, and current disk state.
 * Returns categorized actions following the 6-case decision matrix.
 */
function compareManifests(oldManifest, newSourceFiles, targetDir) {
  const actions = {
    install: [],   // Case 1: new file, not in old manifest
    replace: [],   // Case 2: unmodified by user, changed upstream
    current: [],   // Case 3: already up to date
    skip: [],      // Case 4: user modified, or Case 6: removed upstream + user modified
    remove: [],    // Case 5: removed upstream, unmodified by user
  };

  const oldFiles = oldManifest.files || {};

  // Process files in new source
  for (const [relPath, newEntry] of Object.entries(newSourceFiles)) {
    const oldEntry = oldFiles[relPath];
    const diskPath = path.join(targetDir, relPath);
    const diskExists = fs.existsSync(diskPath);

    if (!oldEntry) {
      // Case 1: Not in old manifest → NEW file
      actions.install.push(relPath);
      continue;
    }

    if (!diskExists) {
      // File was in old manifest but is missing from disk — treat as new install
      actions.install.push(relPath);
      continue;
    }

    const diskHash = hashFile(diskPath);

    // Evaluation order per spec: check disk vs NEW first (case 3),
    // then disk vs OLD (case 2 vs 4)
    if (diskHash === newEntry.hash) {
      // Case 3: Already up to date
      actions.current.push(relPath);
    } else if (diskHash === oldEntry.hash) {
      // Case 2: Unmodified by user, changed upstream → replace
      actions.replace.push(relPath);
    } else {
      // Case 4: User modified → skip with warning
      actions.skip.push(relPath);
    }
  }

  // Process files in old manifest but NOT in new source (removed upstream)
  for (const [relPath, oldEntry] of Object.entries(oldFiles)) {
    if (newSourceFiles[relPath]) continue; // already handled above

    const diskPath = path.join(targetDir, relPath);
    if (!fs.existsSync(diskPath)) {
      // Already gone from disk — nothing to do
      continue;
    }

    const diskHash = hashFile(diskPath);
    if (diskHash === oldEntry.hash) {
      // Case 5: Removed upstream, unmodified by user → delete with backup
      actions.remove.push(relPath);
    } else {
      // Case 6: Removed upstream, but user modified → skip with warning
      actions.skip.push(relPath);
    }
  }

  return actions;
}

/**
 * Display a human-readable update summary.
 */
function displayUpdateSummary(actions, oldVersion, newVersion) {
  process.stdout.write(`\n${BOLD}  Oh-My-Kiro Update: ${oldVersion} \u2192 ${newVersion}${RESET}\n\n`);

  if (actions.install.length > 0) {
    process.stdout.write(`  ${GREEN}New files (will install):${RESET}\n`);
    for (const f of actions.install) {
      process.stdout.write(`    ${GREEN}+${RESET} ${f}\n`);
    }
    process.stdout.write('\n');
  }

  if (actions.replace.length > 0) {
    process.stdout.write(`  ${BLUE}Updated files (will replace, backup to *.bak):${RESET}\n`);
    for (const f of actions.replace) {
      process.stdout.write(`    ${BLUE}~${RESET} ${f}\n`);
    }
    process.stdout.write('\n');
  }

  if (actions.current.length > 0) {
    process.stdout.write(`  Already up to date:\n`);
    for (const f of actions.current) {
      process.stdout.write(`    = ${f}\n`);
    }
    process.stdout.write('\n');
  }

  if (actions.skip.length > 0) {
    process.stdout.write(`  ${YELLOW}Skipped (user modified):${RESET}\n`);
    for (const f of actions.skip) {
      process.stdout.write(`    ${YELLOW}!${RESET} ${f} (local changes detected)\n`);
    }
    process.stdout.write('\n');
  }

  if (actions.remove.length > 0) {
    process.stdout.write(`  ${RED}Removed files (will delete, backup to *.bak):${RESET}\n`);
    for (const f of actions.remove) {
      process.stdout.write(`    ${RED}-${RESET} ${f}\n`);
    }
    process.stdout.write('\n');
  }

  process.stdout.write(
    `  Summary: ${actions.install.length} new, ${actions.replace.length} updated, ` +
    `${actions.current.length} current, ${actions.skip.length} skipped, ${actions.remove.length} removed\n\n`
  );
}

/**
 * Apply update actions: install new files, replace updated files, remove deleted files.
 */
function applyUpdateActions(actions, sourceDir, targetDir, newSourceFiles, newVersion) {
  // Install new files
  for (const relPath of actions.install) {
    const src = path.join(sourceDir, relPath);
    const dst = path.join(targetDir, relPath);
    ensureDir(path.dirname(dst));
    fs.copyFileSync(src, dst);
    // Make hooks executable
    if (relPath.startsWith('hooks/')) {
      fs.chmodSync(dst, 0o755);
    }
    ok(`  Installed: ${relPath}`);
  }

  // Replace updated files (backup first)
  for (const relPath of actions.replace) {
    const src = path.join(sourceDir, relPath);
    const dst = path.join(targetDir, relPath);
    fs.copyFileSync(dst, `${dst}.bak`);
    fs.copyFileSync(src, dst);
    if (relPath.startsWith('hooks/')) {
      fs.chmodSync(dst, 0o755);
    }
    ok(`  Updated:   ${relPath} (backup: ${path.basename(relPath)}.bak)`);
  }

  // Remove deleted files (backup first)
  for (const relPath of actions.remove) {
    const dst = path.join(targetDir, relPath);
    fs.copyFileSync(dst, `${dst}.bak`);
    fs.unlinkSync(dst);
    ok(`  Removed:   ${relPath} (backup: ${path.basename(relPath)}.bak)`);
  }

  // Warn about skipped files
  for (const relPath of actions.skip) {
    warn(`  Skipped:   ${relPath} (local changes detected)`);
  }
}

/**
 * Write the manifest file to the target directory.
 */
function writeManifest(targetDir, manifest) {
  const manifestPath = path.join(targetDir, '.omk-manifest.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2) + '\n');
  info('Manifest written: .omk-manifest.json');
}

/**
 * Helper: ensure directory exists (recursive)
 */
function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

// ---------------------------------------------------------------------------
// Uninstall logic
// ---------------------------------------------------------------------------
if (uninstall) {
  process.stdout.write(`\n${BOLD}  Oh-My-Kiro Uninstaller${RESET}\n`);
  process.stdout.write(`  Target: ${BOLD}${TARGET_DIR}${RESET}\n\n`);

  // Check if target directory exists at all
  if (!fs.existsSync(TARGET_DIR)) {
    warn(`Target directory does not exist: ${TARGET_DIR}`);
    info('Nothing to uninstall.');
    process.exit(0);
  }

  // Confirmation prompt (unless --force)
  if (!force) {
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });
    const answer = await rl.question(`  This will remove Oh-My-Kiro files from ${TARGET_DIR}. Continue? [y/N] `);
    rl.close();
    if (!/^y(es)?$/i.test(answer)) {
      info('Uninstall cancelled.');
      process.exit(0);
    }
    process.stdout.write('\n');
  }

  let removed = 0;
  let notFound = 0;

  // Helper: remove a single file, count result
  function removeFile(filePath) {
    if (fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
      removed++;
      return true;
    }
    notFound++;
    return false;
  }

  // Helper: remove directory if it exists and is empty
  function removeDirIfEmpty(dirPath) {
    if (fs.existsSync(dirPath) && fs.statSync(dirPath).isDirectory()) {
      const entries = fs.readdirSync(dirPath);
      if (entries.length === 0) {
        fs.rmdirSync(dirPath);
        return true;
      }
    }
    return false;
  }

  // --- Agents ---
  info('Removing agents...');
  for (const f of AGENT_FILES) {
    removeFile(path.join(TARGET_DIR, 'agents', f));
    // Also remove any .bak files we may have created
    removeFile(path.join(TARGET_DIR, 'agents', `${f}.bak`));
  }

  // --- Prompts ---
  info('Removing prompts...');
  for (const f of PROMPT_FILES) {
    removeFile(path.join(TARGET_DIR, 'prompts', f));
    removeFile(path.join(TARGET_DIR, 'prompts', `${f}.bak`));
  }

  // --- Steering (entire omk/ directory is ours) ---
  info('Removing steering files...');
  const steeringOmkDir = path.join(TARGET_DIR, 'steering', 'omk');
  if (fs.existsSync(steeringOmkDir) && fs.statSync(steeringOmkDir).isDirectory()) {
    fs.rmSync(steeringOmkDir, { recursive: true });
    // Count the files that were inside
    removed++; // count as one unit (the directory)
  } else {
    notFound++;
  }

  // --- Hooks ---
  info('Removing hooks...');
  for (const f of HOOK_FILES) {
    removeFile(path.join(TARGET_DIR, 'hooks', f));
    removeFile(path.join(TARGET_DIR, 'hooks', `${f}.bak`));
  }

  // --- Skills (entire skill directories are ours) ---
  info('Removing skills...');
  for (const skill of SKILL_DIRS) {
    const skillDir = path.join(TARGET_DIR, 'skills', skill);
    if (fs.existsSync(skillDir) && fs.statSync(skillDir).isDirectory()) {
      fs.rmSync(skillDir, { recursive: true });
      removed++;
    } else {
      notFound++;
    }
  }

  // --- Runtime .gitkeep files ---
  info('Removing runtime files...');
  removeFile(path.join(TARGET_DIR, 'plans', '.gitkeep'));
  removeFile(path.join(TARGET_DIR, 'notepads', '.gitkeep'));

  // --- Manifest ---
  removeFile(path.join(TARGET_DIR, '.omk-manifest.json'));

  // --- Clean up empty directories (bottom-up) ---
  info('Cleaning up empty directories...');
  const dirsToCheck = [
    path.join(TARGET_DIR, 'agents'),
    path.join(TARGET_DIR, 'prompts'),
    path.join(TARGET_DIR, 'steering'),
    path.join(TARGET_DIR, 'hooks'),
    path.join(TARGET_DIR, 'skills'),
    path.join(TARGET_DIR, 'plans'),
    path.join(TARGET_DIR, 'notepads'),
  ];

  let dirsRemoved = 0;
  for (const dir of dirsToCheck) {
    if (removeDirIfEmpty(dir)) {
      dirsRemoved++;
    }
  }

  // --- Summary ---
  process.stdout.write('\n');
  process.stdout.write(`${GREEN}${BOLD}  Uninstall complete!${RESET}\n\n`);
  process.stdout.write(`  Files/dirs removed: ${BOLD}${removed}${RESET}\n`);
  if (notFound > 0) {
    process.stdout.write(`  Already absent:     ${BOLD}${notFound}${RESET}\n`);
  }
  if (dirsRemoved > 0) {
    process.stdout.write(`  Empty dirs cleaned: ${BOLD}${dirsRemoved}${RESET}\n`);
  }

  // Check what's left
  if (fs.existsSync(TARGET_DIR)) {
    const remaining = fs.readdirSync(TARGET_DIR);
    if (remaining.length > 0) {
      process.stdout.write(`\n  ${YELLOW}Remaining items in ${TARGET_DIR}:${RESET}\n`);
      for (const item of remaining) {
        process.stdout.write(`    - ${item}\n`);
      }
      process.stdout.write(`\n  These are not Oh-My-Kiro files and were left untouched.\n`);
    } else {
      process.stdout.write(`\n  ${TARGET_DIR} is now empty (but preserved).\n`);
    }
  }
  process.stdout.write('\n');

  process.exit(0);
}

// ---------------------------------------------------------------------------
// Update logic (--update)
// ---------------------------------------------------------------------------
if (update) {
  process.stdout.write(`\n${BOLD}  Oh-My-Kiro Updater${RESET}\n`);
  process.stdout.write(`  Target: ${BOLD}${TARGET_DIR}${RESET}\n\n`);

  // Read version from package.json
  const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'package.json'), 'utf8'));
  const newVersion = pkg.version;

  // Verify source files exist
  if (!fs.existsSync(SOURCE_DIR)) {
    error(`Source directory not found: ${SOURCE_DIR}`);
    error('Are you running the updater from a valid Oh-My-Kiro package?');
    process.exit(1);
  }

  // Read existing manifest
  const manifestPath = path.join(TARGET_DIR, '.omk-manifest.json');
  let oldManifest = null;

  if (fs.existsSync(manifestPath)) {
    try {
      oldManifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
    } catch {
      warn('Manifest file is corrupted. Running full install instead of update.');
      update = false;
    }
  } else {
    warn('No manifest found. This looks like a pre-manifest installation.');
    warn('Running full install instead of update.');
    update = false;
  }

  if (update && oldManifest) {
    const oldVersion = oldManifest.version;

    // Compute what the new install would look like from source files
    const newSourceFiles = computeSourceManifest(SOURCE_DIR, newVersion);

    // Compare and categorize files
    const actions = compareManifests(oldManifest, newSourceFiles, TARGET_DIR);

    // Display human-readable summary
    displayUpdateSummary(actions, oldVersion, newVersion);

    const totalChanges = actions.install.length + actions.replace.length + actions.remove.length;

    // Dry run: show summary and exit
    if (dryRun) {
      info('Dry run complete. No files were changed.');
      process.exit(0);
    }

    // Nothing to do
    if (totalChanges === 0) {
      process.stdout.write(`${GREEN}${BOLD}  Already up to date!${RESET}\n\n`);
      process.exit(0);
    }

    // Confirmation prompt (unless --force)
    if (!force) {
      const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
      });
      const answer = await rl.question('  Proceed? [y/N] ');
      rl.close();
      if (!/^y(es)?$/i.test(answer)) {
        info('Update cancelled.');
        process.exit(0);
      }
      process.stdout.write('\n');
    }

    // Apply changes
    info('Applying updates...');
    applyUpdateActions(actions, SOURCE_DIR, TARGET_DIR, newSourceFiles, newVersion);

    // Write updated manifest
    process.stdout.write('\n');
    const updatedManifest = generateManifest(TARGET_DIR, newVersion, globalInstall ? 'global' : 'local');
    // Preserve original installedAt from old manifest
    updatedManifest.installedAt = oldManifest.installedAt;
    writeManifest(TARGET_DIR, updatedManifest);

    // Summary
    process.stdout.write('\n');
    process.stdout.write(`${GREEN}${BOLD}  Update complete!${RESET}\n\n`);
    process.stdout.write(`  Version: ${BOLD}${oldVersion} \u2192 ${newVersion}${RESET}\n`);
    process.stdout.write(`  Files installed: ${BOLD}${actions.install.length}${RESET}\n`);
    process.stdout.write(`  Files updated:   ${BOLD}${actions.replace.length}${RESET}\n`);
    process.stdout.write(`  Files removed:   ${BOLD}${actions.remove.length}${RESET}\n`);
    if (actions.skip.length > 0) {
      process.stdout.write(`  Files skipped:   ${BOLD}${actions.skip.length}${RESET} (user modified)\n`);
    }
    process.stdout.write(`  Target:          ${BOLD}${TARGET_DIR}${RESET}\n\n`);

    process.exit(0);
  }
  // If update was set to false (no manifest), fall through to fresh install
}

// ---------------------------------------------------------------------------
// Banner
// ---------------------------------------------------------------------------
process.stdout.write(`\n${BOLD}  Oh-My-Kiro Installer${RESET}\n`);
process.stdout.write(`  Target: ${BOLD}${TARGET_DIR}${RESET}\n\n`);

// ---------------------------------------------------------------------------
// Pre-flight checks
// ---------------------------------------------------------------------------

// 1. Check for kiro-cli
try {
  const kiroBin = execSync('which kiro-cli', { encoding: 'utf8' }).trim();
  ok(`kiro-cli found: ${kiroBin}`);
} catch {
  try {
    // Windows fallback
    const kiroBin = execSync('where kiro-cli', { encoding: 'utf8', stdio: ['pipe', 'pipe', 'pipe'] }).trim().split('\n')[0];
    ok(`kiro-cli found: ${kiroBin}`);
  } catch {
    warn('kiro-cli not found in PATH \u2014 Oh-My-Kiro requires Kiro to work.');
    warn('Install Kiro first: https://kiro.dev');
    // Not fatal — user may install kiro-cli later
  }
}

// 2. Verify source files exist
if (!fs.existsSync(SOURCE_DIR)) {
  error(`Source directory not found: ${SOURCE_DIR}`);
  error('Are you running the installer from a valid Oh-My-Kiro package?');
  process.exit(1);
}

if (!fs.existsSync(path.join(SOURCE_DIR, 'agents')) || !fs.existsSync(path.join(SOURCE_DIR, 'prompts'))) {
  error('Source directory is missing expected subdirectories (agents/, prompts/).');
  process.exit(1);
}

ok(`Source directory verified: ${SOURCE_DIR}`);

// 3. Check if target already has oh-my-kiro files
if (fs.existsSync(TARGET_DIR) && !force) {
  const hasPhantomAgent = fs.existsSync(path.join(TARGET_DIR, 'agents', 'phantom.json'));
  const hasPhantomPrompt = fs.existsSync(path.join(TARGET_DIR, 'prompts', 'phantom.md'));

  if (hasPhantomAgent || hasPhantomPrompt) {
    warn(`Existing Oh-My-Kiro files detected in ${TARGET_DIR}`);
    process.stdout.write('\n');
    process.stdout.write('  Existing files will be backed up to *.bak before overwriting.\n');
    process.stdout.write('  Use --force to skip this prompt.\n\n');

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const answer = await rl.question('  Continue? [y/N] ');
    rl.close();

    if (!/^y(es)?$/i.test(answer)) {
      info('Installation cancelled.');
      process.exit(0);
    }
  }
}

// ---------------------------------------------------------------------------
// File copy helper (for fresh install)
// ---------------------------------------------------------------------------
function copyFile(src, dst) {
  if (!fs.existsSync(src)) {
    warn(`Source file missing, skipping: ${src}`);
    return false;
  }

  // Backup existing file (unless --force)
  if (fs.existsSync(dst) && !force) {
    fs.copyFileSync(dst, `${dst}.bak`);
  }

  fs.copyFileSync(src, dst);
  return true;
}

// ---------------------------------------------------------------------------
// Installation
// ---------------------------------------------------------------------------
let installed = 0;
let skipped = 0;

// --- Agents ---
info('Installing agents...');
ensureDir(path.join(TARGET_DIR, 'agents'));
for (const f of AGENT_FILES) {
  if (copyFile(path.join(SOURCE_DIR, 'agents', f), path.join(TARGET_DIR, 'agents', f))) {
    installed++;
  } else {
    skipped++;
  }
}

// --- Prompts ---
info('Installing prompts...');
ensureDir(path.join(TARGET_DIR, 'prompts'));
for (const f of PROMPT_FILES) {
  if (copyFile(path.join(SOURCE_DIR, 'prompts', f), path.join(TARGET_DIR, 'prompts', f))) {
    installed++;
  } else {
    skipped++;
  }
}

// --- Steering ---
info('Installing steering files...');
ensureDir(path.join(TARGET_DIR, 'steering', 'omk'));
for (const f of STEERING_FILES) {
  if (copyFile(path.join(SOURCE_DIR, 'steering', 'omk', f), path.join(TARGET_DIR, 'steering', 'omk', f))) {
    installed++;
  } else {
    skipped++;
  }
}

// --- Hooks ---
info('Installing hooks...');
ensureDir(path.join(TARGET_DIR, 'hooks'));
for (const f of HOOK_FILES) {
  const dst = path.join(TARGET_DIR, 'hooks', f);
  if (copyFile(path.join(SOURCE_DIR, 'hooks', f), dst)) {
    fs.chmodSync(dst, 0o755);
    installed++;
  } else {
    skipped++;
  }
}

// --- Skills ---
info('Installing skills...');
for (const skill of SKILL_DIRS) {
  ensureDir(path.join(TARGET_DIR, 'skills', skill));
  if (
    copyFile(
      path.join(SOURCE_DIR, 'skills', skill, 'SKILL.md'),
      path.join(TARGET_DIR, 'skills', skill, 'SKILL.md'),
    )
  ) {
    installed++;
  } else {
    skipped++;
  }
}

// --- Runtime directories ---
info('Creating runtime directories...');
ensureDir(path.join(TARGET_DIR, 'plans'));
ensureDir(path.join(TARGET_DIR, 'notepads'));

const gitkeepPlans = path.join(TARGET_DIR, 'plans', '.gitkeep');
const gitkeepNotepads = path.join(TARGET_DIR, 'notepads', '.gitkeep');
if (!fs.existsSync(gitkeepPlans)) fs.writeFileSync(gitkeepPlans, '');
if (!fs.existsSync(gitkeepNotepads)) fs.writeFileSync(gitkeepNotepads, '');

// --- Write manifest ---
const pkg = JSON.parse(fs.readFileSync(path.resolve(__dirname, '..', 'package.json'), 'utf8'));
const manifest = generateManifest(TARGET_DIR, pkg.version, globalInstall ? 'global' : 'local');
writeManifest(TARGET_DIR, manifest);

// ---------------------------------------------------------------------------
// Post-install validation
// ---------------------------------------------------------------------------
process.stdout.write('\n');
info('Validating installation...');

let errors = 0;

const checkFiles = [
  'agents/phantom.json',
  'prompts/phantom.md',
  path.join('steering', 'omk', 'product.md'),
  'hooks/agent-spawn.sh',
  path.join('skills', 'git-operations', 'SKILL.md'),
  path.join('plans', '.gitkeep'),
  path.join('notepads', '.gitkeep'),
];

for (const checkFile of checkFiles) {
  if (fs.existsSync(path.join(TARGET_DIR, checkFile))) {
    ok(`  ${checkFile}`);
  } else {
    error(`  Missing: ${checkFile}`);
    errors++;
  }
}

// Verify hooks are executable
for (const f of HOOK_FILES) {
  const hookPath = path.join(TARGET_DIR, 'hooks', f);
  if (fs.existsSync(hookPath)) {
    try {
      fs.accessSync(hookPath, fs.constants.X_OK);
    } catch {
      error(`  Hook not executable: hooks/${f}`);
      errors++;
    }
  }
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------
process.stdout.write('\n');

if (errors > 0) {
  error(`Installation completed with ${errors} error(s).`);
  process.stdout.write('\n');
  process.exit(1);
}

process.stdout.write(`${GREEN}${BOLD}  Installation complete!${RESET}\n\n`);
process.stdout.write(`  Files installed: ${BOLD}${installed}${RESET}\n`);
if (skipped > 0) {
  process.stdout.write(`  Files skipped:   ${BOLD}${skipped}${RESET} (source missing)\n`);
}
process.stdout.write(`  Target:          ${BOLD}${TARGET_DIR}${RESET}\n`);

process.stdout.write(`\n${BOLD}  Next steps:${RESET}\n`);
if (globalInstall) {
  process.stdout.write('  1. Open any project in Kiro \u2014 Oh-My-Kiro agents are available globally.\n');
} else {
  process.stdout.write('  1. Open this project in Kiro \u2014 Oh-My-Kiro agents are ready to use.\n');
}
process.stdout.write(`  2. Start a conversation with the ${BOLD}Phantom${RESET} agent for planning.\n`);
process.stdout.write(`  3. Use ${BOLD}Wraith${RESET} for execution or ${BOLD}Revenant${RESET} for exploration.\n`);
process.stdout.write('\n  Docs: https://github.com/NachoFLizaur/oh-my-kiro\n\n');
