+++
date = "2018-02-21T00:00:00+09:00"
title = "Vecの実装 in Rust - Push & Pop"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/allocating_memory" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Push and Pop](https://doc.rust-lang.org/nomicon/vec-push-pop.html)

メモリ確保ができるようになったので、push, popを実装する。

便利メソッドとして `OwnedPtr` から `*mut T` を取り出す関数を作っておく。

```rust
impl<T: ?Sized> OwnedPtr<T> {
    pub(crate) fn as_ptr(&self) -> *mut T {
        self.ptr.as_ptr()
    }
}
```

まずは `Vec::push()` だが、素直に実装すればよい。
確保したメモリ領域が足りなくなったら伸ばし、`ptr::write()` で要素を書き込む。
書き込むアドレスは、`OwnedPtr` から取り出した `*mut T` に `self.len` だけオフセットを加えたものとする。
`ptr::write()` 時にpanicした場合を考慮して、`self.len` のインクリメントは最後におこなう。

```rust
impl<T> Vec<T> {
    pub fn push(&mut self, elem: T) {
        if self.len == self.cap {
            self.grow();
        }

        unsafe {
            let ptr_last = self.ptr.as_ptr().offset(self.len as isize);
            ptr::write(ptr_last, elem);
        }

        self.len += 1;
    }
}
```

`Vec::pop()` も同様に、`ptr::read()` を使い実装する。
読み込むアドレスは、`OwnedPtr` から取り出した `*mut T` に `self.len` だけオフセットを加えたものとする。

```rust
impl<T> Vec<T> {
    pub fn pop(&mut self) -> Option<T> {
        if self.len == 0 {
            None
        } else {
            self.len -= 1;

            unsafe {
                let ptr_last = self.ptr.as_ptr().offset(self.len as isize);
                Some(ptr::read(ptr_last))
            }
        }
    }
}
```

簡単なテストを書き、動作確認しておく。

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn push_pop() {
        let mut v = Vec::new();

        const ELEM_NUM: usize = 32;
        let elems = 0..ELEM_NUM;

        for (i, e) in elems.clone().enumerate() {
            v.push(e);
            assert_eq!(v.len(), i + 1);
        }

        for (i, e) in elems.rev().enumerate() {
            let p = v.pop();
            assert!(p.is_some() && p.unwrap() == e);
            assert_eq!(v.len(), ELEM_NUM - 1 - i);
        }
    }
}
```
