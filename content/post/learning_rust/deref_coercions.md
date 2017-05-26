+++
date = "2016-01-03T13:00:00+09:00"
title = "Learning Rust - Deref Coercions"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## `Deref` coercions
前回はtraitによる演算子のoverloadを扱いました。
Overloadできる演算子には、間接参照演算子`*`を実装する、`Deref`traitがあります。
この`Deref`traitはユーザー定義ポインタ型の間接参照に使えますが、
すこし特別な機能も持っています。

まずは普通の使いかたから。
`DerefExample`というポインタっぽい型を定義し、`Deref`traitをimplします。
間接参照先の型を`Target`というassociation typeに指定します。

```rust
use std::ops::Deref;

struct DerefExample<T> {
    value: T,
}

impl<T> Deref for DerefExample<T> {
    type Target = T;

    fn deref(&self) -> &T {
        &self.value
    }
}

fn main() {
    let x = DerefExample { value: 'a' };
    assert_eq!('a', *x);
}
```

それでは`Deref`の何が特別かというと、次のようなルールがあります。

型`U`に対して、`Deref<Target = T>`をimplすると、`&U`型の値は暗黙的に`&T`に変換できる。

例を見てみます。

```rust
fn foo(s: &str) {
    //
}

let owned = "Hello".to_string(); // owned: String

// String implements Deref<Target = str>
// Thus, &String will coerced to &str
foo(&owned);
```

`String`は`Deref<Target = str>`をimplされているので、
`&String`は暗黙的に`&str`に変換され、`foo()`に渡されます。

他には、リファレンスカウンタをもつ`Rc<T>`型は、`Deref<Target = T>`をimplされています。
よって、`&Rc<T>`型の値は暗黙的に`&T`型にキャストできます。

```rust
use std::rc::Rc;

fn foo(s: &str) {
    //
}

let owned = "Hello".to_string(); // owned: String
let counted = Rc::new(owned); // counted: Rc<String>

foo(&counted); // &Rc<String> -> &String -> &str
```

この例では、`&Rc<String>`から`&String`を経て`&str`へ、二段階のキャストが起こっています。

### Deref and method calls
もう一つ、`Deref`には特別な機能があります。
それは、メソッドをよぶときは`*`を省略して、間接参照できるということです。

```rust
struct Foo;

impl Foo {
    fn foo(&self) { println!("Foo"); }
}

let f = &&Foo;

f.foo();
```

`f`は`&&Foo`型ですが、`&Foo`をとるメソッドが呼べます。
これは、コンパイラが自動的に`*`を挿入してくれるからです。
`*`は必要なだけ挿入されるので、`(&&&&&&&&&f).foo()`みたいなのもコンパイルできます。
