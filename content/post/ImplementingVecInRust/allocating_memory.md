+++
date = "2018-02-20T00:00:01+09:00"
title = "Vecの実装 in Rust - メモリ確保"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/layout" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Allocating Memory](https://doc.rust-lang.org/nomicon/vec-alloc.html)

この節に書かれているアロケータ周りのAPIは古い。
現在のRustでは、メモリアロケータ周りのAPIについて [RFC](https://github.com/rust-lang/rfcs/pull/1398) がマージされ、
[詳細な設計と実装が進んでいる](https://github.com/rust-lang/rust/issues/32838)｡
今回の実装では、このAPIを使っていく。

まず、上で定義した `Vec` 構造体を修正する必要がある。
新しいメモリアロケータAPIでは、アロケータが構造体として提供されるようになった（もともとは `heap::allocate()` のような関数だった）。
今回はデフォルトのアロケータ [`heap::Heap`](https://doc.rust-lang.org/nightly/std/heap/struct.Heap.html) を用いる。

```rust
use std::heap::Heap;

pub struct Vec<T> {
    ptr: OwnedPtr<T>,
    cap: usize,
    len: usize,
    alloc: Heap,
}
```

メモリ領域を割り当てていく。
本来、`Vec<T>` は `T` が [ZST (Zero Sized Type)](https://doc.rust-lang.org/nomicon/exotic-sizes.html#zero-sized-types-zsts) のときにも対応しないといけないが、
特殊な対応が必要になるので、とりあえず今のところはZSTでないことを前提とする。

```rust
use std::mem;

impl<T> Vec<T> {
    pub fn new() -> Self {
        assert!(mem::size_of::<T>() != 0, "We're not ready to handle ZSTs");

        Vec {
            ptr: OwnedPtr::empty(),
            cap: 0,
            len: 0,
            alloc: Heap,
        }
    }
}
```

`Vec::push()` などで実際にメモリ領域をアロケーションし伸ばしていくときの動作を実装する。
先に実装を見せる。

```rust
impl<T: ?Sized> OwnedPtr<T> {
    pub(crate) fn with_non_null(ptr: NonNull<T>) -> Self {
        OwnedPtr {
            ptr,
            _marker: PhantomData,
        }
    }

    pub(crate) fn as_non_null(&self) -> NonNull<T> {
        self.ptr
    }
}
```

```rust
use std::heap::{Alloc, Heap};

use owned_ptr::OwnedPtr;

impl<T> Vec<T> {
    fn grow(&mut self) {
        let (new_cap, ptr) = if self.cap == 0 {
            (1, self.alloc.alloc_one::<T>())
        } else {
            let old_num_bytes = self.cap * mem::size_of::<T>();
            assert!(                                                // (*) explained below
                old_num_bytes <= (::std::isize::MAX as usize) / 2,
                "capacity overflow"
            );

            unsafe {
                let new_cap = self.cap * 2;
                let ptr = self.alloc
                    .realloc_array::<T>(self.ptr.as_non_null(), self.cap, new_cap);
                (new_cap, ptr)
            }
        };

        if let Err(e) = ptr {
            self.alloc.oom(e);
        }

        self.ptr = OwnedPtr::with_non_null(ptr.unwrap());
        self.cap = new_cap;
    }
}
```

最初の要素をpushするとき（`self.cap == 0` のとき）は、
[`Alloc::alloc_one<T>()`](https://doc.rust-lang.org/nightly/std/heap/trait.Alloc.html#method.alloc_one) を利用する。
`T` 型の値を一つおける領域を確保してくれる。

またpushするときは、[`Alloc::realloc_array<T>()`](https://doc.rust-lang.org/nightly/std/heap/trait.Alloc.html#method.realloc_array) を呼ぶ。
要素を指定の個数おける領域を再確保する。

### メモリ確保失敗

Rustでのメモリアロケーションでは、いくつか考慮すべき事項がある。

`Alloc::alloc_one<T>()` などの戻り値の型は `Result<NonNull<T>, AllocErr>` である。
OOM (Out of Memory)状態に陥るなどしてメモリ確保に失敗すると
[`AllocErr`](https://doc.rust-lang.org/nightly/std/heap/enum.AllocErr.html) が返る。

Rustの標準ライブラリでは、メモリ確保に失敗した場合 `abort` する。
`panic!()` でないのは、`panic!()` に伴うスタックの巻き戻し操作自体にメモリアロケーションが必要になるからである。

この `abort` 処理は [`Alloc::oom()`](https://doc.rust-lang.org/nightly/std/heap/trait.Alloc.html#method.oom) で実行できる。

### LLVMのメモリアロケーション

RustコンパイラがバックエンドとしているLLVMにおけるアドレス管理には少々クセがあり、配列のインデックスが符号付きで表されるらしい。
従って、確保できる要素数は最大で `isize::MAX (= usize::MAX / 2)` となる。
実際には、2 byte以上の型は先にアドレスが `usize::MAX` を超えるため、要素数による制限は1 byteの型についてのみ考慮すればよいが、
配列のreinterpret操作などに起因するコーナーケースを潰すため、標準ライブラリではすべての型について要素数を `isize::MAX` に制限している [^1]。

上で定義した `Vec::grow()` におけるアサーション `(*)` は、この制限をチェックしている。
`old_num_bytes <= isize::MAX / 2` のとき `new_cap <= isize::MAX && new_num_bytes <= usize::MAX` が満たされる。

[^1]: ここでは64 bit環境を考える。現在の64 bitマシンはアドレス空間が実際には64 bitではなく44 bitや48 bitなので、アドレスのオーバーフローより先にOOMが起こる。
