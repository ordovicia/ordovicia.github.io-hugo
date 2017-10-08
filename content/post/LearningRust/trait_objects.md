+++
date = "2016-01-01T12:00:00+09:00"
title = "Learning Rust - Trait Objects"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Trait objects
関数に多相性をもたせるときは、実際にその関数はなんの型について実行されているのか判定され、
適切なバージョンの関数が呼ばれなければいけません。
この、判定と分岐はdispatchと呼ばれ、2種類あります。
ひとつは静的なdispatch、もうひとつは動的なdispatchです。

安全性を大事にするRustに合っているのは静的なdispatchのほうですが、
動的なdispatchのほうも、`trait objects`という機能によってサポートされています。

## Background
今後の例では、次のようなtraitとメソッドをつかいます。
`Foo`traitのメソッド`method()`は`String`を返すもので、
これを`u8`と`String`にimplしておきます。

```rust
trait Foo {
    fn method(&self) -> String;
}

impl Foo for u8 {
    fn method(&self) -> String { format!("u8: {}", *self) }
}

impl Foo for String {
    fn method(&self) -> String { format!("string: {}", *self) }
}
```

## Static dispatch
まずは静的ディスパッチのおさらいをしましょう。
例えば、さきほどの`Foo`traitをつかうジェネリックな関数`do_something()`があったとします。

```rust
fn do_something<T: Foo>(x: T) {
    x.method();
}

fn main() {
    let x = 5u8;
    let y = "Hello".to_string();

    do_something(x);
    do_something(y);
}
```

静的ディスパッチによって、`do_something()`の`u8`版と`String`版が別々につくられます。
つまり、次のような置き換えが起こるということです。

```rust
fn do_something_u8(x: u8) {
    x.method();
}

fn do_something_string(x: String) {
    x.method();
}

fn main() {
    let x = 5u8;
    let y = "Hello".to_string();

    do_something_u8(x);
    do_something_string(y);
}
```

静的ディスパッチは、関数のinline展開やその他の最適化がしやすく、コードが高速化できます。
その一方で、関数の同じようなコピーがたくさん作られ、
実行バイナリの肥大化を招くという問題もあります。

## Dynamic dispatch
Rustは'trait objects'という機能によって、動的ディスパッチを実現しています。
Trait objectは`&Foo`や`Box<Foo>`と表され、`Foo`traitをもつどんな型も入れることができ、
実際にどの型がはいっているかは実行時にのみ決まります。

Trait objectは、`&x as &Foo`のようなキャストや、
`&x`を`&Foo`型の引数としてうけとることで得られます。

```rust
fn do_something(x: &Foo) {
    x.method();
}

fn main() {
    let x = 5u8;
    do_something(&x as &Foo);

    let y = "Hello".to_string();
    do_something(&y);
}
```

動的ディスパッチを採用すると、実行ファイルの肥大化は防げます。
しかし、仮想関数呼び出しのオーバーヘッドがかかったり、最適化ができなくなったりします。

## Why pointers? / Representation
よくわかりませんでした。

Trait objectはなぜポインタで表現しているのかという話だと思います。
どんな型でもポインタならサイズが同じなので、動的ディスパッチできるということでしょう。
C++のアップキャストとたぶん同じです。

また、trait objectは、キャスト前の値のポインタと、
それに対応するメソッドのポインタをもつ構造体のようです。
つまりこういうのですね。

```rust
pub struct TraitObject {
    pub data: *mut (),
    pub vtable: *mut (),
}
```

`*mut`というのは生ポインタのようです。
たぶん普通は使いません。
vtableをもっているのもC++と同じでしょう。

## Object safety
Trait objectに変換できるtraitには、'Object safety'と呼ばれる制限があるようです。
詳しい定義は難しかったのですが、

> A good intuition is “except in special circumstances,
  if your trait’s method uses Self, it is not object-safe.”

と公式ドキュメントに書いてある通り、traitがもつメソッドが`Self`(自分自身の型?)を使う場合、
そのtraitはobject-safeではない、と考えておけばよさそうです。
たとえば、`Clone`traitは

```rust
pub trait Clone {
    fn clone(&self) -> Self;

    fn clone_from(&mut self, source: &Self) { ... }
}
```

のように、`Self`を使うメソッドをもつので、`Clone`のtrait objectに変換することはできません。

```rust
let v = vec![1, 2, 3];
let o = &v as &Clone; // Error
```
