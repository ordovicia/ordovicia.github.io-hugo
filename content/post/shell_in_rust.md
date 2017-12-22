+++
date = "2017-10-12"
title = "シェルの実装 in Rust"
tags = ["Rust", "Programming"]
+++

## 概要

Rustで簡単なシェルを書きました。
コードは [github](https://github.com/ordovicia/rush.git) にあります。

インタラクティブでのみ動作し、リダイレクトとパイプが使えます。
ビルトインコマンドは `cd` のみ実装されています。

## 入力

Readline alternativeの [linenoise](https://github.com/antirez/linenoise) を使ったことがあったので、それに似ている [rustyline](https://crates.io/crates/rustyline) を使いました。
一行読んでパーサに渡しているだけです。

## パース

パーサコンビネータの [nom](https://crates.io/crates/nom) を使いました。
だいたい以下のような文法です。

```text
arg_list     := token+

redir_in     := "<" token
redir_trunc  := ">" token
redir_append := ">>" token
redir_out    := redir_trunc
              | redir_append

proc_cdr     := arg_list proc_out?
pipe_proc    := "|" proc_cdr
proc_out     := pipe_proc
              | redir_out

proc_car     := arg_list
              | arg_list proc_out
              | arg_list redir_in proc_out?

end_job      := eof | ";" | "\n" | "\r"
job          := proc_car "&"? end_job
```

nomを使うと簡単にパーサーが書けるのですが、今回は失敗だったと思っています。
というのも、シェルはリダイレクトの位置に自由度があるからです。
例えば `cmd < file0 > file1` は `< file0 cmd > file1` とも書けます。
nomでこれに対応するのは面倒なので、今回は `cmd0 < file0 > file1` の形式（にパイプを加えたもの）のみ認識するようになっています。

シェルの文法はそんなに難しくないので、パーサーを手書きすれば自由度にうまく対処できたのではないかと思います。

## ジョブ実行

ジョブとプロセスの構造は次のようになっています。

プロセスは `Input::Pipe`, `Output::Pipe` によって他のプロセスとパイプで繋がり、`Input::Redirect`, `Input::Redirect` によってファイルリダイレクションを表しています。

```rust
pub(super) struct Job {
    process_list: process::Process,
    mode: JobMode,
}

pub(crate) struct Process {
    argument_list: Vec<String>,
    input: Input,
    output: Output,
}

pub(crate) enum Input {
    Inherit,
    Redirect(String),
    Pipe,
}

pub(crate) enum Output {
    Inherit,
    Redirect(OutputRedirect),
    Pipe(Box<Process>),
}
```

実行は `std::process` を使っています。
`Process::spawn()`, `spawn_rec()` が `Input`, `Output` に従って入出力を設定し、`spawn_one()` がspawnします。

パイプやリダイレクトから `std::process::Stdin` を作るには、生のファイルディスクリプタを経由する必要があるようです。
この操作はunsafeになっています。

```rust
use std::process as stdproc;

pub(super) fn spawn(&self) -> Result<ChildList> {
    let stdin = match self.input {
        Input::Inherit => stdproc::Stdio::inherit(),
        Input::Redirect(ref file_name) => ...,
        Input::Pipe => unreachable!(),
    };

    self.spawn_rec(stdin)
}

fn spawn_rec(&self, stdin: stdproc::Stdio) -> Result<ChildList> {
    let (head, piped) = match self.output {
        Output::Inherit => {
            let head = self.spawn_one(stdin, stdproc::Stdio::inherit())?;
            (head, None)
        }
        Output::Redirect(ref redir_out) => {
            let file = ...;
            let head = self.spawn_one(stdin, file)?;
            (head, None)
        }
        Output::Pipe(ref piped) => {
            let head = self.spawn_one(stdin, stdproc::Stdio::piped())?;
            let stdin = ...;
            let piped = piped.spawn_rec(stdin)?;
            (head, Some(Box::new(piped)))
        }
    };

    Ok(ChildList { head, piped })
}

fn spawn_one(&self, stdin: stdproc::Stdio, stdout: stdproc::Stdio) -> Result<Child> {
    ...

    stdproc::Command::new(&self.argument_list[0])
        .args(&self.argument_list[1..])
        .stdin(stdin)
        .stdout(stdout)
        .spawn()
        .map(Child::External)
        .map_err(Error::from)
}
```

## Future Work: バックグラウンド実行

バックグラウンド実行にも対応しようと思ったのですが、 `std::process` だけではできず、libcバインディングが必要になるようでした。

バックグラウンド実行くらいは対応しないとシェルを書いたとは言えないですね......。
