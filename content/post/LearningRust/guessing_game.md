+++
date = "2015-11-07T13:00:00+09:00"
title = "Learning Rust - Guessing Game"
tags = ["Programming", "Rust"]
+++

[公式ドキュメント](https://doc.rust-lang.org/book/README.html)
にしたがってRustを学んでいこうと思います。

# Learn Rust
Rustのoverview的なチュートリアルです。

* Guessing Game
* Dining Philosophers
* Rust Inside Other Language

という3つの節がありますが、このうち最初の二つを読んでみます。
今回はGuessing Gameです。

## Guessing Game
よくある、ランダムな数値をあてるゲームですね。
数値を推測して入力するごとに、答えより大きい・小さいかが出力されるようにします。

### Processing a Guess
まずはユーザーが入力した数値を出力してみます。コードは以下のようになります。

```rust
use std::io;

fn main() {
    println!("Guess the number!");

    println!("Please input your guess.");

    let mut guess = String::new();

    io::stdin().read_line(&mut guess)
        .ok()
        .expect("Failed to read line");

    println!("You guessed: {}", guess);
}
```

C++とあんまり変わりませんね。

variable binding(変数、と言ってしまうとRustでのデータの扱いを正しく表現できないので、
     無理に訳さずそのままの名前をつかいます)をつくるにはlet statementを使います。
Rustでのvariable bindingはデフォルトでconstantなので、`guess`は明示的に`mut`指定
します。

入力を受付けているところ、`read_line(&mut guess)`についてですが、この関数は
`&mut String`を引数にとるようです。
mutableな`String`の参照ということらしいです。

Rustではデータのownershipという概念が重要で、あるデータをownするvariable binding
はたったひとつしか許されないということのようです。
強い制約ですが安全性の強化や内部でのメモリ管理に役立っているのでしょう。

`read_line()`の戻り値にさらにメソッドを作用させています。

```rust
.ok()
.expect("Failed to read line");
```

なんでしょうねこれ。一見すると例外処理のようですが。
ドキュメントを読み進めると、まさにその通りでした。

`read_line()`関数は`io::Result`という型の値を返します。
この型は`ok()`メソッドをもっていて、受け取った値が'ok'でなければ`expect()`によって
プログラムが終了し例外メッセージが吐かれる、ということのようです。

最後の行です。

```rust
println!("You guessed: {}", guess);
```

出力しています。`println!()`はmacroで、`!`がmacroであることの印である、
と書いてありました。
ただしCのようなmacroではなく、型安全性に不安をもつ必要はないそうです。

`{}`がplaceholderで、ここに`guess`の中身が挿入されるというわけらしいです。
フォーマットが書きやすい`printf()`と、型推論してくれる`std::cout <<`の
いいとこ取りと言った感じですね。

ここまででvariable bindingの作り方と入出力がわかりました。
次はランダムな数値を作って当てるまでループしてみます。

### Generating a secret number
ランダムな数値を生成するには、開発チームが提供しているパッケージを使います。
rand crateといって、crateはRustコードのパッケージを意味するそうです。

ビルドツールCargoの設定ファイル、`Cargo.toml`に以下のように書きます。

```rust
[dependencies]
rand="0.3.0"
```

そして`cargo build`するとrand crateとそれが依存しているパッケージが
githubから落ちてきました。crateはgithub上にあるんですね。おもしろいです。

ランダムな数値を生成したコードが以下になります。

```rust
extern crate rand;

use std::io;
use rand::Rng;

fn main() {
    println!("Guess the number!");

    let secret_number = rand::thread_rng().gen_range(1, 101);

    println!("The secret number is: {}", secret_number);

    // 略
}
```

crateを使うには`extern crate rand;`などと書くようですね。

`use rand::Rng`という行が加わっています。`std::io`についてはコード中に`io::stdin()`が
あったのでnamespaceのようなものかな、と思っていたのですが、`Rng`の記述はありません。
ドキュメントには'traits'をscope内にいれる、といったことが書いてあるのですが、
ここではおまじないとしておきます。

ランダムな数値を生成しているのが、

```rust
let secret_number = rand::thread_rng().gen_range(1, 101);
```

という行のようです。`rand::thread_rng()`でmain threadに乱数生成器をコピーしている
とのことです。そして`use rand::Rng`しているので`gen_range()`関数が使えると
書いてありました。
この時点で'traits'がなんなのかよくわかりませんが、とりあえず[1, 101)の乱数が
得られて`secret_number`にbindされていることは推測できます。

### Comparing guesses
さて、入力した数値と答えを比較してみます。

```rust
extern crate rand;

use std::io;
use std::cmp::Ordering;
use rand::Rng;

fn main() {
    println!("Guess the number!");

    let secret_number = rand::thread_rng().gen_range(1, 101);

    println!("The secret number is: {}", secret_number);

    println!("Please input your guess.");

    let mut guess = String::new();

    io::stdin().read_line(&mut guess)
        .ok()
        .expect("failed to read line");

    println!("You guessed: {}", guess);

    match guess.cmp(&secret_number) {
        Ordering::Less    => println!("Too small!"),
        Ordering::Greater => println!("Too big!"),
        Ordering::Equal   => println!("You win!"),
    }
}
```

`std::cmp::Ordering`という型をscopeにいれました。これで`Ordering::Less`などの
値が使えるようになります。

Rustにはパターンマッチ構文が用意されています。それが最後の5行です。

```rust
match guess.cmp(&secret_number) {
    Ordering::Less    => println!("Too small!"),
    Ordering::Greater => println!("Too big!"),
    Ordering::Equal   => println!("You win!"),
}
```

`guess`を`secret_number`の参照と`cmp`して、その戻り値を`match`構文でパターンマッチ
しているようです。
`Ordering`はEnumで、その要素には`Ordering::Less`のようにアクセスすることがわかります。
C++の`enum class`と同じですね。

実はこのコードはコンパイルエラーになります。エラーメッセージは、

```console
src/main.rs:24:21: 24:35 error: mismatched types:
 expected `&collections::string::String`,
    found `&_`
(expected struct `collections::string::String`,
    found integral variable) [E0308]
src/main.rs:24     match guess.cmp(&secret_number) {
                                   ^~~~~~~~~~~~~~
src/main.rs:24:21: 24:35 help: run `rustc --explain E0308` to see a detailed explanation
error: aborting due to previous error
Could not compile `guessing_game`.

To learn more, run the command again with --verbose.
```

のようになります。`guess.cmp()`で`mismathed types`と言われています。
`guess`は`String`型なのに、数値である`&secret_number`と比較しているのが原因のようです。

ちなみに`secret_number`は型を明示していませんでしたが、Rustには型推論があり、
ここではおそらく`i32`型になっています。
Rustの整数型には他に`i64, u32, u64`などがあるようです。

`guess`を整数に変換してみます。`read_line()`で読み込んだ後につぎの処理を加えます。

```rust
let guess: u32 = guess.trim().parse()
    .ok()
    .expect("Please type a number!");
```

なんと`guess`をもういちど作っています。Rustでは同名のvariable bindingを作ることができ、
古いものを隠せるようです。便利ですね。

ここでは型を明示して`guess`を作っています。`let guess: u32`のように、コロン`:`のあとに
型を書くようです。Haskellを思い出しました。

数値に変換するには`trim().parse()`します。`trim()`で文字列前後の空白や改行文字を取り除き、
`parse()`で変換しているようです。
`parse()`も失敗することがあるので、`read_line()`と同じく例外処理をおこなっています。

これでコンパイルエラーが直りました。`cargo run`で実行してみると、答えと入力に合わせて
`Too small!`, `Too big!`, `You win!`のどれかが正しく表示されているのがわかります。

### Looping
最後に、正解するまでループするようにしてみましょう。
`loop`キーワードを使うと無限ループを作ることができます。

```rust
extern crate rand;

use std::io;
use std::cmp::Ordering;
use rand::Rng;

fn main() {
    println!("Guess the number!");

    let secret_number = rand::thread_rng().gen_range(1, 101);

    println!("The secret number is: {}", secret_number);

    loop {
        println!("Please input your guess.");

        let mut guess = String::new();

        io::stdin().read_line(&mut guess)
            .ok()
            .expect("failed to read line");

        let guess: u32 = guess.trim().parse()
            .ok()
            .expect("Please type a number!");

        println!("You guessed: {}", guess);

        match guess.cmp(&secret_number) {
            Ordering::Less    => println!("Too small!"),
            Ordering::Greater => println!("Too big!"),
            Ordering::Equal   => {
                println!("You win!");
                break;
            }
        }
    }
}
```

波括弧`{}`を使うのはC++と同じですね。
パターンマッチのところで、`Ordering::Equal`にマッチしたら`break`するようにしました。
簡単ですね。

入力をparseするところの例外処理を少し変更してみます。

```rust
let guess: u32 = match guess.trim().parse() {
    Ok(num) => num,
    Err(_) => continue,
};
```

ここでもパターンマッチを使います。`parse()`の戻り値`Result`型はEnumで、`Ok`と`Err`という
値をもっているようです。でも値がまた`num`などの引数をとるのでしょうか？
Haskellの型コンストラクタのようなものでしょうか？

`_`は、その中身は気にしないので単に`_`として捨てています。
`Err`だった場合は`continue`してもう一度入力を受け付ける、というわけです。

最後にひとつ、これまでデバッグ用に答えである`secret_number`を表示していましたが、
これではゲームになりません。出力していた行を消しておきます。
最終的なコードは次のようになります。

<script src="https://gist.github.com/ordovicia/9a689a281a432cfb2c2e.js"></script>

完成しました。実行してみるとちゃんと動いていることがわかります。
これにてめでたくRustデビューです。

最後にC++で書いたコードを載せておきます。

<script src="https://gist.github.com/ordovicia/7ed8c35ad2ea7deb0476.js"></script>

C++だと入力がおかしかったときの例外処理がややこしいですね。
また、Rustにはパターンマッチがあるので 条件分岐がわかりやすいと思います。
