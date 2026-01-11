import os
import sys

PLACEHOLDER = "__TEMP_IP__"

def process_file(path, src_ip, dst_ip, mode):
    try:
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()
    except (UnicodeDecodeError, PermissionError):
        return  # skip binary or unreadable files

    original = content

    if mode == "1":
        # src → dst
        content = content.replace(src_ip, dst_ip)

    elif mode == "2":
        # dst → src
        content = content.replace(dst_ip, src_ip)

    elif mode == "3":
        # swap both ways safely
        content = content.replace(src_ip, PLACEHOLDER)
        content = content.replace(dst_ip, src_ip)
        content = content.replace(PLACEHOLDER, dst_ip)

    if content != original:
        with open(path, "w", encoding="utf-8") as f:
            f.write(content)
        print(f"Updated: {path}")

def main():
    if len(sys.argv) != 2:
        print("Usage: python switch_ips.py <folder_path>")
        sys.exit(1)

    folder = sys.argv[1]

    src_ip = input("Enter first IP: ").strip()
    dst_ip = input("Enter second IP: ").strip()

    print("\nChoose switch mode:")
    print(f"1 - {src_ip} → {dst_ip}")
    print(f"2 - {dst_ip} → {src_ip}")
    print("3 - Swap both ways")

    mode = input("Enter choice (1/2/3): ").strip()

    if mode not in {"1", "2", "3"}:
        print("Invalid choice.")
        sys.exit(1)

    for root, _, files in os.walk(folder):
        for file in files:
            path = os.path.join(root, file)
            process_file(path, src_ip, dst_ip, mode)

    print("\nDone.")

if __name__ == "__main__":
    main()