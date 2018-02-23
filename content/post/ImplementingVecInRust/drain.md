+++
date = "2018-02-23T00:00:01+09:00"
title = "Vecの実装 in Rust - Drain"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/raw_vec" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Drain](https://doc.rust-lang.org/nomicon/vec-drain.html)

`IntoIter` に続く有用なイテレータとして、`Drain` を実装する。
`Drain` はおよそ `IntoIter` と同じだが、`Vec` の要素を消費せず借用して取り出し、メモリ領域の管理は移さない。
[標準ライブラリの `vec::Drain`](https://doc.rust-lang.org/nightly/std/vec/struct.Drain.html) は取り出す要素をrangeで指定でき、一部だけ取り出すこともできる。
今回は簡単に、開始位置だけ指定でき、そこから最後の要素までを取り出すバージョンを書いてみる [^1]。

まず、`Drain` 構造体の定義を考える。
`IntoIter` と同じく、`Iterator` と `DoubleEndedIterator` を `Drain` に実装したいので、前方・後方イテレータを用いる実装がよさそうだ。
そうすると、`IntoIter` の実装とかぶる部分がでてくるので、この部分を切り出し抽象的なイテレータ構造を定義できそうだと考える。

```rust
pub(super) struct RawValIter<T> {
    start: *const T,
    end: *const T,
}

impl<T> RawValIter<T> {
    pub(super) unsafe fn new(slice: &[T]) -> Self {
        let start = slice.as_ptr();

        RawValIter {
            start,
            end: if slice.len() == 0 {
                start
            } else {
                start.offset(slice.len() as isize)
            },
        }
    }
}
```

前方・後方イテレータをもつ抽象的なイテレータ構造ができた。
`new()` がunsafeなのは、スライスから生ポインタを取り出すことでlifetimeの情報が失われるためである。
あとで `RawValIter` を `RawVec` と同じ構造体に入れるので、lifetime情報を付与したままにはできない。

`RawValIter` に実装する `Iterator` と `DoubleEndedIterator` は、 `IntoIter` に定義したものと同様に定義しておく。

`RawValIter` を用いて、`IntoIter` および `Vec::into_iter()` は次のように修正できる。
`Iterator`, `DoubleEndedIterator` の実装は、内部に持つ `RawValIter` の実装に委任できる。

```rust
pub struct IntoIter<T> {
    _buf: RawVec<T>,
    iter: RawValIter<T>,
}

impl<T> Iterator for IntoIter<T> {
    type Item = T;

    fn next(&mut self) -> Option<T> {
        self.iter.next()
    }

    fn size_hint(&self) -> (usize, Option<usize>) {
        self.iter.size_hint()
    }
}

impl<T> DoubleEndedIterator for IntoIter<T> {
    fn next_back(&mut self) -> Option<T> {
        self.iter.next_back()
    }
}

impl<T> IntoIter<T> {
    pub(super) fn new(buf: RawVec<T>, iter: RawValIter<T>) -> Self {
        IntoIter { _buf: buf, iter }
    }
}
```

```rust
impl<T> for Vec<T> {
    pub fn into_iter(self) -> IntoIter<T> {
        unsafe {
            let iter = RawValIter::new(&self);

            let buf = ptr::read(&self.buf);
            mem::forget(self);

            IntoIter::new(buf, iter)
        }
    }
}
```

`Drain` を実装する。
`Vec` から要素を借用するのでlifetime引数をとるが、定義には現れないので `PhantomData` を用いる。

```rust
use std::marker::PhantomData;

pub struct Drain<'a, T: 'a> {
    // Need to bound the lifetime here, so we do it with `&'a mut Vec<T>`
    // because that's semantically what we contain. We're "just" calling
    // `pop()` and `remove(0)`.
    _vec: PhantomData<&'a mut Vec<T>>,
    iter: RawValIter<T>,
}

impl<'a, T> Drop for Drain<'a, T> {
    fn drop(&mut self) {
        for _ in &mut self.iter {}
    }
}

impl<'a, T> Drain<'a, T> {
    pub(super) fn new(iter: RawValIter<T>) -> Self {
        Drain {
            _vec: PhantomData,
            iter,
        }
    }
}
```

`Vec::drain()` は次のように書ける。

```rust
impl<T> Vec<T> {
    pub fn drain(&mut self, start: usize) -> Drain<T> {
        assert!(start < len);

        unsafe {
            let iter = RawValIter::new(&self[start..]);
            self.len = start;
            Drain::new(iter)
        }
    }
}
```

簡単なテストを書き動作確認する。

```rust
#![feature(crate_in_paths)] // in lib.rs

#[cfg(test)]
mod tests {
    use crate::vec::Vec;

    #[test]
    fn drain() {
        let mut v = Vec::default();
        v.push(0);
        v.push(1);

        {
            let mut drain = v.drain(1);
            assert_eq!(drain.next(), Some(1));
            assert_eq!(drain.next(), None);
        }

        assert_eq!(v.len(), 1);

        let mut iter = v.into_iter();
        assert_eq!(iter.next(), Some(0));
        assert_eq!(iter.next(), None);
    }
}
```

[^1]: Rustnomiconでは全範囲を取り出すバージョンを書いているが、それではあまりに単純すぎる。
