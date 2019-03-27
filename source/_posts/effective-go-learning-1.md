---
title: effective go learning
date: 2018-09-16 21:04:20
tags:
    - go
---

## Formmating：

* gofmt：针对文件进行格式化
* go fmt：针对包进行格式化

### Indentation

We use tabs for indentation（**使用tab来缩进**） and gofmt emits them by default. Use spaces only if you must.（**仅在必要时使用空格**）

### Line length

Go has no line length limit. Don't worry about overflowing a punched card. If a line feels too long, wrap it and indent with an extra tab.

### Parentheses

Go needs fewer parentheses（**更少的括号**） than C and Java: control structures (if, for, switch) do not have parentheses in their syntax. Also, the operator precedence hierarchy is shorter and clearer

控制结构（if，for，switch）的语法中没有括号，使用严格的空格来提升直观感。

## Commentary：

* 提供C模式的 /* */的块注释，和C++模式的行注释，行注释更加普遍，而块模式在包注释以及大块注释的时候比较常用
* godoc会抽取注释成文档
* **在顶级声明之前出现的注释**（没有中间换行符）将与声明一起提取，以作为项目的解释性文本。
* 每个包都应该有一个包注释，在package子句之前有一个块注释。对于多个文件的package，只需要在任意一个文件中声名包注释即可。包注释应该介绍包，并提供与整个包相关的信息。它将首先出现在godoc页面上。
* **程序中的每个导出（大写）名称都应具有doc注释。并且最好以被声明的函数、字段或者其他作为开头**。这样子用godoc时，容易搜索到对应的文档

<!--more-->

## Names：

### package name：

* 按照惯例，软件包被赋予 **小写单字**名称; 应该不需要下划线或者混合使用。如果包名冲突的话，可以使用别名引用
* 包名是其 **源目录的基本名称**，包中src/encoding/base64 输入"encoding/base64"，但是有名称base64，不是encoding_base64也不是encodingBase64
* 使用package.New的形式定义实例函数

### Getters：

* 使用与字段相同的方法（首字母大写）来命名getter
* 使用Set+与字段相同的方法（首字母大写）来命名setter

### Interface names：

* 一个方法接口由该方法name加上 **er后缀**或类似的修改命名：Reader， Writer，Formatter， CloseNotifier等。
* Read，Write，Close，Flush， String等有规范签名和意义。为避免混淆，请不要将您的方法作为其中一个名称，除非它具有相同的签名和含义。
* 相反，如果您的类型实现的方法与众所周知类型的方法具有相同的含义，请为其指定相同的名称和签名;
* 使用String调用你的字符串转换方法而不是ToString，即使用String而不是ToString

### MixedCaps：

* 使用首字母大写的驼峰或者首字母小写的驼峰对多字名称进行命名
* **而不是使用下划线**

## Semicolons：

* 与C语言一样使用分号对语句进行分割，不同的是大部分工作由词法分析器完成
* 如果一行以 int、float64、数字或者字符串常量，或者为以下其中之一，则词法分析器会在此句末尾添加分号
	* break continue fallthrough return ++ -- ) }
* 对于一个闭包来说，分号也可以省略
* **在go中，一般只有for循环子句之类具有分号**
* 不能把控制结构的左括号（if，for，switch，或select）在下一行（因为放在下一行，词法分析器会自动加分号到行尾），如错误示范
	* if i < f() // wrong!{ // wrong!g()}

## Control structures：

与C语言类似，不过没有do和while，只有for、if、switch、selectif：
	
* **if语句必须包含大括号**，无论子句有多简单
* 由于if和switch接受初始化语句，它经常可以看到一个用于设置一个局部变量用法
* 由于在go中倾向于使用return来返回错误，所以在这种流程中不需要else子句

### Redeclaration and reassignment：

* 再次声明和再次赋值需要注意三个方面

	* 再次声明是在相同的域下发生的（**如果v已在外部声明中声明，这时声明将创建一个新变量§**）（注释：在go中变量的作用域与传统语言比较类似，比如if语句中的变量为局部变量，而在python中，if语句中的变量不是局部变量，而是与if外部共享作用域和命名空间）
	* **初始化中的相应值可分配给v**
	* 声明中至少有一个变量被新建，如果都已经被声明过，则应该使用 "="，而不是":="，因为 ":=" 的第一步是重新创建变量，如果变量均已经存在，则不需要重新创建新的变量，所以不能使用 ":="

### For：

* 没有while和do-while
* 三种形式

	* for init; condition; post { } // Like a C for
	* for condition { } // Like a C while
	* for { } // Like a C for(;;) or while(true)
* **结合range对数组，切片，字符串，map，channel进行遍历**
	* range能够比较好的处理，utf-8类型的字符串，能够自动解码，同时应该使用 "%q" 占位符进行输出
* go中没有逗号运算
* ++ 和 -- 是一个声明，而不是一个表达式
* 注意for的post中只允许一个表达式，所以如果想要在for中使用多个变量，你应该使用 **并行**赋值，如
	* for i, j := 0, len(a)-1; i < j; i, j = i+1, j-1 {}
	* ~~所以也不能在post段使用 ++ 或者 --，因为post中需要一个表达式，但是这两个是声明。~~ 应该说如果在post需要给两个变量赋值时，不能使用 ++ 或者 --

### Switch：

* case后面可以跟多个条件，用逗号分隔即可，如

	* case ' ', '?', '&', '=', '#', '+', '%':
* 与c不同的是，**go的switch中的case子句并不会因为没有break就一直执行**，而是只执行一个case
* 并且switch中的break是为了提前结束case后的代码，从而跳转到switch语句块后
* 如果switch外有for循环，则可以在for外增加label，break + label则在case中可以直接跳转到循环外。当然continue也可以使用label，但是只对loop有用

### Type switch：

* switch 也可以用来发现一个**接口变量的动态类型**。需要配合 type 关键字使用
* 实际上声明了一个具有相同名称但在每种情况下具有不同类型的新变量，如

```go
var t interface{}t = functionOfSomeType()
switch t := t.(type) {  
    default:    fmt.Printf("unexpected type %T\n", t) // %T prints whatever type t has  
    case bool:    fmt.Printf("boolean %t\n", t) // t has type bool  
    case int:    fmt.Printf("integer %d\n", t) // t has type int  
    case *bool:    fmt.Printf("pointer to boolean %t\n", *t) // t has type *bool  
    case *int:    fmt.Printf("pointer to integer %d\n", *t) // t has type *int
}
```

* 类型查询，就是根据变量，查询这个变量的类型。为什么会有这样的需求呢？goalng中有一个特殊的类型interface{}，这个类型可以被任何类型的变量赋值，如果想要知道到底是哪个类型的变量赋值给了interface{}类型变量，就需要使用类型查询来解决这个需求

## Functions：

### Multiple return values：

* 可以返回多个值，避免了类似C的传指针到函数中才能该数值的方式

### Named result parameters：

* 定义函数的返回值类型的时候，也可以指定变量名
* 指定了变量名后，当函数开始时，将会根据它们的类型进行零值初始化，这时函数可以直接return不用添加任何值，会默认返回已经声明的返回变量

### Defer：

* 在解锁互斥锁和关闭文件中最常用
* 在函数返回前，立刻调用被声明为defer的函数
* 如果被defer的函数有参数，那么 **参数值为defer语句执行时参数的值**，不会因为参数在后面的流程中被更改而导致defer函数的参数被修改
* 如果有多个defer时，遵循“LIFO”后进先出的原则，入栈出栈

## Data：

### Allocation with new：
* go有两个分配语句，new和make
* new
	* 内建函数
	* 分配内存，但是不像其他语言一样初始化内存，而是仅仅用零值填充它
	* new(T)在内存分配了一个零化的T，并返回T的指针 *T 
* 由于返回的内存new为零，因此需要零值的数据结构情况下，**可以直接使用不用进一步的初始化**
* 零值有传递性

```go

type SyncedBuffer struct {    
    lock sync.Mutex    
    buffer bytes.Buffer
    }
    p := new(SyncedBuffer) // type *SyncedBuffer
    var v SyncedBuffer // type SyncedBuffer
    
```
### Constructors and composite literals:

* 如果不用初始化结构体的内部字段，则 new(File) 等价于 &File{}
* 可以指定初始化File的某些字段，如 &File{fd: fd, name: name}

### Allocation with make:
	
* 与new相比，内置函数make(T, args)有不同的用途new(T)。它仅创建slice，maps和channels，并返回类型初始化（非零值）的T（不是*T）。
* 有这样的区别的原因是，这三种类型的数据结构必须初始化了才能使用，比如slice必须初始化指向数组的指针、长度、容量，map和channel也是如此。
* 比如，make([]int,10,100)，分配一个100个整数的数组，然后创建一个长度为10且容量为100的切片结构，指向数组的前10个元素。**注意底层是申请cap大小的数组**，而 **c=new([]int) 则返回一个指向新分配slice数据结构**，虽然len和cap会初始化为0，**但是这个slice的指针指向nil，*c ==nil 为true。**
* 以下例子解释了new和make的区别。

```go
var p *[]int = new([]int) // allocates slice structure; *p == nil; rarely useful
var v []int = make([]int, 100) // the slice v now refers to a new array of 100 ints

// Unnecessarily complex:
var p *[]int = new([]int)
*p = make([]int, 100, 100)

// Idiomatic:
v := make([]int, 100)
```

### Arrays:

* 数组在Go和C中的工作方式有很大差异。在Go中，
	* **数组是值，不再是指针**。将一个数组赋值给另一个数组会 **复制**所有元素。
	* 特别是，如果将数组传递给函数，它将接收数组的副本，而不是指向它的指针。
	* **数组的大小是其类型**的一部分。**类型[10]int 和[20]int不同**
* 当然可以用 & 显式地取数组的地址，如

```go
func Sum(a *[3]float64) (sum float64) {    
    for _, v := range *a {        
        sum += v    
        }    
        return
    }

array := [...]float64{7.0, 8.5, 9.1}
x := Sum(&array) // Note the explicit address-of operator
```

### Slice:

* 在go中，slice使用远远比array使用广泛。slice 持有对底层数组的引用，当一个切片赋值给另一个时，将会持有相同数组的引用。
* 如果函数采用slice参数，则对切片元素所做的更改将对调用者可见，类似于将指针传递给基础数组。有疑问
* 对于slice，经常需要Append配合使用，Append实现如下。之后我们必须返回切片，因为虽然Append可以修改切片的元素，但切片本身（运行时的数据结构包含指针，长度和容量）是按值传递的。


```go
func Append(slice, data []byte) []byte {
    l := len(slice)
    if l + len(data) > cap(slice) {  // reallocate
        // Allocate double what's needed, for future growth.
        newSlice := make([]byte, (l+len(data))*2)
        // The copy function is predeclared and works for any slice type.
        copy(newSlice, slice)
        slice = newSlice
    }
    slice = slice[0:l+len(data)]
    copy(slice[l:], data)
    return slice
}
```