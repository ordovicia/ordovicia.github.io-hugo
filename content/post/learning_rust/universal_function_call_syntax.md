+++
date = "2016-01-01T14:00:00+09:00"
title = "Learning Rust - Universal Function Call Syntax"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Universal Function Call Syntax
別々のtraitが同名の関数を持っていることがありますね。

```rust
fn main() {
    trait Foo {
        fn f(&self);
    }

    trait Bar {
        fn f(&self);
    }

    struct Baz;

    impl Foo for Baz {
        fn f(&self) { println!("Baz’s impl of Foo"); }
    }

    impl Bar for Baz {
        fn f(&self) { println!("Baz’s impl of Bar"); }
    }

    let b = Baz;
}
```

`Foo`と`Bar`というtraitがともに`f()`メソッドをもっていて、
それらを`Baz`structにimplしました。
これだけではエラーにはなりませんが、`b.f()`を呼ぶとエラーです。

```rust
b.f(); // Error
```

これはシグネチャが違っていても(`Bar`の`f()`が`f(&self, i32)`とかでも)、
コンパイルエラーになるようです。

それで、どうにかして曖昧さをなくさないといけないのですが、
'universal function call syntax'を使えば可能です。

Syntaxは以下のように、

```rust
Foo::f(&b);
Bar::f(&b);
```

C++の名前空間みたいにtraitを指定します。
`b.f()`のようなメソッド呼び出しとは違い、`&b`は明示的に渡さなければいけません。

## Angle-bracket Form
実はこの'universal function call syntax'は、
'Angle-bracket form'の短縮版らしいです。
Angle-bracket formは、

```rust
<Type as Trait>::method(args);
```

のようなsyntaxで記述します。
`Type`にimplされている`Trait`がもつ`method`を呼ぶ、ということですね。

```rust
trait Foo {
    fn clone(&self);
}

#[derive(Clone)]
struct Bar;

impl Foo for Bar {
    fn clone(&self) {
        println!("Making a clone of Bar");

        <Bar as Clone>::clone(self);
    }
}
```

上のように使えますが、`Clone::clone(self)`でも大丈夫なようです。
どっちでもいいということでしょうか。
