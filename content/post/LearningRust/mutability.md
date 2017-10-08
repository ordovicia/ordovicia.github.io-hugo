+++
date = "2015-12-21T12:00:00+09:00"
title = "Learning Rust - Mutability"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Mutability
これまで話してきたとおり、Rustはデフォルトでimmutableです。
今回は、Rustのmutabilityについて確認しておきます。

`let`文でvaliable bindingを宣言するとき、`mut`指定すれば
mutable variable bindingとなり、変更が可能になります。

```rust
let mut x = 5;
x = 6;
```

このとき、'mutable'とは`x`が指している`i32`型のものが変更可能という意味であり、
`x`が変更可能という意味ではありません。

Mutableなvariable bindingは`&mut`参照で受け取ることができます。

```rust
let mut x = 5;
let y = &mut x;
*y = 6;
```

これで`x`が指している値が6に変わりました。

上のコードでは、`y`自体は`mut`指定されていません。
これは、参照先を変えられないということを意味します。

```rust
let mut x = 5;
let mut z = 6;
let mut y = &mut x;
y = &mut z;
```

このように`y`も`mut`指定すると参照先を`z`に変えることができました。

最後に、`mut`は'pattern'の一部なので、次のようにかけます。

```rust
let (mut x, y) = (5, 6);
```

このとき、`x`はmutableですが、`y`はimmutableです。

---

短いですが、今回はここまでです。
デフォルトでimmutableなのは、面倒ですがバグ回避のためには大事ですね。
