#!/usr/bin/env python3
"""Fast line counter for projects with exclusion support."""

import os
import sys
from pathlib import Path
from collections import defaultdict
import time

def should_exclude(file_path: Path, base_path: Path, dev_root: Path) -> bool:
    """Check if a file should be excluded from counting."""
    rel_path = file_path.relative_to(base_path)
    parts = rel_path.parts

    # Global exclusions
    if 'log' in str(file_path).lower() or file_path.suffix == '.log':
        return True

    # Exclude .vsix files everywhere
    if file_path.suffix == '.vsix':
        return True

    # Determine the project name from the dev root perspective
    try:
        rel_to_dev = file_path.relative_to(dev_root)
        project = rel_to_dev.parts[0] if len(rel_to_dev.parts) > 0 else None
    except ValueError:
        # File is outside dev root, use first part of relative path
        project = parts[0] if len(parts) > 0 else None

    # Project-specific exclusions
    if project:

        # alohomora: exclude all except common.go and alohomora.go
        if project == 'alohomora':
            if file_path.name not in ['common.go', 'alohomora.go']:
                return True

        # e911: exclude all
        elif project == 'e911':
            return True

        # mcampbel@192.168.7.202: exclude all
        elif project == 'mcampbel@192.168.7.202':
            return True

        # entity-network-hub: only include vpn.tf explicitly
        elif project == 'entity-network-hub':
            if file_path.name != 'vpn.tf':
                return True

        # ets-nettools: exclude dev environment subdirectory
        elif project == 'ets-nettools':
            if 'etsnettoolsdev' in parts:
                return True

        # meraki-api: exclude backups and logs directories
        elif project == 'meraki-api':
            if 'backups' in parts or 'logs' in parts or "config" in parts:
                return True

        # misc-scripts: exclude specific files
        elif project == 'misc-scripts':
            if (file_path.name == '30001_KEVLAR_61F.conf' or
                file_path.name.startswith('hpp3') or
                file_path.name == 'vpn_config_output.xlsx'):
                return True

        # defender: exclude .csv files
        elif project == 'defender':
            if file_path.suffix == '.csv':
                return True

        # powershell-aws-console: exclude files with 'backup' in name
        elif project == 'powershell-aws-console':
            if (file_path.name == 'npm-packages.json' or
                'backup' in file_path.name.lower()):
                return True

    return False

def count_lines_in_file(file_path: Path) -> int:
    """Count lines in a file, handling various encodings."""
    encodings = ['utf-8', 'latin-1', 'cp1252']

    for encoding in encodings:
        try:
            with open(file_path, 'r', encoding=encoding) as f:
                return sum(1 for _ in f)
        except (UnicodeDecodeError, PermissionError):
            continue
        except Exception:
            return 0
    return 0

def count_project_lines(base_path: Path, dev_root: Path = None):
    """Count lines across all projects with exclusions."""
    start_time = time.time()

    # If dev_root not specified, assume base_path is the dev root
    if dev_root is None:
        dev_root = base_path

    project_stats = defaultdict(lambda: {'files': 0, 'lines': 0})
    total_files = 0
    total_lines = 0
    excluded_files = 0

    for root, dirs, files in os.walk(base_path):
        # Skip hidden directories and git directories
        dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'node_modules']

        for file in files:
            file_path = Path(root) / file

            if should_exclude(file_path, base_path, dev_root):
                excluded_files += 1
                continue

            try:
                rel_path = file_path.relative_to(base_path)
                project = rel_path.parts[0] if len(rel_path.parts) > 0 else 'root'

                lines = count_lines_in_file(file_path)

                project_stats[project]['files'] += 1
                project_stats[project]['lines'] += lines
                total_files += 1
                total_lines += lines

            except Exception as e:
                continue

    # Display results
    print("\n" + "="*70)
    print(f"ANALYZING: {base_path}")
    print("="*70)
    print(f"{'Project':<30} {'Files':>12} {'Lines':>15}")
    print("-"*70)

    # Sort by lines descending
    sorted_projects = sorted(project_stats.items(),
                            key=lambda x: x[1]['lines'],
                            reverse=True)

    for project, stats in sorted_projects:
        print(f"{project:<30} {stats['files']:>12,} {stats['lines']:>15,}")

    elapsed = time.time() - start_time

    print("="*70)
    print(f"{'TOTAL':<30} {total_files:>12,} {total_lines:>15,}")
    print("="*70)
    print(f"\nExcluded files: {excluded_files:,}")
    print(f"Processing time: {elapsed:.2f} seconds")
    print("="*70)

if __name__ == '__main__':
    # Dev root for exclusion rules
    dev_root = Path(r'C:\AppInstall\dev')

    # Parse command line arguments
    if len(sys.argv) > 1:
        # User specified a path
        target = sys.argv[1]

        # Convert to absolute path
        if os.path.isabs(target):
            base_path = Path(target)
        else:
            # Relative path - resolve from current directory
            base_path = Path(os.getcwd()) / target

        # Validate path exists
        if not base_path.exists():
            print(f"Error: Path does not exist: {base_path}")
            sys.exit(1)

        # If it's a file, count just that file
        if base_path.is_file():
            print(f"\nCounting single file: {base_path}")
            lines = count_lines_in_file(base_path)
            print(f"Lines: {lines:,}")
            sys.exit(0)
    else:
        # Default to C:\AppInstall\dev
        base_path = dev_root

    count_project_lines(base_path, dev_root)
