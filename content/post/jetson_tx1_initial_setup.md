+++
date = "2017-01-20"
title = "Jetson TX1 initial setup"
tags = ["Jetson TX1"]
+++

Jetson TX1を買いました。
セットアップの手順を記録しておきます。

# JetPackを使ったインストール
ホストOSはUbuntu14.04を使います。
最初Ubuntu16.04で試したのですが、OpenCV4Tegraのビルドに失敗したので、14.04で作業しました。

ホストPCで、TX1用の最新のJetPackをダウンロードし、マニュアルに従ってインストールします。
デフォルトの構成だと10GBほどダウンロードされるので、ネットワーク速度が十分な環境で作業しましょう。

インストール後、Jetsonの電源を入れ直して、

```shell
$ ssh ubuntu@tegra-ubuntu.local
```

でログインできればOKです。

# リカバリー用SDカード作成
SDカードをさし、マウントします。/dev/mmcblk1がSDカードになっています。
ext4でフォーマットします。

[NVIDIA](https://developer.nvidia.com/embedded/downloads)から、TX1用のDriver PackageとSample Root Filesystemをダウンロードし、

```shell
$ sudo tar -vxjf <Driver Package>
$ cd Linux_for_Tegra/rootfs
$ sudo tar jxpf ../../<Sample Root Filesystem>
$ cd ..
$ sudo ./apply_binaries.sh
```

を実行します。
SDカードにrootfs以下をまるごとコピーすると完了です。
このときroot権限で操作しないと、sudoがつかえなくなって詰みます。

JetsonTX1は、eMMCの/boot/extlinux/extlinux.confを読んでブートディスクを選択します。
これを編集し、SDカードからブートするようにします。
具体的には、`LABEL primary`以下をファイル末尾にコピペして、`LABEL sdcard`にかえ、最後のほうにある`root=/dev/mmcblk0p1`を、`root=/dev/mmcblk1p1`に変えます。
最後に、二行目の`DEFAULT primary`を`DEFAULT sdcard`にして、再起動します。

起動後、`df`などでディスクを確認しておきます。

# SSDからのブート
SDカードからブートしたとき、eMMCには/dev/mmcblk0p1からアクセスできます。
SATAポートに繋いだSSDは/dev/sdaに見えます。
ともにマウントしたあと、/dev/mmcblk0p1を/dev/sda1にまるごとコピーして、eMMCの/boot/extlinux/extlinux.confを編集して終わりです。

# Wi-Fiアクセスポイント設定
JetsonTX1は、単体でWi-Fiのアクセスポイントになることが出来ます。
`/etc/modprobe.d/bcmdhd.conf`に、

```
options bcmdhd op_mode=2
```

と追記してから、[これ](https://seravo.fi/2014/create-wireless-access-point-hostapd)に従って設定します。
パスフレーズを8文字以上にすることと、WPAをパーソナルモード(PSK, PSK-SHA-256)にすることに注意しましょう。
