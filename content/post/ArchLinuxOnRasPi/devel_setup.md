+++
date = "2015-12-21"
title = "Arch Linux on Raspberry Pi 2 - 開発用セットアップ"
tags = ["Linux", "Arch Linux", "Raspberry Pi"]
+++

# 開発環境のセットアップ
前回作成したユーザーcyanで作業します。

## 基本的な開発用ソフトウェア群
まずは基本的なソフトウェア群をインストールします。

```shell
$ sudo pacman -s --needed base-devel
```

`base-devel`はDebianでいう`build-essential`のようなものらしく、
`make`とか`gcc`とかが入っています。
すこし時間がかかります。

## 個人設定
### Dotfiles
私は`.zshrc`などのdotfilesをgithubにあるリポジトリで管理しています。
そのため、まずはgitをインストールし、dotfilesをcloneしてシンボリックリンクを張っておきます。

```shell
$ sudo pacman -S git
$ git clone https://github.com/***/dotfiles.git .dotfiles
$ ln -s .dotfiles/.zshrc .
$ ln -s .dotfiles/.zshrc_linux .
$ ...
```

### Zsh
Zshをつかっているので、`$ sudo pacman -S zsh`でインストールし、
`$ chsh` でログインシェルを変えておきます。
いったんexitしてから再度sshではいって、
さきほどcloneしてきた`.zshrc`がただしく読み込まれているかチェックします。

### Vim
sshで作業するのでエディタはVimを使います。
まずは`$ sudo pacman -S vim`でインストール。

プラグイン管理には[Neobundle](https://github.com/Shougo/neobundle.vim)を使っています。
GitHubのページに書いてあるとおりにインストールします。

カラースキームは[molokai](https://github.com/tomasr/molokai)を使っているので、
これをcloneしてきて`molokai/colors/molokai.vim`ファイルを`~/.vim/colors`に
コピーします。

```shell
$ cd ~/.vim
$ git clone https://github.com/tomasr/molokai.git
$ mkdir colors
$ cp molokai/colors/molokai.vim colors
```

あとはVimを開けばNeobundleによってプラグインがインストールできます。

---

少し作業してみて、RasPi上でコンパイルするのはけっこうつらいことがわかりました。
クロスコンパイルができないか調べてみます。
