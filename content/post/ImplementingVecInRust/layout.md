+++
date = "2018-02-20T00:00:00+09:00"
title = "Vecの実装 in Rust - 構造体レイアウト"
tags = ["Programming", "Rust"]
+++

[The Rustnomicon](https://doc.rust-lang.org/nomicon) の [Implementing `Vec`](https://doc.rust-lang.org/nomicon/vec.html) をやってみる。

コード全体は [GitHub上のリポジトリ](https://github.com/ordovicia/rustnomicon_vec.git) にある。

rustcのバージョンは以下のとおり。
このバージョンに基づいて書いていく。

```console
$ rustc --version
rustc 1.25.0-nightly (27a046e93 2018-02-18)
```

## [Subtyping and Variance](https://doc.rust-lang.org/nomicon/subtyping.html)

### 部分型 (subtyping)

"Implementing `Vec`" の最初の節は [Layout](https://doc.rust-lang.org/nomicon/vec-layout.html) だが、
事前知識のため変性 (variance)の節から見ていく。

Rustには [構造的部分型 (structural subtyping)](https://en.wikipedia.org/wiki/Structural_type_system) は存在しないが、lifetimeについて部分型が採用されている。
Lifetime `'a` が `'b` を「含む」あるいは「より長い」ことを意味する `'a: 'b` が成り立っていれば、 `'a` は `'b` の部分型である。
「`'a` が `'b` を含む」のに「部分型である」というのは直感に反するようだが、`'a` は `'b` に暗黙的に変換できる（置換できる）ので部分型だといえる。

### 変性 (variance)

[変性 (variance)](https://en.wikipedia.org/wiki/Covariance_and_contravariance_(computer_science)) は、
型コンストラクタがもつ性質で、引数にとる型やlifetimeの派生関係が、出力される型にどのように伝搬するかを表したもの。
例えば、 `'a: 'b` ならば `&'a T` は `&'b T` に暗黙的に変換できる。
このように半順序が保存されて伝搬するとき、**共変 (variant)** と言う。
これ以外の場合、**非変 (invariant)** と言う [^1]。

`&'a T` は `'a`, `T` どちらについても共変である。
`'a` について共変であることで、`'a: 'b` のとき（`'a` が `'b` より長いとき） `&'a T` が `&'b T` に暗黙的に置き換えられる。

`&'a mut T` は `'a` については共変だが、`T` について非変である。
これにより、ある種のdangling pointerが回避されている。
例として、次のコードを考える。

```rust
fn overwrite<T: Copy>(input: &mut T, new: &mut T) {
    *input = *new;
}

fn main() {
    let mut forever_str: &'static str = "hello";
    {
        let string = String::from("world");
        overwrite(&mut forever_str, &mut &*string);
    }
    // Oops, printing free'd memory
    println!("{}", forever_str);
}
```

`string` のlifetimeを `'s` と名付けることにする。
`&'a T` は `'a` について共変なので、`&'static str` は `&'s str` に置き換えられる。
従って、もし `&mut T` が `T` について共変だったとすると、 `&mut &'static str` は `&mut &'s str` の部分型となる。
すると、`&mut forever_str` は `&mut &*string` と同じ型 `&mut &*string` に暗黙的に変換でき、コード中の `overwrite()` の呼び出しが有効になる。
そして、ブロックを抜けて `string` が破棄されたとき、 `forever_str` はdangling pointerとなる。
つまり、 `&mut T` を `T` について非変にすることで、 `&mut T` のスコープが狭くなりdangling pointerが発生することを防いでいる。

`&'a mut T` と同様に、内部可変性 (interior mutability) をもつ型 `UnsafeCell<T>`, `Cell<T>`, `RefCell<T>`, `Mutex<T>` も `T` について非変となっている。

`Fn(T) -> U` は、 `T` については非変、`U` については共変となっている。
`T` について非変であることにより、例えば `fn f(&'a str s)` が `fn f(&'static str s)` の部分型となる。
もし共変だったとすると、逆に `fn f(&'static str s)` が `fn f(&'a str s)` で置換できることになり、より強いlifetime制約を要求してしまう。
一方、`U` について共変であることにより、例えば `fn f(&'a str) -> &'static str` は `fn f(&'a str) -> &'a str` に変換できる。

## [`PhantomData`](https://doc.rust-lang.org/nomicon/phantom-data.html)

さらに事前知識をおさらいする。

Rustでは、ジェネリックな構造体などの定義における型引数・lifetime引数がフィールドで使われていないとコンパイルエラーになる。
何らかの理由で未使用の引数を定義に含める必要がある場合、`PhantomData` が使われる。

例えば、スライス `&'a [T]` の `Iter` は次のように定義されている。

```rust
use std::marker;

struct Iter<'a, T: 'a> {
    ptr: *const T,
    end: *const T,
    _marker: marker::PhantomData<&'a T>
}
```

（[現在の実装](https://doc.rust-lang.org/nightly/src/core/slice/mod.rs.html#1390-1394) も同様）

`PhantomData` の型引数におくものを注意深く設定することで、`PhantomData` がもつ性質をうまくコントロールできる。
[PhantomDataの使いかたの表](https://doc.rust-lang.org/nomicon/phantom-data.html#table-of-phantomdata-patterns) にまとまっているが、
重要なものを抜粋する。

* `PhantomData<T>`
    * `T` について共変
    * `T` 型の値を所有する
* `PhantomData<fn() -> T>`
    * `T` について共変
    * `T` 型の値を所有しない

## [Layout](https://doc.rust-lang.org/nomicon/vec-layout.html)

やっと "Implementing `Vec`" の最初の節。

`Vec<T>` は「連続領域に確保された、動的に要素数の変わる配列」なので、ナイーブには次のように実装しようと考える。

```rust
pub struct Vec<T> {
    ptr: *mut T,    // pointer to contiguous region elements are stored on
    cap: usize,     // capacity of the region
    len: usize,     // number of elements actually stored
}
```

しかし、この実装には以下の問題がある。

* `Vec<T>` は `T` について共変であるべきだが、`*mut T` は `T` について非変なので、`Vec<T>` も非変になってしまう
    * フィールドが一つでも非変だと構造体全体が非変になる
* `T` 型の値を所有していない

さらに、以下の二点が満たされているとよい。

* `T: Send` なら `Vec<T>: Send` としたい
    * `Sync` についても同様
* `ptr` はnullにならないことを型レベルで保証したい
    * [null-pointer-optimization](https://doc.rust-lang.org/nomicon/repr-rust.html) のため、

そこで、`ptr` として `ptr::NonNull` と `PhantomData` を組み合わせて用いることにする。
[`NonNull`](https://doc.rust-lang.org/nightly/std/ptr/struct.NonNull.html) は1.25.0から安定化される生ポインタのラッパ構造体で、

* `T` について共変
* Nullになってはいけない

という特性をもつ。
`Vec<T>` が要素を所有することを表しdrop checkerを正しく動作させるため、 `PhantomData<T>` を用いる。

```rust
use std::marker::PhantomData;
use std::ptr::NonNull;

pub(crate) struct OwnedPtr<T: ?Sized> {
    ptr: NonNull<T>,
    _marker: PhantomData<T>,
}

unsafe impl<T: ?Sized + Send> Send for OwnedPtr<T> {}
unsafe impl<T: ?Sized + Sync> Sync for OwnedPtr<T> {}

pub struct Vec<T> {
    ptr: OwnedPtr<T>,
    cap: usize,
    len: usize,
}
```

`Vec::new()` の際、空の `Vec` にメモリを割り当てないようにすると、`Vec::ptr` や `OwnedPtr::ptr` はnullになってしまう。
実のところ、`NonNull` がnullになってはいけないという制約は、nullをdereferenceしてはいけないという意味で、deref.しないならnullになること自体は問題ない。
`Vec` の場合、`cap`, `len` のチェックが必要になるので、null pointer deref.の発生は防ぎやすい。
Nullとなっている（がアライメントは整っている） `NonNull` は、
[`NonNull::dangling()`](https://doc.rust-lang.org/nightly/std/ptr/struct.NonNull.html#method.dangling) で作れる。

```rust
impl<T> OwnedPtr<T> {
    pub(crate) fn empty() -> Self {
        OwnedPtr {
            ptr: NonNull::dangling(),
            _marker: PhantomData,
        }
    }
}
```

なお、`NonNull` が持つ特性と `Send`, `Sync`, `T` の所有をすべて備える構造体として、
[`ptr::Unique`](https://doc.rust-lang.org/nightly/std/ptr/struct.Unique.html) があり、現在は使うことができる。
しかし、[`Unique` は `NonNull` に置き換えられ、今後安定化することはない](https://github.com/rust-lang/rust/pull/46952)。

[^1]: この説明はかなり簡略化されたもの。ここでのvariantは実際にはcovariantと呼ばれる。また、半順序が逆向きに伝搬するとき、**反変 (contravariant)** と言う。`fn(T)` は `T` について反変である。
