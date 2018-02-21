+++
date = "2018-02-21T00:00:01+09:00"
title = "Vecの実装 in Rust - メモリ解放"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/push_and_pop" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Deallocating](https://doc.rust-lang.org/nomicon/vec-dealloc.html)

確保したメモリは使わなくなったら解放しなくてはいけない。
`Drop for Vec` を実装し、その中で解放処理を書くことにする。
ここでも新しい [メモリアロケータAPI](https://github.com/rust-lang/rfcs/pull/1398) を使う。

`self.cap == 0` のときはメモリ確保していないので、解放もしなくてよい。
`self.cap == 1` のときは、`pop()` することで要素をdropし、
[`Alloc::dealloc_one<T>()`](https://github.com/rust-lang/rust/blob/27a046e9338fb0455c33b13e8fe28da78212dedc/src/liballoc/allocator.rs#L926) を使う。
それ以外の場合は、すべての要素を順に `pop()` することでdropし、
[`Alloc::dealloc_array<T>()`](https://github.com/rust-lang/rust/blob/27a046e9338fb0455c33b13e8fe28da78212dedc/src/liballoc/allocator.rs#L1051) を呼ぶ。

```rust
impl<T> Drop for Vec<T> {
    fn drop(&mut self) {
        match self.cap {
            0 => {}
            1 => {
                self.pop();
                unsafe {
                    self.alloc.dealloc_one(self.ptr.as_non_null());
                }
            }
            n => {
                while let Some(_) = self.pop() {}
                unsafe {
                    if let Err(e) = self.alloc.dealloc_array(self.ptr.as_non_null(), n) {
                        self.alloc.oom(e);
                    }
                }
            }
        }
    }
}
```

なお、`T: !Drop` の場合は `pop()` を呼ぶ処理を省略できる。
`T: Drop` かどうかは [`mem::needs_drop()`](https://github.com/rust-lang/rust/blob/27a046e9338fb0455c33b13e8fe28da78212dedc/src/libcore/mem.rs#L485) で判定できる。

```rust
...
match self.cap {
    ...
    1 => {
        if mem::needs_drop::<T>() {
            self.pop();
        }
        ...
    }
    n => {
        if mem::needs_drop::<T>() {
            while let Some(_) = self.pop() {}
        }
        ...
    }
}
...
```

しかし、この最適化を施しても効果はほぼ見られなかった。
LLVMの最適化がかなり強いらしい。

ちなみに、
[標準ライブラリの `Drop for Vec` の実装](https://github.com/rust-lang/rust/blob/27a046e9338fb0455c33b13e8fe28da78212dedc/src/libcore/vec.rs#L2108) では、
`ptr::drop_in_place()` を使って `Drop for [T]` にフォールバックしているようだ。
