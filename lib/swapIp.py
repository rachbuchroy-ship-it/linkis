import os
import sys

IP_LOCAL = "44.222.98.94"
IP_REMOTE = "44.222.98.94"
PLACEHOLDER = "__TEMP_IP__"

def process_file(path, mode):
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError):
        return  # skip binary or unreadable files

    original = content

    if mode == "1":
        content = content.replace(IP_LOCAL, IP_REMOTE)
    elif mode == "2":
        content = content.replace(IP_REMOTE, IP_LOCAL)
    elif mode == "3":
        content = content.replace(IP_LOCAL, PLACEHOLDER)
        content = content.replace(IP_REMOTE, IP_LOCAL)
        content = content.replace(PLACEHOLDER, IP_REMOTE)

    if content != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated: {path}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python switch_ips.py <folder_path>")
        sys.exit(1)

    folder = sys.argv[1]

    print("Choose switch mode:")
    print("1 - 44.222.98.94 → 44.222.98.94")
    print("2 - 44.222.98.94 → 44.222.98.94")
    print("3 - Swap both ways")

    mode = input("Enter choice (1/2/3): ").strip()

    if mode not in {"1", "2", "3"}:
        print("Invalid choice.")
        sys.exit(1)

    for root, _, files in os.walk(folder):
        for file in files:
            path = os.path.join(root, file)
            process_file(path, mode)

    print("Done.")

if __name__ == "__main__":
    main()