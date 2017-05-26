+++
date = "2015-12-03"
title = "Learning Rust - Ownership"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
今回扱うのは、Rustのリソース管理システムであるownershipの概念です。

このシステムによる解析はすべてコンパイル時におこなわれ、
Rustの目標の一つであった"Zero-cost abstraction"を達成しているそうです。

公式ドキュメントでは、ownershipシステムは

* Ownership
* References and Borrowing
* Lifetimes

の3つの章からなっています。
今回はそのうち最初の二つを取り上げます。
というのは、ownershipシステムが難しくて(と、ドキュメントに書いてあります)、
Lifetimesまではまだ理解できていないからです(半分くらいは英語力のせいですが)。

## Ownership
variabe bindingsはownershipをもちます。
そしてvariable bindingsがスコープを抜けると、それがもっているデータは
メモリ上から破棄されます。

次の例では、vectorがヒープ上につくられ、
`v`というvariable bindingがそのownershipをもち、
`foo()`のスコープを抜けるとこのvectorに関するすべてのデータが削除されます。

```rust
fn foo() {
    let v = vec![1, 2, 3];
}
```

ヒープに確保されるんですね。驚きです。

## Move semantics
Rustではメモリ上に確保されたひとつのデータのownershipをもつ
variable bindingはたったひとつだけです。
よって、例えばvectorを他のvectorに代入できますが、そのときmoveが起こります。

```rust
let v = vec![1, 2, 3];
let v2 = v;

println!("v[0] is: {}", v[0]);
```

このコードはコンパイルエラーになります。2行目で`v`が`v2`にmoveされて
vectorのownershipを失っているので、
`v[0]`という操作ができなくなっているのです。

関数に渡したときもmoveが起こり、下のコードもコンパイルエラーとなります。

```rust
fn take(v: Vec<i32>) {
    // what happens here isn’t important.
}

let v = vec![1, 2, 3];
take(v);

println!("v[0] is: {}", v[0]);
```

## The details
Rustのメモリアロケーションがどのように働き、
なぜmoveが起こるのか、次のコードを題材に詳しく見ていきます。

```rust
let v = vec![1, 2, 3];

let v2 = v;
```

1行目では、vectorのメモリアロケーションが起こります。
vectorの要素(`[1, 2, 3]`)がヒープ上に確保され、
それを指すポインタがvectorオブジェクトとしてスタックに確保されます。
上で「vectorがヒープ上につくられる」といったのは、
詳しくはこういうことになります。

そして2行目では、`v`から`v2`へのmoveが起こります。
このとき、vectorオブジェクト`v`が持っているポインタが、`v2`にコピーされます。
するとヒープ上の同一データを指すポインタが二つ存在することになり、
これはdata raceの起こりえないことを保証する
Rustのシステムに反することになるため、 以降`v`をつかっていないことがコンパイル時に確かめられるようです。

## `Copy` types
vectorは代入でmoveが起こりましたが、下のコードはエラーになりません。

```rust
let v = 1;
let v2 = v;

println!("v is: {}", v);
```

これは、`v`の型である`i32`が`Copy`traitを持っているためです。
vectorとちがって`i32`は軽くポインタを利用していないので、
moveではなくdeep copyが起きる、ということのようです。

`i32`や`bool`などの組み込み型はすべて`Copy`traitをもっています。
よって関数に渡したりほかのvariable bindingsに代入しても
moveは起こりません。

## More than ownership
こんなコードを書けばコンパイルエラーは起こりません。

```rust
fn foo(v1: Vec<i32>, v2: Vec<i32>) -> (Vec<i32>, Vec<i32>, i32) {
    // do stuff with v1 and v2

    // hand back ownership, and the result of our function
    (v1, v2, 42)
}

let v1 = vec![1, 2, 3];
let v2 = vec![1, 2, 3];

let (v1, v2, answer) = foo(v1, v2);
```

`foo()`に`v1, v2`のownershipを渡していますが、
`foo()`からまたownershipも返すようにしています。
ちゃんと動きます(Rustは同じ変数名を付けて、古いものを隠せるんでしたね)。

でも、ownershipを行ったり来たりさせるの面倒だし遅そうだし
やりたくないですよね。
ほかの現代的な言語とおなじように、Rustにもちゃんと解決策があります。

# References and Borrowing
## Borrowing
上のコードを次のように改善します。

```rust
fn foo(v1: &Vec<i32>, v2: &Vec<i32>) -> i32 {
    // do stuff with v1 and v2

    // return the answer
    42
}

let v1 = vec![1, 2, 3];
let v2 = vec![1, 2, 3];

let answer = foo(&v1, &v2);
```

まず、`foo()`の引数の型`Vec<i32>`に`&`をつけました。
さらに引数`v1, v2`にも`&`をつけます。
こうすることで参照の受け渡しとなりました。

参照はメモリ上のデータのownershipをもつのではなく、借ります。
参照がスコープを抜けてもメモリの解放はおこなわれません。

## `&mut` references
Rustはデフォルトでimmutableなので、上のように参照を定義しても、
それを通して書き換えることはできません。
書き換えたい場合は`&mut Type`のように明示します。

```rust
let mut x = 5;

{
    let y = &mut x;
    *y += 1;
}

println!("{}", x)
```

このコードは'6'を出力します。
`{}`内で`&mut`な参照`y`をつくり、`*y`で間接参照してインクリメントしました。
C++とおなじように、参照先は`*`でアクセスできます。

ここで一つ実験してみました。
次のコードは順に5, 5, 6, 6, 6を出力します。
出力部で`p`と`*p`がどっちも使えるのは、
`println!()`マクロのポリモーフィズムのおかげでしょうか？

```rust
let mut q = 5;
let p = &mut q;

println!("{}", p);
println!("{}", *p);

*p += 1; // p += 1 はコンパイルエラー

println!("{}", p);
println!("{}", *p);
println!("{}", q)
```

## The Rules
さて、上に挙げた

```rust
let mut x = 5;

{
    let y = &mut x;
    *y += 1;
}

println!("{}", x)
```

のコードは、`{}`でスコープをつくり、`y`を囲っていますね。
実はこの`{}`を取り除くと、コンパイルエラーになります。

なぜでしょう。ここで参照によるownershipの貸与について
規則が述べられていました。

1. 参照はその参照先が消えたあとにも存在していてはいけない
1. ある元データについて定義できる参照は次の二種類があるが、
   両方同時にはつくれない
    * 一つまたは複数のimmutableな参照(`&T`)
    * 一つのみのmutableな参照(`&mut T`)

二つ目の規則は、data raceを防ぐ十分条件になっています。
同時にメモリ上の同じデータに複数のアクセスがあり、
そのうち一つ以上が書き込み操作のときdata raceが起こるのでした。

`{}`を取り除くと、この二つ目に反することになります。
mutableな参照`y`が存在しているうちに、`println!()`においてまた`x`の
参照が作られようとするからです。

```rust
let mut x = 5;

let y = &mut x;    // -+ &mut borrow of x starts here
*y += 1;           //  |
                   //  |
println!("{}", x); // -+ - try to borrow x here
                   // -+ &mut borrow of x ends here
```

そこで`y`を`{}`で囲むと、参照の存在がconflictせず、
data raceがないことが保証できます。

## Issues borrowing prevents
このようにRustは厳格(すぎる)リソース管理システムを持っています。
なぜこのような制限が必要なのか一度確認しておきましょう。

### Use after free
まずはひとつ目の、参照が元データより長く存在してはいけないというルールです。

```rust
let y: &i32;

{
    let x = 5;
    y = &x;
}

println!("{}", y);
```

このコードは、`x`を参照する`y`が`x`より長く存在しているので違反となります。
参照先が不定になると再現性の無いバグとなって大変ですね。
Rustではこのようなスコープ解析がコンパイル時におこなわれます。

さらに次のコードもコンパイルエラーになります。

```rust
let y: &i32;
let x = 5;
y = &x;

println!("{}", y);
```

スコープは同じですが、`y`が`x`より先に定義されているため、
スコープを抜けるときは逆順に、
つまり`x`の次に`y`が削除されることになるからです。
スタックの下にあるものしか参照できないということでしょう。厳しいですね。

### Iterator invalidation
二つ目のルールを確認します。
次のコードはコンパイルエラーです。

```rust
let mut v = vec![1, 2, 3];
v.push(42);

for i in &v {
    println!("{}", i);
    v.push(34);
}
```

まず、一行目でvectorの`v`を`mut`として定義しました。
二行目では`push`を行うために、`v`のmutableな参照が一時的につくられ、
`push`後すぐに破棄されるようです。

そのあとの`for`ループで、immutableな参照として`v`の
ownershipを借りています。
そのループ内で`v`に対して`push`しようとすると、さらに`v`のmutableな参照を
得ることになります。
これは、mutableな参照を一つ作ると、その他に(mutable,
immutableにかかわらず)参照が作れないというルールに反していますね。

---

今回はここまでです。
次回はLifetimesを扱うつもりですが、一読してもさっぱりだったので、
まだ時間がかかりそうです。
