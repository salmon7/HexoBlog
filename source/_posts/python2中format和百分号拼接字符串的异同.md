---
title: python2中format和%拼接字符串的异同
date: 2020-08-08 15:25:55
tags:
    - python2
    - python3
    - 编码
---

### 基础知识

相信python2的编码问题大多数开发同学都遇到过，在出现非 ascii 编码字符时，就很容易编码异常的问题。python2的字符编码分为 str 以及 unicode，具体情况这里不再敖述，只会总结字符串拼接时应该注意的问题以及可能遇到的坑点。

以下几点常识是下面进一步讨论问题的基础：

- str转为unicode的过程，称为解码，即 decode。
- unicode转为str，称为编码，即 encode。
- 使用`%`把str和unicode拼接，会自动隐式地把str转为unicode后，再进行拼接。（如果是fomat拼接呢？这里留个悬念，答案稍后揭晓）
- 当导入__future__包的unicode_literals特性时，python定义的字符都是unicode，而不是默认的str。这个也是为了让python2能够导入python3的特性，因为在python3中的str都是unicode。

### `%` 拼接字符串

我们首先看看pyhon2中的使用`%`字符串拼接情况。从第一组结果来看，我们可以看到只要格式化串和字符串参数其中一个为unicode，最终结果就为unicode，这个和上面讲的第三点一致。在对str和unicode拼接的时候，会自动把str转为unicode，如第二组的中间两个结果。

但是我们需要注意编码的问题，如第2个结果，由于"中文"是非 acsii 编码，而且python解释器不知道其类型，会用ascii编码对其进行解码，相当于 `u"%s" % ("中文").decode("ascii")`，而ascii不认识非 0~127 编码所以就报错，当然我们可以手动指定用"utf-8"进行解码。

```python
>>> type("%s" % ("hello"))
<type 'str'>
>>> type(u"%s" % ("hello"))
<type 'unicode'>
>>> type("%s" % (u"hello"))
<type 'unicode'>
>>> type(u"%s" % (u"hello"))
<type 'unicode'>
>>>
>>> type("%s" % ("中文"))
<type 'str'>
>>> type(u"%s" % ("中文"))         # 最终结果为unicode，会隐式地通过ascii编码把"中文"解码为unicode
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
UnicodeDecodeError: 'ascii' codec can't decode byte 0xe4 in position 0: ordinal not in range(128)
>>> type(u"%s" % ("中文".decode("utf-8")))
<type 'unicode'>
>>> type("%s" % (u"中文"))
<type 'unicode'>
>>> type(u"%s" % (u"中文"))
<type 'unicode'>
```

### `format` 拼接字符串

同样的，我们先看下面的第一组结果，是不是有点吃惊？第一组的第二结果不是unicode类型，而是str类型，这个跟`%`是不同的。很显然从结果上看，我们知道对于`format`其拼接结果类型取决于其格式化串的类型，而与参数没有任何关系。

理解的第一组数据的规律后，再看第二组就知道为什么有的情况会报异常了。第二组的第二个结果，由于最终结果为str，pyhton解释器会默认用 ascii 对 `u"中文"` 进行编码，而第三个结果，由于最终结果为unicode，python解释器会默认用 ascii 对应 "中文" 进行解码，而报错的理由和前面的情况一致，都是因为ascii不认识非 0~127 编码。

```python
>>> type("{}".format("hello"))
<type 'str'>
>>> type("{}".format(u"hello"))
<type 'str'>
>>> type(u"{}".format("hello"))
<type 'unicode'>
>>> type(u"{}".format(u"hello"))
<type 'unicode'>
>>>
>>> type("{}".format("中文"))
<type 'str'>
>>> type("{}".format(u"中文"))         # 最终结果为str，会隐式地通过ascii编码把u"中文"编码为ascii
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
UnicodeEncodeError: 'ascii' codec can't encode characters in position 0-1: ordinal not in range(128)
>>> type("{}".format(u"中文".encode("utf-8")))
<type 'str'>
>>> type(u"{}".format("中文"))          # 最终结果为unicode，会隐式地通过ascii编码把"中文"解码为unicdoe
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
UnicodeDecodeError: 'ascii' codec can't decode byte 0xe4 in position 0: ordinal not in range(128)
>>> type(u"{}".format("中文".decode("utf-8")))
<type 'unicode'>
>>> type(u"{}".format(u"中文"))
<type 'unicode'>
```

### 坑点

而我们线上的问题，要比以上两种都要隐蔽，大致如下：

#### 代码目录结构

```
 tree -L 2 -I "*.pyc"
.
├── test_module_002
│   ├── __init__.py
│   ├── __pycache__
│   ├── main.py
│   └── module_a.py
```

<!--more-->

#### 代码

```python
# module_a.py
from __future__ import unicode_literals

variable_a = "mytag"

# main.py
# -*- encoding=utf8 -*-
import six

from test_module_002 import module_a

if six.PY2:
    variable_b = u"中文".encode("utf-8")
else:
    variable_b = u"中文"

if __name__ == "__main__":
    print("%s %s" % (module_a.variable_a, variable_b))
    print("{} {}".format(module_a.variable_a, variable_b))
    print("%s %s" % (module_a.variable_a.encode("utf-8"), variable_b))

```

#### 分析

我们一开始使用的是 `%` 方式进行拼接字符串，会报类似以下的错误。当时就意识到可能是中文编码问题，于是就尝试使用format，没想到居然成功解决了，但是当时不知道具体原因是什么。

```
print "%s %s" % (module_a.variable_a, variable_b)
UnicodeDecodeError: 'ascii' codec can't decode byte 0xe4 in position 0: ordinal not in range(128)
```

但是经过前面的分析，现在回过头来看还是比较清晰的，由于format最终类型为str，所以第二个variable_b不需要解码，只需要把variable_a进行编码就行了。哎？variable_a为什么是unicode，它前面没有u，不应该是str吗？这个也是一大坑点，在引用开源代码时需要注意其模块是否引入了 unicode_literals 特性，如果引入了那么定义的字符就默认为unicode了。

可能有人会觉得，那我把variable_a用 utf-8 进行编码不就行了，这样不就只是两个str进行拼接吗？是的，这样在 `python2` 中的确可以，但是需要注意的是这样在 `python3` 中会加前缀b以及单引号，这样对一些匹配场景会有影响，如下结果所示。

```
b'mytag' 中文
```

所以，如果要兼容python2和python3的话，最佳解决办法还是使用format。python2后两种均能正常显示，python3前两种均能正常显示。当然，也可以在print之前通过 six 进行判断，如：

```python
    if six.PY2:
        print("%s %s" % (module_a.variable_a.encode("utf-8"), variable_b))
    else:
        print("%s %s" % (module_a.variable_a, variable_b))
```

> 在编写代码时，从外面导入到系统的参数应该尽快转为unicode类型，在输出到外部时，应该转为str类型，这个也被称为 unicode sandwitch模型。

### 总结

经过以上论述，我们知道了`%`和`format`的一些特性以及两者的异同点，分析了一个常见的坑点，并总结了在兼容python2和python3的场景下的方案。以下是本文要点：

- 使用 `%` 进行拼接时，格式化串和字符串参数其中一个为unicode，最终结果就为unicode。
- 使用 `format` 进行拼接时，拼接结果类型取决于其格式化串的类型。
- 如果引入了unicode_literals特性，那么该模块定义的字符串均为unicode类型。

### 参考

[How to fix: “UnicodeDecodeError: 'ascii' codec can't decode byte”](https://stackoverflow.com/questions/21129020/how-to-fix-unicodedecodeerror-ascii-codec-cant-decode-byte)  
[Using % and .format() for great good!](https://pyformat.info/#conversion_flags)  
[Pragmatic Unicode](https://nedbatchelder.com/text/unipain.html) ===> 重点推荐这个视频  
[Python - 'ascii' codec can't decode byte](https://stackoverflow.com/questions/9644099/python-ascii-codec-cant-decode-byte)  
[Python2, string .format(), and unicode](https://anonbadger.wordpress.com/2016/01/05/python2-string-format-and-unicode/) ===> 重点推荐这个文章  