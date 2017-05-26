+++
date = "2015-11-24"
title = "Learning Rust - If and Loops"
tags = ["Programming", "Rust"]
+++

ひさびさのRustです。
というか最近更新サボり気味ですね。

# Syntax and Semantics
引き続いてRustのsyntaxとsemanticsを学びます。

## If
条件分岐ですね。以下のようなsyntaxです。

```rust
let x = 5;

if x == 5 {
    println!("x is five!");
} else if x == 6 {
    println!("x is six!");
} else {
    println!("x is not five or six :(");
}
```

条件式の`()`はつけないが、then節、else節には`{}`が必要なようです。
もちろんelse節は省略できます。

実は`if`はexpressionなので、値を返します。
例えば、

```rust
let x = 5;
let y = if x == 5 { 10 } else { 15 }; // y = 10
```

となります。
then節、else節にstatementを書くと空tuple`()`が返るようです。
もちろんthen節とelse節に違う型のexpressionを書くことはできません。

現時点でのドキュメントだと、

> An if without an else always results in () as the value.

と書いてあったのですが、
Rust v1.4でif-expressionの値を代入するとき、
else節を省略するとコンパイルエラーになりました。

## Loop
条件式とならんで制御構文を代表する繰り返し構文です。
Rustには3つの方法があります。
`loop, while, for`です。

(`until`や`unless`があるとよかったのですが、かえってわかりにくいでしょうか)

### `loop`
`loop`キーワードは無限ループを作ります。
`break`や`return`で抜けることができます。

```rust
loop {
    println!("Loop forever!");
}
```

### `while`
おなじみ`while`は、条件が満たされるまで繰り返します。

```rust
let mut x = 5;
let mut done = false;

while !done {
    x += x - 3;
    println!("{}", x);

    if x % 5 == 0 {
        done = true;
    }
}
```

上述の`loop`は`while true`と同値でしょうか？
実は(少なくともv1.4の)Rustでは、
`loop`は`while true`の単なる置き換えではありません。
例えば、

```rust
let mut a;
loop {
    a = 1;
    break;
}
println!("{}", a);
```

は正しいコードですが、`loop`を`while true`で置き換えると、
`a`が未初期化であるとのコンパイルエラーになります。
というのは、`loop`キーワードを使うと、
必ずその中身が実行されることがわかっているので、
`a`がちゃんと初期化されることがわかるから、ということらしいです。(参考: https://github.com/rust-lang/rust/issues/12975 )

でも、コンパイラが`while true`を見つけたら
`loop`とみなすのではダメなんでしょうか？

## `for`
`for`はある範囲を走査しながら繰り返す構文です。
syntaxは以下のようになっています。

```rust
for var in expression {
    code
}
```

C++とかにもある形ですが、
`var, expression`に適用できるものパターンが強力になっています。

まずはC++にもある、数値を動かしていくもの。

```rust
for i in 0..10 {
    println!("{}", i);
}
```

は、想像通り0から9を順に出力します。

vectorの要素を辿っていくこともできます。

```rust
let nums = vec![1, 2, 3];

for num in &nums {
    println!("{}", num);
}
```

便利ですね。
もっとも、C++11にもrange-based-forがあって同じ書き方はできますが。

### Enumerate
「何番目まで走査しているか」を知りたいときは、`enumerate()`関数が使えます。
rangeに対しては、

```rust
for (i, j) in (5..10).enumerate() {
    println!("The {}st number is {}.", i, j)
}
```

で、`0: 5`などの出力が得られ、

```rust
let lines = "hello\nworld!".line();
for (linenumber, line) in lines.enumerate() {
    println!("{}: {}", linenumber, line);
}
```

は、

```console
0: hello
1: world!
```

を出力します。

## Ending iteration early
上述の通り、`break`や`return`を使えばループを抜けられます。
よって、上に挙げた`while`の例は以下のように書き換えられます。

```rust
let mut x = 5;

loop {
    x += x - 3;
    println!("{}", x);

    if x % 5 == 0 { break; }
}
```

`continue`は次のイテレーションに進みます。
よって次のコードは奇数のみ出力します。

```rust
for x in 0..10 {
    if x % 2 == 0 { continue; }

    println!("{}", x);
}
```

`break, continue`どちらもご存知のとおりでしたね。

## Loop label
最後はRust特有の機能でしょうか。私は見たことがありませんでした。

入れ子になったループで`break, continue`すると、
デフォルトではそれが実行された最も内側のループに対して働きますが、
もっと上層のループを抜けたいときもあります。

そこでRustでは、ループに名前をつけることができます。
以下のように、`outer`や`inner`というラベルをつけ、`continue 'outer`
のようにすれば、外側のループを次に進めることができます。

```rust
'outer: for x in 0..10 {
    'inner: for y in 0..10 {
        if x % 2 == 0 { continue 'outer; } // continues the loop over x
        if y % 2 == 0 { continue 'inner; } // continues the loop over y
        println!("x: {}, y: {}", x, y);
    }
}
```

---

今回はここまでです。
若干syntaxが違うもののsemanticsはほぼおなじ、条件分岐とループの話でした。

最後のLoop labelは便利ですね。
「終了フラグをたててすべてのループを順に抜ける」のようなコードを書かなくてすみます。
(関数にしてreturnすべしという話はありますが)
