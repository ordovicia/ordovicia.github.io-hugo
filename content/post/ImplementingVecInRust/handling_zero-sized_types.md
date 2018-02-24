+++
date = "2018-02-24T00:00:00+09:00"
title = "Vecの実装 in Rust - Handling Zero-Sized Types"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/drain" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Handling Zero-Sized Types](https://doc.rust-lang.org/nomicon/vec-zsts.html)

最後に、[ZST (Zero Sized Type)](https://doc.rust-lang.org/nomicon/exotic-sizes.html#zero-sized-types-zsts) に対応する。
これに際して、二点考慮する必要がある。

まず、[`heap::Alloc`](https://doc.rust-lang.org/nightly/std/heap/trait.Alloc.html) はZSTを正しく扱えるとは限ず、このtraitを実装する型に依存する。
今回は [`heap::Heap`](https://doc.rust-lang.org/nightly/std/heap/struct.Heap.html) を用いることがわかっているが、あまりドキュメントもないので実装に依存しないことにする。

ZSTに対応するため、`RawVec` に以下の修正を加える。

* `default()` では、キャパシティをはじめから `usize::MAX` に設定してしまう [^1]。
* `grow()` が呼ばれたら `panic!()` する。キャパシティが `usize::MAX` なので、`grow()` が呼ばれるということはそれを超える要素が格納されようとしていることを意味する。
* `drop()` ではメモリ解放しない。

つまり、次のように変更する。

```rust
impl<T> RawVec<T> {
    pub(super) fn default() -> Self {
        // !0 is usize::MAX. This branch should be stripped at compile time.
        let cap = if mem::size_of::<T>() == 0 { !0 } else { 0 };

        RawVec {
            ptr: OwnedPtr::empty(),
            cap: cap,
            alloc: Heap,
        }
    }

    pub(super) fn grow(&mut self) {
        let elem_size = mem::size_of::<T>();

        // since we set the capacity to usize::MAX when elem_size is
        // 0, getting to here necessarily means the Vec is overfull.
        assert!(elem_size != 0, "capacity overflow");

        let (ptr, new_cap) = if self.cap == 0 {
            (self.alloc.alloc_one::<T>(), 1)
        } else {
            let old_num_bytes = self.cap * elem_size;

            ...
        };

        ...
    }
}

impl<T> Drop for RawVec<T> {
    fn drop(&mut self) {
        let elem_size = mem::size_of::<T>();

        // don't free zero-sized allocations, as they were never allocated.
        if self.cap == 0 || elem_size == 0 {
            return;
        }

        ...
    }
}
```

次に考慮する点として、イテレータはこれまでのように `ptr.offset()` でポインタを進めていくわけにはいかない。
サイズがゼロなので、 `ptr.offset()` は何もしない。
そこで、ポインタを `usize` にキャストして整数としてインクリメント・デクリメントしていくことにする。

```rust
impl<T> RawValIter<T> {
    pub(super) unsafe fn new(slice: &[T]) -> Self {
        let start = slice.as_ptr();

        RawValIter {
            start,
            end: if mem::size_of::<T>() == 0 {
                ((start as usize) + slice.len()) as *const _
            } else if slice.is_empty() {
                start
            } else {
                start.offset(slice.len() as isize)
            },
        }
    }
}

impl<T> Iterator for RawValIter<T> {
    type Item = T;
    fn next(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                let result = ptr::read(self.start);
                self.start = if mem::size_of::<T>() == 0 {
                    (self.start as usize + 1) as *const _
                } else {
                    self.start.offset(1)
                };
                Some(result)
            }
        }
    }

    ...
}

impl<T> DoubleEndedIterator for RawValIter<T> {
    fn next_back(&mut self) -> Option<T> {
        if self.start == self.end {
            None
        } else {
            unsafe {
                self.end = if mem::size_of::<T>() == 0 {
                    (self.end as usize - 1) as *const _
                } else {
                    self.end.offset(-1)
                };
                Some(ptr::read(self.end))
            }
        }
    }
}
```

最後に、`Iterator::size_hint()` を修正する。
要素のサイズでイテレータの差を割るので、ZSTではゼロで割ることになってしまう。

```rust
impl<T> Iterator for RawValIter<T> {
    ...

    fn size_hint(&self) -> (usize, Option<usize>) {
        let elem_size = mem::size_of::<T>();
        let len = (self.end as usize - self.start as usize)
                  / if elem_size == 0 { 1 } else { elem_size };
        (len, Some(len))
    }
}
```

[^1]: Rustnomiconでも [標準ライブラリの `RawVec`](https://doc.rust-lang.org/nightly/src/alloc/raw_vec.rs.html#53) でも、`usize::MAX` を表すのに `!0` としているが、はじめから `usize::MAX` にすればいいのでは......？
