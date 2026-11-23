# AyuGramDesktop 脅威モデル

対象: `smysle/AyuGramDesktop`（dev ブランチ）。AyuGram/AyuGramDesktop のフォークで、上流は Telegram Desktop (tdesktop)。C++/Qt のデスクトップクライアントで、サーバーやインフラはない（インフラ用リポジトリなし）。

## スコープ（ユーザー回答）
- **AyuGram 独自コードのみ**: `Telegram/SourceFiles/ayu/`、および上流ファイル内の AyuGram 変更箇所（`#include "ayu/..."` / `// AyuGram includes` を含む約175ファイル）。
- 対象外: 同梱ライブラリ `Telegram/SourceFiles/ayu/libs/`（sqlite3, sqlite_orm, nlohmann json）、サブモジュール。

## システム概要と信頼境界
クライアントは MTProto で Telegram サーバーと通信し、リモートの他ユーザーが送る内容（メッセージ、エンティティ、メディア、ファイル名、リンク、Bot ボタン）を描画・処理する。AyuGram は以下を追加する:
- 削除・編集済みメッセージをローカル SQLite DB に保存（`ayu/data/ayu_database.cpp`, `messages_storage.cpp`）。メディアパスも保持。
- ゴーストモード（既読・オンライン送信抑止）、ストリーマーモード、メッセージフィルター（正規表現、インポート可: `ui/boxes/import_filters_box.cpp`, `features/filters/`）。
- 独自ディープリンク `tg://ayu...`、ユーザー/チャット ID 解決、設定ハイライト、Spotify リンク変換、URL スキーム判定（`ayu_url_handlers.cpp`）。
- リモート設定取得（`utils/rc_manager.cpp`: `https://update.ayugram.one/rc/current/desktop2`, `https://api.exteragram.app/api/v1/profiles/compact`）。開発者/公式チャンネル/サポーター/カスタムバッジの ID リストを JSON で受信。
- 翻訳（`features/translator/`: Google `translate-pa.googleapis.com`, Yandex）。メッセージ本文を HTML 化して外部送信し、HTML 応答をエンティティに変換（`html_parser.cpp`）。
- メッセージ転送/同期（`features/forward/`）、メッセージスクリーンショット（`features/message_shot/`）。

## コンポーネント
| 名前 | コード |
|---|---|
| URL Handlers | `ayu/ayu_url_handlers.*`、上流の `core/local_url_handlers` 等の AyuGram 変更箇所 |
| Message Storage | `ayu/data/`、削除・編集メッセージの保存フック（`history/`, `data/` 内の AyuGram 変更） |
| Remote Config | `ayu/utils/rc_manager.*`, `ayu/ayu_infra.*` |
| Translator | `ayu/features/translator/` |
| Privacy Features | ゴースト/ストリーマーモード、フィルター（`ayu/features/streamer_mode`, `ayu/features/filters`, `ayu/ayu_settings.*`, `api/` の AyuGram 変更） |
| UI & Settings | `ayu/ui/`, `ayu/features/message_shot`, `ayu/features/forward`, その他上流 UI の AyuGram 変更 |

## 資産
- アカウントセッション（tdata 内の認証キー）— 最重要（推定）。
- 保存された削除・編集済みメッセージ DB とメディア（相手が削除した内容を含む）。
- メッセージ本文（翻訳時に第三者へ送信される）。
- ローカルファイルシステム（メディア保存パス、リンクから開かれるローカルリソース）。

## 攻撃者（ユーザー回答）
- **利用者は本人のみ（個人用ビルド）。** 配布はしていない。
- 対象: リモートの悪意ある Telegram ユーザー/チャット/Bot（細工したメッセージ・リンク・ファイル名・メディア）、ネットワーク上の攻撃者や侵害された外部サービス（RC 設定、翻訳 API、exteragram API の応答）。ユーザーは「すべての攻撃者が対象」と回答（ただし下記の除外あり）。
- **対象外: 同じ PC にログインできるローカル攻撃者**（ローカル DB の平文保存、tdata の読み取りなど、ローカルアクセスが前提の問題）。

## 既存の対策
- RC 取得は `NoLessSafeRedirectPolicy`、JSON パース失敗時は破棄。
- `IsWebUrl` と危険スキーム拒否リスト（file, smb, shell, javascript, ms-* 等）。
- ディープリンクは ID の数値パースのみで、設定変更は行わずハイライト表示のみ（コードからの推定）。

## 対象外・許容リスク（ユーザー回答）
- Telegram 利用規約違反になる機能（ゴーストモード、削除メッセージ保存など）の**存在そのもの**は許容リスク。実装上のセキュリティ欠陥は対象。
- ローカル攻撃者前提の問題は対象外。
- **上流 tdesktop 由来の問題は優先度を下げる**（AyuGram が導入した問題を優先）。

## 未解決の質問
- 翻訳機能でメッセージ本文を Google/Yandex に送ることを許容しているか。
- RC 設定の応答（バッジ/開発者リスト）を信頼する前提でよいか。
