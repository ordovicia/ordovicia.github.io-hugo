+++
date = "2017-06-29"
title = "Convert Markdown to PDF"
tags = ["Tools"]
+++

[HackMD](https://hackmd.io) というサービスをよく使っています。
これで書いたものをPDF化したくなったことがあったので、その方法について調べたことをメモしておきます。

もともとHackMDにはPDFでエクスポートする機能があったのですが、
サーバー負荷が重かったため、現在は削除されています。
PDF化機能を追加するという[issue](https://github.com/hackmdio/hackmd/issues/33)は存在していて、
開発は続けていらっしゃるようです。

---

HackMDにかぎらずMarkdownをPDF化する方法には、少なくとも以下のものがあります。
このようなサービスやMarkdownエディタは数え切れないほどあり（逆に言うと標準的なのがないのですが）、
方法は他にもたくさんあると思います。

### Markdown -> HTML
* Atomで開いてHTMLで保存
    * MathJaxが使る
    * リアルタイムプレビュー
    * ほかのMarkdownエディタも同じようなもの？
* Gist
    * 数式が使えない
* [grip](https://github.com/joeyespo/grip)
    * GitHubのAPIに投げてレンダリングするので、結果はおよそGistと同じ
    * だが、gripはソースをいじったりAPIを使ったりすることで自分でカスタマイズでき、例えばMathJaxを使ったりもできる
* [pandoc](http://pandoc.org/)
    * CSSで見た目をカスタマイズできる
    * デフォルトだとあまり見栄えしない
    * HackMDの拡張Markdow記法（の多く）が扱える

### HTML -> PDF
* ブラウザの印刷機能
    * 見た目が変わることがある
* [wkhtmltopdf](https://wkhtmltopdf.org/)
    * 見た目が変わることがある
    * 動作が遅い

### Markdown -> PDF
* pandoc + LaTeX
* pandoc + wkhtmltopdf
* [markdown-pdf](https://www.npmjs.com/package/markdown-pdf)
    * 見た目の調整が面倒

---

いろいろ試したところでは、

* CSSで見た目を調節しながら、pandocでHTMLを出力し、
* ブラウザの印刷機能でPDFに変換する

のがベストかなと思いました。
この方法ならHackMDの拡張記法も扱えるようです。

CSSはよくわからないので、[github.css](https://gist.github.com/andyferra/2554919) をそのまま使わせてもらいました。

Pandocは次のように使います。

```console
$ pandoc -s --mathjax -c github.css
```

追加で、`--indented-code-classes` でコードハイライトを有効にしたり、`-H, -B, -A` でヘッダ・フッタを指定すると満足度の高いPDFが得られます。
