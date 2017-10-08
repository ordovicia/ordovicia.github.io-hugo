+++
date = "2015-12-21T12:00:00+09:00"
title = "Learning Rust - Structs and Enums"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
今回は、型を組み合わせて新しい型を作る方法を扱います。

## Structs
まずはstructです。
次のコードを見ればだいたいわかりますね。

```rust
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let origin = Point { x: 0, y: 0 };

    println!("The origin is at ({}, {})", origin.x, origin.y);
}
```

Struct名はUpperCamelCaseが推奨されているようです。
Rustは命名規則にも(雰囲気だけではない)ルールがありますよね。
関数名をlowerCamelCaseで書いたら、コンパイル時に警告がでました。

Rustのstructは、field level mutabilityをサポートしていません。
つまり、

```rust
struct Point {
    mut x: i32,
    y: i32,
}
```

というstructは作ることができません。
そもそも、mutabilityとは型ではなく、bindingに属する性質のものなのです。
Structのbindingをmut指定すれば、そのメンバを変更できます。

```rust
let mut point = Point { x: 0, y: 0 };

point.x = 5;

println!("The point is at ({}, {})", point.x, point.y);
```

## Update syntax
便利機能です。
Structのbindingを、あるメンバだけ違うものにしてコピーしたいとき、
`..`がつかえます。

```rust
struct Point3d {
    x: i32,
    y: i32,
    z: i32,
}

let mut point = Point3d { x: 0, y: 0, z: 0 };
point = Point3d { y: 1, .. point };
```

新しい`point`は、`x = 0, y = 1, z = 0`になっています。

あたらしいbindingをつくりたいときも、このsyntaxがつかえます。

```rust
let origin = Point3d { x: 0, y: 0, z: 0 };
let point = Point3d { z: 1, x: 2, .. origin };
```

## Tuple struct
Structにも何種類かあるようです。
まずは、tupleとのあいのこみたいな、'tuple struct'から。
Tuple structは、メンバが名前を持ちません。

```rust
struct Color(i32, i32, i32);
struct Point(i32, i32, i32);
```

ほとんどの場合は、tuple structより普通にstructを使ったほうがいいでしょう。
メンバが自明であっても、
ちゃんと名前がついていたほうがコードとしてはベターでしょう。

しかし、tuple structにもひとつ使いどころがあります。
'Newtype'をつくりたいときです。

```rust
struct Inches(i32);

let length = Inches(10);

let Inches(integer_length) = length;
println!("length is {} inches", integer_length);
```

このように、`Inches`を`i32`のnewtypeとしてつくることができます。

`Inches`と`i32`は型が違うので、
`Inches`をそのまま`println!()`に渡すことはできません。

中身をとりだすには、上のようにlet文にパターンを使います。
あるいは、tupleと同じように、`length.0`でもアクセスできました。

ちょっと面倒/わかりにくいですが、newtypeをつくったので仕方ないのでしょう。

## Unit-like structs
もうひとつ、変なstructがあります。
メンバをもたないstructです。

```rust
struct Electron;

let x = Electron;
```

ほかの機能を組み合わせて使うときに、
このstructがあることのみが必要な場合などに使えるそうです。

## Enums
Structのつぎは、Enumです。直和型ですね。

```rust
enum Message {
    Quit,
    ChangeColor(i32, i32, i32),
    Move { x: i32, y: i32 },
    Write(String),
}
```

Enumのメンバには、structのようなものがはいります。
Tuple struct, unit-like structも可能です。
上の例では、`Quit, ChangeColor(i32, i32, i32)`などの型をまとめたものが、
一つの`Message`型になっています。

Enumのメンバとなっている型は、enum名に`::`をつけて使用します。
Scopedということですね。

もちろん、enum型のbindingは、
それがenumのどのメンバの型であるのかの情報も持っているので、
不用意に`Quit`と`ChangeColor(i32, i32, i32)`が混ざることはないようです。

## Constructors as functions
Enumのコンストラクタはデフォルトで関数っぽく扱えます。

```rust
let m = Message::Write("Hello, world".to_string());
```

というと、当たり前のようですが、
特に高階関数としてつかうときに役立つようです。

```rust
let v = vec!["Hello".to_string(), "World".to_string()];

let v1: Vec<Message> = v.into_iter().map(Message::Write).collect();
```

---

今回は型を組み合わせて新しい型をつくる、structとenumを扱いました。
Structについては、メンバ関数にあたるものがみあたりませんが、
これは後ほど登場します。

(そういえばlifetimeについて扱うのを忘れていましたね。またいつか。)
