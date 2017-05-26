+++
date = "2015-11-11"
title = "Learning Rust - Dining Philosophers"
tags = ["Programming", "Rust"]
+++

# Learn Rust
前回扱うつもりで飛ばしてしまった、overview的なチュートリアル"Dining Philosophers"
を扱います。

## Dining Philosophers
並列計算に関する問題です。かのDijkstraの提示した問題をもとにした有名な話ですが、
設定を確認しておきます。

> In ancient times, a wealthy philanthropist endowed a College to accommodate five eminent philosophers. Each philosopher had a room in which they could engage in their professional activity of thinking; there was also a common dining room, furnished with a circular table, surrounded by five chairs, each labelled by the name of the philosopher who was to sit in it. They sat anticlockwise around the table. To the left of each philosopher there was laid a golden fork, and in the centre stood a large bowl of spaghetti, which was constantly replenished. A philosopher was expected to spend most of their time thinking; but when they felt hungry, they went to the dining room, sat down in their own chair, picked up their own fork on their left, and plunged it into the spaghetti. But such is the tangled nature of spaghetti that a second fork is required to carry it to the mouth. The philosopher therefore had also to pick up the fork on their right. When they were finished they would put down both their forks, get up from their chair, and continue thinking. Of course, a fork can be used by only one philosopher at a time. If the other philosopher wants it, they just have to wait until the fork is available again.
--- [C.A.R.Hoare _Communicating Sequential Process_ June 21, 2004](http://www.usingcsp.com/cspbook.pdf)

テーブルを5人の哲学者が囲んでいます。
各人の左にはフォークが一つずつ、合計5本置いてあります。
彼らはこれを一本使って、テーブル中央におかれたスパゲッティ皿からフォークを使って手元に運び、
さらにもう一本で口に運びます。
哲学者は満腹になったらフォークをおき、部屋に戻って思索に耽ります。
もちろんそれぞれのフォークはひとりずつしか使えないので、
使おうとしたフォークが別の哲学者に使われていた場合、
フォークがまた使えるようになるまで待たなくてはなりません。

哲学者が食事を続けられるようにするためにはどうすればいいでしょうか。
単純なアルゴリズムとして、次が考えられます。

1. 哲学者が左にあるフォークを取る。
1. 続いて右にあるフォークを取る。
1. 食事をする。
1. 終わったら2本のフォークを置く。

このアルゴリズムはちゃんと動くでしょうか？
例えば次のような場合を考えてみましょう。

1. 哲学者1が食事を始める。彼は左にあるフォークを取る。
1. 哲学者2が食事を始める。彼は左にあるフォークを取る。
1. 哲学者3が食事を始める。彼は左にあるフォークを取る。
1. 哲学者4が食事を始める。彼は左にあるフォークを取る。
1. 哲学者5が食事を始める。彼は左にあるフォークを取る。
1. ...？誰もが右側のフォークを求めて待ち続けるようになってしまいました。

この問題の解決策はいくつかあります。たとえば[Wikipedia](https://ja.wikipedia.org/wiki/%E9%A3%9F%E4%BA%8B%E3%81%99%E3%82%8B%E5%93%B2%E5%AD%A6%E8%80%85%E3%81%AE%E5%95%8F%E9%A1%8C#cite_note-1)
を見てください。

このチュートリアルでは独自の解放をとっているようです。
まずは問題をモデル化していきます。

```rust
struct Philosopher {
    name: String,
}

impl Philosopher {
    fn new(name: &str) -> Philosopher {
        Philosopher {
            name: name.to_string(),
        }
    }
}

fn main() {
    let p1 = Philosopher::new("Baruch Spinoza");
    let p2 = Philosopher::new("Gilles Deleuze");
    let p3 = Philosopher::new("Karl Marx");
    let p4 = Philosopher::new("Friedrich Nietzsche");
    let p5 = Philosopher::new("Michel Foucault");
}
```

哲学者を表す構造体を作っているようです。
`struct`と`impl`がありますが、`structは`メンバ変数だけ、
`impl`はメンバ関数を定義しています。
このように、構造と定義を別々に書くことができるということでしょうか？

ともかく、`Philosopher`構造体は、`String`型の`name`メンバと
`new()`メンバ関数をもっていることがわかります。

C++に引っ張られてメンバ関数と言ってしまいましたが、`new()`は'associated function'と呼ぶようです。
staticメンバ関数のようなものでしょうか。
`new()`関数は`&str`つまり文字列の参照を受け取り、
`to_string()`によってそのコピーを取り、`name`に代入しています。
`new`という名前は構造体の新しいインスタンスを作るときによく使われるそうです。といっても、Pythonのように名前が限定されているわけではないようです。あくまで習慣というわけですね。

`String`を直接受け取らないのは、
呼び出し元で`to_string()`を呼ばなくていいようにするためだそうです。

この関数でも、`return`は使わずexpressionを最後に書いて戻り値としていますね。

そして`main()`で`new()`を呼び、哲学者を5人登場させています。
構造体のassociated functionにアクセスするときは`::`を使うようです。

基礎となる構造ができたので、実際の動作を付け加えていきます。

まずは哲学者に食事をさせるところからです。

```rust
use std::thread;

struct Philosopher {
    name: String,
}

impl Philosopher {
    fn new(name: &str) -> Philosopher {
        Philosopher {
            name: name.to_string(),
        }
    }

    fn eat(&self) {
        println!("{} is eating.", self.name);

        thread::sleep_ms(1000);

        println!("{} is done eating.", self.name);
    }
}

fn main() {
    let philosophers = vec![
        Philosopher::new("Judith Butler"),
        Philosopher::new("Gilles Deleuze"),
        Philosopher::new("Karl Marx"),
        Philosopher::new("Emma Goldman"),
        Philosopher::new("Michel Foucault"),
    ];

    for p in &philosophers {
        p.eat();
    }
}
```

まず`main()`を見てみると、哲学者たちを`vec!`で作ることにしました。
`vec!`はmacroの一つで、`Vec<T>`という型のvectorを作るようです。
おそらく`<T>`はC++のtemplateのようなものでしょうね。
このvectorを`for`ループで走査し、`p`に参照を代入しています。

`Philosopher`構造体に新たに`eat()`関数をつくりました。
Rustではassociated functionでなく、インスタンスに紐付いたmethodを作る場合、
`self`の参照を明示的に受け取るようにするようです。
`eat()`関数のなかでは、`self`を通して`name`にアクセスしています。

さらに、`eat()`に時間をかけて実際に食べているようにするために、
`thread::sleep_ms()`関数を使いました。
これを使うためには、`use std::thread;`としてincludeする必要があるようです。

このコードはまだシングルスレッドです。
つまり哲学者たちはひとりずつしか食事ができません。
マルチスレッドにしてみましょう。

```rust
let philosophers = vec![
    // 略
];

let handles: Vec<_> = philosophers.into_iter().map(|p| {
    thread::spawn(move || {
        p.eat();
    })
}).collect();

for h in handles {
    h.join.unwrap();
}
```

`handles`というvariable bindingをつくっています。
新しく作ったスレッドを扱うハンドルという意味だそうです。

少しずつ見ていきます。

```rust
philosophers.into_iter().map(|p| {
```

`into_iter()`関数は、哲学者のownershipをとるイテレータを生成します。
さらに各イテレータに対して`map()`関数でclosureを渡し、呼び出しているようです。

```rust
thread::spawn(move || {
    p.eat();
})
```

ここでスレッドが作られ、並列に実行されます。
`thread::spawn()`関数はclosureを一つとり、新しいスレッドをつくってそれを実行するそうです。
ここでは`move`というアノテーションを書いています。
これによって、キャプチャした値、すなわち`p`のownershipがclosure内に移動するようです。

ここでも`thread::spawn()`にセミコロン`;`をつけず、expressionとして戻り値を返しています。

```rust
}).collect();
```

最後に`collect()`を呼んでいます。
この関数は`map()`の結果をまとめ、'collection of some kind'を作りますが、
どんな型にまとめるかの情報が必要になります。
それが`handles`を定義するときに型注釈として書いた`Vec<_>`というわけです。
`collect()`の戻り値をvectorに指定するが、その内部の型はRustの型推論で決めよ、ということらしいです。

`for`ループも変わっています。
操作するのはスレッドを扱う`handles`になり、ループ内部ではそれを`join()`しています。
`unwrap()`については現時点ではよくわかりません。

ともかく、これでマルチスレッドができました。
実行してみると、例えば以下のような出力になり、並列に実行されていることが確認できます。

```
Judith Butler is eating.
Gilles Deleuze is eating.
Karl Marx is eating.
Emma Goldman is eating.
Michel Foucault is eating.
Judith Butler is done eating.
Gilles Deleuze is done eating.
Karl Marx is done eating.
Emma Goldman is done eating.
Michel Foucault is done eating.
```

さて、フォークをモデル化するのを忘れていました。
新しい`struct`を追加します。


```rust
use std::sync::Mutec;

struct Table {
    forks: Vec<Mutex<()>>,
}
```

フォークをmutexとみなし、それが置いてある`Table`をつくりました。
`Mutex`には内部の型を指定するようですが、今回は内部の値を使用するわけではないので、単に空tuple`()`としています。

この`Table`を組み込みましょう。

<script src="https://gist.github.com/ordovicia/dc901d08604244798219.js"></script>

順に見ていきます。

まず`std::sync::Arc`もincludeします。
`std::sync`内のものを複数includeするときはこんな書き方もできるんですね。

```rust
struct Philosopher {
    name: String,
    left: usize,
    right: usize,
}
```

`Philosopher`構造体に二つのフィールドを追加しました。
`left, right`がそれぞれフォークを表します。
型が`usize`となっているのは、フォークのvectorのindexを受け取るためのようです。

```rust
    fn new(name: &str, left: usize, right: usize) -> Philosopher {
        Philosopher {
            name: name.to_string(),
            left: left,
            right: right,
        }
    }
```

`Philosopher::new()`も書き直します。使用するフォークのindexをとるようにしました。

```rust
    fn eat(&self, table: &Table) {
        let _left = table.forks[self.left].lock().unwrap();
        let _right = table.forks[self.right].lock().unwrap();

        println!("{} is eating.", self.name);

        thread::sleep_ms(1000);

        println!("{} is done eating.", self.name);
    }
```

`eat()`関数は、フォークの`Table`の参照をとって、先ほど追加した`left, right`をindexとするmutexを`lock()`するようにしました。
また`unwrap()`がでてきましたが、詳しい説明はされていませんでした。

さて、こうして得たロックを`_left, _right`というvariable bindingに代入しています。
アンダーバー`_`をつけると、このvariable bindingは未使用であるとの印になり、
コンパイラの警告を抑制できると書いてありました。

そしてロック解除は、スコープを抜けて`_left, _right`が破棄されるとき自動でおこなわれるようです。
C++でいうデストラクタの処理ですね。

`main()`内に入っていきます。

```rust
let table = Arc::new(Table { forks: vec![
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
]});
```

`Table`構造体のインスタンス`table`をつくりました。
'arc'は'atomic reference count'の略で、`table`を複数スレッドで扱うため、
`Arc`としてつくっているようです。
`table`を共有するごとに参照カウンタが増え、スレッドを抜けると減る、という仕組みです。

```rust
let philosophers = vec![
    Philosopher::new("Judith Butler", 0, 1),
    Philosopher::new("Gilles Deleuze", 1, 2),
    Philosopher::new("Karl Marx", 2, 3),
    Philosopher::new("Emma Goldman", 3, 4),
    Philosopher::new("Michel Foucault", 0, 4),
];
```

`Philosopher::new()`にフォークのindexも加えて渡すようにしました。
ここで注意したいのが、最後の`Michel Foucault`に渡すindexが、
`4, 0`ではなく`0, 4`になっていることです。
もし`4, 0`にすると、冒頭のデッドロックが起きてしまいます。
# Learn Rust
前回扱うつもりで飛ばしてしまった、overview的なチュートリアル"Dining Philosophers"
を扱います。

## Dining Philosophers
並列計算に関する問題です。かのDijkstraの提示した問題をもとにした有名な話ですが、
設定を確認しておきます。

> In ancient times, a wealthy philanthropist endowed a College to accommodate five eminent philosophers. Each philosopher had a room in which they could engage in their professional activity of thinking; there was also a common dining room, furnished with a circular table, surrounded by five chairs, each labelled by the name of the philosopher who was to sit in it. They sat anticlockwise around the table. To the left of each philosopher there was laid a golden fork, and in the centre stood a large bowl of spaghetti, which was constantly replenished. A philosopher was expected to spend most of their time thinking; but when they felt hungry, they went to the dining room, sat down in their own chair, picked up their own fork on their left, and plunged it into the spaghetti. But such is the tangled nature of spaghetti that a second fork is required to carry it to the mouth. The philosopher therefore had also to pick up the fork on their right. When they were finished they would put down both their forks, get up from their chair, and continue thinking. Of course, a fork can be used by only one philosopher at a time. If the other philosopher wants it, they just have to wait until the fork is available again.
--- [C.A.R.Hoare _Communicating Sequential Process_ June 21, 2004](http://www.usingcsp.com/cspbook.pdf)

テーブルを5人の哲学者が囲んでいます。
各人の左にはフォークが一つずつ、合計5本置いてあります。
彼らはこれを一本使って、テーブル中央におかれたスパゲッティ皿からフォークを使って手元に運び、
さらにもう一本で口に運びます。
哲学者は満腹になったらフォークをおき、部屋に戻って思索に耽ります。
もちろんそれぞれのフォークはひとりずつしか使えないので、
使おうとしたフォークが別の哲学者に使われていた場合、
フォークがまた使えるようになるまで待たなくてはなりません。

哲学者が食事を続けられるようにするためにはどうすればいいでしょうか。
単純なアルゴリズムとして、次が考えられます。

1. 哲学者が左にあるフォークを取る。
1. 続いて右にあるフォークを取る。
1. 食事をする。
1. 終わったら2本のフォークを置く。

このアルゴリズムはちゃんと動くでしょうか？
例えば次のような場合を考えてみましょう。

1. 哲学者1が食事を始める。彼は左にあるフォークを取る。
1. 哲学者2が食事を始める。彼は左にあるフォークを取る。
1. 哲学者3が食事を始める。彼は左にあるフォークを取る。
1. 哲学者4が食事を始める。彼は左にあるフォークを取る。
1. 哲学者5が食事を始める。彼は左にあるフォークを取る。
1. ...？誰もが右側のフォークを求めて待ち続けるようになってしまいました。

この問題の解決策はいくつかあります。たとえば[Wikipedia](https://ja.wikipedia.org/wiki/%E9%A3%9F%E4%BA%8B%E3%81%99%E3%82%8B%E5%93%B2%E5%AD%A6%E8%80%85%E3%81%AE%E5%95%8F%E9%A1%8C#cite_note-1)
を見てください。

このチュートリアルでは独自の解放をとっているようです。
まずは問題をモデル化していきます。

```rust
struct Philosopher {
    name: String,
}

impl Philosopher {
    fn new(name: &str) -> Philosopher {
        Philosopher {
            name: name.to_string(),
        }
    }
}

fn main() {
    let p1 = Philosopher::new("Baruch Spinoza");
    let p2 = Philosopher::new("Gilles Deleuze");
    let p3 = Philosopher::new("Karl Marx");
    let p4 = Philosopher::new("Friedrich Nietzsche");
    let p5 = Philosopher::new("Michel Foucault");
}
```

哲学者を表す構造体を作っているようです。
`struct`と`impl`がありますが、`structは`メンバ変数だけ、
`impl`はメンバ関数を定義しています。
このように、構造と定義を別々に書くことができるということでしょうか？

ともかく、`Philosopher`構造体は、`String`型の`name`メンバと
`new()`メンバ関数をもっていることがわかります。

C++に引っ張られてメンバ関数と言ってしまいましたが、`new()`は'associated function'と呼ぶようです。
staticメンバ関数のようなものでしょうか。
`new()`関数は`&str`つまり文字列の参照を受け取り、
`to_string()`によってそのコピーを取り、`name`に代入しています。
`new`という名前は構造体の新しいインスタンスを作るときによく使われるそうです。といっても、Pythonのように名前が限定されているわけではないようです。あくまで習慣というわけですね。

`String`を直接受け取らないのは、
呼び出し元で`to_string()`を呼ばなくていいようにするためだそうです。

この関数でも、`return`は使わずexpressionを最後に書いて戻り値としていますね。

そして`main()`で`new()`を呼び、哲学者を5人登場させています。
構造体のassociated functionにアクセスするときは`::`を使うようです。

基礎となる構造ができたので、実際の動作を付け加えていきます。

まずは哲学者に食事をさせるところからです。

```rust
use std::thread;

struct Philosopher {
    name: String,
}

impl Philosopher {
    fn new(name: &str) -> Philosopher {
        Philosopher {
            name: name.to_string(),
        }
    }

    fn eat(&self) {
        println!("{} is eating.", self.name);

        thread::sleep_ms(1000);

        println!("{} is done eating.", self.name);
    }
}

fn main() {
    let philosophers = vec![
        Philosopher::new("Judith Butler"),
        Philosopher::new("Gilles Deleuze"),
        Philosopher::new("Karl Marx"),
        Philosopher::new("Emma Goldman"),
        Philosopher::new("Michel Foucault"),
    ];

    for p in &philosophers {
        p.eat();
    }
}
```

まず`main()`を見てみると、哲学者たちを`vec!`で作ることにしました。
`vec!`はmacroの一つで、`Vec<T>`という型のvectorを作るようです。
おそらく`<T>`はC++のtemplateのようなものでしょうね。
このvectorを`for`ループで走査し、`p`に参照を代入しています。

`Philosopher`構造体に新たに`eat()`関数をつくりました。
Rustではassociated functionでなく、インスタンスに紐付いたmethodを作る場合、
`self`の参照を明示的に受け取るようにするようです。
`eat()`関数のなかでは、`self`を通して`name`にアクセスしています。

さらに、`eat()`に時間をかけて実際に食べているようにするために、
`thread::sleep_ms()`関数を使いました。
これを使うためには、`use std::thread;`としてincludeする必要があるようです。

このコードはまだシングルスレッドです。
つまり哲学者たちはひとりずつしか食事ができません。
マルチスレッドにしてみましょう。

```rust
let philosophers = vec![
    // 略
];

let handles: Vec<_> = philosophers.into_iter().map(|p| {
    thread::spawn(move || {
        p.eat();
    })
}).collect();

for h in handles {
    h.join.unwrap();
}
```

`handles`というvariable bindingをつくっています。
新しく作ったスレッドを扱うハンドルという意味だそうです。

少しずつ見ていきます。

```rust
philosophers.into_iter().map(|p| {
```

`into_iter()`関数は、哲学者のownershipをとるイテレータを生成します。
さらに各イテレータに対して`map()`関数でclosureを渡し、呼び出しているようです。

```rust
thread::spawn(move || {
    p.eat();
})
```

ここでスレッドが作られ、並列に実行されます。
`thread::spawn()`関数はclosureを一つとり、新しいスレッドをつくってそれを実行するそうです。
ここでは`move`というアノテーションを書いています。
これによって、キャプチャした値、すなわち`p`のownershipがclosure内に移動するようです。

ここでも`thread::spawn()`にセミコロン`;`をつけず、expressionとして戻り値を返しています。

```rust
}).collect();
```

最後に`collect()`を呼んでいます。
この関数は`map()`の結果をまとめ、'collection of some kind'を作りますが、
どんな型にまとめるかの情報が必要になります。
それが`handles`を定義するときに型注釈として書いた`Vec<_>`というわけです。
`collect()`の戻り値をvectorに指定するが、その内部の型はRustの型推論で決めよ、ということらしいです。

`for`ループも変わっています。
操作するのはスレッドを扱う`handles`になり、ループ内部ではそれを`join()`しています。
`unwrap()`については現時点ではよくわかりません。

ともかく、これでマルチスレッドができました。
実行してみると、例えば以下のような出力になり、並列に実行されていることが確認できます。

```
Judith Butler is eating.
Gilles Deleuze is eating.
Karl Marx is eating.
Emma Goldman is eating.
Michel Foucault is eating.
Judith Butler is done eating.
Gilles Deleuze is done eating.
Karl Marx is done eating.
Emma Goldman is done eating.
Michel Foucault is done eating.
```

さて、フォークをモデル化するのを忘れていました。
新しい`struct`を追加します。


```rust
use std::sync::Mutec;

struct Table {
    forks: Vec<Mutex<()>>,
}
```

フォークをmutexとみなし、それが置いてある`Table`をつくりました。
`Mutex`には内部の型を指定するようですが、今回は内部の値を使用するわけではないので、単に空tuple`()`としています。

この`Table`を組み込みましょう。

<script src="https://gist.github.com/ordovicia/dc901d08604244798219.js"></script>

順に見ていきます。

まず`std::sync::Arc`もincludeします。
`std::sync`内のものを複数includeするときはこんな書き方もできるんですね。

```rust
struct Philosopher {
    name: String,
    left: usize,
    right: usize,
}
```

`Philosopher`構造体に二つのフィールドを追加しました。
`left, right`がそれぞれフォークを表します。
型が`usize`となっているのは、フォークのvectorのindexを受け取るためのようです。

```rust
    fn new(name: &str, left: usize, right: usize) -> Philosopher {
        Philosopher {
            name: name.to_string(),
            left: left,
            right: right,
        }
    }
```

`Philosopher::new()`も書き直します。使用するフォークのindexをとるようにしました。

```rust
    fn eat(&self, table: &Table) {
        let _left = table.forks[self.left].lock().unwrap();
        let _right = table.forks[self.right].lock().unwrap();

        println!("{} is eating.", self.name);

        thread::sleep_ms(1000);

        println!("{} is done eating.", self.name);
    }
```

`eat()`関数は、フォークの`Table`の参照をとって、先ほど追加した`left, right`をindexとするmutexを`lock()`するようにしました。
また`unwrap()`がでてきましたが、詳しい説明はされていませんでした。

さて、こうして得たロックを`_left, _right`というvariable bindingに代入しています。
アンダーバー`_`をつけると、このvariable bindingは未使用であるとの印になり、
コンパイラの警告を抑制できると書いてありました。

そしてロック解除は、スコープを抜けて`_left, _right`が破棄されるとき自動でおこなわれるようです。
C++でいうデストラクタの処理ですね。

`main()`内に入っていきます。

```rust
let table = Arc::new(Table { forks: vec![
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
    Mutex::new(()),
]});
```

`Table`構造体のインスタンス`table`をつくりました。
'arc'は'atomic reference count'の略で、`table`を複数スレッドで扱うため、
`Arc`としてつくっているようです。
`table`を共有するごとに参照カウンタが増え、スレッドを抜けると減る、という仕組みです。

```rust
let philosophers = vec![
    Philosopher::new("Judith Butler", 0, 1),
    Philosopher::new("Gilles Deleuze", 1, 2),
    Philosopher::new("Karl Marx", 2, 3),
    Philosopher::new("Emma Goldman", 3, 4),
    Philosopher::new("Michel Foucault", 0, 4),
];
```

`Philosopher::new()`にフォークのindexも加えて渡すようにしました。
ここで注意したいのが、最後の`Michel Foucault`に渡すindexが、
`4, 0`ではなく`0, 4`になっていることです。
もし`4, 0`にすると、冒頭のデッドロックが起きてしまいます。

```rust
let handles: Vec<_> = philosophers.into_iter().map(|p| {
    let table = table.clone();

    thread::spawn(move || {
        p.eat(&table);
    })
}).collect();
```

最後に、`map()`に渡すclosure内で`table`を`clone()`しています。
`Arc<T>`型のインスタンスに対して`clone()`すると、参照カウンタが増えるとのことです。

これで解決です。哲学者たちはデッドロックに陥らず、食事を続けられるようになりました。
ちょっと工夫するだけで簡単に問題解決しちゃいました。

```rust
let handles: Vec<_> = philosophers.into_iter().map(|p| {
    let table = table.clone();

    thread::spawn(move || {
        p.eat(&table);
    })
}).collect();
```

最後に、`map()`に渡すclosure内で`table`を`clone()`しています。
`Arc<T>`型のインスタンスに対して`clone()`すると、参照カウンタが増えるとのことです。

これで解決です。哲学者たちはデッドロックに陥らず、食事を続けられるようになりました。
