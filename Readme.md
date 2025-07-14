# AWS GenAI Storage Workshop

## 事前準備
- AWSアカウント
- Session Managerアクセス（SSH鍵は不要）

## 目次

- [概要](#概要)
- [セットアップ](#セットアップ)
- [S3 Range テスト](#s3-range-テスト)
- [データセット準備](#データセット準備)
- [ベクターデータベース準備](#ベクターデータベース準備)
- [エージェント検索](#エージェント検索)
- [クリーンアップ](#クリーンアップ)

# 概要

## ビジネスユースケース

エンジニアリング会社は、ドローンの空撮映像を通じて公共インフラの安全性を監査・追跡する必要があります。彼らは数万枚の画像（例：橋のひび割れ）を撮影し、年月別のアーカイブに保存しています。

クラウドエンジニアとして、あなたはGenAIを使用して自然言語でアーカイブから画像を検索できる概念実証を構築する任務を与えられました。

このプロジェクトの技術的な道筋と技術的考慮事項を報告する必要があります。

![](./docs/assets/image-example.jpg)

## アーキテクチャの変更

**旧アーキテクチャ:**
- RDS PostgreSQLインスタンス
- アクセスキーを使用するIAMユーザー
- 手動環境セットアップ

**新アーキテクチャ:**
- **EC2 t3.small** 上の自己ホスト型PostgreSQL + pgvector
- **IAMロールベース認証**（アクセスキー不要）
- **CloudFormation UserDataによる自動セットアップ**
- **固定S3バケット命名**: `aws-storage-genai-workshop-<アカウントID>-<リージョン>`
- **GitHubリポジトリの自動クローン**
- **Session Managerアクセス**（SSH鍵不要）

## 考慮事項と要件

- すべてのリソースは `ap-northeast-1` アジアパシフィック（東京）に作成
- **EC2ベース環境** でCodespacesの代わりに自動セットアップ
- コスト最適化: RDSの代わりにEC2 t3.small（約$0.02/時間）
- **手動認証情報管理なし** - IAMロールを使用
- **AWS リージョンの自動設定**
- リポジトリ: [https://github.com/cm-suzuki-ryo/aws-storage-genai-workshop](https://github.com/cm-suzuki-ryo/aws-storage-genai-workshop)

## 技術的検証項目

- ✅ S3ファイルから特定のバイトを抽出して読み取ることはできますか？
- ✅ Amazon Novaを使用してデータセットを多様化するためのモック画像を生成することはできますか？
- ✅ Amazon Novaを使用して構造化されたJSON出力で画像に注釈を付けることはできますか？
- ✅ S3のzipアーカイブから特定の画像ファイルを抽出することはできますか（アーカイブをダウンロードする必要なく）？
- ✅ Nova Titansを使用してベクター検索データベース用の埋め込みを作成することはできますか？
- ✅ EC2 t3.smallでpgvectorデータベースをデプロイすることはできますか？
- ✅ Amazon Novaにベクターデータベースへのクエリを生成させて結果を返すことはできますか？

## アーキテクチャ図

![](./docs/assets/diagram.png)

## パブリックデータセット

CUBIT インフラ欠陥検出データセットを使用しています

https://github.com/BenyunZhao/CUBIT

# セットアップ

## AWSアカウントセットアップ

### Amazon Bedrockモデルをすべて有効化

1. リージョン変更のドロップダウンをクリック
2. リージョンを `東京 ap-northeast-1` に変更

<img src="./docs/assets/change_region.png" width="600px"></img>

3. 検索バーに `bedrock` と入力
4. Amazon Bedrockをクリックしてサービスに移動

<img src="./docs/assets/navigate_bedrock.png" width="600px"></img>

5. 左側のカラムで `モデルアクセス` をクリック

<img src="./docs/assets/find_model_access.png" width="600px"></img>

6. `すべてのモデルを有効にする` をクリック

<img src="./docs/assets/start_model_access.png" width="600px"></img>

7. `次へ` をクリック

<img src="./docs/assets/select_models.png" width="600px"></img>

8. `送信` をクリック

<img src="./docs/assets/confirm_model.png" width="600px"></img>

9. `Nova Pro`、`Nova Canvas` モデルが有効になっていることを確認

<img src="./docs/assets/see_models.png" width="600px"></img>

### AWSインフラのデプロイ

CloudFormationを使用して以下のAWSインフラをデプロイします：
- **EC2インスタンス**（t3.small）PostgreSQL + pgvector付き
- **S3バケット** 固定命名規則付き
- **IAMロール** 必要な権限付き
- **自動環境セットアップ**

#### AWS CLIでのデプロイ

```bash
aws cloudformation create-stack \
  --stack-name GenAIStorageStackEC2 \
  --template-body file://cfn/setup.yaml \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1
```

#### AWSコンソールでのデプロイ

1. AWSコンソールでCloudFormationに移動
2. 「スタックの作成」→「新しいリソースを使用」をクリック
3. テンプレートファイルをアップロード: `cfn/setup.yaml`
4. スタック名を設定: `GenAIStorageStackEC2`
5. パラメーター設定はデフォルト値のまま（パスワード: `Testing123!`）
6. IAM機能を有効化
7. スタックを作成（10分前後待機）

<img src="./docs/assets/cfn_deploy.png" width="600px"></img>

### EC2インスタンスへのアクセス

スタックがデプロイされたら、Session Manager経由でEC2インスタンスにアクセス：

```bash
# CloudFormation出力からインスタンスIDを取得
aws cloudformation describe-stacks \
  --stack-name GenAIStorageStackEC2 \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text

# Session Manager経由で接続
aws ssm start-session --target i-xxxxxxxxx --region ap-northeast-1
```

### セットアップの確認

EC2インスタンスに接続後、ワークショップの準備完了状況を確認：

```bash
# ワークショップディレクトリに移動
cd /home/ec2-user/aws-storage-genai-workshop

# 🎉 準備完了状況を一目で確認
cat WORKSHOP_READY.txt
```

**WORKSHOP_READY.txt** ファイルには以下の情報が含まれます：
- ✅ セットアップ完了時刻と所要時間
- 📋 環境情報（S3バケット名、アカウントID、リージョン等）
- ✅ 各コンポーネントの準備状況
- 🚀 次のステップの案内
- 🔧 トラブルシューティングコマンド

### 追加の確認コマンド（オプション）

```bash
# 簡単な完了確認
cat ~/setup_complete.txt

# AWS設定テスト
/home/ec2-user/test_aws_config.sh

# データベース状態確認
/home/ec2-user/db_status.sh

# ディレクトリ内容確認
ls -la
```

## 環境設定

環境はEC2起動時に自動設定されます：

### S3バケット命名
- **形式**: `aws-storage-genai-workshop-<アカウントID>-<リージョン>`
- **例**: `aws-storage-genai-workshop-123456789012-ap-northeast-1`

### 環境変数（.env）
正しい値で自動作成されます：
```bash
STACK_NAME=GenAIStorageStackEC2
AWS_REGION=ap-northeast-1
AWS_BUCKET_NAME=aws-storage-genai-workshop-123456789012-ap-northeast-1
DATABASE_URL=postgresql://postgres:Testing123!@localhost:5432/vectordb
AWS_FILE_KEY=images.zip
```

### Ruby環境
- Ruby、bundler、すべてのgemが自動インストール
- PostgreSQLクライアント（psql）がプリインストール
- すべてのbinスクリプトがローカルデータベース接続用に更新

🎉  **セットアップ完了** 🎉 

**準備完了の確認方法:**
```bash
cd /home/ec2-user/aws-storage-genai-workshop
cat WORKSHOP_READY.txt
``` 

# S3 Range テスト

## 技術的検証

ファイル全体をダウンロードせずにファイルの一部を読み取れるかを確認します。
Amazon S3では、RANGE HTTPヘッダーを使用して特定のバイト範囲をダウンロードできることが示唆されています。

### ファイルのアップロード

`hello_world.txt` というファイルをバケットにアップロードします。

このファイルの内容は `こんにちは世界` です。

```bash
./bin/upload_file
```

### ファイルの一部読み取り

バイト範囲を指定して `世界` のみを読み取ります。

```bash
./bin/read_range
```

<img src="./docs/assets/see_range.png" width="600px"></img>

# データセット準備

## モック画像の生成

データセットに不足している画像例がある場合、アプリケーションのエッジケースをテストするために独自の画像を生成できます。

`Amazon Nova Canvas` を使用して画像を生成します。

```sh
./bin/generate
```

これにより `outputs/images/` にファイルが出力されます

<img src="./docs/assets/generated_image_1.png" width="600px"></img>

> 以下のプロンプトを使用して生成された画像の例：「画像は、目に見えるひび割れ、剥離、欠損部品のある建物の軒を示しています。表面は劣化しており、水害と変色の兆候があります。軒は建物の外装の一部であり、欠陥は屋根と壁が接する端に集中しています。」

## 画像の注釈

画像を検索できるように注釈（メタデータ）情報を生成する必要があります。

`Amazon Nova Pro` を使用して画像を分析します。

構造化されたJSON出力を生成することが課題です。
この `./bin/annotate` の実装は機能しますが、1,000回の実行で失敗する可能性があるため、エッジケースをキャッチするためにより多くの作業が必要です。

```sh
./bin/annotate
```

注釈出力の例はこちら：[annotate.json.example](./outputs/annotate.json.example)

> これは実際の画像に注釈を付けます（モック画像ではありません）。モック画像を含めたい場合は、入力ディレクトリにコピーする必要があります

## アーカイブ、インベントリファイルの作成とS3へのアップロード

1. 画像をアーカイブにzip
2. zipファイルを読み取り、正確なファイルのバイト範囲でインベントリファイルを作成
3. zipアーカイブをS3バケットにアップロード

```sh
./bin/upload
```

## アーカイブから単一画像のダウンロードテスト

このスクリプトはインベントリファイルを読み取ってバイト範囲を取得し、
バイト範囲を使用してアーカイブ内から画像をダウンロードします。

最終ファイルを取得するために部分データを解凍する必要があります。

```sh
./bin/download hk0155.jpg
```

## 埋め込みデータの作成

埋め込みモデルを使用して注釈データをベクター埋め込みに変換します。
データベースに一括インポートするためのSQLファイルを生成します。

```sh
./bin/embedd
```

# ベクターデータベース準備

## データベース接続

PostgreSQLデータベースはEC2インスタンス上で自動設定され、実行されています。
追加のインストールは不要です。

## データベースへのデータ読み込み

- ベクター拡張を有効化
- テーブルをセットアップ

```sh
./bin/execute ./sql/setup.sql
```

- データベースにデータを挿入

```sh
./bin/execute ./sql/insert-[タイムスタンプ].sql
```
> ⚠️ このファイルはタイムスタンプ付きで自動生成されるため、タブ補完を使用するか、sql/ディレクトリで実際のファイル名を確認する必要があります

- インデックスを作成

```sh
./bin/execute ./sql/indexes.sql
```

これらの警告は、データ量が少ないことが原因です。
本番環境のユースケースではインデックスが必要です。

```sh
psql:sql/indexes.sql:9: NOTICE:  ivfflat index created with little data
DETAIL:  This will cause low recall.
HINT:  Drop the index until the table has more data.
CREATE INDEX
psql:sql/indexes.sql:11: NOTICE:  ivfflat index created with little data
DETAIL:  This will cause low recall.
HINT:  Drop the index until the table has more data.
CREATE INDEX
```

# エージェント検索

## エージェント

Converse APIとAmazon Nova Proを使用して、
ベクターデータベースに対して検索を実行できます。

クエリの例：
```sh
./bin/agent "cracks in wall that are not a concern"
./bin/agent "severe structural cracks in concrete walls"
./bin/agent "building defects requiring immediate action"
./bin/agent "roof problems with water damage"
./bin/agent "moderate spalling on urban structures"
./bin/agent "all safety concerns in buildings"
```

# トラブルシューティング

## セットアップ状態の確認

```bash
# 🎉 ワークショップ準備完了状況を詳細確認
cat /home/ec2-user/aws-storage-genai-workshop/WORKSHOP_READY.txt

# セットアップ完了の簡単確認
cat /home/ec2-user/setup_complete.txt

# AWS設定のテスト
/home/ec2-user/test_aws_config.sh

# データベース状態の確認
/home/ec2-user/db_status.sh

# UserData実行ログの表示
sudo cat /var/log/user-data.log
```

## よくある問題

### AWS CLIリージョンエラー
`aws: error: argument --region: expected one argument` が表示される場合：
- 環境はセットアップ中に自動設定されます
- 環境変数を確認：`echo $AWS_REGION`
- 環境を再読み込み：`source ~/.bashrc`

### データベース接続の問題
```bash
# データベース接続のテスト
./bin/connect

# PostgreSQL状態の確認
sudo systemctl status postgresql
```

### 権限の問題
```bash
# 必要に応じて所有権を修正
sudo chown -R ec2-user:ec2-user /home/ec2-user/aws-storage-genai-workshop
```

# クリーンアップ

## リソースの削除

1. **S3バケットを空にする**（オブジェクトが含まれている場合）：
```bash
aws s3 rm s3://aws-storage-genai-workshop-<アカウントID>-<リージョン> --recursive
```

2. **CloudFormationスタックを削除**：
```bash
aws cloudformation delete-stack --stack-name GenAIStorageStackEC2 --region ap-northeast-1
```

またはAWSコンソール経由：
1. CloudFormationに移動
2. スタック `GenAIStorageStackEC2` を選択
3. 「削除」をクリック
4. 削除を確認

## コスト最適化

- **EC2 t3.small**: 約$0.02/時間（約$0.50/日）
- **S3ストレージ**: ワークショップデータの最小コスト
- **総推定コスト**: ワークショップ期間中$1未満

ワークショップ完了後は継続的な課金を避けるためにリソースを削除することを忘れずに。

---

## 変更点まとめ

### 主な変更点

1. **RDS → EC2 PostgreSQL**: コスト最適化と完全制御
2. **IAMユーザー → IAMロール**: セキュリティ強化、認証情報管理不要
3. **手動セットアップ → 自動セットアップ**: CloudFormation UserDataがすべてを処理
4. **動的バケット名 → 固定命名**: 予測可能なS3バケット名
5. **Codespaces → EC2 + Session Manager**: 一貫した環境、SSH鍵不要

### メリット

- **コスト効率**: RDSソリューションと比較して約70%のコスト削減
- **セキュア**: アクセスキー不要、IAMロールベース認証
- **自動化**: 手動設定作業ゼロ
- **一貫性**: すべてのユーザーに同じ環境
- **アクセス可能**: どこからでもSession Managerアクセス
