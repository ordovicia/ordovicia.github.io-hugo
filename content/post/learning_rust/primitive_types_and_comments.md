+++
date = "2015-11-12"
title = "Learning Rust - Primitive Types and Comments"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
前々回につづけて、
[syntaxとsemanticsのドキュメント](https://doc.rust-lang.org/book/syntax-and-semantics.html)
を読んでいきます。

## Primitive Types
組み込み型の紹介です。
よくある型に加えて、Rustでは`Slice`や`Tuple`もprimitiveです。

### Boolean
`bool`ですね。`true`または`false`の値があります。

### `char`
文字一つをあらわします。
中身は4byteのUnicodeスカラ値で、

```rust
let two_hearts = '💕';
```

のようなこともできるそうです。

### Numeric types
数値型です。まず列挙すると、

* `i8`
* `i16`
* `i32`
* `i64`
* `u8`
* `u16`
* `u32`
* `u64`
* `isize`
* `usize`
* `f32`
* `f64`

があります。
`i, u, f`のprefixが種類を表し、それぞれ符号付き整数、符号なし整数、浮動小数点となっているようです。
そして数値がサイズを表しています。
例えば`i32`は符号付き32btit整数で、`u64`は符号なし64bit整数です。
整数型にサイズが決まっているのは移植性が高くて好印象です。

Rustの型推論では、整数リテラルは`i32`、小数リテラルは`f64`と推定されるそうです。

`isize, usize`が気になります。
これは実行マシンのアドレスとおなじサイズをもつ整数型だそうです。

### Arrays
配列もあります。型は`[Type; Size]`と表します。例えば以下です。

```rust
let ary = [1, 2, 3]; // a: [i32; 3]
```

ジェネリクスによって、`Type`にはいろんな型がはいります。
要素数である`Size`はコンパイル時定数である必要があるそうです。

すべての要素に同じ値を代入して初期化することもできます。
例えば次のようにすると`ary`は20要素をもち、すべて0で初期化されます。

```rust
let ary = [0; 20]; // a: [i32; 20]
```

要素数を得るには`ary.len()`のように`len()`関数をつかい、
各要素にアクセスするには`ary[0]`のようにします。indexは0-basedです。

```rust
let names = ["Graydon", "Brian", "Niko"]; // names: [&str; 3]
println!("There are {} names. The second name is: {}", names.len(), names[1]);
```

要素アクセスの際、indexが有効かどうかは実行時にチェックされます。
範囲外参照をしていた場合、実行時エラーとなります。

### Slices
`Slice`は連続して配置されているデータ構造への参照です。
内部にポインタと長さをもっているようです。

```rust
let a = [0, 1, 2, 3, 4];
let middle = &a[1..4]; // 1, 2, and 3
let complete = &a[..]; // all of the elements in a
let str_slice: &[&str] = &["one", "two", "three"];
```

`&array[begin..end]`のように書くようですね。
範囲は[begin, end)になります。
また、`&array[..]`と書くとすべての要素をとります。

vectorにも使えます。

```rust
let vec = vec![1, 2, 3];
let int_slice = &vec[..];
```

参照先はmutableにすることもでき、型を`&mut [T]`と表します。

```rust
let xs: &mut [i32] = &mut [1, 2, 3];
xs[1] = 7;
```

### `str`
Rustの文字列はなんだか特殊なようです。
ドキュメントを引用すると、

> Rust’s str type is the most primitive string type. As an unsized type, it’s not very useful by itself, but becomes useful when placed behind a reference, like &str.

とあります。ほとんどの場合は参照、つまり`&str`のかたちで使うようですね。
もっと詳しいリファレンスを読んでもいいのですが、まだ知らない概念がいくつも登場してきたので深追いはやめておきます。

### Tuples
`Tuple`は型の直積です。`(Type0, Type1, .., TypeN)`と表します。

```rust
let mut x: (i32, &str) = (1, "hello");
let y = (2, "world");
x = y;
```

次のように書くと各要素に名前をつけることができます。

```rust
let (x, y, z) = (1, 2, 3);
println!("x is {}", x);
```

let statementにはpatternが渡せるのでしたね。

でも、この例は`Tuple`の型といえるのでしょうか？
`(x, y, z)`は`Tuple`として作られているのでしょうか？

サイズが一つだけの`Tuple`には注意が必要です。
`(0)`はただ0をかっこで囲んだだけです。
`Tuple`にするには、`(0,)`のようにコンマ`,`が必要になります。
ちょっと気持ち悪い記法ですが、仕方ないのでしょう。

#### Tuple indexing
`Tuple`の各要素にアクセスするには、

```rust
let tuple = (1, 2, 3);

let x = tuple.0;
let y = tuple.1;
let z = tuple.2;

println!("x is {}", x);
```

のように、ドット`.`に続けてindexを数値で書きます。
配列の`[]`とは違うようです。

### Functions
関数も型を持ちます。
[Function Pointer](http://hadeaneon.hatenablog.com/entry/2015/11/09/081819)
の節で扱ったとおりです。

```rust
fn add_one(x: i32) -> i32 {
    x + 1
}

let x: fn(i32) -> i32 = foo;
```

## Comments
C++と同じように、`//`を書くと、そこから行末までがコメントになります。
また、`/* */`によるブロックコメントもあります。
`/* */`は入れ子にすることもできるようです。
うれしいですね。

また、Rustには'doc comments'というものがあります。
例えば、

```rust
/// Adds one to the number given.
///
/// # Examples
///
/// ```
/// let five = 5;
///
/// assert_eq!(6, add_one(5));
/// # fn add_one(x: i32) -> i32 {
/// #     x + 1
/// # }
/// ```
fn add_one(x: i32) -> i32 {
    x + 1
}
```

のように`///`を書くと、それに続くコード片のドキュメントになります。
また、`//!`と書くと、続くコード片ではなくそのファイルの内容に対するドキュメントになるようです。
doc commentsにはMarkdown記法がつかえ、`rustdoc`というツールでHTMLに変換できるそうです。
しかもdoc commentsに書いたコード例を実行することもできるそうです。
これは便利ですね。

ところで、上のdoc commentsには`assert_eq!()`が登場しています。
予想できる通り、このmacroは二つの引数が等しいかチェックして、等しくなければその場で`panic!()`します。
また引数が`true`かチェックする`assert!()`ももちろんあります。

---

キリがいいので今回はここまでです。
次回のRustは条件分岐とループを扱います。
