#!/usr/bin/env bash
# dep-upgrader.sh – Unified polyglot dependency, maintenance, and CI/CD bootstrap suite.
# Merged from update-deps.sh (Next.js/pnpm assistant) and dep-upgrader.sh (polyglot multi-repo).
# Supports Node.js/Next.js/pnpm and .NET/Avalonia repositories and parent workspaces.
# Code comments are English; user-facing output is German.

set -Eeuo pipefail
IFS=$'\n\t'

VERSION="3.0.0"
SELF_PATH="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)/$(basename -- "${BASH_SOURCE[0]}")"

# ---------- Defaults ----------
ROOT="."
MODULE=""
MODE="semver-safe"
COOLDOWN="7d"
AUDIT_MODE="report"
AUDIT_LEVEL="${AUDIT_LEVEL:-moderate}"
VALIDATE_MODE="full"
QUALITY_PROFILE="full"
HARDEN_MODE="strict"
ECOSYSTEMS="all"
PROJECT_FILTER=""
SELECT_SPEC=""
DRY_RUN=0
ASSUME_YES=0
KEEP_GOING=1
FIX=0
INSTALL_TOOLS=0
NON_INTERACTIVE=0
LIST_ONLY=0
ROLLBACK_PATH=""
RID=""
STASH=0
CI_FORCE=0
INSTALL_CI_SCRIPT=1
DEPLOY_PROVIDER="none"
NODE_VERSION="24"
PNPM_VERSION="11"
DOTNET_VERSION="10.0.x"
MAINTENANCE_CRON="17 3 * * 1"
DEFAULT_BRANCH=""
REPAIR=0
MIGRATE_NPM=1
VALIDATE_WORKSPACE=0
AUTO_ROLLBACK=0
DEDUPE=1
SIGNATURES=1
GENERATE_SBOM=0
FULL_UPGRADE=0
NCU_PACKAGE="${NCU_PACKAGE:-npm-check-updates@latest}"

NODE_PROJECTS=()
NODE_TYPES=()
NODE_ROOTS=()
DOTNET_PROJECTS=()
DOTNET_TYPES=()
SHARED_PACKAGES=()
REPO_ROOTS=()
INVALID_MANIFESTS=()
APP_MANIFESTS=()
APP_DIRS=()
APP_NAMES=()
SELECTED_INDEXES=()
INSTALL_ROOTS=()
TRACKED_FILES=()
FAILURES=()
FAILED=0
CHANGED=0
UPDATED_APPS=0
ABORT_PIPELINE=0
BACKUP_CREATED=0
BACKUP_DIR=""
BACKUP_ARCHIVE=""
LOG_DIR=""
CURRENT_LOG="/dev/null"
STAMP=""
NCU_SUPPORTS_COOLDOWN=""
NODE_VERSION_RUN=""
PNPM_VERSION_RUN=""
PNPM_MAJOR=0
PNPM_MINOR=0
PNPM_PATCH=0

# ---------- Terminal ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_DIM=$'\033[2m'
  C_BLUE=$'\033[34m'; C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'
  C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_MAGENTA=$'\033[35m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_BLUE="" C_CYAN=""
  C_GREEN="" C_YELLOW="" C_RED="" C_MAGENTA=""
fi

info()    { printf '%sℹ%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
success() { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()    { printf '%s⚠%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
error()   { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
muted()   { printf '%s%s%s\n' "$C_DIM" "$*" "$C_RESET"; }
ok()      { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
err()     { printf '%s✖%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; FAILURES+=("$*"); FAILED=${#FAILURES[@]}; }

line() { printf '%s\n' "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"; }

banner() {
  if [[ -t 1 ]]; then clear 2>/dev/null || true; fi
  printf '%s%s' "$C_BOLD" "$C_CYAN"
  cat <<'TXT'
╭────────────────────────────────────────────────────────────╮
│              Dep Upgrader – Unified Edition                │
│       pnpm · ncu · .NET · CI/CD · Repair · Audit          │
╰────────────────────────────────────────────────────────────╯
TXT
  printf '%s' "$C_RESET"
  muted "Version ${VERSION}"
  printf '\n'
}

usage() {
  cat <<'USAGE'
Dep Upgrader 3.0.0

Verwendung:
  dep-upgrader.sh [Optionen]

Kern:
  --root DIR              Einzelnes Repository oder übergeordneter Projektordner
  --module MODULE         all|deps|repair|clean|validate|security|quality|automation|config|dedupe|ui-analysis|cicd|rollback
  --full-upgrade          Vollautomatisch: latest, repair, strict, audit-fix, volle Validierung
  --mode MODE             latest|minor|patch|semver-safe|semver|interactive
  --ecosystems LISTE      all|node|dotnet
  --projects TEXT         Pfad-/Projektfilter
  --select LISTE          Node-/Next.js-Auswahl, z. B. 1,3-5
  --non-interactive       Kein Menü anzeigen
  --list                  Nur Inventar anzeigen
  --yes, -y               Rückfragen bestätigen
  --dry-run               Keine Projektdateien verändern
  --keep-going            Nach Fehlern weiterarbeiten (Standard)
  --fail-fast             Beim ersten Befehlsfehler stoppen
  --stash                 Schmutzige Git-Repositories vor Änderungen stashen

Node.js, Next.js und pnpm:
  --cooldown ZEIT         0, 24h, 3d, 7d; Standard: 7d
  --audit MODE            off|report|interactive|fix
  --audit-level LEVEL     low|moderate|high|critical
  --validate MODE         off|quick|full|build|format|test|run|publish
  --harden MODE           off|report|balanced|strict
  --repair                Ungültige package.json/tsconfig.json soweit möglich reparieren
  --migrate-npm           npm/yarn auf pnpm migrieren (bei Updates standardmäßig aktiv)
  --no-migrate-npm        Lockfiles und Scripts nicht automatisch migrieren
  --validate-workspace    pnpm-Workspace-Struktur zusätzlich prüfen
  --auto-rollback         Bei mehr als 50 % fehlgeschlagenen Updates zurückrollen
  --no-dedupe             pnpm dedupe überspringen
  --no-signatures         Registry-Signaturprüfung überspringen
  --sbom                  CycloneDX-SBOM je Installations-Root erzeugen
  --ncu-package SPEC      Standard: npm-check-updates@latest

Qualität und .NET/Avalonia:
  --quality-profile MODE  quick|full|deep
  --install-tools         Fehlende optionale Werkzeuge lokal installieren
  --fix                   Qualitätswerkzeuge im Fix-Modus ausführen
  --rid RID               Runtime Identifier für dotnet publish

CI/CD:
  --setup-cicd            Alias für --module cicd
  --ci-force              Vorhandene generierte Dateien überschreiben
  --no-ci-script          Keine Script-Kopie unter .github/scripts installieren
  --deploy-provider NAME  none|coolify|vercel
  --node-version VER      Standard: 24
  --pnpm-version VER      Standard: 11
  --dotnet-version VER    Standard: 10.0.x
  --maintenance-cron CRON Standard: 17 3 * * 1
  --default-branch NAME   Sonst automatisch aus Git ermitteln

Recovery:
  --rollback PFAD         Manifest-Backup-Verzeichnis oder tar.gz-Archiv wiederherstellen

Beispiele:
  ./dep-upgrader.sh --root ~/projekte --list
  ./dep-upgrader.sh --root ~/projekte --full-upgrade
  ./dep-upgrader.sh --root ~/projekte --module deps --mode semver-safe --yes
  ./dep-upgrader.sh --root ~/projekte --setup-cicd --deploy-provider coolify --yes
  ./dep-upgrader.sh --root ~/projekte --module repair --repair --yes
USAGE
}

command_exists() { command -v "$1" >/dev/null 2>&1; }
has() { command -v "$1" >/dev/null 2>&1; }

abs_path() {
  local path="$1"
  if command_exists realpath; then realpath "$path"
  elif command_exists python3; then python3 -c "import os,sys;print(os.path.abspath(sys.argv[1]))" "$path"
  else (cd "$path" 2>/dev/null && pwd -P); fi
}

array_contains() {
  local needle="$1"; shift
  for item in "$@"; do [[ "$item" == "$needle" ]] && return 0; done
  return 1
}

unique_append() {
  local array_name="$1" value="$2"
  local -n target_array="$array_name"
  for existing in "${target_array[@]}"; do [[ "$existing" == "$value" ]] && return 0; done
  target_array+=("$value")
}

matches_filter() {
  [[ -z "$PROJECT_FILTER" ]] && return 0
  local value="${1,,}" needle="${PROJECT_FILTER,,}"
  [[ "$value" == *"$needle"* ]]
}

safe_relative() {
  local path="$1" base="$2"
  if [[ "$path" == "$base" ]]; then printf '.\n'; else printf '%s\n' "${path#"$base"/}"; fi
}

ncu_latest_node_supported() {
  node - "$1" <<'NODE'
const raw = process.argv[2] || '0.0.0';
const [major = 0, minor = 0, patch = 0] = raw.split(/[.-]/).map(Number);
const atLeast = (m, n, p) => major > m || (major === m && (minor > n || (minor === n && patch >= p)));
const supported = (major === 22 && atLeast(22, 22, 2)) || (major === 24 && atLeast(24, 15, 0)) || major >= 26;
process.exit(supported ? 0 : 1);
NODE
}

pnpm_at_least() {
  local req_major="$1" req_minor="$2" req_patch="$3"
  (( PNPM_MAJOR > req_major )) && return 0
  (( PNPM_MAJOR < req_major )) && return 1
  (( PNPM_MINOR > req_minor )) && return 0
  (( PNPM_MINOR < req_minor )) && return 1
  (( PNPM_PATCH >= req_patch ))
}

cooldown_to_minutes() {
  local value="$1" number unit
  if [[ "$value" =~ ^([0-9]+)([mhd]?)$ ]]; then
    number="${BASH_REMATCH[1]}"; unit="${BASH_REMATCH[2]}"
    case "$unit" in m) printf '%s\n' "$number" ;; h) printf '%s\n' "$((number * 60))" ;; d|"") printf '%s\n' "$((number * 1440))" ;; esac
    return 0
  fi
  return 1
}

json_has_next() {
  node - "$1" <<'NODE'
const fs = require('fs');
try {
  const p = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const groups = ['dependencies', 'devDependencies', 'peerDependencies', 'optionalDependencies'];
  process.exit(groups.some(g => p[g] && Object.prototype.hasOwnProperty.call(p[g], 'next')) ? 0 : 1);
} catch (e) { process.exit(2); }
NODE
}

json_name() {
  node - "$1" <<'NODE'
const fs = require('fs');
try { const p = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); process.stdout.write(p.name || '(ohne Namen)'); }
catch { process.stdout.write('(ungültige package.json)'); }
NODE
}

has_script() {
  node - "$1" "$2" <<'NODE'
const fs = require('fs');
try { const p = JSON.parse(fs.readFileSync(process.argv[2], 'utf8')); process.exit(p.scripts && typeof p.scripts[process.argv[3]] === 'string' ? 0 : 1); }
catch { process.exit(1); }
NODE
}

is_valid_json() {
  local file="$1"
  if command_exists python3; then
    python3 - "$file" <<'PYJSON' 2>/dev/null
import json, sys
with open(sys.argv[1], 'r', encoding='utf-8') as handle:
    json.load(handle)
PYJSON
  elif command_exists node; then
    node -e 'JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"))' "$file" >/dev/null 2>&1
  else
    return 1
  fi
}

choose() {
  local __var="$1" default="$2" prompt="$3"
  shift 3
  local options=("$@") _choice i
  printf '%s%s%s\n' "$C_BOLD" "$prompt" "$C_RESET"
  i=1
  for _choice in "${options[@]}"; do printf '  %s%d)%s %s\n' "$C_CYAN" "$i" "$C_RESET" "$_choice"; i=$((i + 1)); done
  while true; do
    printf 'Auswahl [%s]: ' "$default"
    IFS= read -r _choice || _choice="$default"
    _choice="${_choice:-$default}"
    if [[ "$_choice" =~ ^[0-9]+$ ]] && (( _choice >= 1 && _choice <= ${#options[@]} )); then printf -v "$__var" '%s' "$_choice"; return 0; fi
    warn "Bitte eine Zahl zwischen 1 und ${#options[@]} eingeben."
  done
}

confirm() {
  local prompt="$1" default="${2:-y}" answer suffix
  if [[ "$ASSUME_YES" -eq 1 ]]; then return 0; fi
  [[ "$default" == "y" ]] && suffix="[J/n]" || suffix="[j/N]"
  printf '%s %s ' "$prompt" "$suffix"
  IFS= read -r answer || answer=""
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[JjYy]$ ]]
}

run_logged() {
  local label="$1" dir="$2"
  shift 2
  local status

  printf '\n%s▶%s %s\n' "$C_MAGENTA" "$C_RESET" "$label"
  muted "  Verzeichnis: $dir"
  muted "  Befehl: $(printf '%q ' "$@")"

  if ((DRY_RUN)); then
    muted "  Dry-Run: nicht ausgeführt"
    return 0
  fi

  (cd "$dir" || exit 1; "$@") 2>&1 | tee -a "$CURRENT_LOG"
  status=${PIPESTATUS[0]}
  if ((status == 0)); then
    success "$label"
  else
    error "$label (Exit-Code $status)"
  fi
  return "$status"
}

run() {
  local label="$1" cwd="$2"
  shift 2
  local code
  info "$label: $(printf '%q ' "$@")"
  if ((DRY_RUN)); then return 0; fi
  if (cd "$cwd" && "$@") >>"$LOG_DIR/commands.log" 2>&1; then
    return 0
  else
    code=$?
  fi
  err "$label fehlgeschlagen (Exit $code): $cwd"
  ((KEEP_GOING)) || exit "$code"
  return "$code"
}

record_failure() {
  local message="$1" existing
  for existing in "${FAILURES[@]}"; do [[ "$existing" == "$message" ]] && return 0; done
  FAILURES+=("$message")
  FAILED=${#FAILURES[@]}
  if ((KEEP_GOING)); then return 0; fi
  ABORT_PIPELINE=1
  return 1
}

node_workspace_root() {
  local start="$1" dir="$1" parent
  while [[ "$dir" == "$ROOT" || "$dir" == "$ROOT"/* ]]; do
    if [[ -f "$dir/pnpm-workspace.yaml" || -f "$dir/pnpm-workspace.yml" || -f "$dir/turbo.json" ]]; then
      printf '%s\n' "$dir"
      return 0
    fi
    if [[ -f "$dir/package.json" ]] && is_valid_json "$dir/package.json" && command_exists node && \
       node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(p.workspaces?0:1)' "$dir/package.json" 2>/dev/null; then
      printf '%s\n' "$dir"
      return 0
    fi
    [[ "$dir" == "$ROOT" ]] && break
    parent="$(dirname "$dir")"
    [[ "$parent" == "$dir" ]] && break
    dir="$parent"
  done
  printf '%s\n' "$start"
}

detect_app_type() {
  local dir="$1"
  if [[ -f "$dir/next.config.js" || -f "$dir/next.config.ts" || -f "$dir/next.config.mjs" ]]; then echo "next"
  elif [[ -f "$dir/tsconfig.json" ]] && grep -q '"tsx"' "$dir/tsconfig.json" 2>/dev/null; then echo "next"
  else echo "lib"; fi
}

find_install_root_repair() {
  local dir="$1" current="$1"
  while true; do
    if [[ -f "$current/pnpm-workspace.yaml" || -f "$current/pnpm-workspace.yml" ]]; then printf '%s\n' "$current"; return 0; fi
    [[ "$current" == "/" ]] && break
    current="$(dirname "$current")"
  done
  printf '%s\n' "$dir"
}

detect_workspace_deps() {
  local dir="$1" install_root="$2"
  if [[ -d "$install_root/node_modules/@lunexor" ]]; then
    for link in "$install_root/node_modules/@lunexor"/*; do
      [[ -L "$link" ]] || continue
      local scope_name; scope_name="$(basename "$link")"
      printf '@lunexor/%s\n' "$scope_name"
    done
  fi
  if [[ -d "$install_root/node_modules/@lnxr" ]]; then
    for link in "$install_root/node_modules/@lnxr"/*; do
      [[ -L "$link" ]] || continue
      local scope_name; scope_name="$(basename "$link")"
      printf '@lnxr/%s\n' "$scope_name"
    done
  fi
}

detect_imports_from_src() {
  local dir="$1"
  if [[ -d "$dir/src" ]]; then
    grep -rh "from[[:space:]]*[\'\"]" "$dir/src" 2>/dev/null | head -50 | \
      sed -n "s/.*from[[:space:]]*[\'\"]\([^\'\".][^\'\"]*\).*/\1/p" | \
      sed 's|/[^/]*$||' | sort -u
  fi
}

REPAIR_KNOWN_DEPS=(
  next react react-dom typescript eslint eslint-config-next
  "@types/node" "@types/react" "@types/react-dom"
  tailwindcss autoprefixer postcss zod
  "@tailwindcss/postcss" "tailwindcss-animate"
  "@auth/drizzle-adapter" "@auth/core"
  next-auth next-themes drizzle-orm postgres pg
  stripe recharts lucide-react "class-variance-authority"
  clsx "tailwind-merge" "date-fns" sonner bcryptjs bullmq
  "@tanstack/react-table" "@radix-ui/react-icons"
  "@radix-ui/react-dialog" "@radix-ui/react-dropdown-menu"
  "@radix-ui/react-select" "@radix-ui/react-slot"
  "@radix-ui/react-tabs" pino pino-pretty drizzle-kit
  nodemailer redis mjml "zod-to-openapi" tsx vitest
)

repair_package_json() {
  local file="$1" dir repo rel tmp
  dir="$(dirname "$file")"
  is_valid_json "$file" && return 0
  warn "Kaputte package.json erkannt: $file"

  if command_exists git && repo="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    rel="${file#"$repo"/}"
    tmp="$(mktemp)"
    if git -C "$repo" show "HEAD:$rel" >"$tmp" 2>/dev/null && is_valid_json "$tmp"; then
      if ((DRY_RUN)); then
        muted "  Dry-Run: würde aus Git wiederhergestellt"
      else
        mkdir -p "$LOG_DIR/repaired-originals/$(dirname "${file#"$ROOT"/}")"
        cp -p "$file" "$LOG_DIR/repaired-originals/${file#"$ROOT"/}" 2>/dev/null || true
        cp "$tmp" "$file"
        success "package.json aus Git wiederhergestellt: $file"
        CHANGED=1
      fi
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp"
  fi

  command_exists node || { error "Node.js fehlt; $file kann nicht rekonstruiert werden."; return 1; }
  if ((DRY_RUN)); then
    muted "  Dry-Run: package.json würde aus Quellcode rekonstruiert"
    return 0
  fi

  mkdir -p "$LOG_DIR/repaired-originals/$(dirname "${file#"$ROOT"/}")"
  cp -p "$file" "$LOG_DIR/repaired-originals/${file#"$ROOT"/}" 2>/dev/null || true

  node - "$file" "$dir" "$ROOT" "${PNPM_VERSION_RUN:-${PNPM_VERSION}.0.0}" <<'NODE'
const fs = require('fs');
const path = require('path');
const [file, dir, root, pnpmVersion] = process.argv.slice(2);
const skip = new Set(['node_modules','.next','.git','dist','build','coverage','.turbo','.cache','bin','obj','.maintenance']);
const extensions = new Set(['.js','.jsx','.mjs','.cjs','.ts','.tsx','.mts','.cts']);
const builtins = new Set(require('module').builtinModules.flatMap(x => [x, `node:${x}`]));
const imports = new Set();
function packageName(spec) {
  if (!spec || spec.startsWith('.') || spec.startsWith('/') || builtins.has(spec)) return null;
  if (spec.startsWith('@')) return spec.split('/').slice(0,2).join('/');
  return spec.split('/')[0];
}
function walk(current) {
  let entries=[]; try { entries=fs.readdirSync(current,{withFileTypes:true}); } catch { return; }
  for (const entry of entries) {
    if (skip.has(entry.name)) continue;
    const full=path.join(current,entry.name);
    if (entry.isDirectory()) { walk(full); continue; }
    if (!extensions.has(path.extname(entry.name))) continue;
    let text=''; try { text=fs.readFileSync(full,'utf8'); } catch { continue; }
    const patterns=[/\bfrom\s*['"]([^'"]+)['"]/g,/\bimport\s*\(\s*['"]([^'"]+)['"]\s*\)/g,/\brequire\s*\(\s*['"]([^'"]+)['"]\s*\)/g,/\bimport\s*['"]([^'"]+)['"]/g];
    for (const pattern of patterns) for (const match of text.matchAll(pattern)) { const name=packageName(match[1]); if(name) imports.add(name); }
  }
}
walk(dir);
const isNext = ['next.config.js','next.config.mjs','next.config.ts','next.config.cjs'].some(f=>fs.existsSync(path.join(dir,f))) || fs.existsSync(path.join(dir,'app')) || fs.existsSync(path.join(dir,'pages'));
if (isNext) ['next','react','react-dom'].forEach(x=>imports.add(x));
const localNames=new Set();
function collectPackages(current, depth=0) {
  if(depth>5) return;
  let entries=[]; try { entries=fs.readdirSync(current,{withFileTypes:true}); } catch { return; }
  for(const entry of entries){
    if(skip.has(entry.name)) continue;
    const full=path.join(current,entry.name);
    if(!entry.isDirectory()) continue;
    const manifest=path.join(full,'package.json');
    if(fs.existsSync(manifest)) { try { const p=JSON.parse(fs.readFileSync(manifest,'utf8')); if(p.name)localNames.add(p.name); } catch {} }
    collectPackages(full,depth+1);
  }
}
collectPackages(root);
function installedVersion(name) {
  let current=dir;
  while(current.startsWith(root)) {
    const manifest=path.join(current,'node_modules',...name.split('/'),'package.json');
    if(fs.existsSync(manifest)) { try { const v=JSON.parse(fs.readFileSync(manifest,'utf8')).version; if(v)return `^${v}`; } catch {} }
    const parent=path.dirname(current); if(parent===current)break; current=parent;
  }
  return 'latest';
}
const devNames=new Set(['typescript','eslint','eslint-config-next','vitest','jest','tsx','prettier','tailwindcss','postcss','autoprefixer','@types/node','@types/react','@types/react-dom','@eslint/eslintrc','drizzle-kit']);
const dependencies={}; const devDependencies={};
for(const name of [...imports].sort()) {
  const value=localNames.has(name)?'workspace:*':installedVersion(name);
  (devNames.has(name)?devDependencies:dependencies)[name]=value;
}
const hasTS = fs.existsSync(path.join(dir,'tsconfig.json')) || [...extensions].some(()=>false);
if (hasTS || fs.existsSync(path.join(dir,'src'))) {
  for(const name of ['typescript','@types/node']) if(!dependencies[name]) devDependencies[name]=devDependencies[name]||installedVersion(name);
}
if (isNext) {
  for(const name of ['@types/react','@types/react-dom','eslint','eslint-config-next']) if(!dependencies[name]) devDependencies[name]=devDependencies[name]||installedVersion(name);
}
const name=path.basename(dir).toLowerCase().replace(/[^a-z0-9._-]+/g,'-').replace(/^-+|-+$/g,'') || 'recovered-package';
const scripts=isNext ? {dev:'next dev',build:'next build',start:'next start',lint:'eslint .',typecheck:'tsc --noEmit'} : {build:'tsc',typecheck:'tsc --noEmit'};
const pkg={name,version:'0.1.0',private:true,packageManager:`pnpm@${pnpmVersion}`,scripts,dependencies,devDependencies};
fs.writeFileSync(file,JSON.stringify(pkg,null,2)+'\n');
NODE

  if is_valid_json "$file"; then
    success "package.json rekonstruiert: $file"
    warn "Rekonstruierte Abhängigkeiten müssen fachlich geprüft werden; unbekannte Versionen stehen auf latest."
    CHANGED=1
    return 0
  fi
  error "Rekonstruierte package.json ist ungültig: $file"
  return 1
}

repair_tsconfig() {
  local file="$1" dir repo rel tmp app_type
  dir="$(dirname "$file")"
  is_valid_json "$file" && return 0
  warn "Kaputte tsconfig.json erkannt: $file"

  if command_exists git && repo="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null)"; then
    rel="${file#"$repo"/}"
    tmp="$(mktemp)"
    if git -C "$repo" show "HEAD:$rel" >"$tmp" 2>/dev/null && is_valid_json "$tmp"; then
      if ((DRY_RUN)); then muted "  Dry-Run: würde aus Git wiederhergestellt"
      else cp "$tmp" "$file"; success "tsconfig.json aus Git wiederhergestellt: $file"; CHANGED=1; fi
      rm -f "$tmp"
      return 0
    fi
    rm -f "$tmp"
  fi

  app_type="$(detect_app_type "$dir")"
  if ((DRY_RUN)); then muted "  Dry-Run: tsconfig.json würde rekonstruiert"; return 0; fi
  if [[ "$app_type" == next ]]; then
    cat >"$file" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2017", "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true, "skipLibCheck": true, "strict": true, "noEmit": true,
    "esModuleInterop": true, "module": "esnext", "moduleResolution": "bundler",
    "resolveJsonModule": true, "isolatedModules": true, "jsx": "preserve",
    "incremental": true, "plugins": [{"name": "next"}], "paths": {"@/*": ["./src/*"]}
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
JSON
  else
    cat >"$file" <<'JSON'
{
  "compilerOptions": {
    "target": "ES2022", "lib": ["esnext"], "module": "esnext",
    "moduleResolution": "bundler", "strict": true, "esModuleInterop": true,
    "skipLibCheck": true, "resolveJsonModule": true, "isolatedModules": true,
    "declaration": true, "outDir": "dist"
  },
  "include": ["src/**/*.ts"], "exclude": ["node_modules", "dist"]
}
JSON
  fi
  is_valid_json "$file" && { success "tsconfig.json rekonstruiert: $file"; CHANGED=1; return 0; }
  error "Rekonstruierte tsconfig.json ist ungültig: $file"
  return 1
}

migrate_npm_to_pnpm() {
  local install_root="$1" imported=0 lock
  ensure_pnpm || return 1
  for lock in package-lock.json npm-shrinkwrap.json yarn.lock; do
    imported=0
    [[ -f "$install_root/$lock" ]] || continue
    warn "$lock gefunden: $install_root"
    if ((DRY_RUN)); then
      muted "  Dry-Run: pnpm import und Entfernung von $lock"
      imported=1
      continue
    fi
    if (cd "$install_root" && pnpm import) >>"$LOG_DIR/commands.log" 2>&1; then
      imported=1
      success "Lockfile nach pnpm importiert: $install_root/$lock"
    elif [[ -f "$install_root/pnpm-lock.yaml" ]]; then
      imported=1
      warn "pnpm import schlug fehl, vorhandenes pnpm-lock.yaml bleibt maßgeblich."
    else
      record_failure "Lockfile-Import fehlgeschlagen: $install_root/$lock"
      continue
    fi
    ((imported)) && rm -f "$install_root/$lock"
  done
  ensure_workspace_policy "$install_root"
}

validate_workspace() {
  local install_root="$1" ws_file="" issues=0 pattern parent dir
  if [[ -f "$install_root/pnpm-workspace.yaml" ]]; then ws_file="$install_root/pnpm-workspace.yaml"
  elif [[ -f "$install_root/pnpm-workspace.yml" ]]; then ws_file="$install_root/pnpm-workspace.yml"
  else warn "Keine pnpm-workspace.yaml in $install_root"; return 1; fi

  muted "  Workspace: $ws_file"
  while IFS= read -r pattern; do
    [[ -n "$pattern" ]] || continue
    if [[ "$pattern" == *'*'* ]]; then
      parent="${pattern%%\**}"; parent="${parent%/}"
      [[ -z "$parent" || -d "$install_root/$parent" ]] || { warn "Workspace-Basis fehlt: $parent"; ((issues+=1)); }
    elif [[ "$pattern" != "." && ! -d "$install_root/$pattern" ]]; then
      warn "Workspace-Pfad existiert nicht: $pattern"; ((issues+=1))
    fi
  done < <(sed -nE 's/^[[:space:]]*-[[:space:]]*["'\'' ]?([^"'\''#]+)["'\'' ]?.*/\1/p' "$ws_file" 2>/dev/null)

  for dir in "$install_root"/apps/* "$install_root"/packages/* "$install_root"/services/*; do
    [[ -d "$dir" ]] || continue
    [[ -f "$dir/package.json" ]] || { warn "Workspace-Verzeichnis ohne package.json: $dir"; ((issues+=1)); continue; }
    is_valid_json "$dir/package.json" || { warn "Ungültige package.json: $dir/package.json"; ((issues+=1)); }
  done
  if ((issues == 0)); then success "Workspace-Validierung OK: $install_root"; else warn "$issues Workspace-Problem(e): $install_root"; fi
  return "$issues"
}

cleanup_node() {
  local target project root
  for project in "${NODE_PROJECTS[@]}"; do
    target="$(dirname "$project")"
    for target in "$target/.next" "$target/node_modules"; do
      [[ -e "$target" ]] || continue
      if ((DRY_RUN)); then info "[Dry-Run] Löschen: $target"; else rm -rf -- "$target"; ok "Gelöscht: $target"; CHANGED=1; fi
    done
  done
  for root in "${NODE_ROOTS[@]}"; do
    for target in "$root/.next" "$root/node_modules"; do
      [[ -e "$target" ]] || continue
      if ((DRY_RUN)); then info "[Dry-Run] Löschen: $target"; else rm -rf -- "$target"; ok "Gelöscht: $target"; CHANGED=1; fi
    done
  done
}

# ---------- Backup (update-deps style) ----------
TRACKED_FILES=()
track_file() {
  local file="$1" rel state
  case "$file/" in "$ROOT/"*) ;; *) error "Backup verweigert Datei außerhalb des Roots: $file"; return 1;; esac
  rel="${file#$ROOT/}"; [[ "$file" == "$ROOT" ]] && rel="."
  array_contains "$rel" "${TRACKED_FILES[@]}" && return 0
  TRACKED_FILES+=("$rel")
  if [[ -e "$file" ]]; then state="EXISTED"; mkdir -p "$BACKUP_DIR/files/$(dirname "$rel")"; cp -p "$file" "$BACKUP_DIR/files/$rel"
  else state="MISSING"; fi
  printf '%s\t%s\n' "$state" "$rel" >> "$BACKUP_DIR/manifest.tsv"
}

create_backup_manifest() {
  ((DRY_RUN || BACKUP_CREATED)) && return 0
  mkdir -p "$BACKUP_DIR/files"
  : >"$BACKUP_DIR/manifest.tsv"
  TRACKED_FILES=()

  local file root repo rel generated
  while IFS= read -r -d '' file; do track_file "$file"; done < <(
    find "$ROOT" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance -o -name .deps-update-backups -o -name .deps-update-logs \) -prune -o \
      -type f \( -name package.json -o -name tsconfig.json -o -name pnpm-lock.yaml -o -name pnpm-workspace.yaml -o -name pnpm-workspace.yml -o -name package-lock.json -o -name npm-shrinkwrap.json -o -name yarn.lock \
      -o -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' -o -name '*.sln' -o -name '*.slnx' -o -name Directory.Packages.props -o -name Directory.Build.props -o -name global.json -o -iname NuGet.Config \
      -o -name renovate.json -o -path '*/.changeset/*' -o -path '*/.github/workflows/*' -o -path '*/.github/scripts/*' -o -path '*/.github/dep-upgrader/*' \) -print0 2>/dev/null
  )

  for root in "${NODE_ROOTS[@]}"; do
    for file in package.json pnpm-lock.yaml pnpm-workspace.yaml pnpm-workspace.yml package-lock.json npm-shrinkwrap.json yarn.lock; do track_file "$root/$file"; done
  done
  for repo in "${REPO_ROOTS[@]}"; do
    for generated in ci.yml security.yml quality.yml dependency-maintenance.yml release.yml container.yml deploy-coolify.yml deploy-vercel.yml; do
      track_file "$repo/.github/workflows/$generated"
    done
    track_file "$repo/.github/scripts/dep-upgrader.sh"
    track_file "$repo/.github/dep-upgrader/README.md"
    track_file "$repo/renovate.json"
    track_file "$repo/.changeset/config.json"
    track_file "$repo/.changeset/README.md"
  done

  : >"$BACKUP_DIR/install-roots.txt"
  for root in "${NODE_ROOTS[@]}"; do
    rel="${root#"$ROOT"/}"; [[ "$root" == "$ROOT" ]] && rel="."
    printf '%s\n' "$rel" >>"$BACKUP_DIR/install-roots.txt"
  done
  success "Manifest-Backup angelegt: $BACKUP_DIR"
}

rollback_backup() {
  local backup="$1" manifest rel state src target
  backup="$(abs_path "$backup")"
  manifest="$backup/manifest.tsv"
  [[ -f "$manifest" ]] || { error "Kein gültiges Backup-Manifest: $manifest"; return 1; }
  info "Stelle Dateien aus $backup wieder her …"
  while IFS=$'\t' read -r state rel; do
    [[ -n "$rel" && "$rel" != /* && "$rel" != *'..'* ]] || continue
    target="$ROOT/$rel"; src="$backup/files/$rel"
    if [[ "$state" == EXISTED ]]; then
      mkdir -p "$(dirname "$target")"; cp -p "$src" "$target"; success "Wiederhergestellt: $rel"
    elif [[ "$state" == MISSING ]]; then
      rm -f "$target"; success "Entfernt: $rel"
    fi
  done <"$manifest"

  if command_exists pnpm && [[ -f "$backup/install-roots.txt" ]]; then
    while IFS= read -r rel; do
      [[ -n "$rel" ]] || continue
      [[ "$rel" == "." ]] && target="$ROOT" || target="$ROOT/$rel"
      [[ -d "$target" ]] || continue
      info "Synchronisiere node_modules: $rel"
      (cd "$target" && pnpm install --frozen-lockfile) >>"$CURRENT_LOG" 2>&1 || (cd "$target" && pnpm install) >>"$CURRENT_LOG" 2>&1 || true
    done <"$backup/install-roots.txt"
  fi
  success "Rollback abgeschlossen."
}

create_backup_archive() {
  ((DRY_RUN || BACKUP_CREATED)) && return 0
  local list="$LOG_DIR/backup-files.txt"
  BACKUP_ARCHIVE="$ROOT/.maintenance/backups/$STAMP.tar.gz"
  mkdir -p "$(dirname "$BACKUP_ARCHIVE")"
  (cd "$ROOT" && find . -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( \
    -name package.json -o -name tsconfig.json -o -name pnpm-lock.yaml -o -name pnpm-workspace.yaml -o -name pnpm-workspace.yml -o -name package-lock.json -o -name npm-shrinkwrap.json -o -name yarn.lock \
    -o -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' -o -name '*.sln' -o -name '*.slnx' -o -name Directory.Packages.props -o -name Directory.Build.props -o -name global.json -o -iname NuGet.Config \
    -o -name renovate.json -o -path '*/.changeset/*' -o -path '*/.github/workflows/*' -o -path '*/.github/scripts/*' -o -path '*/.github/dep-upgrader/*' \) -print0) >"$list"
  if [[ -s "$list" ]]; then
    (cd "$ROOT" && tar --null -T "$list" -czf "$BACKUP_ARCHIVE") 2>>"$CURRENT_LOG" && success "Archiv-Backup: $BACKUP_ARCHIVE" || record_failure "Archiv-Backup fehlgeschlagen"
  fi
}

discover_repositories() {
  REPO_ROOTS=()
  local gitdir
  while IFS= read -r -d '' gitdir; do unique_append REPO_ROOTS "$(dirname "$gitdir")"; done < <(
    find "$ROOT" -type d \( -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type d -name .git -print0 -prune 2>/dev/null
  )
  ((${#REPO_ROOTS[@]})) || REPO_ROOTS+=("$ROOT")
}

discover_node_projects() {
  NODE_PROJECTS=(); NODE_TYPES=(); NODE_ROOTS=(); SHARED_PACKAGES=(); INVALID_MANIFESTS=()
  local manifest dir type root
  while IFS= read -r -d '' manifest; do
    matches_filter "$manifest" || continue
    if ! is_valid_json "$manifest"; then INVALID_MANIFESTS+=("$manifest"); continue; fi
    dir="$(dirname "$manifest")"; type="node-package"
    if json_has_next "$manifest"; then type="nextjs-app"; fi
    if command_exists node && node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));process.exit(p.private===false||(!p.private&&p.name)?0:1)' "$manifest" 2>/dev/null; then
      SHARED_PACKAGES+=("$dir")
      [[ "$type" == node-package ]] && type="shared-package"
    fi
    NODE_PROJECTS+=("$manifest"); NODE_TYPES+=("$type")
    root="$(node_workspace_root "$dir")"; unique_append NODE_ROOTS "$root"
  done < <(find "$ROOT" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name dist -o -name build -o -name coverage -o -name .turbo -o -name .cache -o -name .maintenance -o -name .deps-update-backups -o -name .deps-update-logs \) -prune -o -type f -name package.json -print0 2>/dev/null)
}

discover_dotnet_projects() {
  DOTNET_PROJECTS=(); DOTNET_TYPES=()
  local manifest type
  while IFS= read -r -d '' manifest; do
    matches_filter "$manifest" || continue
    type="dotnet-lib"
    grep -Eqi '<OutputType>[^<]*(Exe|WinExe)' "$manifest" 2>/dev/null && type="dotnet-app"
    if grep -Eqi 'PackageReference[^>]+Include="Avalonia|Avalonia\.(Desktop|Controls|Themes)' "$manifest" 2>/dev/null || \
       find "$(dirname "$manifest")" -maxdepth 3 -type f \( -name '*.axaml' -o -name 'App.xaml' \) -print -quit 2>/dev/null | grep -q .; then
      type="avalonia-app"
    fi
    DOTNET_PROJECTS+=("$manifest"); DOTNET_TYPES+=("$type")
  done < <(find "$ROOT" -type d \( -name .git -o -name node_modules -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print0 2>/dev/null)
}

find_install_root() {
  node_workspace_root "$1"
}

ensure_pnpm() {
  command_exists pnpm && return 0
  if ((DRY_RUN)); then info '[Dry-Run] pnpm würde lokal bereitgestellt.'; return 0; fi
  if command_exists corepack; then
    run 'pnpm über Corepack aktivieren' "$ROOT" corepack prepare "pnpm@$PNPM_VERSION" --activate || true
    command_exists pnpm && return 0
  fi
  command_exists npm || { err 'Weder pnpm, Corepack noch npm verfügbar.'; return 1; }
  local tool="$ROOT/.maintenance/tools/pnpm"
  run 'pnpm lokal installieren' "$ROOT" npm --prefix "$tool" install --no-audit --no-fund --save=false "pnpm@$PNPM_VERSION"
  export PATH="$tool/node_modules/.bin:$PATH"
  command_exists pnpm || { err 'pnpm konnte nicht bereitgestellt werden.'; return 1; }
}

migrate_manifest_to_pnpm() {
  local manifest="$1" version="$2"
  is_valid_json "$manifest" || { record_failure "Ungültige package.json: $manifest"; return 1; }
  if ((DRY_RUN)); then info "[Dry-Run] packageManager und npm-Scripts migrieren: $manifest"; return 0; fi
  node - "$manifest" "$version" <<'NODE'
const fs=require('fs');
const [file,version]=process.argv.slice(2);
const p=JSON.parse(fs.readFileSync(file,'utf8'));
p.packageManager=`pnpm@${version}`;
if(p.engines&&p.engines.npm)delete p.engines.npm;
if(p.scripts){
  for(const [key,value] of Object.entries(p.scripts)){
    if(typeof value!=='string')continue;
    p.scripts[key]=value
      .replace(/\bnpm\s+run\s+/g,'pnpm run ')
      .replace(/\bnpm\s+(start|test|install|ci)\b/g,(_,cmd)=>cmd==='ci'?'pnpm install --frozen-lockfile':`pnpm ${cmd}`)
      .replace(/\bnpx\s+/g,'pnpm dlx ')
      .replace(/\byarn\s+run\s+/g,'pnpm run ');
  }
}
fs.writeFileSync(file,JSON.stringify(p,null,2)+'\n');
NODE
  CHANGED=1
}

ensure_workspace_policy() {
  local root="$1" file="$root/pnpm-workspace.yaml" minutes packages="" key value
  [[ "$HARDEN_MODE" == off ]] && return 0
  minutes="$(cooldown_to_minutes "$COOLDOWN" 2>/dev/null || printf '10080')"
  if [[ -f "$root/package.json" ]] && is_valid_json "$root/package.json" && command_exists node; then
    packages="$(node - "$root/package.json" <<'NODE' 2>/dev/null || true
const fs=require('fs'); const p=JSON.parse(fs.readFileSync(process.argv[2],'utf8')); let w=p.workspaces||[]; if(!Array.isArray(w))w=w.packages||[]; for(const x of w)console.log(x);
NODE
)"
  fi
  if [[ -z "$packages" ]]; then
    [[ -d "$root/apps" ]] && packages+=$'apps/*\n'
    [[ -d "$root/packages" ]] && packages+=$'packages/*\n'
    [[ -d "$root/services" ]] && packages+=$'services/*\n'
  fi

  if ((DRY_RUN)); then info "[Dry-Run] pnpm-Policy ($minutes Minuten) in $file"; return 0; fi
  if [[ ! -f "$file" ]]; then
    if [[ -n "$packages" ]]; then
      { printf 'packages:\n'; while IFS= read -r value; do [[ -n "$value" ]] && printf '  - "%s"\n' "$value"; done <<<"$packages"; } >"$file"
    else
      printf 'packages: []\n' >"$file"
    fi
  fi

  set_yaml_key() {
    local yaml="$1" yaml_key="$2" yaml_value="$3"
    if grep -Eq "^${yaml_key}:" "$yaml"; then
      sed -i.bak -E "s|^${yaml_key}:.*|${yaml_key}: ${yaml_value}|" "$yaml"; rm -f "$yaml.bak"
    else
      printf '%s: %s\n' "$yaml_key" "$yaml_value" >>"$yaml"
    fi
  }
  set_yaml_key "$file" minimumReleaseAge "$minutes"
  if [[ "$HARDEN_MODE" == balanced || "$HARDEN_MODE" == strict ]]; then
    if ((PNPM_MAJOR > 10 || (PNPM_MAJOR == 10 && PNPM_MINOR >= 26) || PNPM_MAJOR == 0)); then set_yaml_key "$file" blockExoticSubdeps true; fi
  fi
  if [[ "$HARDEN_MODE" == strict ]]; then
    if ((PNPM_MAJOR > 10 || (PNPM_MAJOR == 10 && PNPM_MINOR >= 21) || PNPM_MAJOR == 0)); then set_yaml_key "$file" trustPolicy no-downgrade; fi
    if ((PNPM_MAJOR >= 11)); then set_yaml_key "$file" minimumReleaseAgeStrict true; fi
  fi
  success "pnpm-Policy gesetzt: $file"
  CHANGED=1
}

ncu_target() { case "$MODE" in patch) printf patch;; minor) printf minor;; semver-safe) printf semver;; *) printf latest;; esac; }

ncu_has_cooldown() {
  [[ -n "$NCU_SUPPORTS_COOLDOWN" ]] && [[ "$NCU_SUPPORTS_COOLDOWN" == 1 ]] && return 0
  if ((DRY_RUN)); then NCU_SUPPORTS_COOLDOWN=1; return 0; fi
  if pnpm dlx "$NCU_PACKAGE" --help 2>/dev/null | grep -q -- '--cooldown'; then NCU_SUPPORTS_COOLDOWN=1; else NCU_SUPPORTS_COOLDOWN=0; fi
  [[ "$NCU_SUPPORTS_COOLDOWN" == 1 ]]
}

update_node() {
  ((${#NODE_PROJECTS[@]})) || { info 'Keine Node-Projekte ausgewählt.'; return 0; }
  ensure_pnpm || return 1
  create_backup_once
  cleanup_node

  local version manifest dir root target sbom_file safe_name
  local -a args
  if command_exists pnpm; then version="$(pnpm --version 2>/dev/null || printf '%s.0.0' "$PNPM_VERSION")"; else version="${PNPM_VERSION}.0.0"; fi

  if ((MIGRATE_NPM)); then
    for root in "${NODE_ROOTS[@]}"; do migrate_npm_to_pnpm "$root" || true; done
  fi

  for manifest in "${NODE_PROJECTS[@]}"; do
    [[ "$ABORT_PIPELINE" -eq 0 ]] || break
    dir="$(dirname "$manifest")"
    if ! is_valid_json "$manifest"; then record_failure "Ungültige package.json: $manifest"; continue; fi
    migrate_manifest_to_pnpm "$manifest" "$version" || true
    args=(--packageManager pnpm --dep prod,dev,optional,peer,packageManager --format group,cooldown --install never)
    if [[ "$MODE" == interactive ]]; then args+=(--interactive); else target="$(ncu_target)"; args+=(--target "$target"); ((DRY_RUN)) || args+=(-u); fi
    if [[ "$COOLDOWN" != 0 && -n "$COOLDOWN" ]] && ncu_has_cooldown; then args+=(--cooldown "$COOLDOWN"); fi
    if run_logged "Dependencies prüfen/aktualisieren: ${manifest#"$ROOT"/}" "$dir" pnpm dlx "$NCU_PACKAGE" "${args[@]}"; then
      ((UPDATED_APPS+=1))
    else
      record_failure "ncu: $dir" || break
    fi
  done

  for root in "${NODE_ROOTS[@]}"; do
    [[ "$ABORT_PIPELINE" -eq 0 ]] || break
    [[ -f "$root/package.json" ]] && migrate_manifest_to_pnpm "$root/package.json" "$version" || true
    apply_hardening "$root"
    run_logged 'pnpm install --fix-lockfile' "$root" pnpm install --fix-lockfile || record_failure "install: $root"
    if ((DEDUPE)); then run_logged 'pnpm dedupe' "$root" pnpm dedupe || record_failure "dedupe: $root"; fi
    if ((PNPM_MAJOR >= 11)); then run_logged 'Peer-Dependencies prüfen' "$root" pnpm peers check || record_failure "peer dependencies: $root"; fi
    [[ "$AUDIT_MODE" == off ]] || run_security_audit "$root"
    if ((SIGNATURES)) && ((PNPM_MAJOR > 11 || (PNPM_MAJOR == 11 && PNPM_MINOR >= 1))); then
      run_logged 'Registry-Signaturen prüfen' "$root" pnpm audit signatures || record_failure "signature audit: $root"
    fi
    if ((GENERATE_SBOM)); then
      safe_name="${root#"$ROOT"/}"; [[ "$root" == "$ROOT" ]] && safe_name=root; safe_name="${safe_name//\//_}"
      sbom_file="$LOG_DIR/sbom-${safe_name}.cdx.json"
      if ((DRY_RUN)); then info "[Dry-Run] SBOM: $sbom_file"
      elif (cd "$root" && pnpm sbom --sbom-format cyclonedx >"$sbom_file") 2>>"$CURRENT_LOG"; then success "SBOM: $sbom_file"
      else record_failure "sbom: $root"; fi
    fi
    ((VALIDATE_WORKSPACE)) && validate_workspace "$root" || true
  done
}

update_nextjs_apps() {
  update_node
}

ensure_dotnet_outdated() {
  local tool="$ROOT/.maintenance/tools/dotnet-outdated" bin="$ROOT/.maintenance/tools/dotnet-outdated/dotnet-outdated"
  [[ -x "$bin" ]] && { printf '%s\n' "$bin"; return; }
  ((DRY_RUN)) && { printf '%s\n' "$bin"; return; }
  mkdir -p "$tool"
  dotnet tool install dotnet-outdated-tool --tool-path "$tool" >>"$LOG_DIR/commands.log" 2>&1 || return 1
  printf '%s\n' "$bin"
}

update_dotnet() {
  ((${#DOTNET_PROJECTS[@]})) || { info 'Keine .NET-Projekte ausgewählt.'; return 0; }
  command_exists dotnet || { err 'dotnet fehlt.'; return 1; }
  create_backup_once
  local project dir tool lock
  for project in "${DOTNET_PROJECTS[@]}"; do
    dir="$(dirname "$project")"
    if dotnet package update --help >/dev/null 2>&1 && [[ "$MODE" == latest ]]; then
      run "NuGet aktualisieren: ${project#"$ROOT"/}" "$dir" dotnet package update --project "$project" || true
    else
      tool="$(ensure_dotnet_outdated || true)"
      [[ -n "$tool" ]] || { record_failure "dotnet-outdated fehlt: $project"; continue; }
      lock=None; [[ "$MODE" == minor || "$MODE" == semver-safe || "$MODE" == semver ]] && lock=Major; [[ "$MODE" == patch ]] && lock=Minor
      if [[ "$MODE" == interactive ]]; then
        run 'NuGet interaktiv aktualisieren' "$dir" "$tool" "$project" --upgrade:Prompt --pre-release Never --version-lock "$lock" || true
      else
        run 'NuGet aktualisieren' "$dir" "$tool" "$project" --upgrade --pre-release Never --version-lock "$lock" || true
      fi
    fi
    run 'dotnet restore mit NuGet-Audit' "$dir" dotnet restore "$project" -p:NuGetAudit=true -p:NuGetAuditMode=all -p:NuGetAuditLevel="$AUDIT_LEVEL" || true
  done
}


write_generated_file() {
  local path="$1" mode="${2:-0644}" tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  if [[ -e "$path" && "$CI_FORCE" -ne 1 ]]; then warn "Existiert, nicht überschrieben: $path"; rm -f "$tmp"; return 0; fi
  if ((DRY_RUN)); then
    info "[Dry-Run] Erzeuge $path"
    mkdir -p "$LOG_DIR/previews"
    cp "$tmp" "$LOG_DIR/previews/$(printf '%s' "${path#"$ROOT"/}" | tr '/' '_')" 2>/dev/null || true
    rm -f "$tmp"
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  mv "$tmp" "$path"
  chmod "$mode" "$path"
  success "Erzeugt: $path"
  CHANGED=1
}

ensure_gitignore_entry() {
  local repo="$1" entry="$2" file="$repo/.gitignore"
  grep -Fxq "$entry" "$file" 2>/dev/null && return 0
  if ((DRY_RUN)); then info "[Dry-Run] .gitignore: $entry"
  else mkdir -p "$repo"; printf '%s\n' "$entry" >>"$file"; CHANGED=1; fi
}

create_backup_once() {
  ((BACKUP_CREATED)) && return 0
  if ((DRY_RUN)); then info '[Dry-Run] Backup würde erstellt.'; BACKUP_CREATED=1; return 0; fi
  create_backup_manifest
  create_backup_archive
  BACKUP_CREATED=1
}

create_backup() { create_backup_once; }

prepare_node_for_cicd() {
  ((${#NODE_PROJECTS[@]})) || return 0
  ensure_pnpm || return 1
  create_backup_once
  cleanup_node
  local version manifest root
  version="$(pnpm --version 2>/dev/null || printf '%s.0.0' "$PNPM_VERSION")"
  for root in "${NODE_ROOTS[@]}"; do ((MIGRATE_NPM)) && migrate_npm_to_pnpm "$root" || true; done
  for manifest in "${NODE_PROJECTS[@]}"; do is_valid_json "$manifest" && migrate_manifest_to_pnpm "$manifest" "$version" || true; done
  for root in "${NODE_ROOTS[@]}"; do
    [[ -f "$root/package.json" ]] && migrate_manifest_to_pnpm "$root/package.json" "$version" || true
    apply_hardening "$root"
    run 'pnpm install --fix-lockfile' "$root" pnpm install --fix-lockfile || true
  done
}

cleanup_dotnet() {
  local project dir target
  for project in "${DOTNET_PROJECTS[@]}"; do
    dir="$(dirname "$project")"
    for target in "$dir/bin" "$dir/obj"; do
      [[ -e "$target" ]] || continue
      if ((DRY_RUN)); then info "[Dry-Run] Löschen: $target"; else rm -rf -- "$target"; success "Gelöscht: $target"; CHANGED=1; fi
    done
  done
}

run_app_script_if_present() {
  local app_dir="$1" script="$2" label="$3"
  if has_script "$app_dir/package.json" "$script"; then run_logged "$label" "$app_dir" pnpm run "$script"
  else muted "  ↷ $label übersprungen: Script '$script' fehlt"; fi
}


security() {
  local root project dir file
  for root in "${NODE_ROOTS[@]}"; do
    ensure_pnpm || break
    if [[ "$AUDIT_MODE" != off ]]; then
      run 'pnpm audit' "$root" pnpm audit --audit-level "$AUDIT_LEVEL" || true
    fi
    if ((SIGNATURES)) && pnpm audit --help 2>/dev/null | grep -q signatures; then
      run 'pnpm audit signatures' "$root" pnpm audit signatures || true
    fi
  done
  if has dotnet; then
    for project in "${DOTNET_PROJECTS[@]}"; do
      dir="$(dirname "$project")"
      if dotnet package list --help >/dev/null 2>&1; then
        run 'NuGet vulnerable' "$dir" dotnet package list --project "$project" --vulnerable --include-transitive --format json || true
      else
        run 'NuGet vulnerable' "$dir" dotnet list "$project" package --vulnerable --include-transitive --format json || true
      fi
    done
    run 'NuGet-Quellen' "$ROOT" dotnet nuget list source || true
  fi
  while IFS= read -r file; do
    grep -En 'value="http://|Version="(\*|[^\"]*-)' "$file" >>"$LOG_DIR/security-static.txt" 2>/dev/null || true
  done < <(find "$ROOT" -type f \( -iname NuGet.Config -o -name '*.csproj' -o -name Directory.Packages.props \) -not -path '*/bin/*' -not -path '*/obj/*')
}

node_script() {
  local manifest="$1" script="$2" dir
  dir="$(dirname "$manifest")"
  node -e 'const p=require(process.argv[1]);process.exit(p.scripts&&p.scripts[process.argv[2]]?0:1)' "$manifest" "$script" 2>/dev/null || return 0
  run "$script: ${manifest#$ROOT/}" "$dir" pnpm run "$script" || true
}

validate() {
  local manifest project dir action index project_type
  if [[ "$ECOSYSTEMS" != dotnet ]] && ((${#NODE_PROJECTS[@]})); then
    ensure_pnpm || true
    for manifest in "${NODE_PROJECTS[@]}"; do
      case "$VALIDATE_MODE" in
        quick) for action in lint typecheck; do node_script "$manifest" "$action"; done ;;
        build|publish) node_script "$manifest" build ;;
        format) node_script "$manifest" format:check; node_script "$manifest" format ;;
        test) node_script "$manifest" test ;;
        run)
          if node -e 'const p=require(process.argv[1]);process.exit(p.scripts&&p.scripts.dev?0:1)' "$manifest" 2>/dev/null; then node_script "$manifest" dev; else node_script "$manifest" start; fi
          ;;
        *) for action in lint format:check typecheck test build; do node_script "$manifest" "$action"; done ;;
      esac
    done
  fi
  if [[ "$ECOSYSTEMS" != node ]] && has dotnet; then
    for index in "${!DOTNET_PROJECTS[@]}"; do
      project="${DOTNET_PROJECTS[$index]}"; project_type="${DOTNET_TYPES[$index]}"; dir="$(dirname "$project")"
      run 'dotnet restore' "$dir" dotnet restore "$project" || true
      case "$VALIDATE_MODE" in quick|full|build) run 'dotnet build' "$dir" dotnet build "$project" --no-restore || true ;; esac
      case "$VALIDATE_MODE" in
        format|full) if dotnet format --help >/dev/null 2>&1; then run 'dotnet format' "$dir" dotnet format "$project" --verify-no-changes || true; fi ;;
        run) if [[ "$project_type" == dotnet-app || "$project_type" == avalonia-app ]]; then run 'dotnet run' "$dir" dotnet run --project "$project" --no-restore || true; fi ;;
        publish)
          if [[ "$project_type" == dotnet-app || "$project_type" == avalonia-app ]]; then
            local publish_args=(publish "$project" -c Release --no-restore)
            if [[ -n "$RID" ]]; then publish_args+=(-r "$RID" --self-contained true); fi
            run 'dotnet publish' "$dir" dotnet "${publish_args[@]}" || true
          fi
          ;;
      esac
      if grep -Eqi 'Microsoft.NET.Test.Sdk|<IsTestProject>true' "$project"; then
        case "$VALIDATE_MODE" in test|full) run 'dotnet test' "$dir" dotnet test "$project" --no-restore || true ;; esac
      fi
    done
  fi
}

quality() {
  local root package project report node_tools=1
  if ((${#NODE_ROOTS[@]})) && ! ensure_pnpm; then node_tools=0; fi
  if ((node_tools)); then
    for root in "${NODE_ROOTS[@]}"; do
      run 'Syncpack' "$root" pnpm dlx syncpack@latest "$([[ "$FIX" == 1 ]] && printf fix || printf lint)" || true
      run 'Knip' "$root" pnpm dlx knip@latest --reporter json || true
      if [[ "$QUALITY_PROFILE" != quick ]]; then
        run 'Dependency Cruiser' "$root" pnpm dlx dependency-cruiser@latest --no-config --output-type json --exclude '(^|/)node_modules(/|$)' . || true
      fi
    done
    for package in "${SHARED_PACKAGES[@]}"; do
      run 'Publint' "$package" pnpm dlx publint@latest "$package" || true
      [[ "$QUALITY_PROFILE" == quick ]] || run 'Are The Types Wrong' "$package" pnpm dlx @arethetypeswrong/cli@latest --pack "$package" || true
    done
    [[ "$QUALITY_PROFILE" == quick ]] || run 'JSCPD' "$ROOT" pnpm dlx jscpd@latest --min-lines 10 --min-tokens 70 --reporters console,json --output "$LOG_DIR/jscpd" "$ROOT" || true
  fi
  if has osv-scanner; then
    report="$LOG_DIR/osv-scanner.json"; run 'OSV-Scanner' "$ROOT" osv-scanner scan source --recursive --format=json --output-file "$report" "$ROOT" || true
  else
    warn 'OSV-Scanner fehlt; Scan übersprungen.'
  fi
  if [[ "$QUALITY_PROFILE" == deep ]]; then
    if has trivy; then run 'Trivy Deep Scan' "$ROOT" trivy fs --scanners vuln,secret,misconfig,license --format json --output "$LOG_DIR/trivy.json" "$ROOT" || true; else warn 'Trivy fehlt; Deep Scan übersprungen.'; fi
    if has dotnet && ((${#DOTNET_PROJECTS[@]})); then
      local stryker="$ROOT/.maintenance/tools/stryker/dotnet-stryker"
      if [[ ! -x "$stryker" && "$INSTALL_TOOLS" == 1 ]]; then run 'Stryker.NET lokal installieren' "$ROOT" dotnet tool install dotnet-stryker --tool-path "$(dirname "$stryker")" || true; fi
      if [[ -x "$stryker" ]]; then
        for project in "${DOTNET_PROJECTS[@]}"; do grep -Eqi 'Microsoft.NET.Test.Sdk|<IsTestProject>true' "$project" && run 'Stryker.NET' "$(dirname "$project")" "$stryker" || true; done
      else
        warn 'Stryker.NET fehlt; mit --install-tools lokal installieren.'
      fi
    fi
  fi
}

generate_renovate_for_repo() {
  local repo="$1" file="$repo/renovate.json"
  write_generated_file "$file" <<'JSON'
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:recommended"],
  "minimumReleaseAge": "7 days",
  "dependencyDashboard": true,
  "rangeStrategy": "replace",
  "labels": ["dependencies", "automated"],
  "packageRules": [
    {
      "matchManagers": ["npm"],
      "groupName": "Node dependencies",
      "minimumReleaseAge": "7 days",
      "rangeStrategy": "replace"
    },
    {
      "matchManagers": ["nuget"],
      "groupName": "NuGet dependencies",
      "minimumReleaseAge": "7 days"
    },
    {
      "matchManagers": ["github-actions"],
      "groupName": "GitHub Actions",
      "pinDigests": true
    },
    {
      "matchDepTypes": ["devDependencies"],
      "groupName": "Development dependencies"
    }
  ]
}
JSON
}

generate_changesets_for_repo() {
  local repo="$1" file="$repo/.changeset/config.json"
  [[ -n "$(find "$repo" -type f -name package.json -not -path '*/node_modules/*' -print -quit 2>/dev/null)" ]] || return 0
  write_generated_file "$file" <<'JSON'
{
  "$schema": "https://unpkg.com/@changesets/config@3.1.1/schema.json",
  "changelog": "@changesets/cli/changelog",
  "commit": false,
  "fixed": [],
  "linked": [],
  "access": "restricted",
  "baseBranch": "main",
  "updateInternalDependencies": "patch",
  "ignore": []
}
JSON
  if [[ ! -e "$repo/.changeset/README.md" || "$CI_FORCE" -eq 1 ]]; then
    write_generated_file "$repo/.changeset/README.md" <<'MD'
# Changesets

Run `pnpm changeset` for user-facing package changes. Review generated version and changelog changes before publishing.
MD
  fi
}

automation() {
  create_backup_once
  local repo
  for repo in "${REPO_ROOTS[@]}"; do
    generate_renovate_for_repo "$repo"
    generate_changesets_for_repo "$repo"
  done
}

config_analysis() {
  local env_report="$LOG_DIR/env-keys.txt" dotnet_report="$LOG_DIR/dotnet-config-keys.txt"
  { grep -RhoE 'process\.env\.[A-Z0-9_]+' "$ROOT" --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=bin --exclude-dir=obj --exclude-dir=.maintenance 2>/dev/null || true; } | sed 's/^process\.env\.//' | sort -u >"$env_report"
  { grep -RhoE 'Environment\.GetEnvironmentVariable\("[^"]+"\)|Configuration\["[^"]+"\]' "$ROOT" --exclude-dir=.git --exclude-dir=bin --exclude-dir=obj --exclude-dir=.maintenance 2>/dev/null || true; } | sed -E 's/.*\("([^"]+)"\).*/\1/;s/.*\["([^"]+)"\].*/\1/' | sort -u >"$dotnet_report"
  cat "$env_report" "$dotnet_report" | sort -u >"$LOG_DIR/config-keys.txt"
  ok "Config-Report: $LOG_DIR/config-keys.txt"

  ((ASSUME_YES || FIX)) || return 0
  if [[ -s "$env_report" && ! -e "$ROOT/.env.example" ]]; then
    if ((DRY_RUN)); then info "[Dry-Run] Erzeuge $ROOT/.env.example"; else while IFS= read -r key; do [[ -n "$key" ]] && printf '%s=\n' "$key"; done <"$env_report" >"$ROOT/.env.example"; ok 'Erzeugt: .env.example'; CHANGED=1; fi
  fi
  if [[ -s "$dotnet_report" && ! -e "$ROOT/appsettings.Example.json" ]]; then
    if ((DRY_RUN)); then info "[Dry-Run] Erzeuge $ROOT/appsettings.Example.json"; else
      if has node; then
        node - "$dotnet_report" "$ROOT/appsettings.Example.json" <<'NODE'
const fs=require('fs');const [input,output]=process.argv.slice(2);const result={};
for(const key of fs.readFileSync(input,'utf8').split(/\r?\n/).filter(Boolean)) result[key]='';
fs.writeFileSync(output,JSON.stringify(result,null,2)+'\n');
NODE
      else
        printf '{}\n' >"$ROOT/appsettings.Example.json"
      fi
      ok 'Erzeugt: appsettings.Example.json'; CHANGED=1
    fi
  fi
}

dedupe() {
  local root
  for root in "${NODE_ROOTS[@]}"; do ensure_pnpm || continue; run 'pnpm dedupe' "$root" pnpm dedupe || true; run 'Syncpack lint' "$root" pnpm dlx syncpack@latest lint || true; done
  grep -RhoE '<PackageReference[^>]+Include="[^"]+"[^>]+Version="[^"]+"' "$ROOT" --include='*.csproj' --exclude-dir=bin --exclude-dir=obj 2>/dev/null | sort >"$LOG_DIR/nuget-version-consolidation.txt" || true
  ok "NuGet-Konsolidierungsreport: $LOG_DIR/nuget-version-consolidation.txt"
}

ui_analysis() {
  find "$ROOT" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( \
    -path '*/components/*' -o -path '*/Styles/*' -o -path '*/Themes/*' -o -path '*/Controls/*' -o -path '*/Views/*' -o -path '*/ViewModels/*' \
    -o -name '*.axaml' -o -name '*.css' -o -name '*.scss' \) -print | sed "s,^$ROOT/,," | sort >"$LOG_DIR/ui-candidates.txt"
  ok "UI-Kandidaten: $LOG_DIR/ui-candidates.txt"
  warn 'Analyse-only: Keine Dateien wurden verschoben oder Imports umgeschrieben.'
}


# ---------- pnpm hardening ----------
report_hardening() {
  local install_root="$1" key value
  printf '\n%s▶%s pnpm-Sicherheitseinstellungen: %s\n' "$C_MAGENTA" "$C_RESET" "$install_root"
  if ! command_exists pnpm; then muted '  pnpm ist nicht verfügbar.'; return 0; fi
  for key in minimumReleaseAge minimumReleaseAgeStrict blockExoticSubdeps trustPolicy dangerouslyAllowAllBuilds; do
    value="$(cd "$install_root" && pnpm config get --location=project "$key" 2>/dev/null || true)"
    [[ -n "$value" ]] || value="(nicht gesetzt)"
    printf '  %-29s %s\n' "$key:" "$value" | tee -a "$CURRENT_LOG"
  done
}

apply_hardening() {
  local install_root="$1"
  [[ "$HARDEN_MODE" == off ]] && return 0
  if [[ "$HARDEN_MODE" != report ]]; then ensure_workspace_policy "$install_root"; fi
  report_hardening "$install_root"
}

run_security_audit() {
  local install_root="$1"
  case "$AUDIT_MODE" in
    off) return 0 ;;
    report)
      run_logged 'Security-Audit' "$install_root" pnpm audit --audit-level "$AUDIT_LEVEL" || record_failure "audit findings: $install_root"
      ;;
    interactive)
      if ((PNPM_MAJOR >= 11)); then run_logged 'Security-Audit interaktiv beheben' "$install_root" pnpm audit --fix=update --interactive --audit-level "$AUDIT_LEVEL" || record_failure "audit fix interactive: $install_root"
      else run_logged 'Security-Audit beheben' "$install_root" pnpm audit --fix --audit-level "$AUDIT_LEVEL" || record_failure "audit fix: $install_root"; fi
      ;;
    fix)
      if ((PNPM_MAJOR >= 11)); then run_logged 'Security-Audit automatisch beheben' "$install_root" pnpm audit --fix=update --audit-level "$AUDIT_LEVEL" || record_failure "audit auto-fix: $install_root"
      else run_logged 'Security-Audit automatisch beheben' "$install_root" pnpm audit --fix --audit-level "$AUDIT_LEVEL" || record_failure "audit auto-fix: $install_root"; fi
      ;;
  esac
  if [[ "$AUDIT_MODE" == interactive || "$AUDIT_MODE" == fix ]]; then
    run_logged 'Lockfile nach Audit-Fix synchronisieren' "$install_root" pnpm install || record_failure "post-audit install: $install_root"
    run_logged 'Security-Audit nach Fix' "$install_root" pnpm audit --audit-level "$AUDIT_LEVEL" || record_failure "remaining audit findings: $install_root"
  fi
}

repo_has_node() { find "$1" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f -name package.json -print -quit | grep -q .; }
repo_has_dotnet() { find "$1" -type d \( -name .git -o -name node_modules -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print -quit | grep -q .; }
repo_has_docker() { find "$1" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( -name Dockerfile -o -name 'Dockerfile.*' \) -print -quit | grep -q .; }
repo_has_next() { grep -Rql '"next"[[:space:]]*:' "$1" --include=package.json --exclude-dir=node_modules --exclude-dir=.next --exclude-dir=.git 2>/dev/null; }

repo_dotnet_release_projects() {
  local repo="$1" project
  while IFS= read -r -d '' project; do
    if grep -Eqi '<OutputType>[^<]*(Exe|WinExe)' "$project" || grep -Eqi 'PackageReference[^>]+Include="Avalonia' "$project"; then printf '%s\0' "$project"; fi
  done < <(find "$repo" -type d \( -name .git -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -print0)
}

repo_default_branch() {
  local repo="$1" branch
  [[ -n "$DEFAULT_BRANCH" ]] && { printf '%s\n' "$DEFAULT_BRANCH"; return; }
  branch="$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##' || true)"
  [[ -n "$branch" ]] || branch="$(git -C "$repo" branch --show-current 2>/dev/null || true)"
  [[ -n "$branch" ]] || branch="main"
  printf '%s\n' "$branch"
}

install_ci_script() {
  local repo="$1" destination="$repo/.github/scripts/dep-upgrader.sh"
  ((INSTALL_CI_SCRIPT)) || return 0
  if [[ -e "$destination" && "$CI_FORCE" -ne 1 ]]; then warn "Existiert, nicht überschrieben: $destination"; return 0; fi
  if ((DRY_RUN)); then info "[Dry-Run] Installiere Script: $destination"; return 0; fi
  mkdir -p "$(dirname "$destination")"
  cp "$SELF_PATH" "$destination"
  chmod 0755 "$destination"
  ok "Installiert: $destination"
  CHANGED=1
}

generate_ci_workflow() {
  local repo="$1" has_node="$2" has_dotnet="$3" branch="$4" path="$repo/.github/workflows/ci.yml"
  {
    cat <<YAML
name: CI

on:
  push:
    branches: ["$branch", "dev", "develop"]
  pull_request:
  workflow_dispatch:

concurrency:
  group: \${{ github.workflow }}-\${{ github.ref }}
  cancel-in-progress: true

permissions:
  contents: read

jobs:
YAML
    if ((has_node)); then cat <<YAML
  node:
    name: Node / pnpm
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v6
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
          cache: pnpm
          cache-dependency-path: "**/pnpm-lock.yaml"
      - name: Install dependencies
        shell: bash
        run: |
          set -euo pipefail
          found=0
          while IFS= read -r -d '' lock; do
            found=1
            root="\$(dirname "\$lock")"
            (cd "\$root" && pnpm install --frozen-lockfile)
          done < <(find . -type f -name pnpm-lock.yaml -not -path '*/node_modules/*' -print0)
          if [ "\$found" -eq 0 ]; then pnpm install --no-frozen-lockfile; fi
      - name: Lint, typecheck, test and build
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' manifest; do
            dir="\$(dirname "\$manifest")"
            for script in lint format:check typecheck test build; do
              if node -e 'const p=require(process.argv[1]);process.exit(p.scripts&&p.scripts[process.argv[2]]?0:1)' "\$manifest" "\$script"; then
                (cd "\$dir" && pnpm run "\$script")
              fi
            done
          done < <(find . -type f -name package.json -not -path '*/node_modules/*' -not -path '*/.next/*' -print0)
YAML
    fi
    if ((has_dotnet)); then cat <<YAML
  dotnet:
    name: .NET / Avalonia
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: "$DOTNET_VERSION"
      - name: Restore, audit and build
        shell: bash
        run: |
          set -euo pipefail
          mapfile -d '' solutions < <(find . -type f \( -name '*.sln' -o -name '*.slnx' \) -not -path '*/bin/*' -not -path '*/obj/*' -print0)
          if [ "\${#solutions[@]}" -gt 0 ]; then targets=("\${solutions[@]}"); else mapfile -d '' targets < <(find . -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -not -path '*/bin/*' -not -path '*/obj/*' -print0); fi
          for target in "\${targets[@]}"; do
            dotnet restore "\$target" -p:NuGetAudit=true -p:NuGetAuditMode=all -p:NuGetAuditLevel=moderate
            dotnet build "\$target" -c Release --no-restore
          done
      - name: Tests
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' project; do
            if grep -Eqi 'Microsoft.NET.Test.Sdk|<IsTestProject>true' "\$project"; then dotnet test "\$project" -c Release --no-restore; fi
          done < <(find . -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -not -path '*/bin/*' -not -path '*/obj/*' -print0)
      - name: Format check
        shell: bash
        run: |
          set -euo pipefail
          target="\$(find . -type f \( -name '*.slnx' -o -name '*.sln' -o -name '*.csproj' \) -not -path '*/bin/*' -not -path '*/obj/*' | head -n 1)"
          if [ -n "\$target" ]; then dotnet format "\$target" --verify-no-changes --no-restore; fi
YAML
    fi
  } | write_generated_file "$path"
}

generate_quality_workflow() {
  local repo="$1" path="$repo/.github/workflows/quality.yml"
  cat <<YAML | write_generated_file "$path"
name: Quality

on:
  pull_request:
  push:
    branches: ["$(repo_default_branch "$repo")"]
  schedule:
    - cron: "43 4 * * 6"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  node-quality:
    name: Node quality analysis
    runs-on: ubuntu-latest
    timeout-minutes: 45
    steps:
      - uses: actions/checkout@v6
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
          cache: pnpm
          cache-dependency-path: "**/pnpm-lock.yaml"
      - name: Install
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' lock; do (cd "\$(dirname "\$lock")" && pnpm install --frozen-lockfile); done < <(find . -type f -name pnpm-lock.yaml -not -path '*/node_modules/*' -print0)
      - name: Syncpack
        run: pnpm dlx syncpack@latest lint
      - name: Knip
        continue-on-error: true
        run: pnpm dlx knip@latest --reporter compact
      - name: Dependency Cruiser
        continue-on-error: true
        run: pnpm dlx dependency-cruiser@latest --no-config --output-type err --exclude '(^|/)node_modules(/|$)' .
      - name: Duplicate code
        continue-on-error: true
        run: pnpm dlx jscpd@latest --min-lines 10 --min-tokens 70 --reporters console .
      - name: Package validation
        continue-on-error: true
        shell: bash
        run: |
          while IFS= read -r -d '' manifest; do
            if node -e 'const p=require(process.argv[1]);process.exit(p.private===false||(!p.private&&p.name)?0:1)' "\$manifest"; then
              dir="\$(dirname "\$manifest")"
              pnpm dlx publint@latest "\$dir" || true
              pnpm dlx @arethetypeswrong/cli@latest --pack "\$dir" || true
            fi
          done < <(find . -type f -name package.json -not -path '*/node_modules/*' -print0)
YAML
}

generate_security_workflow() {
  local repo="$1" has_node="$2" has_dotnet="$3" path="$repo/.github/workflows/security.yml" languages=""
  ((has_node)) && languages="javascript-typescript"
  if ((has_dotnet)); then [[ -n "$languages" ]] && languages+=","; languages+="csharp"; fi
  {
    cat <<YAML
name: Security

on:
  pull_request:
  push:
    branches: ["$(repo_default_branch "$repo")"]
  schedule:
    - cron: "11 2 * * 3"
  workflow_dispatch:

permissions:
  contents: read
  security-events: write

jobs:
  dependency-review:
    name: Dependency Review
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@v6
      - uses: actions/dependency-review-action@v5
        continue-on-error: \${{ github.event.repository.visibility != 'public' }}
        with:
          fail-on-severity: moderate

YAML
    if [[ -n "$languages" ]]; then cat <<YAML
  codeql:
    name: CodeQL
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v6
      - uses: github/codeql-action/init@v4
        with:
          languages: "$languages"
      - uses: github/codeql-action/autobuild@v4
      - uses: github/codeql-action/analyze@v4
        with:
          category: "/language:$languages"

YAML
    fi
    cat <<YAML
  native-audits:
    name: Native dependency audits
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v6
YAML
    if ((has_node)); then cat <<YAML
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
      - name: pnpm audit
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' lock; do
            root="\$(dirname "\$lock")"
            (cd "\$root" && pnpm audit --audit-level moderate)
            if pnpm audit --help | grep -q signatures; then (cd "\$root" && pnpm audit signatures); fi
          done < <(find . -type f -name pnpm-lock.yaml -not -path '*/node_modules/*' -print0)
YAML
    fi
    if ((has_dotnet)); then cat <<YAML
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: "$DOTNET_VERSION"
      - name: NuGet audit
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' project; do
            dotnet restore "\$project" -p:NuGetAudit=true -p:NuGetAuditMode=all -p:NuGetAuditLevel=moderate
            if dotnet package list --help >/dev/null 2>&1; then
              dotnet package list --project "\$project" --vulnerable --include-transitive --format json
            else
              dotnet list "\$project" package --vulnerable --include-transitive --format json
            fi
          done < <(find . -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) -not -path '*/bin/*' -not -path '*/obj/*' -print0)
          dotnet nuget list source
YAML
    fi
  } | write_generated_file "$path"
}

generate_dependency_maintenance_workflow() {
  local repo="$1" has_node="$2" has_dotnet="$3" branch="$4" path="$repo/.github/workflows/dependency-maintenance.yml"
  {
    cat <<YAML
name: Dependency Maintenance

on:
  schedule:
    - cron: "$MAINTENANCE_CRON"
  workflow_dispatch:
    inputs:
      mode:
        description: Update mode
        required: true
        default: semver-safe
        type: choice
        options: [semver-safe, patch, minor, latest]

permissions:
  contents: write
  pull-requests: write

concurrency:
  group: dependency-maintenance
  cancel-in-progress: false

jobs:
  update:
    runs-on: ubuntu-latest
    timeout-minutes: 90
    env:
      GH_TOKEN: \${{ secrets.DEP_UPGRADER_TOKEN || github.token }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
YAML
    if ((has_node)); then cat <<YAML
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
YAML
    fi
    if ((has_dotnet)); then cat <<YAML
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: "$DOTNET_VERSION"
YAML
    fi
    cat <<'YAML'
      - name: Update dependencies
        shell: bash
        run: |
          set -euo pipefail
          mode="${{ inputs.mode || 'semver-safe' }}"
          bash .github/scripts/dep-upgrader.sh \
            --root . \
            --non-interactive \
            --module deps \
            --mode "$mode" \
            --audit report \
            --harden strict \
            --yes \
            --keep-going
          rm -rf .maintenance
      - name: Create pull request
        shell: bash
        run: |
          set -euo pipefail
          git add -A
          if git diff --cached --quiet; then
            echo "No dependency changes."
            exit 0
          fi
          branch="automation/dependency-maintenance-${GITHUB_RUN_ID}"
          git config user.name "github-actions[bot]"
          git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
          git checkout -b "$branch"
          git commit -m "chore(deps): automated dependency maintenance"
          git remote set-url origin "https://x-access-token:${GH_TOKEN}@github.com/${GITHUB_REPOSITORY}.git"
          git push --set-upstream origin "$branch"
          gh pr create \
            --base "${{ github.event.repository.default_branch }}" \
            --head "$branch" \
            --title "chore(deps): automated dependency maintenance" \
            --body $'Automated dependency maintenance by dep-upgrader.\n\n- Seven-day package cooldown enforced\n- npm workspaces migrated to pnpm where applicable\n- Native audits executed during the update run\n\nReview CI results before merging.' || true
YAML
  } | write_generated_file "$path"
}

generate_release_workflow() {
  local repo="$1" has_node="$2" has_dotnet="$3" path="$repo/.github/workflows/release.yml" project rel name
  local release_projects=()
  while IFS= read -r -d '' project; do release_projects+=("$project"); done < <(repo_dotnet_release_projects "$repo")
  if ((has_node == 0 && ${#release_projects[@]} == 0)); then return 0; fi
  {
    cat <<'YAML'
name: Release

on:
  push:
    tags: ["v*"]
  workflow_dispatch:
    inputs:
      tag:
        description: Release tag, for example v1.2.3
        required: true
        type: string

permissions:
  contents: write

jobs:
  create-release:
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ github.token }}
      RELEASE_TAG: ${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
      - name: Create GitHub release
        run: gh release view "$RELEASE_TAG" || gh release create "$RELEASE_TAG" --target "$GITHUB_SHA" --generate-notes

YAML
    if ((has_node)); then cat <<YAML
  node-release:
    name: Node release assets
    needs: create-release
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: \${{ github.token }}
      RELEASE_TAG: \${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}
    steps:
      - uses: actions/checkout@v6
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
          cache: pnpm
          cache-dependency-path: "**/pnpm-lock.yaml"
      - name: Build
        shell: bash
        run: |
          set -euo pipefail
          while IFS= read -r -d '' lock; do (cd "\$(dirname "\$lock")" && pnpm install --frozen-lockfile); done < <(find . -type f -name pnpm-lock.yaml -not -path '*/node_modules/*' -print0)
          while IFS= read -r -d '' manifest; do
            if node -e 'const p=require(process.argv[1]);process.exit(p.scripts&&p.scripts.build?0:1)' "\$manifest"; then (cd "\$(dirname "\$manifest")" && pnpm run build); fi
          done < <(find . -type f -name package.json -not -path '*/node_modules/*' -print0)
      - name: Package and upload
        shell: bash
        run: |
          set -euo pipefail
          mkdir -p release-staging
          while IFS= read -r -d '' output; do
            safe="\$(printf '%s' "\$output" | sed 's#^\./##;s#[/.]#-#g')"
            tar -czf "release-staging/\${safe}.tar.gz" "\$output"
          done < <(find . -type d \( -name dist -o -name build -o -name out -o -path '*/.next/standalone' \) -not -path '*/node_modules/*' -print0)
          shopt -s nullglob
          assets=(release-staging/*)
          if (( \${#assets[@]} )); then gh release upload "\$RELEASE_TAG" "\${assets[@]}" --clobber; else echo 'No Node release output found.'; fi

YAML
    fi
    if ((${#release_projects[@]})); then
      cat <<YAML
  dotnet-release:
    name: .NET \${{ matrix.name }} / \${{ matrix.rid }}
    needs: create-release
    strategy:
      fail-fast: false
      matrix:
        include:
YAML
      for project in "${release_projects[@]}"; do
        rel="$(safe_relative "$project" "$repo")"
        name="$(basename "$project")"; name="${name%.*}"
        printf '          - os: ubuntu-latest\n            rid: linux-x64\n            project: "%s"\n            name: "%s"\n' "$rel" "$name"
        printf '          - os: windows-latest\n            rid: win-x64\n            project: "%s"\n            name: "%s"\n' "$rel" "$name"
        printf '          - os: macos-latest\n            rid: osx-x64\n            project: "%s"\n            name: "%s"\n' "$rel" "$name"
        printf '          - os: macos-latest\n            rid: osx-arm64\n            project: "%s"\n            name: "%s"\n' "$rel" "$name"
      done
      cat <<YAML
    runs-on: \${{ matrix.os }}
    env:
      GH_TOKEN: \${{ github.token }}
      RELEASE_TAG: \${{ github.event_name == 'workflow_dispatch' && inputs.tag || github.ref_name }}
    steps:
      - uses: actions/checkout@v6
      - uses: actions/setup-dotnet@v5
        with:
          dotnet-version: "$DOTNET_VERSION"
      - name: Publish and upload
        shell: pwsh
        run: |
          \$output = "artifacts/\${{ matrix.name }}-\${{ matrix.rid }}"
          dotnet restore "\${{ matrix.project }}" -p:NuGetAudit=true -p:NuGetAuditMode=all
          dotnet publish "\${{ matrix.project }}" -c Release -r "\${{ matrix.rid }}" --self-contained true --no-restore -o \$output
          \$asset = "artifacts/\${{ matrix.name }}-\${{ matrix.rid }}.zip"
          Compress-Archive -Path "\$output/*" -DestinationPath \$asset -Force
          gh release upload \$env:RELEASE_TAG \$asset --clobber
YAML
    fi
  } | write_generated_file "$path"
}

generate_container_workflow() {
  local repo="$1" path="$repo/.github/workflows/container.yml" dockerfile rel context suffix index=0
  local dockerfiles=()
  while IFS= read -r -d '' dockerfile; do dockerfiles+=("$dockerfile"); done < <(find "$repo" -type d \( -name .git -o -name node_modules -o -name .next -o -name bin -o -name obj -o -name .maintenance \) -prune -o -type f \( -name Dockerfile -o -name 'Dockerfile.*' \) -print0)
  ((${#dockerfiles[@]})) || return 0
  {
    cat <<YAML
name: Container

on:
  push:
    branches: ["$(repo_default_branch "$repo")"]
    tags: ["v*"]
  pull_request:
  workflow_dispatch:

permissions:
  contents: read
  packages: write
  attestations: write
  id-token: write

jobs:
  build:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        include:
YAML
    for dockerfile in "${dockerfiles[@]}"; do
      rel="$(safe_relative "$dockerfile" "$repo")"; context="$(dirname "$rel")"; [[ "$context" == . ]] || context="./$context"
      suffix=""; ((index > 0)) && suffix="-$(basename "$dockerfile" | tr '[:upper:]._' '[:lower:]--')"
      printf '          - file: "%s"\n            context: "%s"\n            suffix: "%s"\n' "$rel" "$context" "$suffix"
      index=$((index + 1))
    done
    cat <<'YAML'
    steps:
      - uses: actions/checkout@v6
      - uses: docker/setup-buildx-action@v4
      - name: Log in to GHCR
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      - id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}${{ matrix.suffix }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha
      - uses: docker/build-push-action@v7
        with:
          context: ${{ matrix.context }}
          file: ${{ matrix.file }}
          push: ${{ github.event_name != 'pull_request' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          platforms: linux/amd64,linux/arm64
          cache-from: type=gha
          cache-to: type=gha,mode=max
          provenance: true
          sbom: true
YAML
  } | write_generated_file "$path"
}

generate_coolify_workflow() {
  local repo="$1" path="$repo/.github/workflows/deploy-coolify.yml"
  cat <<'YAML' | write_generated_file "$path"
name: Deploy to Coolify

on:
  workflow_run:
    workflows: ["CI"]
    types: [completed]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-coolify-production
  cancel-in-progress: true

jobs:
  deploy:
    if: >-
      github.event_name == 'workflow_dispatch' ||
      (github.event.workflow_run.conclusion == 'success' &&
       github.event.workflow_run.head_branch == github.event.repository.default_branch)
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Trigger Coolify deployment
        env:
          COOLIFY_DEPLOY_WEBHOOK_URL: ${{ secrets.COOLIFY_DEPLOY_WEBHOOK_URL }}
          COOLIFY_API_TOKEN: ${{ secrets.COOLIFY_API_TOKEN }}
        shell: bash
        run: |
          set -euo pipefail
          test -n "$COOLIFY_DEPLOY_WEBHOOK_URL"
          args=(-fsS -X POST)
          if [ -n "${COOLIFY_API_TOKEN:-}" ]; then args+=(-H "Authorization: Bearer $COOLIFY_API_TOKEN"); fi
          curl "${args[@]}" "$COOLIFY_DEPLOY_WEBHOOK_URL"
YAML
}

generate_vercel_workflow() {
  local repo="$1" path="$repo/.github/workflows/deploy-vercel.yml"
  cat <<YAML | write_generated_file "$path"
name: Deploy to Vercel

on:
  push:
    branches: ["$(repo_default_branch "$repo")"]
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: deploy-vercel-production
  cancel-in-progress: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - uses: actions/checkout@v6
      - uses: pnpm/action-setup@v6
        with:
          version: "$PNPM_VERSION"
      - uses: actions/setup-node@v6
        with:
          node-version: "$NODE_VERSION"
      - name: Pull Vercel environment
        env:
          VERCEL_TOKEN: \${{ secrets.VERCEL_TOKEN }}
          VERCEL_ORG_ID: \${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: \${{ secrets.VERCEL_PROJECT_ID }}
        run: pnpm dlx vercel@latest pull --yes --environment=production --token="\$VERCEL_TOKEN"
      - name: Build
        env:
          VERCEL_TOKEN: \${{ secrets.VERCEL_TOKEN }}
          VERCEL_ORG_ID: \${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: \${{ secrets.VERCEL_PROJECT_ID }}
        run: pnpm dlx vercel@latest build --prod --token="\$VERCEL_TOKEN"
      - name: Deploy
        env:
          VERCEL_TOKEN: \${{ secrets.VERCEL_TOKEN }}
          VERCEL_ORG_ID: \${{ secrets.VERCEL_ORG_ID }}
          VERCEL_PROJECT_ID: \${{ secrets.VERCEL_PROJECT_ID }}
        run: pnpm dlx vercel@latest deploy --prebuilt --prod --token="\$VERCEL_TOKEN"
YAML
}

generate_cicd_docs() {
  local repo="$1" has_node="$2" has_dotnet="$3" path="$repo/.github/dep-upgrader/README.md"
  {
    cat <<'MD'
# dep-upgrader CI/CD

Generated by the standalone dep-upgrader suite.

## Workflows

- **CI**: stack-aware restore, lint/format/typecheck/test/build.
- **Security**: dependency review, CodeQL, pnpm audit, NuGet audit.
- **Dependency Maintenance**: weekly dependency PR; seven-day cooldown remains enforced.
- **Quality**: Syncpack, Knip, Dependency Cruiser, JSCPD, Publint and ATTW when Node is present.
- **Release**: GitHub releases for Node build outputs and self-contained .NET/Avalonia RID packages.
- **Container**: multi-architecture GHCR publishing when a Dockerfile is present.

## Required or optional secrets

- `DEP_UPGRADER_TOKEN` (optional): fine-grained PAT with Contents and Pull Requests write. Recommended so PR pushes can trigger normal CI. Without it the workflow uses `GITHUB_TOKEN`.
- `COOLIFY_DEPLOY_WEBHOOK_URL` and optional `COOLIFY_API_TOKEN` when Coolify deployment is generated.
- `VERCEL_TOKEN`, `VERCEL_ORG_ID`, and `VERCEL_PROJECT_ID` when Vercel deployment is generated.

## Repository settings

Require CI and Security checks before merging. Protect the default branch, disallow force pushes, require pull requests, and review environment protection for production deployments.

The generated workflows use current major action lines at generation time. Renovate is configured to update and pin GitHub Action digests.
MD
    printf '\nDetected stacks: Node=%s, .NET=%s.\n' "$has_node" "$has_dotnet"
    printf 'Generator version: %s.\n' "$VERSION"
  } | write_generated_file "$path"
}

setup_cicd() {
  create_backup_once
  if [[ "$ECOSYSTEMS" != dotnet ]] && ((${#NODE_PROJECTS[@]})); then prepare_node_for_cicd; fi
  local repo has_node=0 has_dotnet=0 branch
  for repo in "${REPO_ROOTS[@]}"; do
    has_node=0; has_dotnet=0
    repo_has_node "$repo" && has_node=1
    repo_has_dotnet "$repo" && has_dotnet=1
    if ((has_node == 0 && has_dotnet == 0)); then warn "Kein unterstützter Stack: $repo"; continue; fi
    branch="$(repo_default_branch "$repo")"
    info "CI/CD für $repo (Node=$has_node, .NET=$has_dotnet, Branch=$branch)"
    ensure_gitignore_entry "$repo" '.maintenance/'
    ensure_gitignore_entry "$repo" '.deps-update-backups/'
    install_ci_script "$repo"
    generate_ci_workflow "$repo" "$has_node" "$has_dotnet" "$branch"
    generate_security_workflow "$repo" "$has_node" "$has_dotnet"
    ((has_node)) && generate_quality_workflow "$repo"
    generate_dependency_maintenance_workflow "$repo" "$has_node" "$has_dotnet" "$branch"
    generate_release_workflow "$repo" "$has_node" "$has_dotnet"
    repo_has_docker "$repo" && generate_container_workflow "$repo"
    [[ "$DEPLOY_PROVIDER" == coolify ]] && generate_coolify_workflow "$repo"
    [[ "$DEPLOY_PROVIDER" == vercel ]] && repo_has_next "$repo" && generate_vercel_workflow "$repo"
    generate_renovate_for_repo "$repo"
    ((has_node)) && generate_changesets_for_repo "$repo"
    generate_cicd_docs "$repo" "$has_node" "$has_dotnet"
  done
}


# ---------- Inventory and selection ----------
print_inventory() {
  printf '%sDep Upgrader %s%s\n' "$C_BOLD$C_CYAN" "$VERSION" "$C_RESET"
  printf 'Root: %s\n\n' "$ROOT"
  local i rel
  printf '%sRepositories%s\n' "$C_BOLD" "$C_RESET"
  for i in "${!REPO_ROOTS[@]}"; do rel="${REPO_ROOTS[$i]#"$ROOT"/}"; [[ "${REPO_ROOTS[$i]}" == "$ROOT" ]] && rel="."; printf '  %s\n' "$rel"; done
  if [[ "$ECOSYSTEMS" != dotnet ]]; then
    printf '\n%sNode / pnpm%s\n' "$C_BOLD" "$C_RESET"
    for i in "${!NODE_PROJECTS[@]}"; do printf '  %3d) %-16s %s\n' "$((i+1))" "${NODE_TYPES[$i]}" "${NODE_PROJECTS[$i]#"$ROOT"/}"; done
    ((${#INVALID_MANIFESTS[@]})) && printf '  Ungültige package.json: %s\n' "${#INVALID_MANIFESTS[@]}"
  fi
  if [[ "$ECOSYSTEMS" != node ]]; then
    printf '\n%s.NET / Avalonia%s\n' "$C_BOLD" "$C_RESET"
    for i in "${!DOTNET_PROJECTS[@]}"; do printf '  %-16s %s\n' "${DOTNET_TYPES[$i]}" "${DOTNET_PROJECTS[$i]#"$ROOT"/}"; done
  fi
  printf '\nRepositories: %s · Node: %s · .NET: %s\n' "${#REPO_ROOTS[@]}" "${#NODE_PROJECTS[@]}" "${#DOTNET_PROJECTS[@]}"
}

parse_selection() {
  local spec="$1" token start end n j
  SELECTED_INDEXES=()
  IFS=',' read -r -a tokens <<<"$spec"
  for token in "${tokens[@]}"; do
    token="${token//[[:space:]]/}"
    if [[ "$token" =~ ^([0-9]+)-([0-9]+)$ ]]; then
      start="${BASH_REMATCH[1]}"; end="${BASH_REMATCH[2]}"; ((start>end)) && { n="$start"; start="$end"; end="$n"; }
      for ((j=start;j<=end;j++)); do ((j>=1 && j<=${#NODE_PROJECTS[@]})) && ! array_contains "$((j-1))" "${SELECTED_INDEXES[@]}" && SELECTED_INDEXES+=("$((j-1))"); done
    elif [[ "$token" =~ ^[0-9]+$ ]]; then
      n="$token"; ((n>=1 && n<=${#NODE_PROJECTS[@]})) || continue
      array_contains "$((n-1))" "${SELECTED_INDEXES[@]}" || SELECTED_INDEXES+=("$((n-1))")
    else return 1; fi
  done
  ((${#SELECTED_INDEXES[@]}))
}

apply_node_selection() {
  [[ -n "$SELECT_SPEC" ]] || return 0
  parse_selection "$SELECT_SPEC" || { error "Ungültige Auswahl: $SELECT_SPEC"; return 1; }
  local -a selected_projects=() selected_types=() selected_roots=() selected_shared=()
  local idx root dir
  for idx in "${SELECTED_INDEXES[@]}"; do
    selected_projects+=("${NODE_PROJECTS[$idx]}"); selected_types+=("${NODE_TYPES[$idx]}")
    dir="$(dirname "${NODE_PROJECTS[$idx]}")"; root="$(node_workspace_root "$dir")"; unique_append selected_roots "$root"
    array_contains "$dir" "${SHARED_PACKAGES[@]}" && selected_shared+=("$dir") || true
  done
  NODE_PROJECTS=("${selected_projects[@]}"); NODE_TYPES=("${selected_types[@]}"); NODE_ROOTS=("${selected_roots[@]}"); SHARED_PACKAGES=("${selected_shared[@]}")
}

repair_invalid_files() {
  ((${#INVALID_MANIFESTS[@]})) || return 0
  create_backup_once
  local file tsconfig
  for file in "${INVALID_MANIFESTS[@]}"; do
    repair_package_json "$file" || record_failure "repair package.json: $file"
    tsconfig="$(dirname "$file")/tsconfig.json"
    [[ -f "$tsconfig" ]] && ! is_valid_json "$tsconfig" && repair_tsconfig "$tsconfig" || true
  done
}

interactive_menu() {
  print_inventory
  printf '\n%sModul wählen%s\n' "$C_BOLD" "$C_RESET"
  PS3='Auswahl: '
  select choice in 'Komplette Pipeline inkl. CI/CD' 'Dependencies' 'Reparatur' 'Cleanup' 'Validation' 'Security' 'Quality' 'Automation' 'Config Analysis' 'Dedupe / Consolidation' 'UI Analysis' 'CI/CD einrichten' 'Beenden'; do
    case "$REPLY" in 1) MODULE=all;; 2) MODULE=deps;; 3) MODULE=repair; REPAIR=1;; 4) MODULE=clean;; 5) MODULE=validate;; 6) MODULE=security;; 7) MODULE=quality;; 8) MODULE=automation;; 9) MODULE=config;; 10) MODULE=dedupe;; 11) MODULE=ui-analysis;; 12) MODULE=cicd;; 13) exit 0;; *) continue;; esac
    break
  done
  if [[ "$MODULE" == deps || "$MODULE" == all ]]; then
    if ((${#NODE_PROJECTS[@]} > 1)); then printf 'Node-Projekte auswählen (z. B. 1,3-5; Enter=alle): '; read -r SELECT_SPEC; fi
    printf 'Update-Modus [latest/minor/patch/semver-safe/interactive] (%s): ' "$MODE"; read -r input; [[ -n "$input" ]] && MODE="$input"
    printf 'Cooldown [0/24h/3d/7d] (%s): ' "$COOLDOWN"; read -r input; [[ -n "$input" ]] && COOLDOWN="$input"
    warn 'Node-Projekte: Lockfiles werden gesichert, npm/yarn wird auf pnpm migriert und Build-Artefakte werden bereinigt.'
    confirm 'Fortfahren?' n || exit 0
  fi
}

need_value() { [[ $# -ge 2 && -n "$2" ]] || { error "Fehlender Wert für $1"; exit 64; }; }

parse_args() {
  while (($#)); do
    case "$1" in
      --root) need_value "$@"; ROOT="$2"; shift 2;;
      --module) need_value "$@"; MODULE="$2"; NON_INTERACTIVE=1; shift 2;;
      --setup-cicd) MODULE=cicd; NON_INTERACTIVE=1; shift;;
      --full-upgrade) FULL_UPGRADE=1; MODULE=all; MODE=latest; REPAIR=1; MIGRATE_NPM=1; HARDEN_MODE=strict; AUDIT_MODE=fix; VALIDATE_MODE=full; QUALITY_PROFILE=full; VALIDATE_WORKSPACE=1; ASSUME_YES=1; NON_INTERACTIVE=1; shift;;
      --mode) need_value "$@"; MODE="$2"; shift 2;;
      --cooldown) need_value "$@"; COOLDOWN="$2"; shift 2;;
      --audit) need_value "$@"; AUDIT_MODE="$2"; shift 2;;
      --audit-level) need_value "$@"; AUDIT_LEVEL="$2"; shift 2;;
      --validate) need_value "$@"; VALIDATE_MODE="$2"; shift 2;;
      --quality-profile) need_value "$@"; QUALITY_PROFILE="$2"; shift 2;;
      --harden) need_value "$@"; HARDEN_MODE="$2"; shift 2;;
      --ecosystems) need_value "$@"; ECOSYSTEMS="$2"; shift 2;;
      --projects) need_value "$@"; PROJECT_FILTER="$2"; shift 2;;
      --select) need_value "$@"; SELECT_SPEC="$2"; shift 2;;
      --rid) need_value "$@"; RID="$2"; shift 2;;
      --rollback) need_value "$@"; ROLLBACK_PATH="$2"; MODULE=rollback; NON_INTERACTIVE=1; shift 2;;
      --non-interactive) NON_INTERACTIVE=1; shift;;
      --list) LIST_ONLY=1; NON_INTERACTIVE=1; shift;;
      --dry-run) DRY_RUN=1; shift;;
      --yes|-y) ASSUME_YES=1; shift;;
      --fail-fast) KEEP_GOING=0; shift;;
      --keep-going) KEEP_GOING=1; shift;;
      --stash) STASH=1; shift;;
      --repair) REPAIR=1; shift;;
      --migrate-npm) MIGRATE_NPM=1; shift;;
      --no-migrate-npm) MIGRATE_NPM=0; shift;;
      --validate-workspace) VALIDATE_WORKSPACE=1; shift;;
      --auto-rollback) AUTO_ROLLBACK=1; shift;;
      --no-dedupe) DEDUPE=0; shift;;
      --no-signatures) SIGNATURES=0; shift;;
      --sbom) GENERATE_SBOM=1; shift;;
      --ncu-package) need_value "$@"; NCU_PACKAGE="$2"; shift 2;;
      --fix) FIX=1; shift;;
      --install-tools) INSTALL_TOOLS=1; shift;;
      --ci-force) CI_FORCE=1; shift;;
      --no-ci-script) INSTALL_CI_SCRIPT=0; shift;;
      --deploy-provider) need_value "$@"; DEPLOY_PROVIDER="$2"; shift 2;;
      --node-version) need_value "$@"; NODE_VERSION="$2"; shift 2;;
      --pnpm-version) need_value "$@"; PNPM_VERSION="$2"; shift 2;;
      --dotnet-version) need_value "$@"; DOTNET_VERSION="$2"; shift 2;;
      --maintenance-cron) need_value "$@"; MAINTENANCE_CRON="$2"; shift 2;;
      --default-branch) need_value "$@"; DEFAULT_BRANCH="$2"; shift 2;;
      --version) printf '%s\n' "$VERSION"; exit 0;;
      --help|-h) usage; exit 0;;
      *) error "Unbekannte Option: $1"; usage; exit 64;;
    esac
  done
}

validate_options() {
  case "$MODULE" in ''|all|deps|repair|clean|validate|security|quality|automation|config|dedupe|ui-analysis|cicd|rollback) ;; *) error "Ungültiges Modul: $MODULE"; exit 64;; esac
  case "$MODE" in latest|minor|patch|semver-safe|semver|interactive) ;; *) error "Ungültiger Modus: $MODE"; exit 64;; esac
  case "$AUDIT_MODE" in off|report|interactive|fix) ;; *) error "Ungültiger Audit-Modus: $AUDIT_MODE"; exit 64;; esac
  case "$AUDIT_LEVEL" in low|moderate|high|critical) ;; *) error "Ungültiger Audit-Level: $AUDIT_LEVEL"; exit 64;; esac
  case "$VALIDATE_MODE" in off|quick|full|build|format|test|run|publish) ;; *) error "Ungültige Validierung: $VALIDATE_MODE"; exit 64;; esac
  case "$QUALITY_PROFILE" in quick|full|deep) ;; *) error "Ungültiges Qualitätsprofil: $QUALITY_PROFILE"; exit 64;; esac
  case "$HARDEN_MODE" in off|report|balanced|strict) ;; *) error "Ungültiges Hardening: $HARDEN_MODE"; exit 64;; esac
  case "$ECOSYSTEMS" in all|node|dotnet) ;; *) error "Ungültiges Ecosystem: $ECOSYSTEMS"; exit 64;; esac
  case "$DEPLOY_PROVIDER" in none|coolify|vercel) ;; *) error "Ungültiger Deploy-Provider: $DEPLOY_PROVIDER"; exit 64;; esac
  cooldown_to_minutes "$COOLDOWN" >/dev/null || { error "Ungültiger Cooldown: $COOLDOWN"; exit 64; }
  [[ "$MODE" == semver ]] && MODE=semver-safe || true
  return 0
}

git_preflight_all() {
  command_exists git || return 0
  local repo status
  for repo in "${REPO_ROOTS[@]}"; do
    git -C "$repo" rev-parse --is-inside-work-tree >/dev/null 2>&1 || continue
    status="$(git -C "$repo" status --short 2>/dev/null || true)"
    [[ -z "$status" ]] && continue
    warn "Git-Working-Tree enthält Änderungen: $repo"
    printf '%s\n' "$status" >>"$LOG_DIR/git-status-before.txt"
    ((STASH)) && run 'Git stash' "$repo" git stash push -u -m "dep-upgrader $STAMP" || true
  done
}

init_runtime() {
  ROOT="$(abs_path "$ROOT")"
  [[ -d "$ROOT" ]] || { error "Verzeichnis nicht gefunden: $ROOT"; exit 1; }
  STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  if ((DRY_RUN)); then LOG_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dep-upgrader-$STAMP-XXXX")"
  else LOG_DIR="$ROOT/.maintenance/logs/$STAMP"; mkdir -p "$LOG_DIR"; fi
  CURRENT_LOG="$LOG_DIR/dep-upgrader.log"; : >"$CURRENT_LOG"
  BACKUP_DIR="$ROOT/.maintenance/backups/$STAMP"
  if command_exists node; then NODE_VERSION_RUN="$(node --version 2>/dev/null | sed 's/^v//' || true)"; fi
  if command_exists pnpm; then
    PNPM_VERSION_RUN="$(pnpm --version 2>/dev/null || true)"
    PNPM_MAJOR="${PNPM_VERSION_RUN%%.*}"; PNPM_MINOR="$(printf '%s' "$PNPM_VERSION_RUN" | cut -d. -f2)"; PNPM_PATCH="$(printf '%s' "$PNPM_VERSION_RUN" | cut -d. -f3 | sed 's/[^0-9].*$//')"
    PNPM_MAJOR="${PNPM_MAJOR:-0}"; PNPM_MINOR="${PNPM_MINOR:-0}"; PNPM_PATCH="${PNPM_PATCH:-0}"
  fi
}

summary() {
  line
  printf '%sKonfiguration%s\n' "$C_BOLD" "$C_RESET"
  printf '  Root:              %s\n' "$ROOT"
  printf '  Modul:             %s\n' "$MODULE"
  printf '  Modus:             %s\n' "$MODE"
  printf '  Ecosystems:        %s\n' "$ECOSYSTEMS"
  printf '  Node-Projekte:     %s\n' "${#NODE_PROJECTS[@]}"
  printf '  .NET-Projekte:     %s\n' "${#DOTNET_PROJECTS[@]}"
  printf '  Repositories:      %s\n' "${#REPO_ROOTS[@]}"
  printf '  Cooldown:          %s\n' "$COOLDOWN"
  printf '  Audit:             %s (%s+)\n' "$AUDIT_MODE" "$AUDIT_LEVEL"
  printf '  Härtung:           %s\n' "$HARDEN_MODE"
  printf '  Validierung:       %s\n' "$VALIDATE_MODE"
  printf '  Repair:            %s\n' "$([[ "$REPAIR" -eq 1 ]] && echo ja || echo nein)"
  printf '  npm→pnpm:          %s\n' "$([[ "$MIGRATE_NPM" -eq 1 ]] && echo ja || echo nein)"
  printf '  Dry-Run:           %s\n' "$([[ "$DRY_RUN" -eq 1 ]] && echo ja || echo nein)"
  line
}

main() {
  parse_args "$@"
  validate_options
  init_runtime
  banner

  if [[ "$MODULE" == rollback ]]; then
    [[ -n "$ROLLBACK_PATH" ]] || { error 'Rollback-Pfad fehlt.'; exit 1; }
    if [[ -d "$ROLLBACK_PATH" && -f "$ROLLBACK_PATH/manifest.tsv" ]]; then rollback_backup "$ROLLBACK_PATH"
    elif [[ -f "$ROLLBACK_PATH" ]]; then confirm "Archiv nach $ROOT wiederherstellen?" n || exit 0; tar -xzf "$ROLLBACK_PATH" -C "$ROOT"; success 'Archiv-Rollback abgeschlossen.'
    else error "Backup nicht gefunden: $ROLLBACK_PATH"; exit 1; fi
    exit 0
  fi

  command_exists find || { error 'find fehlt.'; exit 1; }
  if [[ "$ECOSYSTEMS" != dotnet ]] && ! command_exists node; then error 'Node.js fehlt für Node-Projekte.'; [[ "$ECOSYSTEMS" == node ]] && exit 1; fi

  discover_repositories
  [[ "$ECOSYSTEMS" != dotnet ]] && discover_node_projects
  [[ "$ECOSYSTEMS" != node ]] && discover_dotnet_projects

  if ((LIST_ONLY)); then print_inventory; exit 0; fi
  if ((NON_INTERACTIVE == 0)) && [[ -t 0 && -t 1 ]]; then interactive_menu; fi
  [[ -n "$MODULE" ]] || MODULE=all

  if ((REPAIR)) || [[ "$MODULE" == repair ]]; then
    repair_invalid_files
    discover_repositories
    [[ "$ECOSYSTEMS" != dotnet ]] && discover_node_projects
    [[ "$ECOSYSTEMS" != node ]] && discover_dotnet_projects
  elif ((${#INVALID_MANIFESTS[@]})); then
    warn "${#INVALID_MANIFESTS[@]} ungültige package.json-Datei(en) werden übersprungen. Mit --repair reparieren."
  fi

  apply_node_selection || exit 64
  INSTALL_ROOTS=("${NODE_ROOTS[@]}")
  git_preflight_all
  summary
  if [[ "$MODULE" != validate && "$MODULE" != security && "$MODULE" != quality && "$MODULE" != config && "$MODULE" != ui-analysis ]] && ((DRY_RUN==0 && ASSUME_YES==0 && NON_INTERACTIVE==1)); then
    error 'Nicht-interaktive Änderungen erfordern --yes oder --dry-run.'; exit 64
  fi
  if ((ASSUME_YES==0 && NON_INTERACTIVE==0)) && ! confirm 'Fortfahren?' n; then exit 0; fi

  case "$MODULE" in
    repair)
      if ((${#INVALID_MANIFESTS[@]}==0)); then success 'Keine ungültigen package.json-Dateien mehr gefunden.'; fi
      ;;
    clean)
      create_backup_once; [[ "$ECOSYSTEMS" != dotnet ]] && cleanup_node; [[ "$ECOSYSTEMS" != node ]] && cleanup_dotnet
      ;;
    deps)
      [[ "$ECOSYSTEMS" == dotnet ]] || update_node
      [[ "$ECOSYSTEMS" == node ]] || update_dotnet
      ;;
    validate) [[ "$VALIDATE_MODE" != off ]] && validate ;;
    security) security ;;
    quality) quality ;;
    automation) automation ;;
    config) config_analysis ;;
    dedupe) dedupe ;;
    ui-analysis) ui_analysis ;;
    cicd) setup_cicd ;;
    all)
      [[ "$ECOSYSTEMS" == dotnet ]] || update_node
      [[ "$ECOSYSTEMS" == node ]] || update_dotnet
      ((DEDUPE)) && dedupe || true
      security
      [[ "$VALIDATE_MODE" != off ]] && validate || true
      quality
      config_analysis
      ui_analysis
      automation
      setup_cicd
      ;;
  esac

  if ((AUTO_ROLLBACK && BACKUP_CREATED && ${#FAILURES[@]} > 0)); then
    local total=$(( ${#NODE_PROJECTS[@]} + ${#DOTNET_PROJECTS[@]} )) failed=${#FAILURES[@]}
    if ((total > 0 && failed * 2 > total)); then
      warn "Auto-Rollback-Schwelle erreicht: $failed Fehler bei $total Projekten."
      if ((ASSUME_YES)) || confirm 'Manifest-Backup wiederherstellen?' y; then rollback_backup "$BACKUP_DIR"; fi
    fi
  fi

  printf '\n'; line; printf '%sErgebnis%s\n' "$C_BOLD" "$C_RESET"
  printf '  Logs:              %s\n' "$LOG_DIR"
  ((BACKUP_CREATED && !DRY_RUN)) && printf '  Backup:            %s\n' "$BACKUP_DIR"
  [[ -n "$BACKUP_ARCHIVE" ]] && printf '  Archiv:            %s\n' "$BACKUP_ARCHIVE"
  printf '  Aktualisiert:      %s\n' "$UPDATED_APPS"
  printf '  Änderungen:        %s\n' "$CHANGED"
  printf '  Fehler:            %s\n' "${#FAILURES[@]}"
  if ((${#FAILURES[@]}==0)); then success 'Alle Schritte abgeschlossen.'; return 0; fi
  warn 'Probleme:'; local failure; for failure in "${FAILURES[@]}"; do printf '  - %s\n' "$failure"; done
  ((BACKUP_CREATED && !DRY_RUN)) && printf '\nRollback:\n  %q --root %q --rollback %q --yes\n' "$SELF_PATH" "$ROOT" "$BACKUP_DIR"
  return 1
}

main "$@"
