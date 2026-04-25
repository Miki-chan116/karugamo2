
# Karugamo Counter2 / カルガモカウンター

AtomLite と連携することを想定した、打刻・運行回数カウント用の Android アプリです。

現在は、Web アプリとして作成した HTML / JavaScript を Capacitor を使って Android アプリ化しています。



## 開発環境

- Windows
- VSCode
- Node.js v24.15.0
- npm v11.12.1
- Capacitor CLI v8.3.1
- Android Studio
- Android Emulator



## 使用している主な技術

- HTML
- CSS
- JavaScript
- localStorage
- Capacitor
- Android Studio



## VSCode 拡張機能

以下の拡張機能を使用します。

| 拡張機能 | 用途 |
|---|---|
| ESLint | JavaScript のエラーチェック |
| Prettier - Code formatter | コード整形 |
| Live Preview | HTML のプレビュー確認 |



## プロジェクト構成

```text
karugamo2
├─ android
├─ node_modules
├─ www
│  ├─ index.html
│  ├─ edit.html
│  ├─ register.html
│  ├─ today.html
│  └─ history.html
├─ capacitor.config.json
├─ package.json
├─ package-lock.json
└─ README.md
```
## Capacitor 設定

`capacitor.config.json`

```json
{
  "appId": "jp.karugamo.counter2",
  "appName": "Karugamo-counter2",
  "webDir": "www"
}
```

---

## セットアップ手順

### 1. Node.js / npm の確認

```bash
node -v
npm -v
```

確認済みバージョン：

```text
node v24.15.0
npm 11.12.1
```

---

### 2. npm 初期化

```bash
npm init -y
```

---

### 3. Capacitor のインストール

```bash
npm install @capacitor/core
npm install -D @capacitor/cli
```

確認：

```bash
npx cap --version
```

確認済みバージョン：

```text
8.3.1
```

---

### 4. Capacitor 初期化

```bash
npx cap init
```

設定内容：

```text
Name: karugamo2
Package ID: com.example.app
Web asset directory: www
```

初期化後、`capacitor.config.json` を以下のように修正しました。

```json
{
  "appId": "jp.karugamo.counter2",
  "appName": "Karugamo-counter2",
  "webDir": "www"
}
```

---

### 5. Android パッケージ追加

```bash
npm install @capacitor/android
```

---

### 6. Android プロジェクト作成

```bash
npx cap add android
```

これにより、プロジェクト直下に `android` フォルダが作成されます。

---

### 7. Android Studio で開く

```bash
npx cap open android
```

Android Studio が起動したら、Gradle の読み込みが完了するまで待ちます。

---

## Android Studio での実行

1. Android Studio を開く
2. 実行先デバイスを選択する  
   例：`Small Phone`
3. 実行構成が `app` になっていることを確認する
4. 緑の ▶ ボタンを押す
5. Android エミュレータ上でアプリが起動する

---

## 現在できていること

- Android エミュレータでアプリを起動
- `index.html` の表示
- 「打刻する」ボタンの動作
- 打刻時刻の追加
- 打刻回数の表示
- 前回からの経過時間表示
- `localStorage` への保存
- 画面再描画

---

## 現在の注意点

### Google Apps Script 用コードについて

元の Web アプリでは Google Apps Script の以下の処理を使用していました。

```javascript
google.script.run
```

これは Google Apps Script の HTML 画面内でのみ動作します。

Android アプリ化後はそのままでは使えないため、現在は送信処理を Android アプリ用に変更する必要があります。

---

## 今後の作業予定

### 1. 修正画面への遷移

`index.html` の以下を変更予定です。

```html
<button class="edit-btn">修正する</button>
```

変更後：

```html
<button class="edit-btn" onclick="location.href='edit.html'">修正する</button>
```

変更後は以下を実行します。

```bash
npx cap sync android
```

その後、Android Studio で再実行します。

---

### 2. データ送信処理の変更

現在の Google Apps Script 用の送信処理を、Android アプリから利用できる形に変更する必要があります。

候補：

- Google Apps Script の Web API に `fetch()` で送信する
- Firebase を使う
- 独自 API サーバーを使う

---

### 3. AtomLite 連携

AtomLite から BLE 通信で打刻データを受け取る予定です。

Android アプリ化後は、Web Bluetooth ではなく Capacitor 用の BLE プラグインを使う想定です。

候補：

```bash
npm install @capacitor-community/bluetooth-le
```

---

## よく使うコマンド

### Web 側の変更を Android に反映

```bash
npx cap sync android
```

### Android Studio を開く

```bash
npx cap open android
```

### Capacitor バージョン確認

```bash
npx cap --version
```

### Node.js / npm バージョン確認

```bash
node -v
npm -v
```

---

## 開発メモ

Android Studio 初回起動時には、以下のような通知が表示される場合があります。

- Agent Mode now available
- Project update recommended
- Migrate to Gradle Daemon toolchain

現時点では、これらは無視して問題ありません。

Gradle の読み込みが完了し、実行構成が `app`、実行先がエミュレータになっていれば実行できます。

---

## 現在の到達状況

Android エミュレータ上でアプリの起動に成功しました。

打刻ボタンを押すと、時刻と回数が画面に追加されることを確認済みです。

例：

```text
1回目：15:04
2回目：15:04
前回から：0分
```

---

## ライセンス

未定
