import sys
import json
import platform
import subprocess
import threading
import shutil
import tkinter as tk
from tkinter import messagebox
from pathlib import Path


def find_base_dir() -> Path:
    candidates = []

    # PyInstallerでアプリ化された場合
    if getattr(sys, "frozen", False):
        exe_path = Path(sys.executable).resolve()

        # .app の中から起動された場合、親をたどって候補に入れる
        for parent in exe_path.parents:
            candidates.append(parent)

    # 通常のPython実行の場合
    script_dir = Path(__file__).resolve().parent
    candidates.append(script_dir)

    for parent in script_dir.parents:
        candidates.append(parent)

    # 候補の中から karugamo2 のルートを探す
    for candidate in candidates:
        if (
            (candidate / "tools" / "deploy_atom.py").exists()
            and (candidate / "hardware" / "kamokamo").exists()
        ):
            return candidate

    raise RuntimeError(
        "karugamo2 フォルダが見つかりません。\n"
        "KarugamoAtomDeploy.app は karugamo2 フォルダ内の dist フォルダに置いて実行してください。"
    )


BASE_DIR = find_base_dir()
DEPLOY_SCRIPT = BASE_DIR / "tools" / "deploy_atom.py"
CONFIG_FILE = BASE_DIR / "tools" / "deploy_atom_gui_config.json"
DEVICE_ID_PREFIX = "atom-"


def default_port() -> str:
    system = platform.system()

    if system == "Windows":
        return "COM3"

    if system == "Darwin":  # macOS
        return "/dev/cu.usbserial"

    return "/dev/ttyUSB0"


def find_python_command() -> str:
    """
    deploy_atom.py を実行するための Python コマンドを取得する。

    通常のPython実行時:
      今動いている Python を使う。

    PyInstallerでexe/.app化されている時:
      sys.executable は GUI本体を指すため、そのまま使うと
      KarugamoAtomDeploy.exe / .app 自身を再起動してしまう。
      そのため外部の Python を探して使う。
    """
    if not getattr(sys, "frozen", False):
        return sys.executable

    if sys.platform == "win32":
        candidates = ["py", "python", "python3"]
    else:
        candidates = ["python3", "python"]

    for name in candidates:
        path = shutil.which(name)
        if path:
            return path

    raise RuntimeError(
        "Python が見つかりません。\n"
        "AtomLite配布処理を実行するには Python と esptool / pyserial が必要です。\n\n"
        "Windowsの場合:\n"
        "  py -m pip install esptool pyserial\n\n"
        "macOSの場合:\n"
        "  python3 -m pip install esptool pyserial"
    )


BG_COLOR = "#0b5a35"
PRIMARY_GREEN = "#00aa55"
ORANGE = "#F4A261"
WHITE = "#ffffff"
BLACK = "#000000"


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
            # 設定保存失敗は配布処理自体を止めない
            pass

    def _build_ui(self):
        header = tk.Frame(self.root, bg=WHITE, height=64)
        header.pack(fill="x")

        title = tk.Label(
            header,
            text="🦆 AtomLite 配布ツール",
            bg=WHITE,
            fg=BLACK,
            font=("Yu Gothic UI", 20, "bold"),
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
            font=("Yu Gothic UI", 11),
            anchor="w",
        )
        note.pack(fill="x", pady=(0, 20))

        self._label(body, "COMポート")
        self.port_entry = tk.Entry(
            body,
            textvariable=self.port_var,
            font=("Yu Gothic UI", 18),
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
            font=("Yu Gothic UI", 18),
            bg=WHITE,
            fg=BLACK,
            padx=8,
        )
        prefix_label.pack(side="left", ipady=10)

        self.device_entry = tk.Entry(
            device_frame,
            textvariable=self.device_number_var,
            font=("Yu Gothic UI", 18),
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
            font=("Yu Gothic UI", 16, "bold"),
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
            font=("Yu Gothic UI", 16, "bold"),
            relief="flat",
            cursor="hand2",
        )
        self.set_only_button.pack(side="left", fill="x", expand=True, ipady=12)

        self.status_label = tk.Label(
            body,
            text="待機中",
            bg=BG_COLOR,
            fg=WHITE,
            font=("Yu Gothic UI", 12, "bold"),
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
            font=("Yu Gothic UI", 13, "bold"),
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
            python_cmd = find_python_command()

            self.root.after(
                0,
                lambda: self.append_log(f"Python command: {python_cmd}\n"),
            )

            command = [
                python_cmd,
                str(DEPLOY_SCRIPT),
                "--port",
                port,
                "--device-id",
                device_id,
            ]

            if skip_upload:
                command.append("--skip-upload")

            startupinfo = None
            creationflags = 0

            if sys.platform == "win32":
                startupinfo = subprocess.STARTUPINFO()
                startupinfo.dwFlags |= subprocess.STARTF_USESHOWWINDOW
                startupinfo.wShowWindow = subprocess.SW_HIDE
                creationflags = subprocess.CREATE_NO_WINDOW

            process = subprocess.Popen(
                command,
                cwd=BASE_DIR,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                startupinfo=startupinfo,
                creationflags=creationflags,
            )

            assert process.stdout is not None

            for line in process.stdout:
                self.root.after(0, lambda line=line: self.append_log(line))

            return_code = process.wait()

            if return_code == 0:
                self.root.after(0, lambda: self.append_log("\n✅ 完了しました。\n"))
                self.root.after(
                    0,
                    lambda: messagebox.showinfo(
                        "完了",
                        f"AtomLiteの配布/設定が完了しました。\n\n{device_id}",
                    ),
                )
            else:
                self.root.after(0, lambda: self.append_log("\n❌ 失敗しました。\n"))
                self.root.after(
                    0,
                    lambda: messagebox.showerror(
                        "エラー",
                        "配布/設定に失敗しました。ログを確認してください。",
                    ),
                )

        except Exception as e:
            error_message = str(e)

            self.root.after(0, lambda: self.append_log(f"\nERROR: {error_message}\n"))
            self.root.after(0, lambda: messagebox.showerror("エラー", error_message))

        finally:
            self.root.after(0, lambda: self.set_running(False))


def main():
    root = tk.Tk()
    AtomDeployApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()