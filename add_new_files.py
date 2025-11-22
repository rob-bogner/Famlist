#!/usr/bin/env python3
"""
Script to add new CRDT sync files to Xcode project.
"""

import subprocess
import os

# Base directory
base_dir = "/Users/robertbogner/.cursor/worktrees/Famlist/TuHmI"
project_file = f"{base_dir}/Famlist.xcodeproj/project.pbxproj"

# Files to add
sync_files = [
    "Famlist/Core/Sync/HybridLogicalClock.swift",
    "Famlist/Core/Sync/CRDTMetadata.swift",
    "Famlist/Core/Sync/ConflictResolver.swift",
    "Famlist/Core/Sync/SyncOperation.swift",
    "Famlist/Core/Sync/OperationQueue.swift",
    "Famlist/Core/Sync/SyncEngine.swift",
    "Famlist/Core/Sync/RealtimeEventProcessor.swift",
    "Famlist/Core/Sync/SyncMonitor.swift",
]

test_files = [
    "FamlistTests/HybridLogicalClockTests.swift",
    "FamlistTests/ConflictResolverTests.swift",
    "FamlistTests/MultiDeviceSyncIntegrationTests.swift",
]

print("🔧 Adding CRDT Sync files to Xcode project...")
print(f"Project: {project_file}")

# Check if files exist
for file_path in sync_files + test_files:
    full_path = f"{base_dir}/{file_path}"
    if not os.path.exists(full_path):
        print(f"❌ File not found: {file_path}")
    else:
        print(f"✅ Found: {file_path}")

print("\n📋 To add these files to Xcode:")
print("1. Open Famlist.xcodeproj in Xcode")
print("2. Right-click on 'Core' folder → 'Add Files to Famlist'")
print("3. Navigate to Famlist/Core/Sync/")
print("4. Select all 8 .swift files")
print("5. Make sure 'Copy items if needed' is UNCHECKED")
print("6. Target: 'Famlist' should be checked")
print("7. Click 'Add'")
print("\n8. Repeat for test files:")
print("   - Right-click 'FamlistTests' folder → 'Add Files to Famlist'")
print("   - Select 3 test files")
print("   - Target: 'FamlistTests' should be checked")
print("\n✨ Alternative: Run this in Xcode terminal:")
print("cd Famlist.xcodeproj")
print("# Then manually edit project.pbxproj or use Xcode GUI")

