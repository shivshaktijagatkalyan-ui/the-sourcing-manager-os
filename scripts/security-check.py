import os
import sys
import re

# Non-negotiable blocked terms (System Constitution)
BLOCKED_TERMS = [
    'masked_phone',
    'last_four',
    'plain_phone',
    'customer_phone',
    'mobile_number',
    'tel:',
    'wa.me',
    'api.whatsapp.com',
    'console.log(phone',
    'console.log(payload',
    'raw_provider_payload'
]

# Directories to scan
SCAN_DIRS = ['flutter_app/lib', 'supabase/functions']

# Exclude list (e.g. this script itself)
EXCLUDE_FILES = ['security-check.py']

def scan_files():
    violations = []
    for scan_dir in SCAN_DIRS:
        if not os.path.exists(scan_dir):
            continue
            
        for root, _, files in os.walk(scan_dir):
            for file in files:
                if file in EXCLUDE_FILES:
                    continue
                
                file_path = os.path.join(root, file)
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        content = f.read()
                        for term in BLOCKED_TERMS:
                            if term in content:
                                # Check for false positives or permitted usage if any (none for now)
                                violations.append(f"VIOLATION: '{term}' found in {file_path}")
                except Exception as e:
                    print(f"Error reading {file_path}: {e}")
    
    return violations

if __name__ == "__main__":
    print("Starting Security Constitution Scan...")
    violations = scan_files()
    
    if violations:
        print("\n!!! SECURITY CONSTITUTION VIOLATED !!!")
        for v in violations:
            print(v)
        sys.exit(1)
    else:
        print("\nSecurity check passed. No forbidden terms detected.")
        sys.exit(0)
