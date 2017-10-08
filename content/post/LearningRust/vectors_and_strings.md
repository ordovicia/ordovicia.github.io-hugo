+++
date = "2015-12-23"
title = "Learning Rust - Vectors and Strings"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
今回は、Rustのvectorと文字列を学びます。
Vectorの使いかたはわかりやすいですが、Rustの文字列は他の言語とすこし違うようです。

## Vectors
Rustでのvectorのはなしです。

`vector`は可変長配列です。
標準ライブラリに`Vec<T>`という型で定義されています。
(`<T>`はすぐあとででてくるジェネリクスです。いろんな型のvectorがつくれます。)

Vectorをつくるには、`vec![]`マクロを使います。

```rust
let v = vec![1, 2, 3, 4, 5]; // v: Vec<i32>

let u = vec![0; 10]; // ten zeros
```

Vectorの要素はヒープ上に確保されるそうです。

### Accessing elements
`vector`の要素にアクセスするには、`[]`をつかいます。
インデックスは0始まりです。

```rust
let v = vec![1, 2, 3, 4, 5];

println!("The third element of v is {}", v[2]); // 3
```

インデックスをvariable bindingで指定するとき、
その型は`usize`でないといけません。
`i32`などは不可です。

```rust
let i: usize = 0;
let j: i32 = 0;

println!("{}", v[i]); // works
println!("{}", v[j]); // doesn't
```

### Iterating
`for`ループで要素を走査できます。

```rust
let mut v = vec![1, 2, 3, 4, 5];

for i in &v {
    println!("A reference to {}", i);
}
```

Immutableな参照`&v`だけでなく、`&mut v, v`で受け取るのも可能です。

## Strings
つぎは、Rustでの文字列のはなしです。
Rustでは文字列のあつかいが、Cなどと比べて結構違うようです。

まず、Rustの文字列はUnicodeスカラ値が並んだもので、
UTF-8にエンコードされます。
終端がnull文字だったりはせず、null文字自体を含むこともできるようです。

Rustには二つの文字列型があります。
`&str`と`String`です。
`&str`は文字列リテラルのスライスです。

```rust
let greeting = "Hello there."; // greeting: &'static str
```

文字列リテラルは`'static`なlifetimeをもち、
`greeting`はこの文字列を参照しています。
文字列リテラルのスライスはimmutableです。

一方、`String`はヒープ上に確保され、mutableです。
多くの場合、`&str`から`to_string()`メソッドで`String`に変換されます。

```Rust
let mut s = "Hello".to_string(); // mut s: String
println!("{}", s);

s.push_str(", world.");
println!("{}", s);
```

`String`型のものに`&`をつけて参照しようとすると、
勝手に`&str`型のスライスに変換されます。

```rust
fn takes_slice(slice: &str) {
    println!("Got: {}", slice);
}

fn main() {
    let s = "Hello".to_string();
    takes_slice(&s);
}
```

というのも、`&str`を`String`に変換すると、
無駄なメモリアロケーションが起こってしまうためです。

## Indexing
Rustの文字列はUTF-8で、文字によってバイト数がことなるため、
単純にインデックス指定することはできません。

文字列の初めから調べていって、文字に分解する必要があります。
そのためのメソッドがちゃんと用意されていて、次のように使います。

```rust
let hachiko = "忠犬ハチ公";

for b in hachiko.as_bytes() {
    print!("{}, ", b);
}

println!("");

for c in hachiko.chars() {
    print!("{}, ", c);
}

println!("");

let dog = hachiko.chars().nth(1);
match dog {
    Some(d) => println!("{}", d),
    None => println!("Error!"),
}
```

出力は以下です。

```
229, 191, 160, 231, 138, 172, 227, 131, 143, 227, 131, 129, 229, 133, 172,
忠, 犬, ハ, チ, 公,
犬
```

## Slicing
スライスのsyntaxをつかってスライスを得ることもできますが、
indexが文字単位ではなくバイト単位であることに注意が必要です。

```rust
let dog = "hachiko";
let hachi = &dog[0..5]; // works

let dog = "忠犬ハチ公";
let hachi = &dog[0..2]; // runtime error
```
