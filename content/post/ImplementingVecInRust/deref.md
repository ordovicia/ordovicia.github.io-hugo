+++
date = "2018-02-21T00:00:02+09:00"
title = "Vecの実装 in Rust - Deref"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/deallocating" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Deref](https://doc.rust-lang.org/nomicon/vec-deref.html)

[標準ライブラリのドキュメント](https://doc.rust-lang.org/nightly/std/vec/struct.Vec.html) を見ると、
`Vec` に適用できるかなりのメソッドはスライスへのderef.を経由して呼べることが分かる。
`Vec` の中身は同じ型を集めた配列なので、スライスへderef.するのは自然である。

そこで、`Deref<Target = [T]> for Vec<T>` を実装する。
簡単で、[`slice::from_raw_parts()`](https://doc.rust-lang.org/nightly/alloc/slice/fn.from_raw_parts.html) を呼ぶだけである。
はじめのアドレスと要素数を渡すとスライスを作ってくれる。
要素数が0のときも正しく動作するようだ。

```rust
use std::ops::Deref;

impl<T> Deref for Vec<T> {
    type Target = [T];

    fn deref(&self) -> &[T] {
        unsafe { ::std::slice::from_raw_parts(self.ptr.as_ptr(), self.len) }
    }
}
```

`&mut [T]` にderef.する `DerefMut` 版もつくっておく。
今度は [`slice::from_raw_parts_mut()`](https://doc.rust-lang.org/nightly/alloc/slice/fn.from_raw_parts_mut.html) を呼ぶ。
`DerefMut: Deref` なので、`Target` の指定は必要ない。

```rust
use std::ops::{Deref, DerefMut};

impl<T> DerefMut for Vec<T> {
    fn deref_mut(&mut self) -> &mut [T] {
        unsafe { ::std::slice::from_raw_parts_mut(self.ptr.as_ptr(), self.len) }
    }
}
```
