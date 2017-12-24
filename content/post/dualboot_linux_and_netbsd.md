+++
date = "2017-12-24"
title = "LinuxとNetBSDのデュアルブート"
tags = ["Linux", "BSD", "NetBSD"]
+++

LinuxとNetBSDをデュアルブートする方法をメモしておきます。

## 環境

* DELL Latitude E6540
    * BIOS (Legacy boot)
* Ubuntu Desktop 16.04 と NetBSD 7.1 をデュアルブート

## Linuxのインストール

Linuxのディストーションとして、今回はUbuntu Desktop 16.04をインストールします。
Ubuntuは通常どおり、[公式のリリースページ](http://releases.ubuntu.com/16.04/)からISOファイルをダウンロードし、USBメモリなどに焼いてインストールすればOKです。
ただしあとでNetBSDをインストールするパーティションを確保しておきましょう。

## NetBSDのインストール

まずは[公式のリリースページ](https://www.netbsd.org/releases/index.html)からUSBメモリ用のイメージをダウンロードし、焼きます。
USBメモリから起動してインストーラを実行します。
基本的な流れは、[NetBSD公式のインストールガイド](https://www.netbsd.org/docs/guide/en/chap-exinst.html)や
[webzoit.netさん](https://www.webzoit.net/hp/it/internet/homepage/env/os/bsd_unix_linux/netbsd/03_install)がたいへん参考になります。
そこで、デュアルブートのために必要な手順のみ説明します。

### NetBSDのブートローダをインストールしない

NetBSDのインストール中に、「bootselect codeをインストールするか？」と聞かれるステップがあります。
これはUbuntuで使っているブートローダを上書きしてしまうので、Noと答えます。

### UbuntuのGRUBからNetBSDが起動できるよう設定

NetBSDのブートローダは使わずに、Ubuntuの領域にインストールしたGRUBからNetBSDがブートできるように設定します。

まず、`/etc/grub.d/40-custom` に以下のようなエントリーを追記します。

```text
menuentry `NetBSD 7.1 on sda3` {
    insmod bsd
    set root=(hd0,3)
    chainloader (hd0,3)+1
}
```

エントリーの名前は好きなものに設定してください。
`root`, `chainloader`で設定するパーティションは、NetBSDをインストールしたところ指すように設定するため、環境によって変わります。
NetBSDをインストールしたパーティションの番号や`fdisk`の結果から決めてください。

次に、`/etc/default/grub` を編集します。
7, 8行目付近に `GRUB_HIDDEN_TIMEOUT` を含む二行があるので、これをコメントアウトします。
GRUBのメニューで勝手にUbuntuを起動させず、NetBSDのエントリーを選べるようにするためです。

最後に `sudo update-grub` を実行し、GRUBの設定を更新します。

## 動作確認

以上でデュアルブートの設定は終わりです。
再起動してGRUBのメニューにNetBSDが現れることを確認しましょう。
