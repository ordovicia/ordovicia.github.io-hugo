+++
date = "2017-12-25"
title = "NetBSDの初期設定"
tags = ["BSD", "NetBSD"]
+++

NetBSDの初期設定についてメモしておきます。
[furandon_pigさんのQiitaの記事](https://qiita.com/furandon_pig/items/5479293cb21d6fd9f17c)を参考にしています。

基本的にrootで作業します。

## 環境

* DELL Latitude E6540
    * Intel Core i7-4610M (Haswell)
    * BIOS (Legacy boot)
* NetBSD 7.1

## コンソール上でCaps LockをCtrlにする

以下を実行すると、コンソール上でCaps LockがCtrlとしてふるまいます。

```shell
/sbin/wsconsctl -w map+='keysym Caps_Lock = Control_R' > /dev/null
```

起動時にこれを自動で設定するためには、`/etc/rc.local` に次を追記します。

```shell
/sbin/wsconsctl -w map+='keysym Caps_Lock = Control_R' > /dev/null
```

## DHCP環境下での有線LAN設定

### ホスト名の設定

`/etc/myname` に好きなホスト名を書き込みます。

### DHCPクライアントの自動起動

`/etc/rc.conf` に、以下の行を追記します。

```text
dhcpcd=yes
```

`dhcpcd`というのがDHCPクライアントのようです。

NetBSDの再起動後、`ifconfig`でIPアドレスが振られていることが確認できます。

## パッケージマネージャの設定

NetBSDのパッケージマネージャは、`PKG_PATH`環境変数に格納されているURLからパッケージをダウンロードします。
この環境変数は`~/.profile`にかかれているのですが、コメントアウトされているので修正します。

まず、`~/.profile`の書き込み権限を追加します。

```shell
# chmod +w ~/.profile
```

次に、`~/.profile`を編集します。

```shell
#export PKG_PATH=ftp://ftp.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -m)/7.0/All
```

のような行があるので、このコメントアウトを外します。

### 動作確認

その後、ログアウトして再ログインすれば、`~/.profile`が読み込まれます。
`echo $PKG_PATH`で環境変数が設定されていることを確認しておきます。

パッケージのインストールは、

```shell
# pkg_add sudo
```

のようにすればOKです。

## sudoの設定

上でインストールしたsudoを、`wheel`グループに属するユーザーが使えるようにします。

Linuxの`/etc/sudoers`に相当するファイルが、NetBSDでは`/usr/pkg/etc/sudoers`として存在します。
そこでこのファイルを開き、

```shell
# %wheel ALL=(ALL) ALL
```

のコメントを外します。

## `pkgin`の導入

上で使っている`pkg_add`など、NetBSD標準のパッケージマネージャは正直使いづらいです。
そこで`pkgin`を導入します。

```shell
# pkg_add -v pkgin
# pkgin update
```

Debian系での`apt`と同じ感覚で使えます。
たとえば、

* リポジトリの更新 `pkgin update` （省略形 `pkgin up`）
* インストール済みパッケージの更新 `pkgin upgrade` （省略形 `pkgin ug`）
* パッケージのインストール `pkgin install package` （省略形 `pkgin in`）
* パッケージの削除 `pkgin remove package` （省略形 `pkgin rm`）
* パッケージの検索 `pkgin search keywords` （省略形 `pkgin se`）

などが使えます。
