#!/usr/bin/env bash
set -euo pipefail

changes_dir="openspec/changes"

if [ ! -d "$changes_dir" ]; then
  echo "openspec/changes not found"
  exit 1
fi

find "$changes_dir" -maxdepth 1 -mindepth 1 -type d \
  ! -name archive \
  -exec basename {} \; | sort
