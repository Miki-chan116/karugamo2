import argparse
import subprocess
import sys
import time
from pathlib import Path

import serial


BASE_DIR = Path(__file__).resolve().parents[1]
RELEASE_ASSETS_DIR = BASE_DIR / "release_assets"

BAUDRATE = 115200
FLASH_BAUDRATE = "1500000"

BOOTLOADER_BIN = RELEASE_ASSETS_DIR / "bootloader.bin"
PARTITIONS_BIN = RELEASE_ASSETS_DIR / "partitions.bin"
BOOT_APP0_BIN = RELEASE_ASSETS_DIR / "boot_app0.bin"
FIRMWARE_BIN = RELEASE_ASSETS_DIR / "firmware.bin"


def validate_release_assets() -> None:
    required_files = [
        BOOTLOADER_BIN,
        PARTITIONS_BIN,
        BOOT_APP0_BIN,
        FIRMWARE_BIN,
    ]

    missing_files = [
        path for path in required_files
        if not path.exists()
    ]

    if missing_files:
        message = "配布用binファイルが見つかりません:\n"
        message += "\n".join(str(path) for path in missing_files)
        message += "\n\nrelease_assets フォルダに以下4ファイルを配置してください:\n"
        message += "bootloader.bin\n"
        message += "partitions.bin\n"
        message += "boot_app0.bin\n"
        message += "firmware.bin"
        raise RuntimeError(message)


def run_upload(port: str) -> None:
    print("=== Upload start ===")
    print("Upload method: esptool")
    print(f"Release assets: {RELEASE_ASSETS_DIR}")

    validate_release_assets()

    cmd = [
        sys.executable,
        "-m",
        "esptool",
        "--chip",
        "esp32",
        "--port",
        port,
        "--baud",
        FLASH_BAUDRATE,
        "write-flash",
        "0x1000",
        str(BOOTLOADER_BIN),
        "0x8000",
        str(PARTITIONS_BIN),
        "0xe000",
        str(BOOT_APP0_BIN),
        "0x10000",
        str(FIRMWARE_BIN),
    ]

    result = subprocess.run(
        cmd,
        cwd=BASE_DIR,
        text=True,
    )

    if result.returncode != 0:
        raise RuntimeError("Upload failed")

    print("=== Upload success ===")

    # 書き込み後のリセット・再起動待ち
    time.sleep(2.0)


def read_until_idle(ser: serial.Serial, seconds: float = 3.0) -> str:
    end_time = time.time() + seconds
    chunks = []

    while time.time() < end_time:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting).decode(errors="replace")
            chunks.append(data)
            print(data, end="")
            end_time = time.time() + 0.5
        else:
            time.sleep(0.1)

    return "".join(chunks)


def send_command(ser: serial.Serial, command: str, wait_seconds: float = 1.5) -> str:
    print(f"\n>>> {command}")
    ser.write((command + "\n").encode("utf-8"))
    ser.flush()
    return read_until_idle(ser, wait_seconds)


def configure_device_id(port: str, device_id: str) -> None:
    print("=== Serial connect ===")

    with serial.Serial(port, BAUDRATE, timeout=0.2) as ser:
        time.sleep(2.0)

        print("=== Boot log ===")
        read_until_idle(ser, 3.0)

        response = send_command(ser, f"SET_ID {device_id}", 2.0)

        expected = f"OK device_id={device_id}"
        if expected not in response:
            raise RuntimeError(
                f"SET_ID failed. Expected '{expected}' in response."
            )

        response = send_command(ser, "GET_ID", 2.0)

        expected = f"Current device_id: {device_id}"
        if expected not in response:
            raise RuntimeError(
                f"GET_ID failed. Expected '{expected}' in response."
            )

    print("\n=== Device ID configured successfully ===")


def validate_device_id(device_id: str) -> None:
    if not device_id.startswith("atom-"):
        raise ValueError("device_id must start with 'atom-'")

    suffix = device_id.replace("atom-", "", 1)
    if not suffix:
        raise ValueError("device_id suffix is empty")

    if not suffix.isdigit():
        raise ValueError("device_id suffix must be numeric, e.g. atom-001")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Upload firmware to M5Stack Atom Lite and set device_id."
    )
    parser.add_argument("--port", required=True, help="COM port, e.g. COM3")
    parser.add_argument("--device-id", required=True, help="device_id, e.g. atom-001")
    parser.add_argument(
        "--skip-upload",
        action="store_true",
        help="Skip firmware upload and only set device_id",
    )

    args = parser.parse_args()

    try:
        validate_device_id(args.device_id)

        if not args.skip_upload:
            run_upload(args.port)

        configure_device_id(args.port, args.device_id)

        print("\nDONE")
        print(f"Port: {args.port}")
        print(f"Device ID: {args.device_id}")
        return 0

    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())