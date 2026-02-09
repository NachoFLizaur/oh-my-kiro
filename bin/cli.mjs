#!/usr/bin/env node

// Oh-My-Kiro CLI Installer
// Usage: npx oh-my-kiro [--global] [--force] [--uninstall] [--help]
//   --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
//   --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
//   --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
//   --help       Show this help message

import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';
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
    case '--help':
    case '-h':
      process.stdout.write(`Oh-My-Kiro Installer
Usage: npx oh-my-kiro [--global] [--force] [--uninstall] [--help]
  --global     Install/uninstall to/from ~/.kiro/ (available in all projects)
  --force      Overwrite existing files without prompting (or skip confirmation on uninstall)
  --uninstall  Remove Oh-My-Kiro files (only ours — never the whole .kiro/)
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

// ---------------------------------------------------------------------------
// Determine target directory
// ---------------------------------------------------------------------------
const TARGET_DIR = globalInstall
  ? path.join(os.homedir(), '.kiro')
  : path.join(process.cwd(), '.kiro');

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

  // File manifest — must match what install creates
  const AGENT_FILES = [
    'prometheus.json', 'atlas.json', 'sisyphus.json',
    'omk-explorer.json', 'omk-metis.json', 'omk-researcher.json',
    'omk-reviewer.json', 'omk-sisyphus-jr.json',
  ];
  const PROMPT_FILES = [
    'prometheus.md', 'atlas.md', 'sisyphus.md',
    'omk-explorer.md', 'omk-metis.md', 'omk-researcher.md',
    'omk-reviewer.md', 'omk-sisyphus-jr.md',
  ];
  const HOOK_FILES = [
    'agent-spawn.sh', 'pre-tool-use.sh',
    'prometheus-read-guard.sh', 'prometheus-write-guard.sh',
  ];
  const SKILL_DIRS = ['git-operations', 'code-review', 'frontend-ux'];

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
  const hasPrometheusAgent = fs.existsSync(path.join(TARGET_DIR, 'agents', 'prometheus.json'));
  const hasPrometheusPrompt = fs.existsSync(path.join(TARGET_DIR, 'prompts', 'prometheus.md'));

  if (hasPrometheusAgent || hasPrometheusPrompt) {
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
// File manifest — everything we install
// ---------------------------------------------------------------------------
const AGENT_FILES = [
  'prometheus.json',
  'atlas.json',
  'sisyphus.json',
  'omk-explorer.json',
  'omk-metis.json',
  'omk-researcher.json',
  'omk-reviewer.json',
  'omk-sisyphus-jr.json',
];

const PROMPT_FILES = [
  'prometheus.md',
  'atlas.md',
  'sisyphus.md',
  'omk-explorer.md',
  'omk-metis.md',
  'omk-researcher.md',
  'omk-reviewer.md',
  'omk-sisyphus-jr.md',
];

const STEERING_FILES = ['product.md', 'conventions.md', 'plan-format.md', 'architecture.md'];

const HOOK_FILES = [
  'agent-spawn.sh',
  'pre-tool-use.sh',
  'prometheus-read-guard.sh',
  'prometheus-write-guard.sh',
];

const SKILL_DIRS = ['git-operations', 'code-review', 'frontend-ux'];

// ---------------------------------------------------------------------------
// Helper: copy a file, backing up the target if it already exists
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
// Helper: ensure directory exists (recursive)
// ---------------------------------------------------------------------------
function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
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

// ---------------------------------------------------------------------------
// Post-install validation
// ---------------------------------------------------------------------------
process.stdout.write('\n');
info('Validating installation...');

let errors = 0;

const checkFiles = [
  'agents/prometheus.json',
  'prompts/prometheus.md',
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
process.stdout.write(`  2. Start a conversation with the ${BOLD}Prometheus${RESET} agent for planning.\n`);
process.stdout.write(`  3. Use ${BOLD}Sisyphus${RESET} for execution or ${BOLD}Atlas${RESET} for exploration.\n`);
process.stdout.write('\n  Docs: https://github.com/nflizaur/oh-my-kiro\n\n');
