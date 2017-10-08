+++
date = "2016-01-06"
title = "Learning Rust - Lifetime"
tags = ["Programming", "Rust"]
+++

# Syntax and Semantics
## Lifetimes
ずっと後回しにしてきましたが、今回はlifetimeを扱います。
Rustのlifetimeは、リソースの寿命に名前をつけて明確にし、
dangling pointerと、それによるuse after freeを防ぐ仕組みです。

例えば、関数にある参照`a`を渡し、それにリソースを生成し、その参照`b`を返す場合、
`a`の有効範囲は、`b`の有効範囲を包含していなくてはなりません。
さもないと、`a`が不正な参照になった後(dangling pointer)にも、
`a`と同時に不正になった`b`がつかわれてしまう(use after free)からです。

さて、まずはlifetimeに名前をつけるところから始めます。

Lifetimeを気にしないといけないのは、まずは関数を使うときです。
これまでlifetimeが表舞台には登場してこなかったように、
多くの場合、lifetimeの記述は省略できます(後述)。
省略しない場合は、genericsの型パラメータと同じ所に記述します。

```rust
// implicit
fn foo(x: &i32) {
}

// explicit
fn bar<'a>(x: &'a i32) {
}
```

Lifetimeは、`'a`のように、単一の`'`のあとになんらかの名前をつけてあらわします。
二つ以上指定したり、`mut`と同時に使うときなどは次のようになります。

```rust
fn foo<'a, 'b>(x: &'a i32, y: &'b i32) { ... }
fn bar<'a>(x: &'a mut i32) { ... }
```

戻り値にもlifetimeが指定できます。

```rust
fn x_or_y<'a>(x: &'a str, y: &'a str) -> &'a str { ... }
fn x_or_y<'a, 'b>(x: &'a str, y: &'b str) -> &'a str { ... }
```

ひとつ目は、`x, y`が同じlifetimeをもち、さらに戻り値も同じになります。
ふたつ目は、`x, y`が別々のlifetimeをもて、戻り値は`x`と同じlifetimeをもちます。

なお、参照ではないものにはlifetimeは必要ありません。

### In `struct`s
Structにもlifetimeを指定できます。
フィールドが参照の場合、そのlifetimeを決定するためです。

```rust
struct Foo<'a> {
    x: &'a i32,
}

fn main() {
    let y = &5; // this is the same as `let _y = 5; let y = &_y;`
    let f = Foo { x: y };

    println!("{}", f.x);
}
```

この場合、`f.x`は`y`と同じlifetimeを持ちます。

メソッドをimplする際のsyntaxは、genericsのときと同じです。
`impl`とstruct名両方に`<>`で囲ってlifetimeを記述します。

```rust
impl<'a> Foo<'a> {
    fn x(&self) -> &'a i32 { self.x }
}
```

### Thinking in scopes
Lifetimeは、言ってしまえば参照変数の有効範囲に名前をつけただけです。
この有効範囲はソースコードの領域として可視化できます。

まず、関数ローカルに参照を定義します。
この参照のlifetimeは、この関数を抜けるまでです。

```rust
fn main() {
    let y = &5;     // -+ y goes into scope
                    //  |
    // stuff        //  |
                    //  |
}                   // -+ y goes out of scope
```

参照をフィールドにもつstructを定義し、先ほどの参照でコンストラクトします。
Struct`f`のlifetimeは、渡された`y`のlifetimeと同じ、つまり関数を抜けるまでです。

```rust
struct Foo<'a> {
    x: &'a i32,
}

fn main() {
    let y = &5;           // -+ y goes into scope
    let f = Foo { x: y }; // -+ f goes into scope
    // stuff              //  |
                          //  |
}                         // -+ f and y go out of scope
```

この`y`と`f`を新たにスコープでくくると、`y, f`のlifetimeはそのスコープに狭まります。
このスコープ外に参照変数を用意して、`f.x`を指すようにすると......

```rust
struct Foo<'a> {
    x: &'a i32,
}

fn main() {
    let x;                    // -+ x goes into scope
                              //  |
    {                         //  |
        let y = &5;           // ---+ y goes into scope
        let f = Foo { x: y }; // ---+ f goes into scope
        x = &f.x;             //  | | error here
    }                         // ---+ f and y go out of scope
                              //  |
    println!("{}", x);        //  |
}                             // -+ x goes out of scope
```

`f.x`は狭いスコープでlifetimeが切れますが、それを指す`x`のlifetimeは続いています。
ここでdangling pointerが起こっています。
Rustコンパイラはこれを見逃さず、エラーメッセージを吐くことになります。

### `'static`
`'static`という特別なlifetimeがあります。
名前からわかるように、このlifetimeは、プログラムの初めから終わりまでです。

以前にでてきましたが、文字列リテラルは`'static`lifetimeを持ちます。
他には、グローバルに定義した`static`変数を指す参照は、`'static`lifetimeを指定できます。

```rust
let x: &'static str = "Hello, world.";

static FOO: i32 = 5;
let x: &'static i32 = &FOO;
```

### Lifetime Elision
上述したように、関数定義においてlifetimeの記述は多くの場合省略できます。
この、「多くの場合」というのが、次で述べる3つのルールに当てはまる場合です。

ルールについて説明する前に、関数定義におけるlifetimeには二種類あることを説明します。
'Input lifetime'と'output lifetime'です。
その名の通り、input lifetimeは参照型の引数がもつlifetimeで、
output lifetimeは戻り値がもつlifetimeです。

```rust
fn foo<'a>(bar: &'a str) { ... }
fn foo<'a>() -> &'a str { ... }
fn foo<'a>(bar: &'a str) -> &'a str { ... }
```

ひとつ目の例では、input lifetimeがひとつ、
ふたつ目の例では、output lifetimeがひとつ、
みっつ目の例では、同一のinput lifetimeとoutput lifetimeがひとつずつあります。

そして、lifetimeが省略できる場合の3つのルールというのが以下になります。

1. 省略されたlifetimeは、それぞれが別名のlifetimeをあらわす。
1. (省略されたかどうかに関わらず)ちょうどひとつのinput lifetimeがあるとき、
   省略されたoutput lifetimeは、そのinput lifetimeと同一になる。
1. Input lifetimeが複数あり、そのうちひとつが`&self`または`&mut self`のとき
   (つまりstructのメソッドのとき)、
   省略されたoutput lifetimeは`self`と同じlifetimeになる。

これらに当てはまらないときは、output lifetimeを省略できません。
明示的に指定する必要があります。

### Examples
3つのルールに従って、省略されたlifetimeは実際にはどのように推論されるか見てみましょう。

```rust
fn substr(s: &str, until: u32) -> &str; // elided
fn substr<'a>(s: &'a str, until: u32) -> &'a str; // expanded
```

Input lifetmeがひとつなので、ルール2.によって、
output lifetimeはinput lifetimeとおなじになります。

```rust
fn get_str() -> &str; // ILLEGAL, no inputs
```

この例はどのルールにも当てはまらないので、output lifetimeを省略できません。
コンパイルエラーになります。

```rust
fn frob(s: &str, t: &str) -> &str; // ILLEGAL, two inputs
fn frob<'a, 'b>(s: &'a str, t: &'b str) -> &str; // Expanded: Output lifetime is ambiguous
```

まず、ルール1.によって`s`と`t`には別々のlifetimeが推論されます。
しかし、input lifetimeが複数あるにも関わらず、どれも`&self, &mut self`ではないので、
output lifetimeを省略できません。

```rust
fn args<T:ToCStr>(&mut self, args: &[T]) -> &mut Command; // elided
fn args<'a, 'b, T:ToCStr>(&'a mut self, args: &'b [T]) -> &'a mut Command; // expanded
```

ルール1.によって、`&mut self`と`args`は別々のlifetimeを持ちます。
Input lifetimeの一つが`&mut self`なので、ルール3.によって、戻り値のlifetimeは、
`&mut self`と同じになります。

---

おもったほど難しくはありませんでしたね。
Lifetimeについては以上です。
同時に、Rustのsyntax and semaiticsについて学ぶのは今回で最後にしようと思います。
まだ[公式リファレンスのsyntax and semantics部](https://doc.rust-lang.org/stable/book/syntax-and-semantics.html)
には、

* Crates and Modules
* Macros
* Raw pointers
* 'unsafe'

が残っていますが、最初の二つは長いので読むだけにしておきたいし、
残り二つはなるべく使わないようにするほうがいいでしょう。
FFIなどで必要になりそうですが、しばらくは触れないでおきます。
