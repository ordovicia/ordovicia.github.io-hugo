+++
date = "2018-02-22T00:00:00+09:00"
title = "Vecの実装 in Rust - IntoIter"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/insert_and_remove" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [IntoIter](https://doc.rust-lang.org/nomicon/vec-into-iter.html)

スライスへのderef.を実装したことで、イテレータに関するかなりのメソッドが定義できた。
しかし、標準ライブラリの `Vec` は、他にも有用な種類のイテレータも実装している。
`into_iter()` と `drain()` である。
この記事ではまず `into_iter()` を扱う。

`into_iter()` が返す `IntoIter` は、スライスと違い要素を所有する。
従って `Vec` が持っているメモリ領域の管理を `IntoIter` に移す必要がある。

また、標準ライブラリの [`vec::IntoIter`](https://doc.rust-lang.org/nightly/std/iter/trait.IntoIterator.html) は、
[`DoubleEndedIterator`](https://doc.rust-lang.org/nightly/std/iter/trait.DoubleEndedIterator.html) も実装している。
`DoubleEndedIterator` を実装するには、配列の最後の要素を消費して取り出す `next_back()` を提供しなければならない。
こんなときよく使われる方法が、配列の最初と最後（のひとつ後）を指すポインタをそれぞれ前方・後方イテレータとして用意する方法である。

```
          S  E
[X, X, X, O, X, X, X]
```

`X` はすでに消費した要素、`O` は未消費の要素を表す。
`S (start)`, `E (end)` という二つのポインタで前方・後方イテレータを表す。

そこで、今回実装する `IntoIter` の定義は以下のようになる。
`buf`, `cap`, `alloc` が `Vec` から受け継いだメモリ領域に関するものである。

```rust
use std::heap::Heap;

pub struct IntoIter<T> {
    pub(super) buf: OwnedPtr<T>,
    pub(super) cap: usize,
    pub(super) start: *const T,
    pub(super) end: *const T,
    pub(super) alloc: Heap,
}
```

そして `Vec::into_iter()` は次のように実装できる。
気をつけないといけないのが、`Vec` が確保したメモリ領域を管理する責任は `IntoIter` に移ることである。
従って、`Vec::drop()` が呼ばれないように [`mem::forget()`](https://doc.rust-lang.org/nightly/std/mem/fn.forget.html) を呼ぶ必要がある。

```rust
impl<T> for Vec<T> {
    pub fn into_iter(self) -> IntoIter<T> {
        let Vec {
            ptr: buf,
            cap,
            len,
            alloc,
        } = self;

        // Make sure not to drop Vec since that will free the buffer
        mem::forget(self);

        IntoIter {
            buf,
            cap,
            start: buf.as_ptr(),
            end: if cap == 0 {
                // can't offset off this pointer, it's not allocated!
                buf.as_ptr()
            } else {
                unsafe { buf.as_ptr().offset(len as isize) }
            },
            alloc,
        }
    }
}
```

`IntoIter` に、イテレータの機能を実装していく。
まずは `Iterator` traitを忘れてはいけない。
`Iterator` traitの実装に最低限必要なのは、[`next()`](https://doc.rust-lang.org/nightly/std/iter/trait.Iterator.html#tymethod.next) である。
前方イテレータが指す要素を取り出し、イテレータを進める。
すでに全要素が消費されていたら（`start == end` のとき）`None` を返す。

必須ではないが実装しておくことが望ましいメソッドとして、[`size_hint()`](https://doc.rust-lang.org/nightly/std/iter/trait.Iterator.html#method.size_hint) がある。
イテレータが管理している要素の個数を、最小値と最大値（存在すれば）のペアで返す関数で、正しく実装すれば他の関数が最適化のヒントに用いることができる。
今回は `start` と `end` で挟まれた部分を数えれば、要素数が正しく求まる。

```rust
use std::ptr;
use std::mem;
use std::heap::{Alloc, Heap};

impl<T> Iterator for IntoIter<T> {
    type Item = T;

    fn next(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                let result = ptr::read(self.start);
                self.start = self.start.offset(1);
                Some(result)
            }
        }
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        let len = (self.end as usize - self.start as usize) / mem::size_of::<T>();
        (len, Some(len))
    }
}
```

次に `DoubleEndedIterator` traitを実装する。
必須のメソッドは、後方イテレータ（のひとつ前）が指す要素を取り出しイテレータを（後ろに）進める
[`next_back()`](https://doc.rust-lang.org/nightly/std/iter/trait.DoubleEndedIterator.html#tymethod.next_back) のみである。
`Iterator::next()` と同様に実装すればよい。
デフォルト実装が提供される他のメソッドを自前で実装する必要はなさそうだ。

```rust
impl<T> DoubleEndedIterator for IntoIter<T> {
    fn next_back(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                self.end = self.end.offset(-1);
                Some(ptr::read(self.end))
            }
        }
    }
}
```

忘れてはならないのが、`Drop` を実装し、`Vec` から管理を移したメモリ領域を解放することである。
`Vec` のときは `pop()` によって要素ごとのdropをおこなっていたが、イテレータの場合、すべて走査することで代えることができる。

```rust
impl<T> Drop for IntoIter<T> {
    fn drop(&mut self) {
        if self.cap == 0 {
            return;
        }

        if mem::needs_drop::<T>() {
            for _ in &mut *self {}
        }

        unsafe {
            if self.cap == 1 {
                self.alloc.dealloc_one(self.buf.as_non_null());
            } else {
                let e = self.alloc.dealloc_array(self.buf.as_non_null(), self.cap);
                if let Err(e) = e {
                    self.alloc.oom(e);
                }
            }
        }
    }
}
```
