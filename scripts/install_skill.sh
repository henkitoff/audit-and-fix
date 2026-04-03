#!/usr/bin/env bash
set -euo pipefail

TARGET="${1:-auto}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILL_NAME="$(basename "${SKILL_ROOT}")"

copy_skill() {
  local host_root="$1"
  local skills_dir="${host_root}/skills"
  local skill_dir="${skills_dir}/${SKILL_NAME}"

  mkdir -p "${skills_dir}"
  rm -rf "${skill_dir}"
  mkdir -p "${skill_dir}"

  (
    cd "${SKILL_ROOT}"
    shopt -s dotglob nullglob
    for item in * .*; do
      case "${item}" in
        "."|".."|".git") continue ;;
      esac
      cp -R "${item}" "${skill_dir}/"
    done
  )

  printf 'Installed to %s\n' "${skill_dir}"
}

CODEX_HOST_ROOT="${CODEX_HOME:-${HOME}/.codex}"
CLAUDE_HOST_ROOT="${CLAUDE_HOME:-${HOME}/.claude}"

case "${TARGET}" in
  auto|both)
    copy_skill "${CLAUDE_HOST_ROOT}"
    copy_skill "${CODEX_HOST_ROOT}"
    ;;
  claude)
    copy_skill "${CLAUDE_HOST_ROOT}"
    ;;
  codex)
    copy_skill "${CODEX_HOST_ROOT}"
    ;;
  *)
    printf 'Usage: %s [auto|both|claude|codex]\n' "$0" >&2
    exit 1
    ;;
esac
