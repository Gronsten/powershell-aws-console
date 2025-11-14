#!/usr/bin/env python3
"""Fast line counter for projects with exclusion support.

Usage:
    python count-lines.py [PATH] [--show-exclusions]

Arguments:
    PATH                Optional path to analyze (default: devRoot from config.json)
    --show-exclusions   Display detailed list of excluded files and directories

Examples:
    python count-lines.py
    python count-lines.py --show-exclusions
    python count-lines.py C:\\Projects\\myapp
    python count-lines.py C:\\Projects\\myapp --show-exclusions
"""

import os
import sys
import json
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

        # Example: exclude all files from a specific project
        # elif project == 'username@server':
        #     return True

        # Example: only include specific file in a project
        # elif project == 'your-project-name':
        #     if file_path.name != 'specific-file.tf':
        #         return True

        # Example: exclude dev environment subdirectory
        # elif project == 'another-project':
        #     if 'dev-environment' in parts:
        #         return True

        # Example: exclude backups and logs directories
        # elif project == 'api-project':
        #     if 'backups' in parts or 'logs' in parts or "config" in parts:
        #         return True

        # meraki-api: exclude backups, logs, and config directories
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

        # powershell-console: exclude files with 'backup' in name and _prod directory
        elif project == 'powershell-console':
            if (file_path.name == 'npm-packages.json' or
                'backup' in file_path.name.lower() or
                '_prod' in parts):
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

def count_project_lines(base_path: Path, dev_root: Path = None, show_exclusions: bool = False):
    """Count lines across all projects with exclusions."""
    start_time = time.time()

    # If dev_root not specified, assume base_path is the dev root
    if dev_root is None:
        dev_root = base_path

    project_stats = defaultdict(lambda: {'files': 0, 'lines': 0})
    excluded_items = []  # Track excluded files and directories
    total_files = 0
    total_lines = 0
    excluded_files = 0

    for root, dirs, files in os.walk(base_path):
        # Skip hidden directories and git directories
        original_dirs = dirs.copy()
        dirs[:] = [d for d in dirs if not d.startswith('.') and d != 'node_modules']

        # Track excluded directories
        if show_exclusions:
            for d in original_dirs:
                if d not in dirs:
                    excluded_items.append(('dir', Path(root) / d))

        for file in files:
            file_path = Path(root) / file

            if should_exclude(file_path, base_path, dev_root):
                excluded_files += 1
                if show_exclusions:
                    excluded_items.append(('file', file_path))
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

    # Show exclusions if requested
    if show_exclusions and excluded_items:
        print("\n" + "="*70)
        print("EXCLUSIONS")
        print("="*70)

        # Color codes for terminal output
        BLUE = '\033[94m'   # Directories
        YELLOW = '\033[93m' # Files
        RESET = '\033[0m'

        # Group by project
        exclusions_by_project = defaultdict(lambda: {'dirs': [], 'files': []})

        for item_type, item_path in excluded_items:
            try:
                rel_path = item_path.relative_to(base_path)
                project = rel_path.parts[0] if len(rel_path.parts) > 0 else 'root'

                if item_type == 'dir':
                    exclusions_by_project[project]['dirs'].append(str(rel_path))
                else:
                    exclusions_by_project[project]['files'].append(str(rel_path))
            except ValueError:
                continue

        # Sort projects alphabetically
        sorted_exclusions = sorted(exclusions_by_project.items())

        for project, items in sorted_exclusions:
            print(f"\n{project}:")

            # Show directories first (sorted)
            if items['dirs']:
                for d in sorted(items['dirs']):
                    print(f"  {BLUE}[DIR]{RESET}  {d}")

            # Then files (sorted)
            if items['files']:
                for f in sorted(items['files']):
                    print(f"  {YELLOW}[FILE]{RESET} {f}")

        print("\n" + "="*70)
        print(f"Total exclusions: {len(excluded_items):,} ({len([x for x in excluded_items if x[0] == 'dir']):,} dirs, {len([x for x in excluded_items if x[0] == 'file']):,} files)")
        print("="*70)

if __name__ == '__main__':
    # Load dev root from config.json
    script_dir = Path(__file__).resolve().parent
    config_path = script_dir.parent / 'config.json'

    try:
        with open(config_path, 'r', encoding='utf-8') as f:
            config = json.load(f)
        dev_root = Path(config['paths']['devRoot'])
    except (FileNotFoundError, KeyError, json.JSONDecodeError) as e:
        print(f"Error: Could not read devRoot from config.json: {e}")
        print(f"Expected config at: {config_path}")
        sys.exit(1)

    # Parse command line arguments
    show_exclusions = False
    target_path = None

    # Check for flags
    args = sys.argv[1:]
    if '--show-exclusions' in args:
        show_exclusions = True
        args.remove('--show-exclusions')

    # Check for path argument
    if len(args) > 0:
        target_path = args[0]

    if target_path:
        # Convert to absolute path
        if os.path.isabs(target_path):
            base_path = Path(target_path)
        else:
            # Relative path - resolve from current directory
            base_path = Path(os.getcwd()) / target_path

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

    count_project_lines(base_path, dev_root, show_exclusions)
