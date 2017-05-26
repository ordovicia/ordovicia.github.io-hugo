+++
date = "2015-12-23"
title = "Learning Rust - Method Syntax"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Method syntax
Rustでのメソッドのsyntaxについて学びます。

まず、Rustにはclassはありません。
が、オブジェクト指向プログラミングは簡単に実現できます。
Structに`impl`キーワードでメソッドを追加していくことで、
structのオブジェクトにメソッドを持たせることができます。

```rust
struct Circle {
    x: f64,
    y: f64,
    radius: f64,
}

impl Circle {
    fn area(&self) -> f64 {
        std::f64::consts::PI * (self.radius * self.radius)
    }
}

fn main() {
    let c = Circle { x: 0.0, y: 0.0, radius: 2.0 };
    println!("{}", c.area());
}
```

`impl`するメソッドの第一引数には、
`self, &self, &mut self`のどれかを指定します。

Structの定義とメソッドが分離されているので、
メソッドの追加がしやすかったりするのでしょうか。

### Chaining method calls
もちろんメソッドをつなげることもできます。

```rust
impl Circle {
    fn grow(&self, increment: f64) -> Circle {
        Circle { x: self.x, y: self.y, radius: self.radius + increment }
    }
}

fn main() {}
    let d = c.grow(2.0).area();
    println!("{}", d);
}
```

### Associated functions
C++でいうstaticメンバ関数もつくれます。
Rustではassociated functionと呼ばれるようです。

```rust
impl Circle {
    fn new(x: f64, y: f64: radius: f64) -> Circle {
        Circle {
            x: x,
            y: y,
            radius: radius,
        }
    }
}

fn main() {
    let c = Circle::new(0.0, 0.0, 2.0);
}
```
