+++
date = "2015-12-30T13:00:00+09:00"
title = "Learning Rust - If let"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## `if let`
`if let`は、ある種のパターンマッチのwrapperです。
Overheadをなくす効果もあるそうです。

```rust
match option {
    Some(x) => { foo(x) },
    None => {},
}
```

のように、あるパターンにマッチした場合のみ処理をおこなうとき、
`if let`を使うと次のように書けます。

```rust
if let Some(x) = option {
    foo(x);
}
```

`Some(x)`にマッチした場合は`foo(x)`が実行されますが、
マッチしなかった場合、なにも起きずに通り過ぎます。

マッチしなかった場合の処理は、`else`節で書くこともできます。

```rust
if let Some(x) = option {
    foo(x);
} else {
    bar();
}
```

## `while let`
同じように、`while let`もあります。
あるパターンにマッチする限り処理を繰り返します。

例えば、次のコードは10から0までを順に出力します。

```rust
let mut option = Some(10);

while let Some(x) = option {
    println!("{}", x);
    option = if x == 0 {
        None
    } else {
        Some(x - 1)
    }
}
```
