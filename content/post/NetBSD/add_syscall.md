+++
date = "2018-01-03"
title = "NetBSDにシステムコールを追加する"
tags = ["BSD", "NetBSD"]
+++

NetBSDにシステムコールを追加してみます。

## 環境

* DELL Latitude E6540
    * Intel Core i7-4610M (Haswell)
    * BIOS (Legacy boot)
* NetBSD 7.1

## システムコールの追加

まずは`sys/kern/syscalls.master`に、追加するシステムコールのプロトタイプ情報を追記します。
今回は何もしない`nop`システムコールを追加します。
引数はとらず、即座に0を返します。

```text
481 STD RUMP    { int|sys||nop(void); }
```

追記後、`sys/kern/makesyscalls.sh`を実行します。
これがおおかたの作業をやってくれるようです。

```console
# sh makesyscalls.sh syscalls.conf syscalls.master
```

`nop`システムコールのなかみを忘れずに定義しておきます。
ここでは新しいファイル`sys/kern/sys_nop.c`を追加しました。

```c
#include <sys/syscallargs.h>
#include <sys/systm.h>

int	sys_nop(struct lwp* _lwp, const void* _args, register_t* _regs)
{
    printf("nop called\n");
    return 0;
}
```

nopとは言うものの、デバッグ用に`printf()`しています。
`sys/systm.h`のインクルードはそのためです。

関数プロトタイプは、`makesyscalls.sh`を実行したときに`sys/sys/syscallargs.h`に追記されたものに合わせます。

今回は新しいファイルを追加したので、ビルドするファイルのリストにそのファイルを追加しておきます。
編集するファイルは`sys/conf/files`です。

```text
file    kern/sys_nop.c
```

## ビルド

[NetBSDカーネルのビルド]({{< ref "build_kernel.md" >}})を参照してください。
いちど`configure`からやり直すとうまくいくようです。

## 動作確認

libcにラッパーを用意していないので、`syscall(2)`で呼び出すことにします。
`sys/kern/syscalls.master`に`nop`を追加したときのシステムコール番号を指定します。

```c
#include <stdio.h>
#include <sys/syscall.h>

int main(void)
{
    int ret = syscall(481);
    printf("%d\n", ret);

    return 0;
}
```

コンパイルして実行し、以下のような出力があれば成功です。

```text
nop called
0
```
