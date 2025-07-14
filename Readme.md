# AWS GenAI Storage Workshop

## Prerequisites 事前準備
- AWS Account
- Session Manager access (no SSH keys required)

## Table of Contents 目次

- [Overview 概要](#overview)
- [Setup セットアップ](#setup)
- [Test S3 Range](#test-s3-range)
- [Prepare Dataset データセット準備](#prepare-dataset)
- [Prepare Vector Database](#prepare-vector-database)
- [Agent Search](#agent-search)
- [Cleanup](#cleanup)

# Overview

## Business Use-Case

An engineering firm needs to audit and track public infrastructure for safety via drone arial footage. They have captured tens of thousands of images (eg. cracks in bridges) and have stored them within archives based on year and month.

As a Cloud Engineer you have been tasked to building a proof-of-concept where you can use GenAI to use natural language to retrieve an image from the archive.

You need to report back possible technical paths and technical considerations for this project.

エンジニアリング会社は、ドローンの空撮映像を通じて公共インフラの安全性を監査・追跡する必要があります。彼らは数万枚の画像（例：橋のひび割れ）を撮影し、年月別のアーカイブに保存しています。
クラウドエンジニアとして、あなたはGenAIを使用して自然言語でアーカイブから画像を検索できる概念実証を構築する任務を与えられました。
このプロジェクトの技術的な道筋と技術的考慮事項を報告する必要があります。

![](./docs/assets/image-example.jpg)

## Architecture Changes アーキテクチャの変更

**Previous Architecture (旧アーキテクチャ):**
- RDS PostgreSQL instance
- IAM User with Access Keys
- Manual environment setup

**New Architecture (新アーキテクチャ):**
- **EC2 t3.small** with self-hosted PostgreSQL + pgvector
- **IAM Role-based authentication** (no access keys)
- **Automated setup** via CloudFormation UserData
- **Fixed S3 bucket naming**: `aws-storage-genai-workshop-<AccountID>-<Region>`
- **Automatic GitHub repository cloning**
- **Session Manager access** (no SSH keys required)

## Considerations and Requirements

- All resources will be created in `ap-northeast-1` Asia Pacific (Tokyo)
- **EC2-based environment** with automated setup instead of Codespaces
- Cost optimized: EC2 t3.small (~$0.02/hour) instead of RDS
- **No manual credential management** - uses IAM roles
- **Automatic AWS region configuration**
- Repository: [https://github.com/cm-suzuki-ryo/aws-storage-genai-workshop](https://github.com/cm-suzuki-ryo/aws-storage-genai-workshop)

## Technical Uncertainty

- ✅ Can we extract specific bytes from an S3 file and read them?
- ✅ Can we use Amazon Nova to generate mock images to vary our dataset?
- ✅ Can we annotate the images in structure json output using Amazon Nova?
- ✅ Can we extract a specific image file from a zip archive from s3 (without the need to download archive)
- ✅ Can we use Nova Titans to create embeddings for our vector search database?
- ✅ Can we deploy pgvector database on EC2 t3.small?
- ✅ Can we get Amazon Nova to generate our query to our vector database and return the results?

---

- ✅ S3ファイルから特定のバイトを抽出して読み取ることはできますか？
- ✅ Amazon Novaを使用してデータセットを多様化するためのモック画像を生成することはできますか？
- ✅ Amazon Novaを使用して構造化されたJSON出力で画像に注釈を付けることはできますか？
- ✅ S3のzipアーカイブから特定の画像ファイルを抽出することはできますか（アーカイブをダウンロードする必要なく）？
- ✅ Nova Titansを使用してベクター検索データベース用の埋め込みを作成することはできますか？
- ✅ EC2 t3.smallでpgvectorデータベースをデプロイすることはできますか？
- ✅ Amazon Novaにベクターデータベースへのクエリを生成させて結果を返すことはできますか？

## Technical Diagram

![](./docs/assets/diagram.png)

## Public Dataset

We are using the CUBIT Infrastructure Defect Detection Dataset

CUBIT インフラ欠陥検出データセットを使用しています

https://github.com/BenyunZhao/CUBIT

# Setup

## AWS Account Setup

### Enable All Amazon Bedrock Models

1. Drop down the region changer
2. Change your region your to `東京 ap-northeast-1`

<img src="./docs/assets/change_region.png" width="600px"></img>

3. In the search bar type `bedrock`
4. Click on Amazon Bedrock to go to this service.

<img src="./docs/assets/navigate_bedrock.png" width="600px"></img>

5. In the left hand column click on `モデルアクセス`

<img src="./docs/assets/find_model_access.png" width="600px"></img>

6. Click on `すべてのモデルを有効にする`

<img src="./docs/assets/start_model_access.png" width="600px"></img>

7. Click on `次へ`

<img src="./docs/assets/select_models.png" width="600px"></img>

8. Click on `送信`

<img src="./docs/assets/confirm_model.png" width="600px"></img>

9. See that the models `Nova Pro`, `Nova Canvas` are enabled

<img src="./docs/assets/see_models.png" width="600px"></img>

### Deploy AWS Infrastructure

Deploy the following AWS Infrastructure using CloudFormation:
- **EC2 Instance** (t3.small) with PostgreSQL + pgvector
- **S3 Bucket** with fixed naming convention
- **IAM Role** with necessary permissions
- **Automatic environment setup**

**デプロイするAWSインフラ:**
- **EC2インスタンス** (t3.small) PostgreSQL + pgvector付き
- **S3バケット** 固定命名規則付き
- **IAMロール** 必要な権限付き
- **自動環境セットアップ**

#### Deploy via AWS CLI

```bash
aws cloudformation create-stack \
  --stack-name GenAIStorageStackEC2 \
  --template-body file://cfn/setup.yaml \
  --parameters ParameterKey=MasterUserPassword,ParameterValue=Testing123! \
  --capabilities CAPABILITY_IAM \
  --region ap-northeast-1
```

#### Deploy via AWS Console

1. Navigate to CloudFormation in AWS Console
2. Click "Create stack" → "With new resources"
3. Upload the template file: `cfn/setup.yaml`
4. Set stack name: `GenAIStorageStackEC2`
5. Set database password: `Testing123!`
6. Enable IAM capabilities
7. Create stack (wait ~10-15 minutes)

<img src="./docs/assets/cfn_deploy.png" width="600px"></img>

### Access EC2 Instance

Once the stack is deployed, access the EC2 instance via Session Manager:

```bash
# Get Instance ID from CloudFormation outputs
aws cloudformation describe-stacks \
  --stack-name GenAIStorageStackEC2 \
  --query 'Stacks[0].Outputs[?OutputKey==`InstanceId`].OutputValue' \
  --output text

# Connect via Session Manager
aws ssm start-session --target i-xxxxxxxxx --region ap-northeast-1
```

### Verify Setup

Once connected to the EC2 instance:

```bash
# Check setup completion
cat /home/ec2-user/setup_complete.txt

# Test AWS configuration
/home/ec2-user/test_aws_config.sh

# Check database status
/home/ec2-user/db_status.sh

# Navigate to workshop directory
cd /home/ec2-user/aws-storage-genai-workshop
ls -la
```

## Environment Configuration

The environment is automatically configured during EC2 launch:

### S3 Bucket Naming
- **Format**: `aws-storage-genai-workshop-<AccountID>-<Region>`
- **Example**: `aws-storage-genai-workshop-123456789012-ap-northeast-1`

### Environment Variables (.env)
Automatically created with correct values:
```bash
STACK_NAME=GenAIStorageStackEC2
AWS_REGION=ap-northeast-1
AWS_BUCKET_NAME=aws-storage-genai-workshop-123456789012-ap-northeast-1
DATABASE_URL=postgresql://postgres:Testing123!@localhost:5432/vectordb
AWS_FILE_KEY=images.zip
```

### Ruby Environment
- Ruby, bundler, and all gems automatically installed
- PostgreSQL client (psql) pre-installed
- All bin scripts updated for local database connection

🎉  **Setup Complete セットアップ完了** 🎉 

# Test S3 Range

## Technical Uncertainty

We want to determine if we can read part of a file without downloading the entire file.
Amazon S3 suggests you can use a RANGE Http Header to specific the byte range to download.

### Upload File

We will upload a file called `hello_world.txt` to our bucket.

The contents of this file is `こんにちは世界`.

```bash
./bin/upload_file
```

### Read Part Of File

We will specify the byte range to only read `世界`.

```bash
./bin/read_range
```

<img src="./docs/assets/see_range.png" width="600px"></img>

# Prepare Dataset

## Generate Mock Images

If our dataset has missing image examples we can generate our own to help later test
the edge cases for our application.

We are using `Amazon Nova Canvas` to generate images.

```sh
./bin/generate
```

This will output a file to `outputs/images/`

<img src="./docs/assets/generated_image_1.png" width="600px"></img>

> Example of generated image using the following prompt: The image shows the eaves of a building with visible cracks, spalling, and missing components. The surface appears deteriorated, with signs of water damage and discoloration. The eaves are part of the building's exterior, and the defects are concentrated along the edge where the roof meets the wall.

## Annotate Images

We need to generate annotation (metadata) information so we can search our images.

We are using `Amazon Nova Pro` to analyze the image.

The challenge is generating structured json output.
While this implementation of `./bin/annotate` works, there is a chance for 1,000 of runs it might fail and so more work needs to be put to catch edge cases.

```sh
./bin/annotate
```

Here is an example of annotation output: [annotate.json.example](./outputs/annotate.json.example)

> This will annotate our real images, not the mock ones. If we want to include the mock ones we need to copy them into the input directory

## Create Archive, Inventory File and Upload to S3

1. Zip our images to an archive
2. Read the zip file and create an inventory file with byte ranges for exact files
3. Upload the zip archive to our S3 bucket

```sh
./bin/upload
```

## Test Downloading Single Image from the Archive

This script will read the inventory file to get the byte range,
we will use the byte range to download the image from inside the archive.

We have to decompress the partial data to get to the final file.

```sh
./bin/download hk0155.jpg
```

## Create Embedding Data

We will use an embedding model to convert our annotation data into vector embeddings.
We'll generate a SQL file to mass import our data into our database.

```sh
./bin/embedd
```

# Prepare Vector Database

## Database Connection

The PostgreSQL database is automatically configured and running on the EC2 instance.
No additional installation is required.

## Load Data into Database 

- We will enable vector extension
- We will setup our tables

```sh
./bin/execute ./sql/setup.sql
```

- We will insert our data into the database

```sh
./bin/execute ./sql/insert-[timestamp].sql
```
> ⚠️ This file is autogenerated with a timestamp so you'll need to use tab completion or check the actual filename in the sql/ directory

- We will create our indexes

```sh
./bin/execute ./sql/indexes.sql
```

These warnings are due to our low amount of data.
In our production use-case we need to have indexes.

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

# Agent Search

## Agent

Using the converse API and Amazon Nova Pro we can search against
our vector database.

Example queries:
```sh
./bin/agent "cracks in wall that are not a concern"
./bin/agent "severe structural cracks in concrete walls"
./bin/agent "building defects requiring immediate action"
./bin/agent "roof problems with water damage"
./bin/agent "moderate spalling on urban structures"
./bin/agent "all safety concerns in buildings"
```

# Troubleshooting

## Check Setup Status

```bash
# Verify setup completion
cat /home/ec2-user/setup_complete.txt

# Test AWS configuration
/home/ec2-user/test_aws_config.sh

# Check database status
/home/ec2-user/db_status.sh

# View UserData execution log
sudo cat /var/log/user-data.log
```

## Common Issues

### AWS CLI Region Error
If you see `aws: error: argument --region: expected one argument`:
- The environment is automatically configured during setup
- Check environment variables: `echo $AWS_REGION`
- Re-source the environment: `source ~/.bashrc`

### Database Connection Issues
```bash
# Test database connection
./bin/connect

# Check PostgreSQL status
sudo systemctl status postgresql
```

### Permission Issues
```bash
# Fix ownership if needed
sudo chown -R ec2-user:ec2-user /home/ec2-user/aws-storage-genai-workshop
```

# Cleanup

## Delete Resources

1. **Empty S3 Bucket** (if it contains objects):
```bash
aws s3 rm s3://aws-storage-genai-workshop-<AccountID>-<Region> --recursive
```

2. **Delete CloudFormation Stack**:
```bash
aws cloudformation delete-stack --stack-name GenAIStorageStackEC2 --region ap-northeast-1
```

Or via AWS Console:
1. Navigate to CloudFormation
2. Select the stack `GenAIStorageStackEC2`
3. Click "Delete"
4. Confirm deletion

## Cost Optimization

- **EC2 t3.small**: ~$0.02/hour (~$0.50/day)
- **S3 storage**: Minimal cost for workshop data
- **Total estimated cost**: Under $1 USD for workshop duration

Remember to delete resources after completing the workshop to avoid ongoing charges.

---

## Changes Summary 変更点まとめ

### Major Changes 主な変更点

1. **RDS → EC2 PostgreSQL**: Cost optimization and full control
2. **IAM User → IAM Role**: Enhanced security, no credential management
3. **Manual setup → Automated setup**: CloudFormation UserData handles everything
4. **Dynamic bucket names → Fixed naming**: Predictable S3 bucket names
5. **Codespaces → EC2 + Session Manager**: Consistent environment, no SSH keys

### Benefits メリット

- **Cost Effective**: ~70% cost reduction vs RDS
- **Secure**: No access keys, IAM role-based authentication
- **Automated**: Zero manual configuration required
- **Consistent**: Same environment for all users
- **Accessible**: Session Manager access from anywhere
