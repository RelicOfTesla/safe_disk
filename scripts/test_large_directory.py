#!/usr/bin/env python3
"""
Performance test script for large directory loading.

This script creates test directories with many files to test the
performance of the directory listing functionality.

Usage:
  python3 test_large_directory.py create <test_dir> <file_count>
  python3 test_large_directory.py cleanup <test_dir>
  python3 test_large_directory.py test <test_dir>

Examples:
  python3 test_large_directory.py create /tmp/test_1000 1000
  python3 test_large_directory.py test /tmp/test_1000
  python3 test_large_directory.py cleanup /tmp/test_1000
"""

import os
import sys
import time
import shutil
import subprocess
from pathlib import Path


def create_test_directory(test_dir: str, file_count: int):
    """Create a test directory with many empty files."""
    test_path = Path(test_dir)
    if test_path.exists():
        print(f"Directory already exists: {test_dir}")
        response = input("Delete and recreate? (y/n): ")
        if response.lower() != 'y':
            print("Aborted.")
            return
        shutil.rmtree(test_path)

    test_path.mkdir(parents=True)
    print(f"Creating {file_count} files in {test_dir}...")

    start_time = time.time()
    for i in range(file_count):
        file_path = test_path / f"file_{i:05d}.txt"
        file_path.write_text(f"Test file {i}")

    elapsed = time.time() - start_time
    print(f"Created {file_count} files in {elapsed:.2f} seconds")


def cleanup_test_directory(test_dir: str):
    """Remove the test directory."""
    test_path = Path(test_dir)
    if test_path.exists():
        shutil.rmtree(test_path)
        print(f"Deleted: {test_dir}")
    else:
        print(f"Directory not found: {test_dir}")


def test_directory_listing(test_dir: str):
    """Test directory listing performance using the Flutter app."""
    test_path = Path(test_dir)
    if not test_path.exists():
        print(f"Directory not found: {test_dir}")
        return

    file_count = len(list(test_path.iterdir()))
    print(f"Testing directory with {file_count} files...")

    # Test using Flutter driver (if available)
    # For now, just count files using Python
    start_time = time.time()
    files = list(test_path.iterdir())
    elapsed = time.time() - start_time

    print(f"Python list.iterdir(): {elapsed:.4f} seconds for {len(files)} items")

    # Test using Dart/Flutter (if available)
    # This would require running the Flutter app with specific test parameters
    # For now, we'll just print instructions
    print("\nTo test in the Flutter app:")
    print(f"1. Open the Safe Disk app")
    print(f"2. Open an encrypted directory")
    print(f"3. Navigate to: {test_dir}")
    print(f"4. Observe the loading time and UI responsiveness")
    print(f"5. Try switching between list view and tree view")
    print(f"6. Try the 'Load more' button in tree view")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    command = sys.argv[1]
    test_dir = sys.argv[2]

    if command == "create":
        if len(sys.argv) < 4:
            print("Error: file_count required for 'create' command")
            sys.exit(1)
        file_count = int(sys.argv[3])
        create_test_directory(test_dir, file_count)

    elif command == "cleanup":
        cleanup_test_directory(test_dir)

    elif command == "test":
        test_directory_listing(test_dir)

    else:
        print(f"Unknown command: {command}")
        print(__doc__)
        sys.exit(1)


if __name__ == "__main__":
    main()
