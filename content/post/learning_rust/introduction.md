+++
date = "2015-11-07T12:00:00+09:00"
title = "Learning Rust - Introduction"
tags = ["Programming", "Rust"]
+++

[Rust](https://www.rust-lang.org/)というプログラミング言語があります。
Mozillaによって開発中で、1.0が2015年5月16日にリリースされました。

syntaxはC/C++に類似していながら、semanticsは大きく異なっています。
特に私の興味を引いたのは安全性です。
C++を書くときに安全性の面で気をつけていることが、
Rustだと言語仕様でかっちり定められ、危険なコードは書けないようになっています。

コンパイラも強力で、ちょっとRustを触ってみたとき、
「mutableにしなくていいvariable bindingをmutableにしている」
のような細かいミスも逃さず警告してくれました。
[公式ドキュメント](https://doc.rust-lang.org/book/README.html)
のIntroductionには以下のようなフレーズがあります。

> To err is to be human, but compilers never forget.

型推論やパターンマッチなど現代的なプログラミング言語の機能はあらかた備え、
独自のビルドツールCargoも付属しています。

さらに、Rustはマルチパラダイムで、関数型、手続き型、オブジェクト指向、etc.を
サポートしているようです。

こんな言語のRustですが、かなり気に入りました。
これからしばらくRustを学んでいこうと思います。

なお、今後Rustの[公式ドキュメント](https://doc.rust-lang.org)をもとに学んでいきますが、
このドキュメントはMIT license と Apache License 2.0 のデュアルライセンスで提供されています。
