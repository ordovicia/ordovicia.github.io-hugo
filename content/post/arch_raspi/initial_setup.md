+++
date = "2015-12-10"
title = "Arch Linux on Raspberry Pi 2 - Initial Setup"
tags = ["Arch Linux", "Raspberry Pi"]
+++

先日Raspberry Pi 2を買いました。
試してみたかったArch Linuxをインストールしてみたのでその作業を記録しておきます。

# Arch Linuxのインストール
Ubuntu15.04で、
[Arch Linux ARMのページ](http://archlinuxarm.org/platforms/armv7/broadcom/raspberry-pi-2)
の通りに作業をおこなうと、なにも詰まらずにインストールができました。
ただし`fdisk, mkfs`などは`sudo`をつけて実行し、
`bsdtar`コマンドは新たにaptでインストールして実行しました。

インストールが済んだら、RasPi2に挿してLANケーブルをつなぎ、
電源ケーブルをつなぎます。

sshでrootユーザーとして入ろうとしたのですが、
なぜが初期パスワードのはずの'root'を入力しても'Permission denied'でした。
そこでalarmユーザーではいりました。
このユーザーの初期パスワードは'alarm'です。

```shell
Welcome to Arch Linux ARM

     Website: http://archlinuxarm.org
       Forum: http://archlinuxarm.org/forum
         IRC: #archlinux-arm on irc.Freenode.net
Last login: Wed Dec  9 12:54:36 2015 from 192.168.0.4
```

こんな出力がでたので成功のようです。

# 初期セットアップ
## 更新
`sudo`コマンドがなかったので、
`$ su`でrootになり（このときは'root'がパスワードでした）、
とりあえず

```shell
$ pacman -Syu
```

しました。
けっこう時間がかかります。

なお、この前に`/etc/pacman.d/mirrorlist`を編集して、
ミラーサーバーを近所の台湾あたりにしておくといいそうです。
[参考：「Raspberry Pi に ArchARM をインストールする」 - Qiita](http://qiita.com/masahixixi/items/97b40ff0e9d126b296bd#%E5%88%9D%E6%9C%9F%E3%82%BB%E3%83%83%E3%83%88%E3%82%A2%E3%83%83%E3%83%97)

更新したら`$ reboot`しておきます。

## microSDカード
microSDカードの容量が2GBまでしか認識されないとどこかで聞いた気がしたのですが、

```shell
$ df -h
```

で確認すると、本来の16GB近くの値が表示されていたので、
気にしないことにしました。
RasPi1だけの問題だったのでしょうか。

## パスワードの変更
root, alarmユーザーともに、`$ passwd`でパスワードを変更しておきます。

## 時刻合わせ
```shell
$ timedatectl set-timezone Asia/Tokyo
```

で、タイムゾーンを合わせます。
さらに

```shell
$ timedatectl set-ntp true
```

しておくと、時刻サーバーと同期がとれるようです。

## IPアドレスの固定
しようとしましたが、うまく行きませんでした。
[netctl](https://wiki.archlinuxjp.org/index.php/Netctl)をつかって設定したつもりでも、
設定したIPアドレスで接続できませんでした。
`$ ifconfig`を見るとinetが設定したIPアドレスになっているかと思ったら
rebootするとまた変わっていたりしました。
このとき、設定したネットワークの`$ netctl status`を見ると、
設定ファイルが読み込まれていないようでした。

また困ったら調べてみます。

## ホストネームの設定
ここからは[「Raspberry Pi: Arch Linux の初期設定（SSH 接続まで）」 - ochalog](http://ochaochaocha3.hateblo.jp/entry/2014/04/19/raspberry-pi-initial-setting-of-arch-linux-for-ssh-connecting)を参考にしました。

```shell
$ hostnamectl set-hostname raspi
```

これで`/etc/hostname`にホストネームが書き込まれます。

## sshでrootでのログインを禁止する
`/etc/ssh/sshd_config`を開き、

```shell
PermitRootLogin no
```

と編集します。これでsshでrootでのログインを禁止できました。
（もともと何故かできなかったんですけどね。）

## sudoのインストール
```shell
$ pacman -S sudo
```
で`sudo`をインストールし、wheelグループが使えるように、
`$ visudo`を実行して

```shell
%wheel ALL=(ALL) ALL
```

の部分のコメントアウトを解除しました。

## ユーザーの追加
ユーザーを追加し、パスワードを設定して、さらに`sudo`がつかえるように、
wheelグループに追加します。

```shell
$ useradd -m cyan
$ passwd cyan
$ gpasswd -a cyan wheel
```

---

これで初期セットアップが完了しました。
IPアドレスの固定はできていませんが、困ったらまた調べることにします。
ユーザーグループとかも何も知らないので、ぼちぼちArch LinuxのWikiを読んでみます。

さて、RasPiでなにをしようかな。
