+++
date = "2017-01-09"
title = "Implementing Patricia Tree in Rust"
tags = ["Programming", "Rust"]
+++

Rustでパトリシア木を書きました。
写経以外でRustを書くのは初めてです。

## パトリシア木とは
パトリシア木(Patricia tree)または基数木(Radix tree)とは、
文字列を格納するためのデータ構造です。
実際には文字列以外にも、辞書式順序が定義できる集合なら適用でき、整数やビット列でも可能です。

まず、トライ木というデータ構造があり、これは文字列を格納するために、

* 各ノードに文字をもたせ、
* あるノードの子は、自身に対応する文字列をprefixにもつ

という構造になっています。

<p><a href="https://commons.wikimedia.org/wiki/File:Trie_example.svg#/media/File:Trie_example.svg"><img src="https://upload.wikimedia.org/wikipedia/commons/b/be/Trie_example.svg" alt="Trie example.svg" height="145" width="155"></a><br>By <a href="https://en.wikipedia.org/wiki/User:Booyabazooka" class="extiw" title="en:User:Booyabazooka">Booyabazooka</a> (based on PNG image by <a href="https://en.wikipedia.org/wiki/User:Deco" class="extiw" title="en:User:Deco">Deco</a>). Modifications by <a href="//commons.wikimedia.org/wiki/User:Superm401" class="mw-redirect" title="User:Superm401">Superm401</a>. - own work (based on PNG image by <a href="https://en.wikipedia.org/wiki/User:Deco" class="extiw" title="en:User:Deco">Deco</a>), パブリック・ドメイン, <a href="https://commons.wikimedia.org/w/index.php?curid=1197221">Link</a></p>

[トライ木 - Wikipedia](https://ja.wikipedia.org/wiki/%E3%83%88%E3%83%A9%E3%82%A4%E6%9C%A8)


トライ木は文字列を一文字ずつに分割するので、無駄なノードが生じます。
例えば

* "test"
* "tea"
* "teapot"

を格納すると、

```
- (root)
  - 't'
    - 'e'
      - 's'
        - 't' [leaf]
      - 'a'[leaf]
        - 'p'
          - 'o'
            - 't' [leaf]
```

という構造になります（格納した値に対応するノードに`[leaf]`とつけた）。

無駄なノードを圧縮するため、
共通部分を文字列にしてひとつのノードに持たせるようにしたのがパトリシア木です。
そのため、パトリシア木の各ノードは文字**列**をもちます。

<p><a href="https://commons.wikimedia.org/wiki/File:Patricia_trie.svg#/media/File:Patricia_trie.svg"><img src="https://upload.wikimedia.org/wikipedia/commons/a/ae/Patricia_trie.svg" alt="Patricia trie.svg" height="138" width="220"></a><br>By Claudio Rocchini - <span class="int-own-work" lang="ja">投稿者自身による作品</span>, <a href="http://creativecommons.org/licenses/by/2.5" title="Creative Commons Attribution 2.5">CC 表示 2.5</a>, <a href="https://commons.wikimedia.org/w/index.php?curid=2118795">Link</a></p>

上の例は、パトリシア木では

```
- (root)
  - "te"
    - "st" [leaf]
    - "a" [leaf]
      - "pot" [leaf]
```

となります。

[基数木 - Wikipedia](https://ja.wikipedia.org/wiki/%E5%9F%BA%E6%95%B0%E6%9C%A8)

## パトリシア木の機能と性能
パトリシア木は、検索・挿入・削除などの操作が [tex:O(k)] で可能です
（[tex:k] は最大文字列長）。

平衡二分木などでは、これらの操作が [tex:O(\log n)] ([tex:n] は格納されている要素数)で
できますが、それは要素の比較が定数時間でできるという前提のもとで成り立つものです。
文字列を格納する場合、その比較に最悪で [tex:O(k)] かかるので、平衡二分木では遅くなります。
この比較は毎回文字列の先頭からおこなわれるので、
長いprefixを共有している要素が多い場合などに顕著です。

パトリシア木の場合、文字列の比較は先頭から一度だけおこなえばよいので、
[tex:O(k)] で済むことになります。


パトリシア木は文字列をキーとする連想配列を表現するのにも使えます。

## Rust実装
Rustのバージョンは`rustc 1.16.0-nightly (7e38a89a7 2017-01-06)`です。

<script src="https://gist.github.com/ordovicia/f711d40fcea689e97123f200c0f3b225.js"></script>

パトリシア木の実装方法はいくつかあるようですが、
親ノードが子ノードのリストをもつ素朴な方法を取りました。

検索・挿入・削除はすべて、

1. ノードがもつ文字列と対象の文字列を上から順に比較していき、
1. ノードの文字列が先に終わった（対象の文字列のprefixだった）ときは
1. 子ノードに残りの文字列をわたして再帰的に実行する

ようになっています。

子ノードは、最初の文字で比較した順番にソートしてもつようにし、
再帰的に呼び出すノードの決定を二分探索できるようにすることで高速化しました。

ソースコードをよく見ると、ズルをしている箇所があることがわかります。
あるノードに対応する文字列を削除するとき、そのノードの子が、

* 0個の場合 -- そのノードを親ノードから消し、親ノードについて圧縮処理をおこなう。
* 1個の場合 -- そのノードがもつ文字列を、子ノードのものと連結させる。
* 2個以上の場合 -- そのノードが文字列の終端であることを示す`is_leaf`フラグを下ろす

と処理すればよいのですが、上のソースコードでは、0個の場合の処理を、
`is_leaf`フラグを下ろすことで代えています。
これは`PatriciaTree`structが親へアクセスする手段を持たないためです。
`PatriciaTree`に親へのポインタを持たせようとすると実装が面倒になるようだったからで、
今回この処理は省略しました。

### 実装して思ったこと
#### Rustはテストツールやドキュメント化ツールがオールインワンになっていて楽
Rustは、ちゃんとしたテストツールやドキュメント化ツールが公式から提供されていて、
しかもCargoから簡単に扱えるのでかなり楽でした。

僕がよく使うC++だと、テストツールにはgoogletestやCMakeのCTestなどがあって、
比較したり使いかたを覚えるのが大変です。
ドキュメント化にはDoxygenがデファクトスタンダードになっていて
使いかたも難しくないのでいいですが。


Rustはテストが同じファイルに書けます。
上に貼ったソースコードだと、`test`moduleがテストになっています。
関数などのコメント内に、使用例を兼ねてテストを書くこともできます。
テストをコードのすぐ近くに書けて、`$ cargo test`で簡単に実行できて便利です。


ドキュメントは、`$ cargo doc`で生成されます。
[標準ライブラリのリファレンス](https://doc.rust-lang.org/std/index.html)
のような形式のドキュメントができ、標準ライブラリへのリンクも貼ってくれます。

#### 型をつけるのは大事
`exist()`などで文字列をスキャンしていくループでは、ループごとの結果を`IteratingState`型で
表すようにしています。
適当に`()`型にしてしまっても実装できるのですが、型を付けることでバグが見つかりやすくなりました。

`()`型だといろんな文が書けてしまって、`return`忘れとかが見落としがちなので、
型を付けることでちゃんとその型を返すようになっていることを保証するといいと思います。

Rustは最後に書いた式でブロックが型付けされたり、`if`や`match`が式として使えるので便利です。

#### Ownershipがいい
Ownershipのおかげで、データの移動がmoveもしくは明示的なreferenceとなります
（もちろん、`Copy`traitをimplしているような軽い型は低コストでディープコピーできます）。
そのため、明示的にコピー(clone)しない限り
ownershipの付け替えやreferenceという軽い操作になるので、
コピーコストやmove後の不正なアクセスの可能性をいちいち考えなくてよくなって楽でした。

#### 文字列操作が面倒
Rustの`&str`型、`String`型はC++の`std::string`型と中身が異なります。
後者はC/C++の`char`型、つまりASCIIコードであるのに対し、
前者がUTF-8にエンコードされた列となっています。

そのため、簡単にランダムアクセスすることはできず、先頭から順に読んでいくか、
いちど`chars()`で`Vec<char>`型に変換する必要があります。

もちろんRustでも文字列をバイト列として扱うこともできますし、
C++でもワイド幅文字を扱うための型が用意されています。
Rustのprimitiveな型がUTF-8列を扱うというだけです。

文字列操作が面倒というのは、ASCII文字を扱うような環境でということで、
逆に言うと、Unicode文字を扱いたい場合は、C++の`std::string`よりは簡単だと思います。


今回は文字列を走査するとき、
`chars()`でイテレータをつくる方法と、`Vec<char>`に変換する方法を使い分けました。
`Vec<char>`にする必要があったのは、文字列をある位置で前後に分割する必要があるときと、
mutableな操作が必要なときでした。

#### Cyclicなデータ構造が面倒
Rustはownershipの概念があるので、木構造で子が親を参照するようなデータ構造をつくるのが面倒です。
そのため今回は性能を一部制限して（要素の削除で実際にはノードを消さなかったところ）、
cyclicにならないようにしました。

Cyclicにつくるには、子を`Rc`, 親を`Weak`で囲ってうまいこと実装すればよいようです。
