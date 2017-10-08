+++
date = "2015-11-09"
title = "Learning Rust - Variable Bindings and Functions"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
前回に続いて、Rustのoverview的なチュートリアル"Dining Philosophers"を扱うつもりでしたが、
"Syntax and Semantics"章も読み始め、そちらの記事を書いてしまったので、
"Dining Philosophers"は次回に回します。

というわけで、Rustの
[syntaxとsemanticsを解説したページ](https://doc.rust-lang.org/book/syntax-and-semantics.html)
を読んでいきます。

## Variable Bindings
variable bindingについての節です。ややこしいところではないので簡単に読み進めます。

variable bindingの宣言は、

```rust
let x = 5;
```

のようにlet statementをつかいます。`let`が受け入れるのは'pattern'であって、例えば

```rust
let (x, y) = (1, 2);
```

のようにできます。このとき`x = 1, y = 2`となります。
'pattern'については後の節で詳しく説明されるそうです。

上の例では型を明示していませんでした。明示するには

```rust
let x: i32 = 5;
```

のようにします。

Rustのvariable bindingはデフォルトでimmutableなので、mutableにするには

```rust
let mut x = 5;
```

のように`mut`指定します。不必要な`mut`指定があると、コンパイラが警告してくれるようです。

最後に、Rustでは未初期化のvariable bindingはコンパイルエラーになります。例えば

```rust
let x: i32;
println!("The value of x is: {}", x)
```

はエラーです。

以上でvariable bindingが簡単に説明されました。
次に進みましょう。

## Functions
関数ですね。ここも難しい節ではないですが、Rustで重要な'expressions'と'statements'の
違いが浮き彫りになってくるようです。

関数は`fn`キーワードで宣言します。引数をとるには、関数名のあとの丸括弧`()`に名前と型を書きます。
値を返すには`->`のあとに型を書きます。

```rust
fn sum(x: int32, y: int32) -> i32 {
    x + y
}
```

といった具合です。
Rustには型推論がありますが、引数の型は明示する必要があります。
理由をはっきりと述べるのは難しいですが、関数がどんな型をうけとるかくらいはユーザーが
予めわかっていたほうがいい、というの(が理由の一つなこと)はなんとなく理解できます。

注目すべきは、`x + y`にセミコロン`;`がついていないことです。
ここに、Rustがexpression-based languageであることが読み取れます。

### Expressions vs. Statements
Rustはexpession-based languageです。statementには二種類あり、
それ以外はすべてexpressionです。はじめにまとめておくと、次のようになるようです。

* expression
* statement
    * declaration statement
    * expression statement

違いを一言で言うと、expressionは値を返し、statementは返さない、ということらしいです。
したがってstatementである`x + 1;`は値を返さず、

```rust
fn add_one(x: i32) -> i32 {
    x + 1;
}
```

はコンパイルエラーになります。

まずはdeclaration statementについて、ドキュメントに載っている例を挙げてみます。

1. `let x = let y = 5`や`let x = (let y = 5);`はエラー
1. 宣言済みのvariable bindingへ再代入する、
   ```rust
   let mut y = 5;
   let x = (y = 6);
   ```
   はエラーではないが、`x`に空tuple`()`がassignされる。
   丸括弧`()`は必要ないので(コンパイル時に警告が出る)`let x = y = 6`とできるが、
   このときも`x`には空tupleがassignされる。
   ```rust
   let mut x;
   x = y = 6;
   ```
   も同様。

まず1.について。let statementはstatementです。よって値を返さないので、
他のlet statementに渡して代入することはできません。

次に2.について。Rustではデータの所有権(ownership)を持つvariable bindingは一つのみです。
よって`let x = (y = 6)`は、'6'のownershipを`x, y`両方に与えるのではなく
`y`のみに与え、`x`にはexpressionである`y = 6`が返した`()`がassignされる、という
仕組みのようです。

なるほど、ややこしいですね。`x = y = 6`をエラーにせず、空tupleを代入する理由は何か
あるのでしょうか？
今のところはよくわかりませんが、ともかくownershipの概念が重要のようです。

statementにはもう一種類あります。expresion statementです。
これはexpressionをstatementに変換するもので、Rustコードのほとんどの行は
statementでできている、と書いてありました。
つまりexpressionをセミコロン`;`で区切ることでstatementにし、statementどうしを
区別している、というわけです。
これはC++などの言語でみられる文法ですね。

そしてstatement以外がexpressionなのでした。
上で述べたように、Rustコードのほとんどはstatementで、例外的なexpressionが、

```rust
fn add_one(x: i32) -> i32 {
    x + 1
}
```

の`x + 1`という行です。もし`x + 1;`とすると、これはstatementになり、
この関数は`()`を返すという意味になるそうです。

そういえば私はRubyをすこし触ったことがあるのですが、
Rubyでは関数の最後に評価された式の値が戻り値になるのでした。
その話をきいたときは、Rubyは関数型の特徴ももっており、(引数でパラメータづけられた)関数は
その戻り値と対応しているからそういう仕様なのか(あるいは単に利便性のためか)と考えていました。
手続き型は`return`文という手続きを踏んで値を返し、関数型は関数と戻り値が等価なので
戻り値を書くのみの文法にしている、という対応付けができそうだと思っています。

### Early returns
その`return`文ですが、マルチパラダイムなRustには当然用意されています。

```rust
fn foo(x: i32) -> i32 {
    return x;
    x + 1 // we never run this line
}
```

このように書くと`return`で関数を抜けるという、慣れ親しんだ動作をするようです。

### Diverging functions
Rustには、'diverging functions'という特殊な関数があるそうです。
まず、syntaxは以下のとおりです。

```rust
fn diverges() -> ! {
    panic!("This function never returns!");
}
```

`panic!()`はmacroの一つで、実行されるとそのスレッドがクラッシュします。
この関数を呼ぶとクラッシュして値を返さないので、戻り値に`!`を書く、
これが'diverging functions'というわけです。
例外を投げるということでしょうね。catch方法はまだわかりませんが。

`panic!()`が実行されると、

```console
thread ‘<main>’ panicked at ‘This function never returns!’, hello.rs:2
```

のような出力を得ます。`panic!()`した、という情報だけでいいなら十分ですが、
`RUST_BACKTRACE`という環境変数を設定すると、バックトレース情報がいっしょに出力されます。

```console
$ RUST_BACKTRACE=1 ./diverges
thread '<main>' panicked at 'This function never returns!', hello.rs:2
stack backtrace:
   1:     0x7f402773a829 - sys::backtrace::write::h0942de78b6c02817K8r
   2:     0x7f402773d7fc - panicking::on_panic::h3f23f9d0b5f4c91bu9w
   3:     0x7f402773960e - rt::unwind::begin_unwind_inner::h2844b8c5e81e79558Bw
   4:     0x7f4027738893 - rt::unwind::begin_unwind::h4375279447423903650
   5:     0x7f4027738809 - diverges::h2266b4c4b850236beaa
   6:     0x7f40277389e5 - main::h19bb1149c2f00ecfBaa
   7:     0x7f402773f514 - rt::unwind::try::try_fn::h13186883479104382231
   8:     0x7f402773d1d8 - __rust_try
   9:     0x7f402773f201 - rt::lang_start::ha172a3ce74bb453aK5w
  10:     0x7f4027738a19 - main
  11:     0x7f402694ab44 - __libc_start_main
  12:     0x7f40277386c8 - <unknown>
  13:                0x0 - <unknown>
```

`main()`から呼んだ`diverges()`で`panic!()`していることが読み取れます。
この環境変数は`cargo run`にも使えるそうです。

奇妙なことに、diverging functionはどんな型にも代入できるようです。

```rust
let x: i32 = diverges();
let x: String = diverges();
```

これどういう意味があるんでしょう？

### Function pointers
関数をvariable bindingに代入することもできます。

```rust
fn plus_one(i: i32) -> i32 {
    i + 1
}

let f: fn(i32) -> i32 = plus_one; // 明示的な型指定
let f = plus_one; // 型推論
let six = f(5);
```

簡単ですね。

---

今回はこれで終わりです。

すこしRustを書いていて感じたことに、コンパイラによる警告が優秀というのがあります。
不必要なvariable bindingの宣言や`mut`指定はもちろんのこと、
例えば `let mut x = 5; x = 6;`のように、代入した値を使わずすぐ代入しなおしているコードも
拾って警告してくれました。
最適化したコードを書く助けになりそうです。
