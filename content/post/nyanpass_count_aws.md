+++
date = "2019-01-05"
title = "nyanpass.com の推移を表示する webサイトを AWS でつくる"
tags = ["AWS", "Programming", "Python"]
+++

### 概要

[にゃんぱすーボタン](http://nyanpass.com) のカウントの推移を表示する非公式の [webサイト](http://nyanpass-count.s3-website-ap-northeast-1.amazonaws.com) をつくりました。
すべて AWS のサービス上で動いています。
Lambda関数を一定時間ごとに呼び出してカウントを取得し、S3バケットにその値とグラフ画像を保存して、S3 でホストしているサイトから参照しています。

### はじめに

[にゃんぱすーボタン](http://nyanpass.com) という Webサイトがあります。
このサイトに設置してあるボタンをクリックすると、グローバルなカウントを1ずつ増やすことができます。
いまでも日々、カウンターは進んでいます。

カウントの値はある API で取得できます。
「こっそり」公開されているのでここでも明示はしませんが、探せば見つかります。

今回、この API を一定時間ごとに呼び、記録したカウントの推移をグラフで表示する非公式の [webサイト](http://nyanpass-count.s3-website-ap-northeast-1.amazonaws.com) をつくりました。
このサイトはすべて AWS のサービス上で動いており、具体的には主に Lambda と S3 を使っています。

この記事では、この webサイトの仕組みを簡単に説明します。

### 全体構成

全体の構成は以下のようになっています。
Lambda関数は Python 3.6 で実装しました。

{{< figure src="/img/nyanpass_count_aws_arch.png" width="100%">}}

およそ次の流れで動いています。

1. CloudWatch Events が一定時間ごとに Lambda関数を呼び出す。
1. Lambda関数が、
    1. 「にゃんぱすーボタン」からカウントを取得する。
    1. S3バケットに保存してある過去のデータをダウンロードし、新しいカウントを結合する。
    1. 全体のデータをグラフ化し画像として `/tmp` に保存する。
    1. 新しいカウントと画像を S3バケットにアップロードする。
1. S3バケットでホストしている webサイトが画像を参照する。

### Lambda関数を一定時間ごとに呼び出す

CloudWatch Events を用いると、Lambda関数を予め定めたスケジュールで起動できます。

新しいトリガーを作り、ルールタイプを「スケジュール式」に設定します。
今回はスケジュール式に cron を用い、一定時間ごとに呼び出すようにしました。
`cron(0 * * * ? *)` と記述すれば一時間ごとに起動します。

### Lambda関数内でファイルを扱う

Lambda関数では、一時作業用のストレージとして `/tmp` ディレクトリが使えます。
S3 からダウンロードしたファイルや、生成したグラフ画像はここに一時保存しました。

[名前衝突の可能性があるため](https://www.bokukoko.info/entry/2015/09/17/AWS_Lambda_を利用する上でしっておいたほうがよいこと)、
`os.path.join(os.sep, "tmp", uuid4().hex)` などで一意なファイル名を生成するとよいでしょう。

### S3 にアップロード、S3 からダウンロードする

Python用の AWS SDK として [Boto3](https://aws.amazon.com/jp/sdk-for-python) を使いました。
Boto3 は Lambdaランタイムに組み込まれているため、`import boto3` するだけで使えます。

具体的な使いかたは [Boto3公式ドキュメント](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html) を参照してください。

Lambda関数のロールに、対象となる S3バケットへアクセスできる権限を付与しておきましょう。

### 外部 Pythonモジュール (Matplotlib, pandas) を使う

参考：[AWS公式ドキュメント](https://aws.amazon.com/jp/premiumsupport/knowledge-center/build-python-lambda-deployment-package)

今回の実装では、データ整理に pandas を、グラフ化に Matplotlib を使っています。
これら外部モジュールは Lambdaランタイムに組み込まれていないため、そのままインポートはできません。
Lambda関数のデプロイパッケージに含める必要があります。

まず、ローカルの開発用ディレクトリにすべての依存モジュールをインストールします。
これは `$ pip install matplotlib -t <dir>` のように、`-t`（または `--target`）オプションでインストール先ディレクトリを指定することでできます。

Lambda関数があるディレクトリ直下に外部モジュールがあると汚くなるので、今回は `vendor`ディレクトリを作り、そこにインストールしました。
つまり、以下のような構成です。

```bash
.
├── lambda_function.py
└── vendor
    ├── matplotlib
    ├── pandas
    ...
```

`vendor` ディレクトリをインポートパスに追加するため、以下のコードを Lambda関数スクリプト (`lambda_function.py`) の初めに追記します。

```python
import os
import sys

sys.path.append(
    os.path.join(os.path.abspath(os.path.dirname(__file__)), "vendor"))
```

次に、スクリプトと依存モジュールを zip に固め、デプロイパッケージを作成します。

```bash
$ zip -r lambda.zip lambda_function.py vendor
```

このデプロイパッケージを直接あるいは S3バケットを経由して Lambda関数としてアップロードします。
Matplotlib と pandas を含めるとパッケージサイズは 30MB を超えます。

ちなみに、依存モジュールを S3バケットにおいておき、Lambda関数が起動するごとにダウンロードしてきて動的にインポートすることも可能なようです。
こうするとパッケージサイズが小さくなり、スクリプトをインラインで編集できるようになりそうです。

### S3 で静的サイトをホストする

参考：[AWS公式ドキュメント](https://docs.aws.amazon.com/ja_jp/AmazonS3/latest/dev/WebsiteHosting.html)

S3 を使って静的webサイトをホスティングし公開することができます。
今回は、グラフ画像が保存されているバケットに簡単な HTMLファイルを置き webサイトとしています。
独自ドメインは使いません。

まず、バケットの「プロパティ」から "Static website hosting" を有効にします。
HTMLファイルの名前を「インデックスドキュメント」に指定します。

次に、webサイトの読み取り操作ができるよう、「アクセス権限」からバケットポリシーを設定してパブリックアクセス権限を指定します。
`index.html` と画像ファイルを公開する場合、次のように記述します（バケット名は適宜書き換えてください）。

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": [
                "arn:aws:s3:::bucket-name/index.html",
                "arn:aws:s3:::bucket-name/*.png"
            ]
        }
    ]
}
```

### Lambda関数が失敗したときにアラームを送る

Lambda関数でエラーが発生したときにアラームが送られるように設定します。

CloudWatch でアラームを作成し、メトリクスを「エラー > 0 」と設定しました。
また、何らかの理由で Lambda関数が起動しなかったときのため、データの欠落も不正な状態とみなしています。
今回は、アラームの送り先を自分のメールアドレスにしました。

### まとめ

[にゃんぱすーボタン](http://nyanpass.com) のカウントの推移を表示する非公式の [webサイト](http://nyanpass-count.s3-website-ap-northeast-1.amazonaws.com) をつくりました。
AWS Lambda関数を一定時間ごとに起動してカウントを取得し、グラフ画像を生成して S3バケットでホストした webサイトから参照しています。

ちなみに、『のんのんびより』を見たことはありません。
