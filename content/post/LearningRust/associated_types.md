+++
date = "2016-01-02T13:00:00+09:00"
title = "Learning Rust - Associated Types"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Associated Types
いきなりですが、抽象的なグラフに関するtraitを作りたいとします。
例えば以下のように書きますよね。
`N`がnode, `E`がedgeです。

```rust
trait Graph<N, E> {
    fn has_edge(&self, &N, &N) -> bool;
    fn edges(&self, &N) -> Vec<E>;
    // etc
}
```

で、`Graph`を受け取る関数を作ります(Traitに含めてもいいんですが、それはおいといて)。
Node間の距離を計算する関数です。

```rust
fn distance<N, E, G: Graph<N, E>>(graph: &G, start: &N, end: &N) -> u32 {
    //
}
```

このように、シグネチャに`N, E`が何度も登場します。
`Graph`の型がわかれば`N, E`もわかるので、これは無駄っぽいですね。

そこで、`Graph`にnodeとedgeを関連付けます。
このとき使う機能が、'associated type'です。

```rust
trait Graph {
    type N;
    type E;

    fn has_edge(&self, &Self::N, &Self::N) -> bool;
    fn edges(&self, &Self::N) -> Vec<Self::E>;
    // etc
}
```

Syntaxは上のように、`trait`内に`type N`のように記述します。
さきほどの`distance()`関数のシグネチャは次のように変わります。

```rust
fn distance<G: Graph>(graph: &G, start: &G::N, end: &G::N) -> u32 { ... }
```

すこしすっきりしましたね。
しかも、不要だった`E`の記述がなくなっています。

### Defining associated types
Associated typesの定義時に、引数の型のように、あるtraitをimplしていることを要求できます。
Syntaxは引数のときと同じです。

```rust
use std::fmt;

trait Graph {
    type N: fmt::Display;
    type E;

    fn has_edge(&self, &Self::N, &Self::N) -> bool;
    fn edges(&self, &Self::N) -> Vec<Self::E>;
}
```

### Implementing associated types
Associated typesをもっているtraitをimplするときも、これまでとあまり変わりません。

```rust
struct Node;
struct Edge;
struct MyGraph;

impl Graph for MyGraph {
    type N = Node;
    type E = Edge;

    fn has_edge(&self, n1: &Node, n2: &Node) -> bool {
        true
    }

    fn edges(&self, n: &Node) -> Vec<Edge> {
        Vec::new()
    }
}
```

Associated typesである`N, E`に具体的な型を指定し、
指定した型をつかってメソッドを定義していきます。

### Trait objects with associated types
Associated typesをもつtraitのtrait objectに変換するときは、
associated typesが具体的には何の型なのか指定する必要があります。
どの型に対するimplか分からなくなりますからね。

```rust
let graph = MyGraph;
let obj = Box::new(graph) as Box<Graph<N = Node, E = Edge>>;
```
