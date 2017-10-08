+++
date = "2015-12-21T13:00:00+09:00"
title = "Learning Rust - Match and Patterns"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
Rustには強力なパターンマッチがあります。
今回はその紹介です。

## Match
まずは簡単な例から。`match`のsyntaxは以下のようになっています。

```rust
let x = 5;

match x {
    1 => println!("one");
    2 => println!("two");
    3 => println!("three");
    4 => println!("four");
    5 => println!("five");
    _ => println!("something else");
}
```

`match`はexpressionをとり、`{}`で囲んで、
`val => expression`の形で枝を連ねます。

`_`をつかうと、なんにでもmatchすることができます。
Haskellとおなじですね。

`if-else`とちがって、
`match`はすべての場合を網羅することがコンパイル時にチェックされます。

ちなみに、

```rust
match x {
    _ => println!("something else");
    5 => println!("five");
}
```

のように、`_`を上に書くと、`5`の枝に分岐しないよ！
というコンパイルエラーがでました。

`match`自体もexpressionなので、代入できます。

```rust
let x = 5;

let number = match x {
    1 => "one",
    2 => "two",
    3 => "three",
    4 => "four",
    5 => "five",
    _ => "somehing else",
}

println!("x is {}", number);
```

## Matching on enums
`match`と相性がいいのがenumです。

```rust
enum Message {
    Quit,
    ChangeColor(i32, i32, i32),
    Move { x: i32, y: i32 },
    Write(String),
}

fn quit() { /* ... */ }
fn change_color(r: i32, g: i32, b: i32) { /* ... */ }
fn move_cursor(x: i32, y: i32) { /* ... */ }

fn process_message(msg: Message) {
    match msg {
        Message::Quit => quit(),
        Message::ChangeColor(r, g, b) => change_color(r, g, b),
        Message::Move { x: x, y: y } => move_cursor(x, y),
        Message::Write(s) => println!("{}", s),
    };
}
```

Enumをmatchするときも、すべての場合を網羅しているかチェックされます。

上の例のように、Matchの際にstructの中身をとりだすことができます。
このような、patternの詳細は次の章から詳しく見ていきます。

## Patterns
もっとも簡単なpatternの例は最初に扱いました。
次に進みましょう。

### Multiple patterns
`|`をつかうと、orパターンが実現できます。

```rust
let x = 1;

match x {
    1 | 2 => println!("one or two"),
    3 => println!("three"),
    _ => println!("anything"),
}
```

### Destructing
Enumのmatchで扱いましたが、
`struct`や`enum`などの複合型をmatchするときは、
そのなかみをとりだすことができます。

```rust
struct Point {
    x: i32,
    y: i32,
}

let origin = Point { x: 0, y: 0 };

match origin {
    Point { x, y } => println!("({},{})", x, y),
}
```

`struct`なら、要素に別の名前をつけることもできます。

```rust
match origin {
    Point { x: x1, y: y1 } => println!("({},{})", x1, y1),
}
```

さらに、すべての要素が必要でない問は、`..`が使えます。

```rust
match origin {
    Point { y, .. } => println!("y is {}", y),
}
```

### Ignoring bindings
`_`をつかえばなんにでもmatchしますが、次のようにも使えます。

```rust
match some_value {
    Ok(value) => println!("got a value: {}", value),
    Err(_) => println!("an error occurred"),
}
```

`some_value`は`Result<T, E>`という型で、
`Ok`か`Err`という`enum`の可能性があります。

`Err(_)`は、`Err`であるという情報だけでmatchし、
中身がなんであるかは捨てています。

`match`以外でも`_`が使えて、たとえば、

```rust
fn coodinate() -> (i32, i32, i32) {
    // generate and return some sort of triple tuple
}

let (x, _, z) = coodinate();
```

のように、tupleを返す関数の戻り値の一部を捨てることができます。

また、複数のものを捨てるときは、`_, _`などの代わりに、`..`が使えます。

```rust
enum OptionalTuple {
    Value(i32, i32, i32),
    Missing,
}

let x = OptionalTuple::Value(5, -2, 3);

match x {
    OptionalTuple::Value(..) => println!("Got a tuple!"),
    OptionalTuple::Missing => println!("No such luck."),
}
```

### ref and ref mut
Matchしたものを参照で受け取りたいときは、`ref`をつけます。

```rust
let x = 5;

match x {
    ref r => println!("Got a reference to {}", r),
}
```

このとき`r`の型は`&i32`になっています。

mutableな参照なら、`ref mut`とします。

### Ranges
整数型と`char`は、`...`を使ってrangeでmatchができます。

```rust
let x = 1;

match x {
    1 ... 5 => println!("one through five"),
    _ => println!("anything"),
}
```

```rust
let x = '💅'

match x {
    'a' ... 'j' => println!("early letter"),
    'k' ... 'z' => println!("late letter"),
    _ => println!("something else"),
}
```

### Bindings
Matchした結果を`@`をつかってbindすることができます。

```rust
let x = 1;

match x {
    e @ 1 ... 5 => println!("got a range element {}", e),
    _ => println!("anything"),
}
```

この例だと、`x`を表示すればいいですが、
複雑な`struct`などにつかうと便利です。

```rust
#[derive(Debug)]
struct Person {
    name: Option<String>,
}

let name = "Steve".to_string();
let mut x: Option<Person> = Some(Person { name: Some(name) });

match x {
    Some(Person { name: ref a @ Some(_), .. }) => println!("{:?}", a),
    _ => {}
}
```

`a`に`name`をbindしています。

`@`を`|`といっしょにつかうときは、

```rust
let x = 5;
match x {
    e @ 1 ... 5 | e @ 8 ... 10 => println!("got a range element {}", e),
    _ => println!("anything"),
}
```

のように、`|`で区切ったすべての部分についてbindするように書きます。

### Guards
Matchの条件に`if`を書くことで、guardも実現できます。

```rust
enum OptionalInt {
    Value(i32),
    Missing,
}

let x = OptionalInt::Value(5);

match x {
    OptionalInt::Value(i) if i > 5 => println!("Got an int bigger than five!"),
    OptionalInt::Value(..) => println!("Got an int!"),
    OptionalInt::Missing => println!("No such luck."),
}
```

`i > 5`が`false`なので、ひとつ目のパターンにはマッチせず、
ふたつ目に入ります。

```rust
match x {
    OptionalInt::Value(i) => if i > 5 {
            println!("Got an int bigger than five!");
        } else {
            println!("Got an int!"),
        },
    OptionalInt::Missing => println!("No such luck."),
}
```

としても同じですが、guardをつかったほうが多少わかりやすいでしょうか。

`|`と組み合わせるときは、guardの`if`は`|`で区切ったすべての部分に掛かります。
つまり、

```rust
let x = 4;
let y = false;

match x {
    4 | 5 if y => println!("yes"),
    _ => println!("no"),
}
```

と書くと、`4 | (5 if y)`ではなく、`(4 | 5) if y`と解釈されます。

ちなみに、

```rust
let x = 4;

match x {
    i if i % 2 == 0 => println!("even"),
    4 => println!("four"),
    _ => println!("something else"),
}
```

と書くと、最初のguardにマッチするので、`4 =>`のpatternは起こりえません。
`_`を最後以外に書いたときとちがって、この場合は警告も出ないようです。

最後にひとつ注意です。

```rust
let x = 'x';
let c = 'c';

match c {
    x => println!("x: {}, c: {}", x, c),
}

println!("x: {}", x);
```

は、

```
x: c, c: c
x: x
```

を出力します。
Matchの結果をbindした変数は、
`match`のスコープ内でのみ有効な、あたらしくつくられたvariable bindingです。
そのため、一行目で定義した`x`は隠されることになります。

---

今回はパターンマッチを扱いました。
現代的な便利構文なのでぜひ実用してみたいです。
