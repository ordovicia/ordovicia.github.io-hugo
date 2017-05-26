+++
date = "2016-01-01T13:00:00+09:00"
title = "Learning Rust - Closures"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Closures
Rustにも言語レベルでclosureの機能があります。
今回はそのclosureを学びます。

## Syntax
まず、closureの基本的なsyntaxは以下です。

```rust
let plus_one = |x: i32| x + 1;

let plus_two = |x| {
    let mut result: i32 = x;

    result += 1;
    result += 1;

    result
};
```

`fn`ではなく`let`で宣言し、引数は`||`で挟みます。
その後`{}`内にexpressionを書きますが、一行なら`{}`を省略できます。
でも省略しないほうがわかりやすいのではないでしょうか。

`plus_one`には引数`x`に型を明示していますが、`plus_two`には書いていません。
実は、普通の関数ではできなかった型推論が、closureではできるようになっています。
これは、普通の関数はドキュメントとしても型を明示しておく利点があったのに対し、
closureは一時的なものとしてつくられることが多く、その場合いちいち型を書くのは面倒だから、
というのが理由の一つのようです。
同様に、`-> i32`のような戻り値の型も省略できます。

## Closures and their environment
Closureはclosureなので状態をもてます。
こんな感じです。

```rust
let num = 5;
let plus_num = |x: i32| x + num;
```

ここで、`plus_num`は、`num`をimmutableにborrowしています。
よって、次のように、closureで`num`をborrowして、さらにmutableにborrowしようとすると、
コンパイルエラーになります。

```rust
let mut num = 5;
let plus_num = |x: i32| x + num;

let y = &mut num; // コンパイルエラー
```

しかし、`Vec<T>`はtrivially copyableではないので、moveしてclosureに取り込まれます。
よって、closureを作ったあとにそのvectorを使おうとすると、コンパイルエラーになります。
この挙動は普通の関数と同じです。

```rust
let nums = vec![1, 2, 3];

let takes_nums = || nums;

println!("{:?}", nums); // コンパイルエラー
```

## `move` closure
Closureが、ownershipを得ながら状態を取り込むことができます。
`move`キーワードをつかいます。

```rust
let num = 5;

let owns_num = move |x: i32| x + num;
```

Moveセマンティクスは、moveする型にあったセマンティクスになります。
つまり、上の例では`i32`をmoveしていますが、`i32`は`Copy`traitをもっているので、
ここでは`num`をdeep copyしたもののownershipをもつことになります。

ということは、`i32`をmoveせず取り込む場合は、deep copyではなく、
参照になるということです(この例ではmutableな参照です)。

この違いは下の例でわかります。

```rust
let mut num = 5;

{
    let mut add_num = |x: i32| num += x; // not move; num: &mut i32

    add_num(5);
}

assert_eq!(10, num);
```

```rust
let mut num = 5;

{
    let mut add_num = move |x: i32| num += x; // move; num: i32

    add_num(5);
}

assert_eq!(5, num);
```

違う見かたをすると、move closureは自分自身のスタックフレームをもちますが、
moveしないclosureは、それを作ったスタックフレームとつながっています。
よって、後述するclosureを返す関数は、move closureしか返せないということになります。

## Closure implementation
実は、closureは、特別なtraitをimplされたstructのシンタックスシュガーです。
Closureには`()`が作用できますね。
これはそのためのtraitをimplして、overloadしているからです。

```rust
pub trait Fn<Args> : FnMut<Args> {
    extern "rust-call" fn call(&self, args: Args) -> Self::Output;
}

pub trait FnMut<Args> : FnOnce<Args> {
    extern "rust-call" fn call_mut(&mut self, args: Args) -> Self::Output;
}

pub trait FnOnce<Args> {
    type Output;

    extern "rust-call" fn call_once(self, args: Args) -> Self::Output;
}
```

関数の(型理論的な)型がtraitになっているわけです。
Closureを書くと、環境を取り込んだstructを作り、この`Fn`をimplします。
たしかC++のラムダ式も関数オブジェクトなclassをつくるシンタックスシュガーだった気がします。

## Taking closures as argument
さて、closureもtraitをimplしたただのstructであることがわかりました。
ということは、これまでと同じように、何も特別なことなく扱えますね。

例えば、closureをとる関数を考えてみます。

```rust
fn call_with_one<F>(some_closure: F) -> i32
    where F : Fn(i32) -> i32 {

    some_closure(1)
}

let answer = call_with_one(|x| x + 2);

assert_eq!(3, answer);
```

`i32`をとって`i32`を返すclosureをとるために、
`Fn(i32) -> i32`traitをもつ型をとっています。

動的ディスパッチもできます。

```rust
fn call_with_one(some_closure: &Fn(i32) -> i32) -> i32 {
    some_closure(1)
}

let answer = call_with_one(&|x| x + 2);

assert_eq!(3, answer);
```

`as`で型変換もできますが、`&Fn(i32) -> i32`と二度書くことにになるので、
上のような書きかたをするのがよさそうです。

## Function pointers and closures
普通の関数は、状態をもたないclosureとみなせるので、closureとして他の関数に渡したりできます。

```rust
fn call_with_one(some_closure: &Fn(i32) -> i32) -> i32 {
    some_closure(1)
}

fn add_one(i: i32) -> i32 {
    i + 1
}

let answer = call_with_one(&add_one);

assert_eq!(2, answer);
```

## Returning closures
Closureを渡すだけではなく、closureを返すこともできます。
ただし、Rustコンパイラに怒られないように、いくつか注意する必要があります。

結論から言うと、次のようにかけばclosureが返せます。

```rust
fn factory() -> Box<Fn(i32) -> i32> {
    let num = 5;

    Box::new(move |x| x + num)
}

let f = factory();

let answer = f(1);
assert_eq!(6, answer);
```

まず、返すclosureは`Box<Fn>`の形でboxに包んでいます。
`Box`というのは、ヒープ上に確保した、所有者が一つだけのポインタを表しています。
`Box`はコンパイル時にlifetimeがきまるので、Rustが自動的に破棄処理をしてくれるようです。

もうひとつ、`factory()`内でclosureをつくるとき、moveセマンティクスをつかっています。
これは、`num`が`factory()`内のスタック変数のため、
moveしないと不正な参照になってしまうからです。
そこで、`factory()`とは独立した環境に`num`を移すため、`move`の記述が必要になります。

---

長かったですね。
今回はclosureについて学びました。
ここまでくると、Rustのsyntaxとsemanticsについて、かなりたくさんのことを覚えた気がしてきます。
しかし、プログラミング言語というものはたくさん書かないとどうしても身につかないものです。
もうちょっと文法を学んだら、たくさんのコードに触れてみようと思います。
