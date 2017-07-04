+++
date = "2017-07-03"
title = "C++ - Python Interoperation"
tags = ["Programming", "C++", "Python"]
+++

C++とPythonを結ぶ方法について少し調べました。
コードは [GitHub](https://github.com/ordovicia/cplusplus-ffi.git) にあります。

## バージョン情報
* OS X El Capitan (10.11.6)
* CMake 3.8.2
* g++ 7.1.0
* Python 3.6.1
* Boost 1.64.0

## Call C++ from Python
主に二つの方法があります。

* SWIG
* Boost.Python

### SWIG
SWIGは、C/C++プログラムを、他の言語で呼べるように変換してくれるツールです。
Pythonを対象にするときは、Pythonモジュールとして使える形のラッパーを自動で作ってくれるので、それを共有ライブラリにコンパイルして使います。
Python以外にも多くの言語に対応しています。

詳細は、[公式ドキュメント](http://www.swig.org/doc.html) を参照してください。


以下のC++（実質C言語）プログラムを例に取ります。

```cpp
// example.hpp

#pragma once

int fact(int n);
```

```cpp
// example.cpp

#include "example.hpp"

int fact(int n)
{
    return n <= 0 ? 1 : n * fact(n - 1);
}
```

SWIGでは、「インターフェイスファイル」というものを作ります。
上のプログラムのインターフェイスファイルは次のようになります。

```swig
// example.i

%module example

%{

#define SWIG_FILE_WITH_INIT
#include "example.hpp"

%}

%include "example.hpp"
```

基本的には、

```swig
%module module_name

%{
#define SWIG_FILE_WITH_INIT
#include module_header
%}

%include module_header
```

と書きます。


ビルドにはdistutilを使うのが一般的だと思いますが、ここではCMakeを使ってみます。
次のような `CMakeLists.txt` を用意します。
ファイル名が変わってもそのまま使えるようになっています。

```cmake
cmake_minimum_required(VERSION 3.8.0)

find_package(SWIG REQUIRED)
include(${SWIG_USE_FILE})

find_package(PythonLibs 3 REQUIRED)
include_directories(${PYTHON_INCLUDE_PATH})

include_directories(${CMAKE_CURRENT_SOURCE_DIR})

set(CMAKE_SWIG_FLAGS "")

file(GLOB SWIG_FILES *.i)
file(GLOB SRC_FILES *.cpp)

set_source_files_properties(${SWIG_FILES} PROPERTIES CPLUSPLUS ON)
set_source_files_properties(${SWIG_FILES} PROPERTIES SWIG_FLAGS "-includeall")

swig_add_library(example
    LANGUAGE python
    SOURCES ${SWIG_FILES} ${SRC_FILES})
swig_link_libraries(example ${PYTHON_LIBRARIES})
```

（CMakeが3.8より古いと `swig_add_library` ではなく `swig_add_module` を使う必要があります。その際 `LANGUAGE`, `SOURCES` は除いてください。）

あとは `cmake, make` すれば `_example.so` が生成され、Pythonからインポートして使えます。

```python
import example

for i in range(10):
    print(example.fact(i))
```

### Boost.Python
詳細は [公式ドキュメント](http://www.boost.org/doc/libs/1_64_0/libs/python/doc/html/index.html) を参照してください。
[こちらの例](https://github.com/TNG/boost-python-examples) も参考になります。

なお、使ったことはないですが、Boost.Pythonのコードを自動で生成してくれる [Py++](http://pyplusplus.readthedocs.io/en/latest/) というのがあるようです。
また、Boost.Pythonのほかに [SWIG](http://www.swig.org/) も使えると思います。

ちなみに、Boost.Python 1.64.0 からnumpyサポートがmaster入りしたようです。

#### ビルド方法
macOSでのPython3を対象とします。

まず、Boost.PythonをHomebrewでインストールするのですが、Python3に対応させるために、`--with-python3` オプションを付けます。

```console
$ brew install boost-python --with-python3 --c++11
```

GCCを使いたい場合は `--cc=gcc-7` のようなオプションを追加してください。

ビルドにはCMakeを使うことにします。
次のような`CMakeLists.txt`を用意してください。
ここでは、`mod.cpp` をPythonモジュールとしてビルドし、`test_mod.py` から使います。

```cmake
cmake_minimum_required(VERSION 3.8.0)

find_package(PythonInterp 3 REQUIRED)
find_package(PythonLibs 3 REQUIRED)
find_package(Boost COMPONENTS python3)

include_directories(${Boost_INCLUDE_DIRS} ${PYTHON_INCLUDE_DIRS})
link_libraries(${Boost_LIBRARIES} ${PYTHON_LIBRARIES})

python_add_module(mod mod.cpp)
file(COPY test_mod.py DESTINATION .)
```

`cmake` を実行すると `FindBoost.cmake` がwarningを吐きますが、とりあえず気にしないでいいようです。

#### C++の関数を公開する
##### 基本
例えば、次の関数 `mult2()` をPythonから使えるようにしてみます。

```cpp
// fn.cpp

int mult2(int x)
{
    return x * 2;
}
```

次の記述を加えるだけで完了です。

```cpp
#include <boost/python.hpp>

using namespace boost::python;

BOOST_PYTHON_MODULE(fn)
{
    def("mult2", mult2);
}
```

`BOOST_PYTHON_MODULE` マクロでPythonモジュールを作っています。
ここでは `fn` モジュールと名付けました。

`def()` 関数に、関数名と関数ポインタを渡すだけです。
関数名はPython側で使いたいものなので好きに設定できます。

Python側では次のように使えます。

```python
import fn

for i in range(100):
    assert(fn.mult2(i) == i * 2)
```

##### デフォルト引数
デフォルト引数を持つ、次の関数を考えます。

```cpp
int sum(int x, int y = 0)
{
    return x + y;
}
```

これを公開するには、`BOOST_PYTHON_FUNCTION_OVERLOADS` マクロを使うのが便利です。
このマクロに

* 生成されるクラス名（任意の名前）
* 関数名
* 引数の個数の最小・最大値

を渡し、`def()` を下の例のように呼びます。

```cpp
BOOST_PYTHON_FUNCTION_OVERLOADS(sum_overloads, sum, 1, 2)

BOOST_PYTHON_MODULE(fn)
{
    def("sum", sum, sum_overloads());
}
```

Python側で、デフォルト引数が使えていることが確認できます。

```python
assert(fn.sum(2) == 2)
assert(fn.sum(2, 3) == 5)
```

##### オーバーロード
関数オーバーロードでも、`BOOST_PYTHON_FUNCTION_OVERLOADS` マクロを使うのが便利です。
次の関数群 `sub()` を考えます。

```cpp
int sub(int x)
{
    return x;
}

int sub(int x, int y)
{
    return x - y;
}
```

`BOOST_PYTHON_FUNCTION_OVERLOADS` マクロを、デフォルト引数のときと同じように使います。

`def()` の記述は少し変わっています。
第二引数に、最も多くの引数をとる関数シグネチャを次のように書きます。

```cpp
BOOST_PYTHON_FUNCTION_OVERLOADS(sub_overloads, sub, 1, 2)

BOOST_PYTHON_MODULE(fn)
{
    def("sub", (int (*)(int, int))0, sub_overloads());
}
```

##### 手動オーバーロード解決
`sub()` の例では、すべての関数オーバーロードのシグネチャが、最も多くの引数をとる関数シグネチャに含まれるという形をとっていました。
これが成り立たないようなオーバーロードは、現時点では自動では扱えないため、手動でラッパーを書く必要があります。

例えば、次の関数を加えたいとします。

```cpp
double sub(double x)
{
    return x;
}

double sub(double x, double y)
{
    return x - y;
}
```

これを `BOOST_PYTHON_FUNCTION_OVERLOADS` で扱うことはできないため、次のように別名を付けてやります。

```cpp
BOOST_PYTHON_MODULE(fn)
{
    double (*sub_double_1)(double) = sub;
    double (*sub_double_2)(double, double) = sub;

    def("sub", sub_double_1);
    def("sub", sub_double_2);
}
```

##### キーワード引数
C++の関数を、Python側でキーワード引数が使えるようにして公開することができます。
次の関数を例に取ります。

```cpp
double my_div(double dividend, double divisor)
{
    return dividend / divisor;
}
```

`BOOST_PYTHON_MODULE` 内に以下のように記述すると、キーワード引数が使えるようになります。

```cpp
    def("div", my_div, (arg("dividend"), "divisor"));
```

```python
assert(fn.div(3.0, 2.0) == 1.5)
assert(fn.div(dividend=3.0, divisor=2.0) == 1.5)
assert(fn.div(divisor=2.0, dividend=3.0) == 1.5)
```

ちなみに、`arg("dividend") = 0` のように書くとデフォルト引数になります。

#### C++のクラスを公開する
##### 基本
例えば、次の `Person` クラスをPythonから使えるようにします。

```cpp
// cls.cpp

#include <string>

struct Person {
public:
    explicit Person(std::string name) : name(name) {}
    const std::string name;

    std::string greet() const { return "My name is " + name; }
};
```

関数のときと同じように、次の記述を加えて完了です。

```cpp
#include <boost/python.hpp>
using namespace boost::python;

BOOST_PYTHON_MODULE(cls)
{
    class_<Person>("Person", init<std::string>())
        .def("greet", &Person::greet);
}
```

`class_` 関数テンプレートを、公開するクラスを型引数、名前を引数にして呼び出します。
名前とともに `init` を渡すと、それがコンストラクタになります。

`def()` 関数をチェーン状につなげていくことでメンバ関数を定義できます。
ここでは `Person::greet()` 関数を `greet` という名前で公開しています。

すると、Pythonからは次のように使うことができます。

```python
import cls

p = cls.Person("pohe")
assert(p.greet() == "My name is pohe")
```

##### コンストラクタ
上述のようにコンストラクタを公開できましたが、オーバーロードするには、`def()` に `init` を渡していきます。

```cpp
    ...

    explicit Person(std::string name, int age) : name(name), age(age) {}
    int age = 0;
    void grow() { age++; }

    ...

BOOST_PYTHON_MODULE(cls)
{
    class_<Person>("Person", init<std::string>())
        .def(init<std::string, int>())
        .def("greet", &Person::greet);
```

なお、コンストラクタを定義しない抽象クラスの場合は、`init` の代わりに `no_init` という変数を渡すようです。

##### メンバ変数
先程の例で `age` メンバ変数（と `grow()` メンバ関数）を追加しました。
メンバ変数は以下のように `def()` チェーンにつなげていくことで公開できます。

```cpp
        ...

        .def_readwrite("age", &Person::age)
        .def("grow", &Person::grow);

        ...
```

`def_readwrite()` を使うと、メンバ変数が読み込み・書き込みともに可能な状態でPythonから扱えるようになります。
`def_readonly()` を使うと、読み込みのみ可能にできます。

```python
p = cls.Person("fuga", 1)
assert(p.age == 1)
p.age = 10
assert(p.age == 10)
p.grow()
assert(p.age == 11)
```

##### プロパティ
実際のC++では、メンバ変数はprivateにし、getter, setterを定義することが多いでしょう。

上の例に `m_height`, `m_weight` メンバ変数を追加し、`m_height` のgetterとsetter, `m_weight` のgetterを定義します。

```cpp
    ...

    int getHeight() const { return m_height; }
    void setHeight(int height) { m_height = height; }

    int getWeight() const { return m_weight; }

private:
    int m_height = 0;
    int m_weight = 50;
};
```

Python側に公開するには、`add_property()` 関数を `def()` チェーンにつなげていきます。

```cpp
        ...

        .add_property("height", &Person::getHeight, &Person::setHeight)
        .add_property("weight", &Person::getWeight);

        ...
```

`add_property()` 関数に、プロパティ名、getter, setterを渡します。
setterを省略すると読み込み専用になります。

```python
p.height = 150
assert(p.height == 150)

assert(p.weight == 50)
# p.weight = 100 # error
```

##### オペレータ
C++でのクラスに対する、`opeartor+` などのオペレータをPythonでも使えるようにします。
次の `Person::opeartor+=` を例にします。

```cpp
    Person& operator+=(int age)
    {
        this->age += age;
        return *this;
    }
```

これを公開するには、`def()` チェーンに次を追加するだけです。

```cpp
    ...

    .def(self += int())

    ...
```

`self` が `Person`, `int()` が `operator+=` の引数に対応しています。
他のオペレータでも同様に書けます。

##### 特殊メソッド
Pythonにはいくつか特殊メソッドがあります。
ここでは、よく使う `__str__()` のみ紹介します。

C++から公開するクラスに `___str__()` メソッドを定義したいとき、まずC++で `operator<<` を定義します。
そして、`self_ns::str(self_ns::self)` を`def()` チェーンにわたします。

```cpp
std::ostream& operator<<(std::ostream& os, Person p)
{
    os << p.name;
    return os;
}

...

        .def(self_ns::str(self_ns::self))

        ...
```

現時点での公式ドキュメントでは、`.def(str(self))` のように `self_ns` 名前空間の指定が書かれていませんが、これがないとコンパイルエラーになります。

これによりPython側で `__str__()` メソッドが定義され、`print()` で好きな文字列を表示したりできます。

##### イテレータ
C++でのクラスに、Pythonで使えるイテレータを定義することができます。
あまりいい例ではないですが、`Person::name` を一文字ずつ走査するイテレータを考えます。

Person` クラスにイテレータの最初と最後を返すメンバ関数を定義し、`def()` チェーンに次のように渡します。

```cpp
    ...

    auto begin() { return name.begin(); }
    auto end() { return name.end(); }

    ...

        .def("__iter__", range(&Person::begin, &Person::end));
```

`range()` にイテレータの最初と最後を渡しています。
`__iter__` という名前にすることで、Pythonでのfor文に `Person` 型が渡せるようになっていますが、
別の名前にすれば、その名前のメソッドがイテレータを返すようになります。

```python
for s in p:
    print(s)
```

ちなみに、`vector` など

* `iterator` typedef
* `begin()` メンバ関数
* `end()` メンバ関数

をもつクラスについては、`range()` の代わりに `iterator<Person>()` を渡すこともできるようです。

#### 紹介しなかったもの
* 型変換
* 関数呼び出しポリシー
* 継承、仮想関数
* C++からPythonへの例外の変換
* docstring

紹介しなかったものや、詳細は [公式ドキュメント](http://www.boost.org/doc/libs/1_64_0/libs/python/doc/html/tutorial/tutorial/exposing.html) を参照してください。

## Call Python from C++
これもBoost.Pythonを使います。

もともと、PythonのC APIを使ってC/C++からPythonを呼ぶことは（あまり複雑なコードでなければ）難しくなかったため、
Boost.Pythonも今のところ簡単なラッパーを提供するにとどまっています。

PythonのC APIを使う方法で面倒だったのがPythonオブジェクトの参照カウンタの扱いで、
Boost.Pythonがこれを引き受けてくれるのが助かります。

### 準備
C++側で `boost/python.hpp` をインクルードし、`Py_Initialize()` を呼んで初期化します。

```cpp
#include <iostream>
#include <boost/python.hpp>

int main()
{
    using namespace std;
    namespace bp = boost::python;

    try {
        Py_Initialize();
```

### モジュールの読み込みと操作
`import()` 関数にPythonモジュール名を渡すと、そのモジュールが読み込まれます。
`__main__` にすれば、白紙状態のメインモジュールになります。
モジュールをはじめ、Boost.PythonでのPythonオブジェクトの型は `object` になっています。

モジュールの `__dict__` 属性を辞書として参照することで、そのモジュールの名前空間が得られます。
Boost.Pythonの `extract()` 関数テンプレートは、PythonオブジェクトからC++側で使うある値を取り出すときに使います。

```cpp
        bp::object py_main_module = bp::import("__main__");
        bp::dict py_main_namespace
            = bp::extract<bp::dict>(py_main_module.attr("__dict__"));
```

ちなみに、`__main__` 以外のモジュールは、相対パスの場合 `PYTHONPATH` 環境変数からのパスが使われるので、`setenv()` などでの設定が必要です。

名前空間（実体は辞書）に、C++側で値の追加・変更ができます。
辞書なので名前をキーとして `[]` でアクセスして代入するだけです。

```cpp
        py_main_namespace["p"] = "po";
```

PythonオブジェクトからC++での値を取り出すには、先述した `extract()` 関数テンプレートを使います。
テンプレート引数にC++での型を指定します。

ここで注意なのが、文字列(`std::string`)を取り出す際、`auto` で受けると他の型になってしまうので、戻り値の型を明示的に `std::string` に指定します。
`int` や `double` などプリミティブな型は `auto` で大丈夫なようです。

```cpp
        std::string p = bp::extract<std::string>(py_main_namespace["p"]);
        cout << "Defined 'p = \"po\"'\n"
             << "(C++) p = \"" << p << "\"\n" << endl;
```

### Pythonの呼び出し
さて、C++からPythonを呼び出してみましょう。
まずは、式を文字列で渡してPythonインタプリタで評価してみます。

```cpp
        bp::object py_s2 = bp::eval("p + p", py_main_namespace);
        p = bp::extract<std::string>(py_main_namespace["p"]);
        std::string pp = bp::extract<std::string>(py_s2);
        cout << "Evaluated 'p + p'; resulting in 'pp'\n"
             << "(C++) p = \"" << p << "\"\n"
             << "(C++) pp = \"" << pp << "\"\n" << endl;
```

`eval()` 関数にPythonの式を渡すと、評価結果がPythonオブジェクト（`boost::python::object`）で返ってきます。
`eval()` 関数の引数は、

* 第一引数
    * 評価する式を文字列で
* 第二引数
    * 評価する際のローカルな名前空間（辞書）
    * 省略すると空の辞書
* 第三引数
    * 評価する際のグローバルな名前空間（辞書）
    * 省略すると空の辞書

という仕様です。

次に、文を実行してみます。
これには `exec()` 関数を使います。

```cpp
        bp::exec(R"(
def f():
    global p
    p = p + p
    return p

f()
)",
            py_main_namespace);
        p = bp::extract<std::string>(py_main_namespace["p"]);
        cout << "Executed 'p = p + p'\n"
             << "(C++) p = \"" << p << "\"\n" << endl;
```

`exec()` にPythonの文を渡すと、Pythonインタプリタで実行されます。
第二、第三引数の仕様は `eval()` と同様です
（`exec()` もPythonオブジェクトを返すのですが、文の実行結果なので `None` であり、これを使うことはないと思います）。

`py_main_namespace["p"]` が更新されていることが確認できます。

最後に、Pythonスクリプトファイルを読み込んで実行します。
今回は、次のファイルを使います。

```python
ppp = "po " + p
print("(Python) ppp = " + ppp)
```

`exec_file()` にファイル名（相対パスの場合、実行している場所から）を渡すと、それが読み込まれて実行されます。
第二、第三引数の仕様は `exec()` などと同様です。

```cpp
        cout << "Executing 'embedding.py'" << endl;
        bp::exec_file("embedding.py", py_main_namespace);
        std::string ppp = bp::extract<std::string>(py_main_namespace["ppp"]);
        cout << "(C++) ppp = \"" << ppp << "\"\n" << endl;
```

ファイルが存在しない場合、`std::invalid_argument` 例外が投げられます。

### Pythonの例外
Pythonインタプリタの実行時に例外が発生すると、Boost.Pythonは `error_already_set` 例外を投げます。
それ以降の例外処理は実装されていないらしく、[PythonのC API](https://docs.python.org/3/c-api/exceptions.html) に従って処理する必要があるようです。
例えば、

* `PyErr_ExceptionMatches()` 関数で例外の種類を特定
* `PyErr_Print()` 関数で例外の内容を表示

といったAPIがあります。

```cpp
    } catch (const bp::error_already_set& e) {
        if (PyErr_ExceptionMatches(PyExc_ZeroDivisionError)) {
            cerr << "(C++) ZeroDivisionError" << endl;
        }
        PyErr_Print();
        return 1;
    }

    return 0;
}
```
