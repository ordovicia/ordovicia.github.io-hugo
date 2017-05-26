+++
date = "2015-12-25"
title = "Learning Rust - Generics"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
今回はRustのジェネリクスのはなしです。
ジェネリクスがでてくると、佳境に入った気がしますね。

私はC++でテンプレートに慣れているので、
Rustのジェネリクスもスムーズに学べました。

## Generics
Rustの標準ライブラリには、たとえば`Option<T>`という型があります。
ある正常な値をもっているか、あるいは不正かの情報をもち、
`Option<T>`をつかうとエラー処理に統一感がでます。

```rust
enum Option<T> {
    Some(T),
    None,
}

let x: Option<i32> = Some(5);
```

`<T>`がジェネリクスを表しています。
このenumはいろんな型`T`のバージョンをつくることができるというわけです。
正常な値をあらわす`Some`に、おなじ`T`型の値をいれます。

標準ライブラリに、他には`Result<T, E>`という型もあります。
これは`Option<T>`に使う場面が似ていますが、
エラーだった場合の情報を増やすために、エラーを表すstructが、
単なるunit-like structではなく、tuple structになっています。

```rust
enum Result<T, E> {
    Ok(T),
    Err(E),
}
```

このように、二つ以上のパラメータをもったジェネリクス型もつくれます。

### Generic functions
Enumだけでなく、ジェネリックな関数もつくれます。
Syntaxは以下です。

```rust
fn takes_anything<T>(x: T) {
    // do something with x
}
```

もちろん複数の引数をとったり、パラメータが複数になったりもできます。

```rust
fn takes_two_of_the_same_things<T>(x: T, y: T) {
    // ...
}

fn takes_two_things<T, U>(x: T, y: U) {
    // ...
}
```

ジェネリックな関数を呼ぶときは、型は推論されるようです。

```rust
fn main() {
    trait Printable {
        fn print(&self);
    }

    impl Printable for i32 {
        fn print(&self) {
            println!("{}", self);
        }
    }

    impl Printable for f64 {
        fn print(&self) {
            println!("{}", self);
        }
    }

    fn takes_anything<T: Printable>(x: T) {
        x.print();
    }

    takes_anything(1);
    takes_anything(1.0);
}
```

ただし、実際によぶときは多くの場合、
上のコードのようにtraitの定義が必要でしょう。
Traitについては次回に紹介します。

### Generic structs
さらにstructもジェネリクスが可能です。

```rust
struct Point<T> {
    x: T,
    y: T,
}

let int_origin = Point { x: 0, y: 0 };
let float_origin = Point { x: 0.0, y: 0.0 };
```

これもパラメータは推論されるようですね。

メソッドを定義するときは、`impl<T>`と書きます。

```rust
impl<T> Point<T> {
    fn swap(&mut self) {
        std::mem::swap(&mut self.x, &mut self.y);
    }
}
```

---

ジェネリクスは強力で、なくてはならない機能ですが、
一方であらゆる型を受け入れたりすると、すぐに「爆発」してしまいます。
C++で、とんでもなく長くわかりにくい、
テンプレートのエラーメッセージに遭遇したかたも多いでしょう。

これを防ぐため、ジェネリクスが受け取れる型になんらかの条件を設定するのが、
次回扱うtraitです。
