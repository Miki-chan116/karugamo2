import io
import json
import platform
import sys
import threading
import time
import tkinter as tk
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from tkinter import messagebox

import esptool
import serial


BAUDRATE = 115200
FLASH_BAUDRATE = "1500000"
DEVICE_ID_PREFIX = "atom-"

BG_COLOR = "#0b5a35"
PRIMARY_GREEN = "#00aa55"
ORANGE = "#F4A261"
WHITE = "#ffffff"
BLACK = "#000000"


def find_base_dir() -> Path:
    candidates = []

    if getattr(sys, "frozen", False):
        exe_path = Path(sys.executable).resolve()
        for parent in exe_path.parents:
            candidates.append(parent)

    script_dir = Path(__file__).resolve().parent
    candidates.append(script_dir)

    for parent in script_dir.parents:
        candidates.append(parent)

    for candidate in candidates:
        if (candidate / "tools").exists() or (candidate / "release_assets").exists():
            return candidate

    return Path.cwd()


def find_release_assets_dir() -> Path:
    # PyInstaller --add-data で同梱された場合
    if getattr(sys, "frozen", False) and hasattr(sys, "_MEIPASS"):
        bundled_dir = Path(sys._MEIPASS) / "release_assets"
        if bundled_dir.exists():
            return bundled_dir

    # 通常実行またはフォルダ配布の場合
    base_dir = find_base_dir()
    external_dir = base_dir / "release_assets"
    if external_dir.exists():
        return external_dir

    # dist/KarugamoAtomDeploy.exe の隣に release_assets を置いた場合
    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).resolve().parent
        exe_side_dir = exe_dir / "release_assets"
        if exe_side_dir.exists():
            return exe_side_dir

    return external_dir


BASE_DIR = find_base_dir()
RELEASE_ASSETS_DIR = find_release_assets_dir()
CONFIG_FILE = BASE_DIR / "tools" / "deploy_atom_gui_config.json"

BOOTLOADER_BIN = RELEASE_ASSETS_DIR / "bootloader.bin"
PARTITIONS_BIN = RELEASE_ASSETS_DIR / "partitions.bin"
BOOT_APP0_BIN = RELEASE_ASSETS_DIR / "boot_app0.bin"
FIRMWARE_BIN = RELEASE_ASSETS_DIR / "firmware.bin"


def default_font_name() -> str:
    system = platform.system()

    if system == "Windows":
        return "Yu Gothic UI"

    if system == "Darwin":
        return "Hiragino Sans"

    return "TkDefaultFont"


FONT_NAME = default_font_name()


def default_port() -> str:
    system = platform.system()

    if system == "Windows":
        return "COM3"

    if system == "Darwin":
        return "/dev/cu.usbserial"

    return "/dev/ttyUSB0"


def validate_release_assets() -> None:
    required_files = [
        BOOTLOADER_BIN,
        PARTITIONS_BIN,
        BOOT_APP0_BIN,
        FIRMWARE_BIN,
    ]

    missing_files = [path for path in required_files if not path.exists()]

    if missing_files:
        message = "配布用binファイルが見つかりません:\n"
        message += "\n".join(str(path) for path in missing_files)
        message += "\n\nrelease_assets フォルダに以下4ファイルを配置してください:\n"
        message += "bootloader.bin\n"
        message += "partitions.bin\n"
        message += "boot_app0.bin\n"
        message += "firmware.bin"
        raise RuntimeError(message)


def validate_device_id(device_id: str) -> None:
    if not device_id.startswith(DEVICE_ID_PREFIX):
        raise ValueError("device_id must start with 'atom-'")

    suffix = device_id.replace(DEVICE_ID_PREFIX, "", 1)

    if not suffix:
        raise ValueError("device_id suffix is empty")

    if not suffix.isdigit():
        raise ValueError("device_id suffix must be numeric, e.g. atom-001")


def read_until_idle(ser: serial.Serial, seconds: float = 3.0, log=None) -> str:
    end_time = time.time() + seconds
    chunks = []

    while time.time() < end_time:
        if ser.in_waiting:
            data = ser.read(ser.in_waiting).decode(errors="replace")
            chunks.append(data)

            if log:
                log(data)

            end_time = time.time() + 0.5
        else:
            time.sleep(0.1)

    return "".join(chunks)


def send_command(
    ser: serial.Serial,
    command: str,
    wait_seconds: float = 1.5,
    log=None,
) -> str:
    if log:
        log(f"\n>>> {command}\n")

    ser.write((command + "\n").encode("utf-8"))
    ser.flush()

    return read_until_idle(ser, wait_seconds, log=log)


def run_upload(port: str, log=None) -> None:
    if log:
        log("=== Upload start ===\n")
        log("Upload method: esptool bundled\n")
        log(f"Release assets: {RELEASE_ASSETS_DIR}\n")

    validate_release_assets()

    args = [
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

    output = io.StringIO()

    try:
        with redirect_stdout(output), redirect_stderr(output):
            esptool.main(args)
    except SystemExit as e:
        text = output.getvalue()
        if log and text:
            log(text)

        if e.code not in (0, None):
            raise RuntimeError(f"Upload failed. esptool exit code: {e.code}") from e
    except Exception:
        text = output.getvalue()
        if log and text:
            log(text)
        raise

    text = output.getvalue()
    if log and text:
        log(text)

    if log:
        log("=== Upload success ===\n")

    time.sleep(2.0)


def configure_device_id(port: str, device_id: str, log=None) -> None:
    if log:
        log("=== Serial connect ===\n")

    with serial.Serial(port, BAUDRATE, timeout=0.2) as ser:
        time.sleep(2.0)

        if log:
            log("=== Boot log ===\n")

        read_until_idle(ser, 3.0, log=log)

        response = send_command(ser, f"SET_ID {device_id}", 2.0, log=log)

        expected = f"OK device_id={device_id}"
        if expected not in response:
            raise RuntimeError(
                f"SET_ID failed. Expected '{expected}' in response."
            )

        response = send_command(ser, "GET_ID", 2.0, log=log)

        expected = f"Current device_id: {device_id}"
        if expected not in response:
            raise RuntimeError(
                f"GET_ID failed. Expected '{expected}' in response."
            )

    if log:
        log("\n=== Device ID configured successfully ===\n")


class AtomDeployApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Karugamo AtomLite 配布ツール")
        self.root.geometry("720x620")
        self.root.configure(bg=BG_COLOR)
        self.root.resizable(False, False)

        config = self.load_config()

        self.port_var = tk.StringVar(value=config.get("port", default_port()))
        self.device_number_var = tk.StringVar(value="")

        self.is_running = False

        self._build_ui()

    def load_config(self):
        if not CONFIG_FILE.exists():
            return {}

        try:
            with CONFIG_FILE.open("r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def save_config(self, port: str):
        try:
            CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)

            with CONFIG_FILE.open("w", encoding="utf-8") as f:
                json.dump(
                    {
                        "port": port,
                    },
                    f,
                    ensure_ascii=False,
                    indent=2,
                )
        except Exception:
            pass

    def _build_ui(self):
        header = tk.Frame(self.root, bg=WHITE, height=64)
        header.pack(fill="x")

        title = tk.Label(
            header,
            text="🦆 AtomLite 配布ツール",
            bg=WHITE,
            fg=BLACK,
            font=(FONT_NAME, 20, "bold"),
            anchor="w",
            padx=20,
        )
        title.pack(fill="both", expand=True)

        body = tk.Frame(self.root, bg=BG_COLOR, padx=24, pady=24)
        body.pack(fill="both", expand=True)

        note = tk.Label(
            body,
            text="管理者用：AtomLiteへ共通PGを配布し、識別番号を設定します。",
            bg=BG_COLOR,
            fg="#d8f5e5",
            font=(FONT_NAME, 11),
            anchor="w",
        )
        note.pack(fill="x", pady=(0, 20))

        self._label(body, "COMポート")
        self.port_entry = tk.Entry(
            body,
            textvariable=self.port_var,
            font=(FONT_NAME, 18),
            bg=WHITE,
            fg=BLACK,
            relief="flat",
        )
        self.port_entry.pack(fill="x", ipady=10, pady=(0, 18))

        self._label(body, "AtomLite番号")

        device_frame = tk.Frame(body, bg=WHITE)
        device_frame.pack(fill="x", pady=(0, 22))

        prefix_label = tk.Label(
            device_frame,
            text=DEVICE_ID_PREFIX,
            font=(FONT_NAME, 18),
            bg=WHITE,
            fg=BLACK,
            padx=8,
        )
        prefix_label.pack(side="left", ipady=10)

        self.device_entry = tk.Entry(
            device_frame,
            textvariable=self.device_number_var,
            font=(FONT_NAME, 18),
            bg=WHITE,
            fg=BLACK,
            relief="flat",
        )
        self.device_entry.pack(side="left", fill="x", expand=True, ipady=10)

        button_frame = tk.Frame(body, bg=BG_COLOR)
        button_frame.pack(fill="x", pady=(0, 18))

        self.upload_button = tk.Button(
            button_frame,
            text="PG配布＋番号設定",
            command=self.run_upload_and_set,
            bg=PRIMARY_GREEN,
            fg=WHITE,
            activebackground="#008f49",
            activeforeground=WHITE,
            font=(FONT_NAME, 16, "bold"),
            relief="flat",
            cursor="hand2",
        )
        self.upload_button.pack(side="left", fill="x", expand=True, ipady=12)

        spacer = tk.Frame(button_frame, bg=BG_COLOR, width=12)
        spacer.pack(side="left")

        self.set_only_button = tk.Button(
            button_frame,
            text="番号設定のみ",
            command=self.run_set_only,
            bg=ORANGE,
            fg=BLACK,
            activebackground="#e88b3e",
            activeforeground=BLACK,
            font=(FONT_NAME, 16, "bold"),
            relief="flat",
            cursor="hand2",
        )
        self.set_only_button.pack(side="left", fill="x", expand=True, ipady=12)

        self.status_label = tk.Label(
            body,
            text="待機中",
            bg=BG_COLOR,
            fg=WHITE,
            font=(FONT_NAME, 12, "bold"),
            anchor="w",
        )
        self.status_label.pack(fill="x", pady=(0, 8))

        log_frame = tk.Frame(body, bg=WHITE)
        log_frame.pack(fill="both", expand=True)

        self.log_text = tk.Text(
            log_frame,
            font=("Consolas", 10),
            bg="#111111",
            fg="#f2f2f2",
            insertbackground=WHITE,
            relief="flat",
            wrap="word",
        )
        self.log_text.pack(side="left", fill="both", expand=True)

        scrollbar = tk.Scrollbar(log_frame, command=self.log_text.yview)
        scrollbar.pack(side="right", fill="y")
        self.log_text.configure(yscrollcommand=scrollbar.set)

    def _label(self, parent, text):
        label = tk.Label(
            parent,
            text=text,
            bg=BG_COLOR,
            fg=WHITE,
            font=(FONT_NAME, 13, "bold"),
            anchor="w",
        )
        label.pack(fill="x", pady=(0, 6))

    def validate_inputs(self):
        port = self.port_var.get().strip()
        device_number = self.device_number_var.get().strip()

        if not port:
            messagebox.showerror("入力エラー", "COMポートを入力してください。")
            return None

        if not device_number:
            messagebox.showerror("入力エラー", "AtomLite番号を入力してください。")
            return None

        if not device_number.isdigit():
            messagebox.showerror(
                "入力エラー",
                "AtomLite番号は数字だけで入力してください。例: 101",
            )
            return None

        device_id = f"{DEVICE_ID_PREFIX}{device_number}"

        self.save_config(port)

        return port, device_id

    def set_running(self, running: bool):
        self.is_running = running
        state = "disabled" if running else "normal"

        self.upload_button.configure(state=state)
        self.set_only_button.configure(state=state)
        self.port_entry.configure(state=state)
        self.device_entry.configure(state=state)
        self.status_label.configure(text="実行中..." if running else "待機中")

    def append_log(self, text: str):
        self.log_text.insert("end", text)
        self.log_text.see("end")
        self.root.update_idletasks()

    def thread_safe_log(self, text: str):
        self.root.after(0, lambda: self.append_log(text))

    def clear_log(self):
        self.log_text.delete("1.0", "end")

    def run_upload_and_set(self):
        self._run_deploy(skip_upload=False)

    def run_set_only(self):
        self._run_deploy(skip_upload=True)

    def _run_deploy(self, skip_upload: bool):
        if self.is_running:
            return

        values = self.validate_inputs()
        if values is None:
            return

        port, device_id = values

        self.clear_log()
        self.append_log("=== Karugamo AtomLite 配布ツール ===\n")
        self.append_log(f"COMポート: {port}\n")
        self.append_log(f"AtomLite番号: {device_id}\n")
        self.append_log(f"Release assets: {RELEASE_ASSETS_DIR}\n")
        self.append_log("モード: 番号設定のみ\n" if skip_upload else "モード: PG配布＋番号設定\n")
        self.append_log("\n")

        thread = threading.Thread(
            target=self._worker,
            args=(port, device_id, skip_upload),
            daemon=True,
        )
        thread.start()

    def _worker(self, port: str, device_id: str, skip_upload: bool):
        self.root.after(0, lambda: self.set_running(True))

        try:
            validate_device_id(device_id)

            if not skip_upload:
                run_upload(port, log=self.thread_safe_log)

            configure_device_id(port, device_id, log=self.thread_safe_log)

            self.root.after(0, lambda: self.append_log("\n✅ 完了しました。\n"))
            self.root.after(
                0,
                lambda: messagebox.showinfo(
                    "完了",
                    f"AtomLiteの配布/設定が完了しました。\n\n{device_id}",
                ),
            )

        except Exception as e:
            error_message = str(e)

            self.root.after(0, lambda: self.append_log(f"\nERROR: {error_message}\n"))
            self.root.after(0, lambda: self.append_log("\n❌ 失敗しました。\n"))
            self.root.after(0, lambda: messagebox.showerror("エラー", error_message))

        finally:
            self.root.after(0, lambda: self.set_running(False))


def main():
    root = tk.Tk()
    AtomDeployApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()