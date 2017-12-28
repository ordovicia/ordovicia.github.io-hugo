+++
date = "2017-12-28"
title = "NetBSDカーネルのビルド"
tags = ["BSD", "NetBSD"]
+++

NetBSD 7.1のカーネルに手を加える必要があったので、NetBSDのカーネルをビルドして新しいものに差し替える手順を記録しておきます。

## 参考

* [安定版 NetBSD リリースの更新 - The NetBSD Project](http://www.jp.netbsd.org/ja/docs/updating.html)
* [NetBSD ドキュメンテーション: カーネル - The NetBSD Project](http://www.jp.netbsd.org/ja/docs/kernel.html)
* [NetBSDカーネルをビルドしてみる - furandon_pigさんのQiita記事](https://qiita.com/furandon_pig/items/d9b2782372edc1b93263)

## 環境

* DELL Latitude E6540
    * Intel Core i7-4610M (Haswell)
* NetBSD 7.1

## ソースコードの取得

まずはカーネルのソースコードを取得します。
配布されているISOを展開する方法もありますが、今回はCVSをつかいました。

```shell
$ cd /usr
$ export CVS_RSH=ssh
$ cvs -d anoncvs@anoncvs.NetBSD.org:/cvsroot co -r netbsd-7-1 -P src
```

`-r netbsd-7-1` オプションでバージョンが指定できるようです。
ダウンロードにかなり時間がかかるので寝てる間に走らせておくといいです。

## ツールチェインのビルド（今回は必要ない）

> current のカーネルに更新する場合や、より新しいメジャーリリースに更新したい場合には、 はじめに、新しいツールチェインをコンパイルする必要があります。

-- [NetBSD ドキュメンテーション: カーネル - The NetBSD Project](http://www.jp.netbsd.org/ja/docs/kernel.html)

今回は同じバージョン使うので必要ありませんが、必要な場合は以下のようにすればツールチェインがビルドできます。

```shell
$ mkdir /usr/obj /usr/tools
$ cd /usr/src
$ ./build.sh -O /usr/obj -T /usr/tools -U -u tools
```

## カーネルのビルド

それではカーネルをビルドしていきます。

まずは、必要なデバイスドライバやオプションを設定するconfigファイルを用意します。
amd64の場合、configファイルは `/usr/src/sys/arch/amd64/conf` にあります。
ISOとかUSBイメージでインストールされるカーネルはGENERIC configファイルで設定されているもののようです。
configファイルを自分用に編集したい場合はこれをもとにするといいでしょう。

```shell
$ cd /usr/src/sys/arch/amd64/conf/
$ cp GENERIC MYCONF
```

使いたいconfigファイルを指定して `config` を走らせると、コンパイル用のディレクトリが生成されます。

```shell
$ config MYCONF
Build directory is ../compile/MYCONF
Don't forget to run "make depend"
```

そしてこのディレクトリの中で `make depend`, `make` を走らせます。

```shell
$ cd ../compile/MYCONF/
$ make depend
$ make 2>&1 | tee make_20171228_0.log
```

環境によりますが、5分くらいでビルドできました。

できたカーネルは `netbsd` という名前になっています。
これをファイルシステムのルートにおけば、起動時にカーネルとして選択できます。

今回は、既存のカーネルを上書きしないよう違う名前でおいておきます。

```shell
$ cp netbsd /my_netbsd
$ ls /*netbsd
/netbsd	    /my_netbsd
```

## 起動

再起動します。
起動時に、いつもブートオプションを選択する画面が出てくると思います。
ここで `5. Drop to boot prompt` を選択し、プロンプトに移ります。

プロンプト上で `ls` を実行すると、`my_netbsd` が見えるはずです。
そこで、`boot my_netbsd` でカーネルを指定して起動します。

起動後、`uname -a` を実行すると、自分で作ったconfigファイルによるカーネルであることが確認できます。

```text
NetBSD user 7.1.1 NetBSD 7.1.1 (MYCONF) #0: Thu Dec 28 13:54:49 JST 2017  root@user:/usr/src/sys/arch/amd64/compile/MYCONF amd64
```
