+++
date = "2017-04-24"
title = "xv6の紹介"
tags = ["OS development"]
+++

# xv6とは
[xv6](https://pdos.csail.mit.edu/6.828/2014/xv6.html)は、MITで教材用に作られたコンパクトなOSです。
他のいくつかの大学でも使われているようです\[[xv6 - Wikipedia](https://ja.wikipedia.org/wiki/Xv6)\]。

ANSI Cで書かれ、x86で動きます。マルチコアにも対応もしているようです。

ソースコードは[GitHub](https://github.com/mit-pdos/xv6-public)でMITライセンス下で公開されています。
[PDF版](https://pdos.csail.mit.edu/6.828/2014/xv6/xv6-rev8.pdf)もあります。
[xv6のコードと、OSの重要概念の解説](https://pdos.csail.mit.edu/6.828/2014/xv6/book-rev8.pdf)や、
[MITでの授業で使われた資料](https://pdos.csail.mit.edu/6.828/2014/schedule.html)も入手できます。

# xv6のビルド
macOS 10.11.6上のQEMU上で動かします。

macOSはx64でELFじゃないので、xv6のビルド・実行にはクロスコンパイルが必要です。
環境構築については[こちら](http://sairoutine.hatenablog.com/entry/2016/09/02/232318)の方法がたいへん参考になります。
Homebrewを使う方法は依存関係がコンフリクトしていると言われ出来なかったので、binutilsとgccをビルドしました。
