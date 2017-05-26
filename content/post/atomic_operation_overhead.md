+++
date = "2016-12-26"
title = "Atomic operation overhead"
tags = ["Programming"]
+++

ARMはconsistencyが弱く設計されてるメモリモデルだから、強いメモリモデルのx86_64と比べて
atomic変数の操作にともなうオーバーヘッドは大きめ、という記述
[[1]](http://yohhoy.hatenablog.jp/entry/2014/12/21/171035)[[2]](http://www.cl.cam.ac.uk/~pes20/cpp/cpp0xmappings.html)を読んだので、自分でも調べてみました。


CPUではキャッシュ機構やOoOのはたらきにより、
メモリアクセスが機械語の順番通りにおこなわれるとは限りません。
これを制御するために、load/store命令の順序入れ替えに関する振る舞いを定めたものが、
ハードウェアのメモリモデルです。

メモリアクセス順序に保証をもたせたいときは、そのための機構を使用することになります。
それが、順序付けされたload/store命令や、
命令の入れ替えを抑制するメモリバリア命令（またはメモリフェンス命令）です。

x86のメモリバリア命令は`mfence`で、ARMは`dmb`となっています。
これらはともに、それより先に発行されたload/store命令は、
後に発行される命令より先に完了していることを保証します。
[[x86リファレンス]](http://x86.renejeschke.de/html/file_module_x86_id_170.html),
[[ARMリファレンス]](http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dui0204ij/CIHJFGFE.html)

x86_64とARMのメモリモデルは次のようになっているようです。
[[引用元]](http://yohhoy.hatenablog.jp/entry/2014/12/21/171035)

<blockquote>
<dl>
<dt> Intel x86(IA-32, x86-64) </dt>
<dd> 逐次一貫性にかなり近いハードウェア・メモリ一貫性モデルのため、追加のオーバーヘッドはほとんどありません。atomic変数への書き出し処理だけが若干のペナルティを受けます(lock xchg命令)。 </dd>

<dt> ARM(ARMv7, ARMv8) </dt>
<dd> 弱いメモリモデルのハードウェア・メモリ一貫性モデルのため、逐次一貫性の実現にはメモリバリア命令発行が必要です(dmb命令)。ARMv8では専用のメモリ・ストア／ロード命令が追加され(stlr/ldar命令)、メモリバリア命令発行が不要になります。 </dd>
</dl>
</blockquote>

ただ、x86で順序付けされたstoreには`xchg`の代わりに
`mov`と`mfence`が使われることもあるそうです
[[参考]](http://www.cl.cam.ac.uk/~pes20/cpp/cpp0xmappings.html)。


atomic変数の操作で実際にどんな命令が発行されるか調べるため、次のプログラムをそれぞれ、
`Darwin Kernel Version 15.6.0: Wed Nov  2 20:30:56 PDT 2016; root:xnu-3248.60.11.1.2~2/RELEASE_X86_64 x86_64 i386`上の、

* g++ 6.3.0で、オプションは`-std=gnu++14 -O3 -S`
* ARM v7用クロスコンパイラarm-none-eabi-g++ 5.4.1で、`-mcpu=cortex-m4 -mabi=aapcs -mthumb -std=gnu++14 -O3 -S`

でコンパイルしました。

```cpp
// atomic.cpp

#include <atomic>

std::atomic<int> i{1};

void f()
{
    int j = i.load();
    i.store(j * 2);
}
```

```cpp
// nonatomic.cpp

int i = 1;

void f()
{
    int j = i;
    i = j * 2;
}
```

結果が以下になりました。

```asm
# x86_64_atomic.s

__Z1fv:
LFB325:
	movl	_i(%rip), %eax
	addl	%eax, %eax
	movl	%eax, _i(%rip)
	mfence
	ret
```

```asm
# x86_64_nonatomic.s

__Z1fv:
LFB0:
	sall	_i(%rip)
	ret
```

```asm
# arm_atomic.s

_Z1fv:
	.fnstart
.LFB328:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 0, uses_anonymous_args = 0
	@ link register save eliminated.
	ldr	r2, .L2
	dmb	sy
	ldr	r3, [r2]
	dmb	sy
	lsls	r3, r3, #1
	dmb	sy
	str	r3, [r2]
	dmb	sy
	bx	lr
```

```asm
# arm_nonatomic.s

_Z1fv:
	.fnstart
.LFB0:
	@ args = 0, pretend = 0, frame = 0
	@ frame_needed = 0, uses_anonymous_args = 0
	@ link register save eliminated.
	ldr	r2, .L2
	ldr	r3, [r2]
	lsls	r3, r3, #1
	str	r3, [r2]
	bx	lr
```

x86の非atomic版は`i`を二倍するだけに最適化されてしまいましたね。

最適化無しで計算すると、

```asm
movl	_i(%rip), %eax
addl	%eax, %eax
movl	%eax, _i(%rip)
```

になるのでしょう。この最後に`mfence`命令を挿入したのが、x86のatomic版の結果です。
`xchg`ではなくてメモリバリア命令が使われてしまいましたが、
一行目での、atomic変数の読み込み後にメモリバリアが発行されないことから、
一行目から三行目までのあいだにメモリの入れ替えが起こらないことがわかり、
x86が強いメモリモデルであることを示しています。

ARM v7版をみてみましょう。
非atomic版は、グローバル変数を読み込んで二倍して書き込んで...という操作を
アセンブリに忠実に再現しています。
atomic版は、load/storeの前後にいちいちメモリバリアが入っていて、
いかにもオーバーヘッドが大きそうです。
ちなみに`sy`はシステム全体のバリアという意味です。
storeのみを待つモードもあるので、load前にはこっちを使ったほうがいいんじゃないかな...。

上のプログラムでは、`std::atomic<T>::store(), load()`に指定するメモリオーダーはデフォルト値（最も強く遅い`memory_order_seq_cst`）を使っています。
適切なメモリオーダーを指定してやればオーバーヘッドは必要最低限まで減らせるはずですが、適切に設定するのは難しそうです。

というわけで、命令数から見るとARM v7はx86とくらべてatomic変数アクセスのオーバーヘッドが大きい
というのは本当らしいことがわかりました。


実際の計算時間はどうでしょうか。

以下のプログラムで実行時間を測ってみました。

<script src="https://gist.github.com/ordovicia/152afd43579bdd4888858ebfa157c470.js"></script>

実行環境は、

* `macOS Yosemite (Darwin Kernel Version 15.6.0: Wed Nov  2 20:30:56 PDT 2016; root:xnu-3248.60.11.1.2~2/RELEASE_X86_64 x86_64 i386)`でg++ 6.3.0を使い`-O3`でコンパイル
* `Ubuntu 16.04 `で
* `Jetson TX1 (Linux tegra-ubuntu 3.10.96-tegra #1 SMP PREEMPT Wed Sep 28 17:51:08 PDT 2016 aarch64 aarch64 aarch64 GNU/Linux)`でg++ 5.4.0を使い`-O3`でコンパイル

結果は次のようになりました。
ループ回数を横軸に、非atomicとatomicの比率を縦軸にとっています。

![](/img/atomic_operation_overhead_benchmark.png)

（追記予定）
