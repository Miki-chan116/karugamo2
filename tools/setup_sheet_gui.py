import sys
import json
import platform
import tkinter as tk
from tkinter import messagebox, filedialog
from pathlib import Path

import qrcode
from PIL import Image, ImageTk


def find_base_dir() -> Path:
    candidates = []

    # PyInstallerでexe/.app化された場合
    if getattr(sys, "frozen", False):
        exe_path = Path(sys.executable).resolve()

        # Windows exe / macOS app のどちらでも親をたどって karugamo2 を探す
        for parent in exe_path.parents:
            candidates.append(parent)

    # 通常のPython実行の場合
    script_dir = Path(__file__).resolve().parent
    candidates.append(script_dir)

    for parent in script_dir.parents:
        candidates.append(parent)

    # karugamo2 のルートを探す
    for candidate in candidates:
        if (candidate / "tools").exists() and (candidate / "flutter_app").exists():
            return candidate

    raise RuntimeError(
        "karugamo2 フォルダが見つかりません。\n"
        "KarugamoSheetSetup.exe / .app は karugamo2 フォルダ内、またはその配下に置いて実行してください。"
    )


BASE_DIR = find_base_dir()
CONFIG_FILE = BASE_DIR / "tools" / "setup_sheet_gui_config.json"
DEFAULT_QR_FILE = BASE_DIR / "tools" / "karugamo_sheet_config_qr.png"

BG_COLOR = "#0b5a35"
PRIMARY_GREEN = "#00aa55"
ORANGE = "#F4A261"
WHITE = "#ffffff"
BLACK = "#000000"

QR_PREVIEW_MAX_SIZE = 280


def default_font_name() -> str:
    system = platform.system()

    if system == "Windows":
        return "Yu Gothic UI"

    if system == "Darwin":  # macOS
        return "Hiragino Sans"

    return "TkDefaultFont"


FONT_NAME = default_font_name()


class SheetSetupApp:
    def __init__(self, root: tk.Tk):
        self.root = root
        self.root.title("Karugamo スプレッドシート設定ツール")
        self.root.geometry("720x760")
        self.root.configure(bg=BG_COLOR)
        self.root.resizable(False, False)

        config = self.load_config()

        self.facility_name_var = tk.StringVar(value=config.get("facility_name", ""))
        self.gas_url_var = tk.StringVar(value=config.get("gas_web_app_url", ""))

        self.qr_image = None
        self.qr_photo = None

        self._build_ui()

    def load_config(self):
        if not CONFIG_FILE.exists():
            return {}

        try:
            with CONFIG_FILE.open("r", encoding="utf-8") as f:
                return json.load(f)
        except Exception:
            return {}

    def save_config(self, data: dict):
        CONFIG_FILE.parent.mkdir(parents=True, exist_ok=True)

        with CONFIG_FILE.open("w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)

    def _build_ui(self):
        header = tk.Frame(self.root, bg=WHITE, height=64)
        header.pack(fill="x")

        title = tk.Label(
            header,
            text="🦆 スプレッドシート設定ツール",
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
            text="管理者用：会社名とGAS WebアプリURLから、スマホ設定用QRコードを生成します。",
            bg=BG_COLOR,
            fg="#d8f5e5",
            font=(FONT_NAME, 11),
            anchor="w",
        )
        note.pack(fill="x", pady=(0, 20))

        self._label(body, "会社名")
        self.facility_entry = tk.Entry(
            body,
            textvariable=self.facility_name_var,
            font=(FONT_NAME, 18),
            bg=WHITE,
            fg=BLACK,
            relief="flat",
        )
        self.facility_entry.pack(fill="x", ipady=10, pady=(0, 18))

        self._label(body, "GAS WebアプリURL")
        self.url_entry = tk.Entry(
            body,
            textvariable=self.gas_url_var,
            font=(FONT_NAME, 14),
            bg=WHITE,
            fg=BLACK,
            relief="flat",
        )
        self.url_entry.pack(fill="x", ipady=10, pady=(0, 22))

        button_frame = tk.Frame(body, bg=BG_COLOR)
        button_frame.pack(fill="x", pady=(0, 18))

        generate_button = tk.Button(
            button_frame,
            text="QRコード生成",
            command=self.generate_qr,
            bg=PRIMARY_GREEN,
            fg=WHITE,
            activebackground="#008f49",
            activeforeground=WHITE,
            font=(FONT_NAME, 16, "bold"),
            relief="flat",
            cursor="hand2",
        )
        generate_button.pack(side="left", fill="x", expand=True, ipady=12)

        spacer = tk.Frame(button_frame, bg=BG_COLOR, width=12)
        spacer.pack(side="left")

        save_button = tk.Button(
            button_frame,
            text="QR画像を保存",
            command=self.save_qr_as,
            bg=ORANGE,
            fg=BLACK,
            activebackground="#e88b3e",
            activeforeground=BLACK,
            font=(FONT_NAME, 16, "bold"),
            relief="flat",
            cursor="hand2",
        )
        save_button.pack(side="left", fill="x", expand=True, ipady=12)

        self.status_label = tk.Label(
            body,
            text="待機中",
            bg=BG_COLOR,
            fg=WHITE,
            font=(FONT_NAME, 12, "bold"),
            anchor="w",
        )
        self.status_label.pack(fill="x", pady=(0, 8))

        qr_frame = tk.Frame(body, bg=WHITE, width=340, height=340)
        qr_frame.pack(pady=(8, 8))
        qr_frame.pack_propagate(False)

        self.qr_label = tk.Label(
            qr_frame,
            text="QRコードがここに表示されます",
            bg=WHITE,
            fg=BLACK,
            font=(FONT_NAME, 13),
        )
        self.qr_label.pack(fill="both", expand=True)

        self.qr_info_label = tk.Label(
            body,
            text="QRコード生成後、このQRをスマホアプリで読み取ってください。",
            bg=BG_COLOR,
            fg=WHITE,
            font=(FONT_NAME, 11, "bold"),
            anchor="center",
        )
        self.qr_info_label.pack(fill="x", pady=(0, 14))

        help_text = tk.Label(
            body,
            text=(
                "1. 雛形スプレッドシートをコピー\n"
                "2. コピー先でGASをWebアプリとしてデプロイ\n"
                "3. 発行されたURLをここに貼り付け\n"
                "4. QRコードをスマホアプリで読み取り"
            ),
            bg=BG_COLOR,
            fg="#d8f5e5",
            font=(FONT_NAME, 11),
            justify="left",
            anchor="w",
        )
        help_text.pack(fill="x", pady=(0, 0))

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
        facility_name = self.facility_name_var.get().strip()
        gas_url = self.gas_url_var.get().strip()

        if not facility_name:
            messagebox.showerror("入力エラー", "会社名を入力してください。")
            return None

        if not gas_url:
            messagebox.showerror("入力エラー", "GAS WebアプリURLを入力してください。")
            return None

        if "script.google.com/macros/s/" not in gas_url or not gas_url.endswith("/exec"):
            messagebox.showerror(
                "入力エラー",
                "GAS WebアプリURLの形式が正しくない可能性があります。\n\n"
                "例:\n"
                "https://script.google.com/macros/s/xxxxxxxx/exec",
            )
            return None

        return {
            "facility_name": facility_name,
            "gas_web_app_url": gas_url,
        }

    def generate_qr(self):
        data = self.validate_inputs()
        if data is None:
            return

        save_path = filedialog.asksaveasfilename(
            title="QRコードの保存先を選択",
            defaultextension=".png",
            filetypes=[("PNG image", "*.png")],
            initialfile="karugamo_sheet_config_qr.png",
        )

        if not save_path:
            self.status_label.configure(text="QRコード生成をキャンセルしました")
            return

        self.save_config(data)

        qr_text = json.dumps(data, ensure_ascii=False)

        qr = qrcode.QRCode(
            version=None,
            error_correction=qrcode.constants.ERROR_CORRECT_M,
            box_size=10,
            border=4,
        )
        qr.add_data(qr_text)
        qr.make(fit=True)

        self.qr_image = qr.make_image(
            fill_color="black",
            back_color="white",
        ).convert("RGB")

        # 選択した場所に保存
        self.qr_image.save(save_path)

        # 表示枠に収まるように自動縮小
        preview = self.qr_image.copy()
        preview.thumbnail((QR_PREVIEW_MAX_SIZE, QR_PREVIEW_MAX_SIZE), Image.LANCZOS)

        self.qr_photo = ImageTk.PhotoImage(preview)

        self.qr_label.configure(image=self.qr_photo, text="")
        self.status_label.configure(text=f"QRコードを生成・保存しました: {save_path}")
        self.qr_info_label.configure(text="このQRをスマホアプリで読み取ってください。")

        messagebox.showinfo("完了", "QRコードを生成・保存しました。")

    def save_qr_as(self):
        if self.qr_image is None:
            messagebox.showerror("エラー", "先にQRコードを生成してください。")
            return

        path = filedialog.asksaveasfilename(
            title="QR画像を保存",
            defaultextension=".png",
            filetypes=[("PNG image", "*.png")],
            initialfile="karugamo_sheet_config_qr.png",
        )

        if not path:
            return

        self.qr_image.save(path)
        self.status_label.configure(text=f"QR画像を保存しました: {path}")
        messagebox.showinfo("保存完了", "QR画像を保存しました。")


def main():
    root = tk.Tk()
    SheetSetupApp(root)
    root.mainloop()


if __name__ == "__main__":
    main()