# GAS API

Flutterアプリから送信された打刻データを、Googleスプレッドシートの `logs` シートに保存するための Google Apps Script です。

---

## 役割

このGAS APIは、FlutterアプリからHTTP POSTで送信された打刻データを受け取り、Googleスプレッドシートに1件ずつ保存します。

通信の流れは以下です。

```text
ATOM Lite
↓ BLE
Flutterアプリ
↓ HTTP POST
Google Apps Script
↓
Googleスプレッドシート
```

---

## 保存先シート

シート名：

```text
logs
```

---

## カラム

Googleスプレッドシートの `logs` シートには、以下のカラムで保存します。

```text
id
device_id
press_count
interval_ms
interval_min
received_at
work_date
source
memo
```

---

## 各カラムの意味

| カラム名 | 内容 |
|---|---|
| `id` | 通し番号 |
| `device_id` | ATOM Liteなどのデバイス識別ID |
| `press_count` | ボタンが押された回数 |
| `interval_ms` | 前回押下からの経過時間。単位はミリ秒 |
| `interval_min` | `interval_ms` を分に変換した値 |
| `received_at` | GAS側で受信した日時 |
| `work_date` | 作業日 |
| `source` | データ送信元。例：`atom` |
| `memo` | 備考 |

---

## Flutterから送信するJSON

FlutterアプリからGASへ、打刻1回ごとに以下のJSONを送信します。

```json
{
  "device_id": "atom-001",
  "press_count": 3,
  "interval_ms": 62000,
  "source": "atom"
}
```

---

## Flutterから送信する項目

| 項目 | 内容 | 例 |
|---|---|---|
| `device_id` | デバイス識別ID | `atom-001` |
| `press_count` | 押下回数 | `3` |
| `interval_ms` | 前回押下からの経過時間。単位はミリ秒 | `62000` |
| `source` | データ送信元 | `atom` |

---

## GAS側で追加する項目

Flutterから送られてこない以下の項目は、GAS側で追加します。

| 項目 | 内容 |
|---|---|
| `received_at` | GAS側で受信した日時 |
| `work_date` | 作業日 |
| `interval_min` | `interval_ms` を分に変換した値 |

---

## エンドポイント

Apps ScriptをWebアプリとしてデプロイしたURLに対して、FlutterからHTTP POSTします。

```text
POST https://script.google.com/macros/s/xxxxxxxxxxxxxxxx/exec
```

実際のURLは、Apps Scriptのデプロイ後に発行されます。

---

## レスポンス例

保存に成功した場合：

```json
{
  "status": "success",
  "saved_count": 1,
  "received_at": "2026/04/25 15:04:12"
}
```

エラーが発生した場合：

```json
{
  "status": "error",
  "message": "エラー内容"
}
```

---

## 注意点

現時点では、まず動作確認を優先するため、認証なしのWebアプリURLとして利用する想定です。

本番運用に近づける場合は、簡単な `api_key` をJSONに含めて、GAS側で一致確認する方式を検討します。

---

## 今後の検討事項

- `api_key` による簡易認証
- オフライン時の一時保存
- ユーザー名や作業名の追加
- 日別集計
- 複数デバイス対応

