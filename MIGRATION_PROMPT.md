# EC2 AmazonLinux2023環境への移行プロンプト

## 概要

このドキュメントは、AWS GenAI Storage WorkshopをGitHub CodespacesからEC2 AmazonLinux2023環境に移行するための包括的なプロンプトです。

## 移行の背景

### 旧アーキテクチャの課題
- GitHub Codespacesの不安定性
- RDSのコスト（約$0.07/時間）
- 手動認証情報管理の複雑さ
- 環境セットアップの一貫性の欠如

### 新アーキテクチャの利点
- 安定したEC2環境
- コスト最適化（約70%削減）
- IAMロールベースのセキュア認証
- 完全自動化されたセットアップ

## 移行プロンプト

**プロンプト：AWS GenAI Storage WorkshopをEC2 AmazonLinux2023環境に移行**

以下の要件に従って、既存のGitHub Codespaces環境をEC2 AmazonLinux2023ベースの自動セットアップ環境に変更してください：

### 1. アーキテクチャ変更

**旧構成から新構成への変更：**
- RDS PostgreSQL → EC2 t3.small上の自己ホスト型PostgreSQL + pgvector
- IAMユーザー + アクセスキー → IAMロールベース認証
- 手動環境セットアップ → CloudFormation UserDataによる完全自動セットアップ
- 動的S3バケット名 → 固定命名規則: `aws-storage-genai-workshop-<アカウントID>-<リージョン>`
- SSH接続 → Session Managerアクセス

### 2. CloudFormationテンプレート更新

`cfn/setup.yaml`を以下の仕様で更新：

**リソース構成：**
- EC2 Launch Template（Amazon Linux 2023、t3.small）
- IAMロール（Bedrock、S3、CloudFormation、EC2、SSM権限）
- 固定命名のS3バケット
- セキュリティグループ（SSH localhost制限）
- 包括的なUserDataスクリプト

**UserDataスクリプト機能：**
- システム更新とパッケージインストール
- AWS CLI設定（リージョン自動設定）
- GitHubリポジトリ自動クローン
- PostgreSQL 15 + pgvector拡張インストール
- Ruby環境セットアップ（bundle install含む）
- 環境変数ファイル（.env）自動生成
- データベース接続スクリプト更新
- ヘルスチェックスクリプト作成
- ワークショップ準備完了マーカー作成

### 3. README.md更新

**セクション変更：**
- 日本語中心の説明に変更
- EC2ベースセットアップ手順
- Session Managerアクセス方法
- 自動セットアップ確認方法
- トラブルシューティングセクション追加
- コスト最適化情報

**新しいセットアップフロー：**
1. Bedrockモデル有効化
2. CloudFormationスタックデプロイ
3. Session Manager経由でEC2接続
4. `WORKSHOP_READY.txt`で準備完了確認

### 4. スクリプト更新

**bin/execute、bin/connect：**
- RDS接続からローカルPostgreSQL接続に変更
- DATABASE_URL環境変数使用
- エラーハンドリング強化

### 5. 環境変数設定

**.env自動生成内容：**
```bash
STACK_NAME=GenAIStorageStackEC2
AWS_REGION=ap-northeast-1
AWS_BUCKET_NAME=aws-storage-genai-workshop-<アカウントID>-<リージョン>
DATABASE_URL=postgresql://postgres:Testing123!@localhost:5432/vectordb
AWS_FILE_KEY=images.zip
```

### 6. 自動化機能

**UserDataによる自動実行：**
- 全パッケージインストール
- データベース設定
- Ruby gems インストール
- AWS設定
- 権限設定
- 準備完了通知

### 7. 監視・デバッグ機能

**追加スクリプト：**
- `/home/ec2-user/test_aws_config.sh` - AWS設定テスト
- `/home/ec2-user/db_status.sh` - データベース状態確認
- `WORKSHOP_READY.txt` - 詳細な準備状況表示

### 8. セキュリティ強化

- アクセスキー完全排除
- IAMロールベース認証
- Session Managerアクセス
- セキュリティグループ最小権限

### 9. コスト最適化

- RDS削除によるコスト削減（約70%）
- t3.small使用（約$0.02/時間）
- 総コスト$1未満/ワークショップ期間

## 実装の詳細

### CloudFormationテンプレートの主要変更点

1. **リソースタイプの変更**
   - `AWS::RDS::DBInstance` → `AWS::EC2::Instance`
   - `AWS::IAM::User` → `AWS::IAM::Role`

2. **UserDataスクリプトの実装**
   - 500行以上の包括的なセットアップスクリプト
   - エラーハンドリングとログ記録
   - 実行時間計測と状態レポート

3. **固定S3バケット命名**
   ```yaml
   BucketName: !Sub 'aws-storage-genai-workshop-${AWS::AccountId}-${AWS::Region}'
   ```

### スクリプトの更新例

**bin/execute更新前：**
```bash
# RDS接続文字列を使用
CONNECTION_STRING="postgresql://user:pass@rds-endpoint:5432/db"
```

**bin/execute更新後：**
```bash
# ローカルデータベース接続
CONNECTION_STRING="$DATABASE_URL"
psql "$CONNECTION_STRING" -f "$SQL_FILE"
```

### 準備完了確認の仕組み

**WORKSHOP_READY.txt例：**
```
========================================
🎉 AWS GenAI Storage Workshop Ready! 🎉
========================================

Setup completed at: 2024-07-14 15:30:45
Setup duration: 180 seconds

📋 Environment Information:
- S3 Bucket Name: aws-storage-genai-workshop-123456789012-ap-northeast-1
- Account ID: 123456789012
- Region: ap-northeast-1
- Database: PostgreSQL 15 with pgvector extension
- Ruby Environment: Ready with all gems installed

✅ Components Status:
- PostgreSQL Database: READY
- pgvector Extension: INSTALLED
- AWS CLI Configuration: CONFIGURED
- Ruby Environment: READY
- Workshop Repository: CLONED
- Environment Variables: SET

🚀 Next Steps:
1. Upload test file: ./bin/upload_file
2. Test S3 range reading: ./bin/read_range
3. Generate mock images: ./bin/generate
4. Follow the workshop guide in README.md
```

## 移行後の利点

### 運用面
- **一貫性**: すべてのユーザーが同じ環境を取得
- **自動化**: 手動設定作業ゼロ
- **信頼性**: EC2の安定した環境

### セキュリティ面
- **認証情報管理不要**: IAMロールによる自動認証
- **最小権限**: 必要な権限のみ付与
- **セキュアアクセス**: Session Manager使用

### コスト面
- **RDS削除**: 約$0.07/時間 → $0.00
- **EC2最適化**: t3.small（$0.02/時間）
- **総コスト**: ワークショップ期間中$1未満

## トラブルシューティング

### よくある問題と解決方法

1. **UserData実行失敗**
   ```bash
   sudo cat /var/log/user-data.log
   ```

2. **AWS CLI設定問題**
   ```bash
   /home/ec2-user/test_aws_config.sh
   ```

3. **データベース接続問題**
   ```bash
   /home/ec2-user/db_status.sh
   ```

## 結論

この移行により、ユーザーは認証情報管理なしで、完全に自動化された一貫性のある環境でワークショップを実行できるようになります。コスト効率とセキュリティの両面で大幅な改善を実現し、より良いユーザーエクスペリエンスを提供します。

---

**作成日**: 2025-07-14  
**対象**: AWS GenAI Storage Workshop  
**移行元**: GitHub Codespaces + RDS  
**移行先**: EC2 AmazonLinux2023 + 自己ホスト型PostgreSQL
