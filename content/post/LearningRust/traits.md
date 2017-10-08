+++
date = "2015-12-30T12:00:00+09:00"
title = "Learning Rust - Traits"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Traits
Traitは、Haskellでいう型クラスであり、
C++でいうコンセプト(C++14時点では提案のみっぽいですが)です。
ジェネリクスに制限をくわえ、あるメソッドをもった型しか認めないように束縛するのが、traitです。
これによって、ジェネリクス関数やstructがうけとる型に、
そのメソッドが実行できることを保証できます。

### Trait bounds on generic functions
例えば、面積を表示する、以下のジェネリックな関数を作りたいとします。

```rust
fn print_area<T>(shape: T) {
    println!("This shape has an area of {}", shape.area());
}
```

これはコンパイルエラーになります。
`print_area()`関数が受け取る型`T`に、`area()`メソッドが定義されていないからです。
現行のC++では、実際に`print_area()`関数をある型について使ったとき、
それが`area()`メソッドをもたないならエラーになりましたが、
Rustではジェネリクス関数を定義しただけでエラーをおこします。

そこで登場するのがtraitです。
`area()`メソッドをもつことを保証するtraitをつくり、
型`T`を、そのtraitをもつものに制限します。
Syntaxは次のとおりです。

```rust
trait HasArea {
    fn area(&self) -> f64;
}

struct Circle {
    x: f64,
    y: f64,
    radius: f64,
}

impl HasArea for Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * (self.radius * self.radius)
    }
}

fn print_area<T: HasArea>(shape: T) {
    println!("This shape has an area of {}", shape.area());
}
```

`HasArea`traitをつくり、それに`area()`メソッドを含めます。
`print_area()`関数が`Circle`structに適用するため、
`Circle`に`HasArea`traitを実装します。
そして`print_area()`が受け取る型`T`を、`HasArea`traitをもつという条件で束縛します。

ほかのstrctに`HasArea`traitをimplすることもできます。

```rust
struct Square {
    x: f64,
    y: f64,
    side: f64,
}

impl HasArea for Square {
    fn area(&self) -> f64 {
        self.side * self.side
    }
}
```

### Trait bounds on generic structs
ジェネリックなstructについても、traitが使えます。

```rust
struct Rectangle<T> {
    x: T,
    y: T,
    width: T,
    height: T,
}

impl<T: PartialEq> Rectangle<T> {
    fn is_square(&self) -> bool {
        self.width == self.height
    }
}

let mut r = Rectangle {
    x: 0,
    y: 0,
    width: 47,
    height: 47,
};
```

`PartialEq`は標準ライブラリにあるtraitで、
対称律と推移律を満たす関係をもつ型にimplされているようです。
`i32`はこのtraitをもっているので、`Rectangle<i32>`がつくれます。
しかし、`PartialEq`をもっている型に限定しないと、`==`がつかえないのでエラーになります。

## Rules for implementing traits
Traitの作成・使用には、いくつかルールがあります。

まず、他のスコープでつくられたtraitは、明示的に`use`しないと使えません。

```rust
let mut f = std::fs::File::open("foo.txt").ok().expect("Couldn’t open foo.txt");
let buf = b"whatever"; // byte string literal. buf: &[u8; 8]
let result = f.write(buf);
```

これはコンパイルエラーです。
`f.write()`のためには、`f`が`Write`traitをもっている必要があります。

```rust
use std::io::Write;
```

と書いておけばOKです。
知らないところで変なtraitが定義されて、それを使ってしまうのを防ぐための仕様です。

もう一つ、Rustのプリミティブな型に、標準で提供されているtraitをimplすることはできません。
例えば、`i32`に`ToString`をimplすることはできません
(そもそもすでにimplされています)。

## Multiple traits bounds
複数のtraitをもっている型に制限したいときは、`+`で重ねることができます。

```rust
use std::fmt::Debug;

fn foo<T: Clone + Debug>(x: T) {
    x.clone();
    println!("{:?}", x);
}
```

`std::fmt::Debug`traitをもっていると、
`{:?}`というフォーマットですこしくわしい情報が得られるようです。

## Where clause
ジェネリックパラメータが増えたり、multiple traits boundsしたりすると、
`<>`のなかが長くなりがちです。

```rust
use std::fmt::Debug;

fn foo<T: Clone, K: Clone + Debug>(x: T, y: K) {
    x.clone();
    y.clone();
    println!("{:?}", y);
}
```

これくらいだとまだいいですが、これ以上長くなってくると読みにくいですね。
そんなときのために`where`キーワードがあります。

```rust
fn bar<T, K>(x: T, y: K) where T: Clone, K: Clone + Debug {
    x.clone();
    y.clone();
    println!("{:?}", y);
}
```

`where`節をかくと、型制約を引数リストのあとに書くことができます。
関数名と引数が近くなるのでわかりやすいですね。
また、改行をいれたりもできるので、それによっても可読性が上がります。

実は、`where`節でしかかけない型制約があります。
それは、型制約が、型パラメータに直接かかる制約ではなく、
型パラメータへの間接的な制約であるときです。
ことばでいってもわかりにくいので、例を見てみます。

```rust
trait ConvertTo<Output> {
    fn convert(&self) -> Output;
}

impl ConvertTo<i64> for i32 {
    fn convert(&self) -> i64 { *self as i64 }
}

// can be called with T == i32
fn normal<T: ConvertTo<i64>>(x: &T) -> i64 {
    x.convert()
}

// can be called with T == i64
fn inverse<T>() -> T
        // this is using ConvertTo as if it were "ConvertTo<i64>"
        where i32: ConvertTo<T> {
    42.convert()
}
```

`normal()`関数は、`T`が`ConvertTo<i64>`traitをもっていることが型制約ですが、
`inverse()`関数は、`T`に`ConvertTo<T>`できるという、間接的な型制約になっています。

## Default method
Traitがもつメソッドにデフォルト実装を書くことができます。
そのtraitをimplする型でoverrideしない場合、デフォルト実装がつかわれることになります。

```rust
fn main() {
    trait Validation {
        fn is_valid(&self) -> bool { !self.is_invalid() }
        fn is_invalid(&self) -> bool { !self.is_valid() }
    }

    impl Validation for i32 {
        fn is_valid(&self) -> bool {
            *self >= 0
        }
    }

    impl Validation for f64 {
        fn is_invalid(&self) -> bool {
            *self < 0.0
        }
    }

    assert!(1.is_valid());
    assert!((-1).is_invalid());
    assert!((1.1).is_valid());
    assert!((-1.1).is_invalid());
}
```

この例では、`Valiadation`traitのもつメソッドは、お互いの否定をとるような実装になっています。
したがって、`i32`などにimplするとき、
`is_valid()`か`is_invalid()`のどちらか一方のみ実装すれば十分です。

## Inheritance
あるtraitをimplするとき、他のtraitのメソッドが必要になる場合があります。
AというtraitがBというtraitを継承すると、Aをimplする型はBもimplされていることが要請できます。

```rust
fn main() {
    trait Printable : std::fmt::Display {
        fn print(&self) {
            println!("{}", self)
        }
    }

    impl Printable for i32 {}
    1.print();

    struct S;
    impl Printable for S {}
    let s = S;
    s.print();
}
```

この例では、`Printable`traitが`std::fmt::Display`を継承しているので、
`println!("{}", self)`が実行できることが保証されます。

`i32`は`std::fmt::Display`をimplされているので、問題なく`Printable`もimplできます。

一方、struct`S`は`std::fmt::Display`をimplしていないので、`Printable`もimplできません。

## Deriving
基本的には、traitは型ごとにimplしないと使えませんが、
`Debug`とか`Default`とかのよく使う標準ライブラリのtraitをいちいちimplするのは面倒ですね。
そこで、`#[derive(Debug)]`と書くと、自動的にそれがimplされるようになっています。

```rust
#[derive(Debug)]
struct Foo;

fn main() {
    println!("{:?}", Foo);
}
```

ただし、このattributeがつかえるのは、以下のtraitに限られています。

* Clone
* Copy
* Debug
* Default
* Eq
* Hash
* Ord
* PartialEq
* PartialOrd

## Drop
最後に、標準ライブラリにある便利なtraitを紹介しておきます。

`Drop`traitは、C++でいうデストラクタです。
`Drop`をimplした型のVariable bindingがスコープを抜けて破棄されるとき、
`drop()`メソッドが呼ばれます。

```rust
struct HasDrop;

impl Drop for HasDrop {
    fn drop(&mut self) {
        println!("Dropping!");
    }
}

fn main() {
    let x = HasDrop;

    // do stuff

} // x goes out of scope here
```

これを実行すると、プログラムが終了するときに、`Dropping!`と出力されます。

Variable bindingは、宣言と逆順に破棄されていきます。
StackのLIFOということですね。

```rust
struct Firework {
    strength: i32,
}

impl Drop for Firework {
    fn drop(&mut self) {
        println!("BOOM times {}!!!", self.strength);
    }
}

fn main() {
    let firecracker = Firework { strength: 1 };
    let tnt = Firework { strength: 100 };
}
```

`tnt`が`firecracker`より後に宣言されているので、出力は逆順の、

```rust
BOOM times 100!!!
BOOM times 1!!!
```

となります。
