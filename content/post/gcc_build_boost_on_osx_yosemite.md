+++
date = "2015-12-22"
title = "OS X Yosemite上でBoostをGCCでビルドする"
tags = ["Programming", "GCC", "Boost", "macOS"]
+++

Mac OSX Yosemite(10.10.5)上で、
Boost1.60.0をGCC5.3でビルドするのが大変だったので記録しておきます。

# 背景
GCCでビルドしているプロジェクトがあって、
それにBoost.Program_optionsをつかっています。
HomebrewをつかえばBoostは簡単にインストールできます。
しかし、HomebrewでインストールしたBoostは、Clangでビルドされていて、
GCCでビルドしたコードとうまくリンクできませんでした。
（参考：[Compiling boost::program_options on Mac OS X with g++ 4.8 (Mac Ports) -- stackoverflow](http://stackoverflow.com/questions/19912862/compiling-boostprogram-options-on-mac-os-x-with-g-4-8-mac-ports))

そこで、GCCをつかいBoostを自分でビルドすることにしました。

なお、MacPortsを使っているかたは、参考に挙げたページに従えば、
GCCでビルドされたBoostがインストールできるようです。

Homebrewを使う方法はいくつか目にしたのですが、
情報が古かったせいか、うまくいきませんでした。

# 手順
## HomebrewでインストールしたBoostを削除
まず、HomebrewですでにインストールしてあるBoostがあったので、
それをアンインストールします。

```shell
$ brew uninstall boost
```

## Boostダウンロード
まずは[Boost公式ページ](http://www.Boost.org/)から、最新版を落としてきます。
この時点では1.60.0が最新でした。
適当に展開します。

```shell
$ tar xjvf boost_1_60_0.tar.bz2
```

（余談ですが、`tar`のオプションとか覚えきれないので、
zshのsuffix aliasを使っています。
そのため、実際には上のコマンドは打ち込んでいません。
参考：[zshのalias -s (suffix alias)が神な件 -- プログラムモグモグ](http://itchyny.hatenablog.com/entry/20130227/1361933011)）

## GCCの確認
GCC自体は、Homebrewでインストールしたものをつかっています。

```shell
$ which g++
g++: aliased to g++-5 -std=c++11 -Wall -Wextra -Wconversion

$ g++-5 -v
Using built-in specs.
COLLECT_GCC=gcc-5
COLLECT_LTO_WRAPPER=/usr/local/Cellar/gcc/5.3.0/libexec/gcc/x86_64-apple-darwin14.5.0/5.3.0/lto-wrapper
Target: x86_64-apple-darwin14.5.0
Configured with: ../configure --build=x86_64-apple-darwin14.5.0 --prefix=/usr/local/Cellar/gcc/5.3.0 --libdir=/usr/local/Cellar/gcc/5.3.0/lib/gcc/5 --enable-languages=c,c++,objc,obj-c++,fortran --program-suffix=-5 --with-gmp=/usr/local/opt/gmp --with-mpfr=/usr/local/opt/mpfr --with-mpc=/usr/local/opt/libmpc --with-isl=/usr/local/opt/isl --with-system-zlib --enable-libstdcxx-time=yes --enable-stage1-checking --enable-checking=release --enable-lto --with-build-config=bootstrap-debug --disable-werror --with-pkgversion='Homebrew gcc 5.3.0' --with-bugurl=https://github.com/Homebrew/homebrew/issues --enable-plugin --disable-nls --enable-multilib
Thread model: posix
gcc version 5.3.0 (Homebrew gcc 5.3.0)
```

## GCCでビルドするように設定
このままだとOSXにプリインストールされているclangでビルドされてしまうので、
設定します。
これが本当にわかりにくくて大変でした。

まず、いま展開した`boost_1_60_0`ディレクトリにはいって、
`tools/build/example/user-config.jam`を開きます
（なんでこんなところに設定ファイルがあるんでしょうね）。

40行目くらいに、`GCC configuration`の部分があるので、

```
# ------------------
# GCC configuration.
# ------------------

# Configure gcc (default version).
# using gcc ;

# Configure specific gcc version, giving alternative name to use.
using gcc : 5 : g++-5 ;
```

のように、最後の行を書き換えます。

## ビルド
`bootstrap.sh`に、ビルドにつかうコンパイラを教えます。
`g++`ではなく`gcc`のようです。

```shell
$ ./bootstrap.sh --with-toolset=gcc --with-libraries=all
```

そしてビルドです。
`toolset`にバージョンも合わせてコンパイラを指定します。
ここでも`g++-5`ではなく、`gcc-5`のようです。

```shell
$ ./b2 toolset=gcc-5 cxxflags="-std=c++11" --with=all -link=static,shared runtime-link=shared threading=multi variant=release --stagedir="stage/gcc" -j5
```

`ps`してみて`g++-5`が使われているようだったら成功です。
`-j5`したので15分くらいですみました。

## インストール
最後にインストールです。
`boost`ディレクトリにヘッダが、
先ほど生成した`stages/gcc/lib`にライブラリがあるので、
適当なところにコピーします。
`$ ./b2 install`してもいいかもしれません。
