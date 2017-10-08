+++
date = "2016-01-03T12:00:00+09:00"
title = "Learning Rust - Operators and Overloading"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Operators and Overloading
Rustには一般的な関数のoverload機能はありませんが、
いくつかの演算子はoverloadすることができます。
演算子のoverloadは、traitの実装によって実現します。

```rust
use std::ops::Add;

#[derive(Debug)]
struct Point {
    x: i32,
    y: i32,
}

impl Add for Point {
    type Output = Point;

    fn add(self, other: Point) -> Point {
        Point { x: self.x + other.x, y: self.y + other.y }
    }
}

fn main() {
    let p1 = Point { x: 1, y: 0 };
    let p2 = Point { x: 2, y: 3 };

    let p3 = p1 + p2;

    println!("{:?}", p3);
}
```

Overloadできる演算子は`std::ops`に定義されています。
たとえば加算`+`演算子をoverloadしたいときは、`Add`traitの`add()`関数を実装します。

他に、減算`-`をoverloadするときは、`Sub`traitの`sub()`関数を実装します。

```rust
impl Sub for Point {
    type Output = Point;

    fn sub(self, other: Point) -> Point {
        Point {x: self.x - other.x, y: self.y - other.y}
    }
}

let p4 = p1 - p2;

println!("{:?}", p4);
```

`Add`traitについて詳しく見てみましょう。
定義は次のようになっています。

```rust
pub trait Add<RHS = Self> {
    type Output;

    fn add(self, rhs: RHS) -> Self::Output;
}
```

右辺は型パラメータ`RHS`になっています。
デフォルト値が自分自身なので、`Point`に`Point`を足す例だと型パラメータを省略できます。
計算した結果の型は、associated typeである`Output`に指定します。

よって、`Point`に`i32`を足して`f64`を返す関数は、次のようになります。

```rust
impl Add<i32> for Point {
    type Output = f64;

    fn add(self, rhs: i32) -> f64 {
        //
    }
}
```

## Using operator traits in generic structs
以前traitを学んだときに、
`Square`というstructに`HasArea`traitをimplして面積を求める関数を実装しました。
その時は`Square`の要素は`f64`だったりしたのですが、
もっとジェネリックな`Square`にしてみます。

このとき、`Square`の内部型`T`に対して掛け算をおこなって面積を計算しますが、
`T`に乗算演算子`*`が使える必要があります。
そこで`T`が`Mul<Output = T>`traitを持っている制約をかけます。

つまりコードは次のようになります。

```rust
use std::ops::Mul;

trait HasArea<T> {
    fn area(&self) -> T;
}

struct Square<T> {
    x: T,
    y: T,
    side: T,
}

impl<T> HasArea<T> for Square<T>
        where T: Mul<Output = T> + Copy {
    fn area(&self) -> T {
        self.side * self.side
    }
}

fn main() {
    let s = Square {
        x: 0.0f64,
        y: 0.0f64,
        side: 12.0f64,
    };

    println!("Area of s: {}", s.area());
}
```
