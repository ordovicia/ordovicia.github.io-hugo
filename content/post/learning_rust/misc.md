+++
date = "2016-01-02T12:00:00+09:00"
title = "Learning Rust - Misc."
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
Rustのsyntaxとsemanticsについて、いくつか細かい事項をまとめて紹介します。

## `const` and `static`
Const変数とstatic変数は、定数を記述するためのものです。
`let`でも`mut`をつけなければ定数ですが、const, static変数はグローバルに宣言できます。

### `const`
`const`は、コンパイル時定数です。

```rust
const N: i32 = 5;
```

`let`と違って、型を明示する必要があります。
Constな変数は、それを使うところにinline展開されます。
つまり、`N`はすべて`5`に置き換えられるということです。
よって、constな変数はメモリ上に配置されたりしません。

一方、`static`はメモリ上に置かれ、`'static lifetime`をもちます。
よって、static変数へのアクセスは、すべておなじメモリ上の値へのアクセスになります。

あたり前のことですが、const, static変数ともに、初期値が必要です。
実は、static変数は`mut`をつければmutableになります。
ただし、mutableなstatic変数へのアクセスは安全性が保証されないので、
`unsafe`ブロック内でおこなう必要があります。
使わないに越したことはない、ということですね。

定数を使いたいほとんどの場合は`const`を使っておくのがよさそうです。

## Attributes
これまでも`#[derive(Debug)]`とかが登場していましたが、これを'attribute'といいます。
コードになんらかの性質をもたせるものです。

Attributeの書きかたには二種類あり、

```rust
#[foo]
struct Foo;

mod bar {
    #![bar]
}
```

のように、`!`をつけない`#[foo]`と、つける`#![bar]`があります。
`!`をつけないほうは、そのattributeの直後のものについて作用するのに対し、
`!`をつけるほうは、そのattributeがかかれているもの(ここでは`mod bar`)について作用します。
違いはこれだけです。

どんなattributeがあるのかというと、たとえば

```rust
#[test]
fn check() {
    assert_eq!(2, 1 + 1);
}
```

というのがあります。
関数に`#[test]`attributeをつけると、その関数はテスト用の関数となり、
テスト時に実行されます。

他には、inline展開を指定する(もっともinline展開の判断はコンパイラに任せるべきですが)

```rust
#[inline(always)]
fn super_fast_fn() {
```

や、コンパイル条件を設定する

```rust
#[cfg(target_os = "macos")]
mod macos_only {
```

というのがあります。
ほかのattributeについては、
[公式リファレンス](https://doc.rust-lang.org/stable/reference.html#attributes)
を読むのがいいでしょう。

## `type` aliases
`type`は型に別名をつけるものです。
C++でいうusingエイリアスです。
以下のように使います。

```rust
type Name = String;

let x: Name = "Hello".to_string();
```

似たようなものに、要素が一つのtuple structがありました。
要素が一つのtuple structは、別の型をつくった(newtype)のに対し、
`type`エイリアスはただの別名です。

## Casting Between Types
Rustは強い静的型付き言語ですが、型変換もできます。
方法は二通りあります。

### `as`
`as`キーワードをつかうと、ちゃんと型変換できるかコンパイラがチェックしてくれて、
安全にキャストできます。

```rust
let x: i32 = 5;
let y = x as i64;
```

### `transmute`
`transmute`は、型チェックせず、bit列をほかの型として解釈し直します。
`unsafe`ブロック内でしか使えません。
危険なのでできるだけ使いたくないものです。

たとえば、8bit x 4つの配列をu32に解釈しなおすコードは次のようになります。

```rust
use std::mem;

unsafe {
    let a = [0u8, 0u8, 0u8, 0u8];
    let b = mem::transmute::<[u8; 4], u32>(a);
}
```

`transmute`をつかっても、サイズのチェックくらいはしてくれるそうです。
たとえば先ほどの配列`a`を`u64`に`transmute`することはできません。

## Unsized Types
Rustではほとんどの型はサイズがコンパイル時にわかっています。
例えば`i32`は32bitという具合です。

しかし、いくつか可変長な型もあります。
そのひとつが`[T]`で、これは`T`型がいくつか並んだものです(固定長配列`[T; N]`とは違います)。
メモリ上の連続した領域に配置されているようです。

安全なプログラムを目指すため、Rustで可変長型をつかう際には制限があります。

* 可変長型の操作はすべてポインタを通しておこないます。
  つまり`[T]`ではなく`&[T]`です。
* Variableや引数には使えません。
* Structの要素に含めるときは、最後のフィールドでなければなりません。
* Enumは可変長型を要素にもてません。

### `?Sized`
ジェネリックなstructや関数をつくると、
型パラメータには暗黙的に、`Sized`trait制約がつきます。
そのため、`Sized`traitをもっていない型を受け付けることはできません。

この制約を外すのが`?Sized`です。

```rust
struct Foo<T: ?Sized> {
    f: T,
}
```

上のように、`?Sized`という(擬似？)traitを要求しておくと、
`Sized`でないものも`T`とすることができます。
