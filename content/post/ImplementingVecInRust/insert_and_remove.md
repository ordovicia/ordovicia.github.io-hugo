+++
date = "2018-02-21T00:00:03+09:00"
title = "Vecの実装 in Rust - Insert & Remove"
tags = ["Programming", "Rust"]
+++

[前回]({{< ref "post/ImplementingVecInRust/deref" >}}) に引き続き、
[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Insert and Remove](https://doc.rust-lang.org/nomicon/vec-insert-remove.html)

スライスへのderef.で提供されないメソッドとして、例えば `insert()` や `remove()` がある。
これらを追加する。

まず `Vec::insert()` である。
この関数は、要素を指定したインデックスに挿入する。
指定したインデックスと、それより右にあった要素は右にシフトされる。
インデックスが `len` を越えていたら `panic!()` する。

実装は以下のようになる。
インデックスの範囲チェック後、確保したメモリが足りなければ再確保する。
`index < self.len` のとき（つまり、`index == self.len` でないとき）は、もともとあった要素のシフトが必要になる。
この操作は [`ptr::copy()`](https://github.com/rust-lang/rust/blob/27a046e9338fb0455c33b13e8fe28da78212dedc/src/libcore/intrinsics.rs#L1033) でできる。
`ptr::copy()` はC言語でいう `memmove` で、アドレスからアドレスへ指定要素だけその中身をコピーする。
コピー元・先で領域がオーバーラップしていても正しく扱ってくれる。
もともとあった要素をシフトした後は、挿入する要素をメモリに書き込み、`len` をインクリメントして終了である。

```rust
impl<T> Vec<T> {
    pub fn insert(&mut self, index: usize, elem: T) {
        assert!(index <= self.len, "index out of bounds");

        if self.len == self.cap {
            self.grow();
        }

        unsafe {
            if index < self.len {
                ptr::copy(
                    self.ptr.as_ptr().offset(index as isize),
                    self.ptr.as_ptr().offset(index as isize + 1),
                    self.len - index,
                );
            }

            ptr::write(self.ptr.as_ptr().offset(index as isize), elem);
        }

        self.len += 1;
    }
```

次に `Vec::remove()` を実装する。
`insert()` とは逆に、指定したインデックスの要素を削除し返す。
もともとあった要素は左にシフトされる。
`insert()` と同じように、素直に実装すればよい。

```rust
impl<T> Vec<T> {
    pub fn remove(&mut self, index: usize) -> T {
        assert!(index < self.len, "index out of bounds");

        self.len -= 1;

        unsafe {
            let result = ptr::read(self.ptr.as_ptr().offset(index as isize));
            ptr::copy(
                self.ptr.as_ptr().offset(index as isize + 1),
                self.ptr.as_ptr().offset(index as isize),
                self.len - index,
            );
            result
        }
    }
}
```
