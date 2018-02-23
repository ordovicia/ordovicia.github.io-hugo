+++
date = "2018-02-23T00:00:00+09:00"
title = "Vecの実装 in Rust - RawVec"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/into_iter" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [RawVec](https://doc.rust-lang.org/nomicon/vec-raw.html)

前回実装した `IntoIter` をよく見ると、

* `OwnedPtr` と `cap`, `alloc` による、確保したメモリ領域の管理
* `Drop` の実装におけるメモリ解放処理

が `Vec` とかぶっていることが分かる。
こんなとき、重複部分を切り出して抽象化したくなるのが人の情である。

そこで、メモリ管理処理を `RawVec` という構造体に切り出してみる。
標準ライブラリでも [同様の設計](https://doc.rust-lang.org/nightly/alloc/raw_vec/struct.RawVec.html)  を取り、
[`Vec`](https://doc.rust-lang.org/nightly/src/alloc/vec.rs.html#302-305), [`VecDeque`](https://doc.rust-lang.org/nightly/src/alloc/vec_deque.rs.html#57-66) などで使われている。

```rust
use std::heap::{Alloc, Heap};
use std::mem;

pub(super) struct RawVec<T> {
    pub(super) ptr: OwnedPtr<T>,
    pub(super) cap: usize,
    alloc: Heap,
}

impl<T> Drop for RawVec<T> {
    fn drop(&mut self) {
        if self.cap == 0 {
            return;
        }

        unsafe {
            if self.cap == 1 {
                self.alloc.dealloc_one(self.ptr.as_non_null());
            } else {
                let e = self.alloc.dealloc_array(self.ptr.as_non_null(), self.cap);
                if let Err(e) = e {
                    self.alloc.oom(e);
                }
            }
        }
    }
}

impl<T> RawVec<T> {
    pub(super) fn default() -> Self {
        assert!(mem::size_of::<T>() != 0, "We're not ready to handle ZSTs");

        RawVec {
            ptr: OwnedPtr::empty(),
            cap: 0,
            alloc: Heap,
        }
    }

    pub(super) fn grow(&mut self) {
        // unchanged from Vec
    }
}
```

`Drop` の実装でメモリ領域を解放する。
ただし、`RawVec` は「要素」という概念を持たないので、要素の解放は `Vec`, `IntoIter` で処理する必要がある。

この `RawVec` を使うよう、`Vec`, `IntoIter` を修正していく。
まず `impl Drop for Vec` は、要素ごとにdropしたあとはメモリ領域の解放を `RawVec` に任せられる。

```rust
pub struct Vec<T> {
    buf: RawVec<T>,
    len: usize,
}

impl<T> Drop for Vec<T> {
    fn drop(&mut self) {
        if mem::needs_drop::<T>() {
            while let Some(_) = self.pop() {}
        }

        // deallocation is handled by RawVec
    }
}
```

`Vec` の他の部分については、`RawVec` からポインタを取り出す `ptr()` メソッドと、キャパシティを得る `capacity()` を追加し使うようにした以外はほぼ変わらない。
`into_iter()` では、`RawVec` が `Copy` でないため `ptr::read()` によりメモリ領域を取り出す必要がある。

```rust
impl<T> Vec<T> {
    /// Returns capacity.
    pub fn capacity(&self) -> usize {
        self.buf.cap
    }

    /// Creates an [`IntoIter`] instance from self.
    ///
    /// [`IntoIter`]: ../into_iter/struct.IntoIter.html
    pub fn into_iter(self) -> IntoIter<T> {
        // need to use ptr::read to unsafely move the buf out since it's
        // not Copy, and Vec implements Drop (so we can't destructure it).
        let buf = unsafe { ptr::read(&self.buf) };
        let cap = self.capacity();
        let len = self.len;

        mem::forget(self);

        let start = buf.ptr.as_ptr();

        IntoIter::new(
            buf,
            start,
            if cap == 0 {
                // can't offset off this pointer, it's not allocated!
                start
            } else {
                unsafe { start.offset(len as isize) }
            },
        )
    }

    fn ptr(&self) -> *mut T {
        self.buf.ptr.as_ptr()
    }
}
```

次に、`IntoIter` を `RawVec` を使って書き直す。
`Vec` と同様に、`impl Drop for IntoIter` は要素をdropしたあとは `RawVec` に任せる。

```rust
pub struct IntoIter<T> {
    _buf: RawVec<T>, // we don't actually care abount this. Just need it to live.
    start: *const T,
    end: *const T,
}

impl<T> Drop for IntoIter<T> {
    fn drop(&mut self) {
        if mem::needs_drop::<T>() {
            for _ in &mut *self {}
        }

        // deallocation is handled by RawVec
    }
}

impl<T> IntoIter<T> {
    pub(super) fn new(buf: RawVec<T>, start: *const T, end: *const T) -> Self {
        IntoIter {
            _buf: buf,
            start,
            end,
        }
    }
}
```
