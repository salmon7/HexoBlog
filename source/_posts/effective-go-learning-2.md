---
title: effective go learning 2
date: 2018-11-14 01:10:09
tags:
    - go
---

从Two-dimensional slices开始，使用中文版的effctive_go学习  
https://www.kancloud.cn/kancloud/effective/72207

## Data：  
### 二维切片:  
* Go的数组和切片都是一维的。要创建等价的二维数组或者切片，需要定义一个数组的数组或者切片的切片。

### Maps:  
* Map是一种方便，强大的内建数据结构，其将一个类型的值（key）与另一个类型的值（element或value） 关联一起。
* key可以为任何 __定义了等于操作符__ 的类型，例如整数，浮点和复数，字符串，指针，接口（只要其动态类型支持等于操作），结构体和数组。
* __切片不能 作为map的key，因为它们没有定义等于操作__。和切片类似，__map持有对底层数据结构的引用。如果将map传递给函数，其对map的内容做了改变，则这些改变对于调用者是可见的__。

```go
attended := map[string]bool{
    "Ann": true,
    "Joe": true,
    ...}

if attended[person] { // will be false if person is not in the map
    fmt.Println(person, "was at the meeting")}
```
    
* 如果只测试是否在map中存在，而不关心实际的值，你可以将通常使用变量的地方换成空白标识符（_）

```go
_, present := timeZone[tz]
```

* 要删除一个map项，使用delete内建函数，其参数为map和要删除的key。即使key已经不在map中，这样做也是安全的。

```go
delete(timeZone, "PDT")  // Now on Standard Time
```

* __map不太好判断是否存在某个key，如果key不存在返回的对应类型的零值，如果已有key的value恰好为零值会导致误判__

### 打印输出
* Go中的格式化打印使用了与C中printf家族类似的风格，不过更加丰富和通用。这些函数位于fmt程序包中，并具有大写的名字：fmt.Printf，fmt.Fprintf，fmt.Sprintf等等。字符串函数（Sprintf等）返回一个字符串，而不是填充到提供的缓冲里。
* 你不需要提供一个格式串。对每个Printf，Fprintf和Sprintf，都有另外一对相应的函数，例如Print和Println。这些函数不接受格式串，而是为每个参数生成一个缺省的格式。Println版本还会在参数之间插入一个空格，并添加一个换行，而Print版本只有当两边的操作数都不是字符串的时候才增加一个空格。在这个例子中，每一行都会产生相同的输出。
* 格式化打印函数fmt.Fprint等，接受的第一个参数为任何一个实现了io.Writer接口的对象；变量os.Stdout和os.Stderr是常见的实例。
* 如果只是想要缺省的转换，像十进制整数，你可以使用 __通用格式%v（代表“value”）__；这正是Print和Println所产生的结果。而且，这个格式可以打印任意的的值，甚至是数组，切片，结构体和map。
* 当打印一个结构体时，带修饰的格式 __%+v会将结构体的域使用它们的名字进行注解__，对于任意的值，格式%#v会按照完整的Go语法打印出该值。
* 还可以通过 __%q__ 来实现带引号的字符串格式，用于类型为 __string或[]byte__ 的值。格式 __%#q__ 将尽可能的使用反引号。（格式%q还用于整数和符文，产生一个带单引号的符文常量。）
* __%x__ 用于字符串，字节数组和字节切片，以及整数，生成一个 __长的十六进制字符串__，并且如果在格式中 __有一个空格（% x）__，其将会在 __字节中插入空格__。
* 不要在Sprintf里面调用接收者的String方法，否则会造成无穷递归，如下。只有%s匹配才会调用MyString的String方法

```go
type MyString string

func (m MyString) String() string {
    return fmt.Sprintf("MyString=%s", m) // Error: will recur forever.
//    return fmt.Sprintf("MyString=%s", string(m)) // OK: note conversion.
}
```

* 另一种打印技术，是将一个打印程序的参数直接传递给另一个这样的程序。Printf的签名使用了类型...interface{}作为最后一个参数，来指定在格式之后可以出现任意数目的（任意类型的）参数。

### append内建函数:
* 其中T为任意给定类型的占位符。你在Go中是无法写出一个类型T由调用者来确定的函数。这就是为什么append是内建的：它需要编译器的支持。append所做的事情是将元素添加到切片的结尾，并返回结果。

```go
func append(slice []T, elements ...T) []T

x := []int{1,2,3}
x = append(x, 4, 5, 6)
fmt.Println(x)
```

* 如果想要在append中把一个slice添加到另一个slice要怎么做？在调用点使用 "..."，

```go
x := []int{1,2,3}
y := []int{4,5,6}
x = append(x, y...)
fmt.Println(x)
```

* 可以看出 "..." 的作用是，把一个slice转为对应的type，作为一个参数列表进行传递

<!--more-->

## 初始化：
### 常量:
* 在编译时被创建，即使被定义为函数局部的也如此，并且只能是数字，字符（符文），字符串或者布尔类型。
* 由于编译时的限制，定义它们的表达式必须为能被编译器求值的常量表达式。例如，1<<3是一个常量表达式，而math.Sin(math.Pi/4)不是，因为函数调用math.Sin需要在运行时才发生.
* 在Go中，枚举常量使用iota枚举器来创建。由于iota可以为表达式的一部分，并且表达式可以被隐式的重复，所以很容易创建复杂的值集。
* Sprintf只有当想要一个字符串的时候，才调用String方法，而%f是想要一个浮点值。

### init函数:
* init是在 __程序包中所有变量声明都被初始化__，以及所有 __被导入的程序包中的变量初始化之后才被调用__。

## 方法：
### 指针 vs. 值:
* 关于接收者对指针和值的规则是这样的，值方法可以在指针和值上进行调用，而指针方法只能在指针上调用。
* 这是因为指针方法可以修改接收者；使用拷贝的值来调用它们，将会导致那些修改会被丢弃。

## 接口和其他类型：
### 接口:
* 类型可以实现多个接口。例如，如果一个集合实现了sort.Interface，其包含Len()，Less(i, j int) bool和Swap(i, j int)，那么它就可以通过程序包sort中的程序来进行排序，同时它还可以有一个自定义的格式器。

### 转换:
* 因为如果我们忽略类型名字，这两个类型（Sequence和[]int）是相同的，在它们之间进行转换是合法的。该转换并不创建新的值，只不过是暂时使现有的值具有一个新的类型。（__有其它的合法转换，像整数到浮点，是会创建新值的__。）
* 将表达式的类型进行转换，来访问不同的方法集合，这在Go程序中是一种常见用法。例如，我们可以使用已有类型sort.IntSlice来将整个例子简化成这样：

```go
type Sequence []int

// Method for printing - sorts the elements before printing
func (s Sequence) String() string {
    sort.IntSlice(s).Sort()
    return fmt.Sprint([]int(s))
}
```

* 现在，Sequence没有实现多个接口（排序和打印），相反的，我们利用了能够将数据项转换为多个类型（Sequence，sort.IntSlice和[]int）的能力，每个类型完成工作的一部分。这在实际中不常见，但是却可以很有效。

### 接口转换和类型断言：
* type-switch 语句

```go
var value interface{} // Value provided by caller.
switch str := value.(type) {
case string:
    return str
case Stringer:
    return str.String()
}
```

* 强制转换语句

```go
str, ok := value.(string)
if ok {
    fmt.Printf("string value is: %q\n", str)} else {
    fmt.Printf("value is not a string\n")
}
```

* type-if 语句

```go
if str, ok := value.(string); ok {
    return str
} else if str, ok := value.(Stringer); ok {
    return str.String()
}
```

### 概述
* 如果一个类型只是用来实现接口，并且除了该接口以外没有其它被导出的方法，那就不需要导出这个类型。只导出接口，清楚地表明了其重要的是行为，而不是实现，并且其它具有不同属性的实现可以反映原始类型的行为。这也避免了对每个公共方法实例进行重复的文档介绍。

### 接口和方法:
* 由于几乎任何事物都可以附加上方法，所以几乎任何事物都能够满足接口的要求。
* ArgServer现在具有和 __HandlerFunc相同的签名__，所以其可以被转换为那个类型：

```go
// Argument server.
func ArgServer(w http.ResponseWriter, req *http.Request) {
    fmt.Fprintln(w, os.Args)
}
```

## 空白标志符：
### 空白标识符在多赋值语句中的使用:
*  空白标识符在for range循环中使用的其实是其应用在多语句赋值情况下的一个特例。
* 一个多赋值语句需要多个左值，但假如其中某个左值在程序中并没有被使用到，那么就可以用空白标识符来占位，以避免引入一个新的无用变量。

### 未使用的导入和变量:
* 如果你在程序中导入了一个 __包__ 或声明了一个 __变量__ 却没有使用的话,会引起编译错误。

```go
package main

import (
    "fmt"
    "io"
    "log"
    "os")

var _ = fmt.Printf // For debugging; delete when done.
var _ io.Reader    // For debugging; delete when done.

func main() {
    fd, err := os.Open("test.go")
    if err != nil {
        log.Fatal(err)
    }
    // TODO: use fd.
    _ = fd
}
```

* 按照约定，用来临时禁止未使用导入错误的全局声明语句必须 __紧随导入语句块__ 之后，并且需要提供相应的注释信息 —— 这些规定使得将来很容易找并删除这些语句。

### 副作用式导入:
* 像上面例子中的导入的包，fmt或io，最终要么被使用，要么被删除：使用空白标识符只是一种临时性的举措。但有时，导入一个包仅仅是为了引入一些副作用，而不是为了真正使用它们。
* 例如，net/http/pprof包会在其导入阶段调用init函数，该函数注册HTTP处理程序以提供调试信息。这个包中确实也包含一些导出的API，但大多数客户端只会通过注册处理函数的方式访问web页面的数据，而不需要使用这些API。
* 为了实现仅为副作用而导入包的操作，可以在导入语句中，将包用空白标识符进行重命名：

```go
import _ "net/http/pprof"
```

* 这一种非常干净的导入包的方式，由于在当前文件中，__被导入的包是匿名的__，因此你无法访问包内的任何符号。

接口检查:
* 一个类型不需要明确的声明它实现了某个接口。一个类型要实现某个接口，只需要实现该接口对应的方法就可以了。
* 在实际中，多数接口的类型转换和检查都是在编译阶段静态完成的。
	* 其中一个例子来自encoding/json包内定义的Marshaler接口。
	* 当JSON编码器接收到一个实现了Marshaler接口的参数时，就调用该参数的marshaling方法来代替标准方法处理JSON编码。编码器利用类型断言机制在运行时进行类型检查：

```go
m, ok := val.(json.Marshaler)
```

* 假设我们只是想知道某个类型是否实现了某个接口，而实际上并不需要使用这个接口本身 —— 例如在一段错误检查代码中 —— 那么可以使用空白标识符来忽略类型断言的返回值：

```go
if _, ok := val.(json.Marshaler); ok {
    fmt.Printf("value %v of type %T implements json.Marshaler\n", val, val)
}
```

* 在某些情况下，我们必须在包的内部确保某个类型确实满足某个接口的定义。例如类型json.RawMessage，如果它要提供一种定制的JSON格式，就必须实现json.Marshaler接口，但是编译器不会自动对其进行静态类型验证。如果该类型在实现上没有充分满足接口定义，JSON编码器仍然会工作，只不过不是用定制的方式。为了确保接口实现的正确性，可以在包内部，利用空白标识符进行一个全局声明：

```go
var _ json.Marshaler = (*RawMessage)(nil)
```

* 在该声明中，赋值语句导致了从 __*RawMessage到Marshaler的类型转换__，这要求 __*RawMessage必须正确实现了Marshaler接口__ ，该属性将在编译期间被检查。当json.Marshaler接口被修改后，上面的代码将无法正确编译，因而很容易发现错误并及时修改代码。
* 在这个结构中出现的空白标识符，表示了该声明语句仅仅是为了触发编译器进行类型检查，而非创建任何新的变量。但是，也不需要对所有满足某接口的类型都进行这样的处理。按照约定，这类声明仅当代码中没有其他静态转换时才需要使用，这类情况通常很少出现。

## 内嵌：
* 接口只能“内嵌”接口类型。
* 在“内嵌”和“子类型”两种方法间存在一个重要的区别。当我们内嵌一个类型时，该类型的所有方法会变成外部类型的方法，但是当这些方法被调用时，其接收的参数仍然是内部类型，而非外部类型。在本例中，一个bufio.ReadWriter类型的Read方法被调用时，其效果和调用我们刚刚实现的那个Read方法是一样的，只不过前者接收的参数是ReadWriter的reader字段，而不是ReadWriter本身。

## 并发：
### 以通信实现共享：
* Go语言鼓励开发者采用一种不同的方法，即将共享 变量通过Channel相互传递 —— 事实上并没有真正在不同的执行线程间共享数据 —— 的方式解决上述问题。在任意时刻，仅有一个Goroutine可以访问某个变量。数据竞争问题在设计上就被规避了。

### Goroutines:
* 每个Goroutine都对应一个非常简单的模型：它是一个并发的函数执行线索，并且在多个并发的Goroutine间，资 源是共享的。
* Goroutine非常轻量，创建的开销不会比栈空间分配的开销大多少。并且其初始栈空间很小 —— 这也就是它轻量的原因 —— 在后续执行中，会根据需要在堆空间分配（或释放）额外的栈空间。
* 闭包（closure）：实现保证了在这类函数中被 __引用的变量在函数结束之前不会被释放__。

### Channel:
* 与map结构类似，channel也是通过make进行分配的，其返回值实际上是一个指向底层相关数据结构的引用。
* 如果在创建channel时提供一个可选的整型参数，会设置该channel的缓冲区大小。该值缺省为0，用来构建默认的“无缓冲channel”，也称为“同步channel”。

```go
ci := make(chan int)            // unbuffered channel of integers
cj := make(chan int, 0)         // unbuffered channel of integers
cs := make(chan *os.File, 100)  // buffered channel of pointers to Files
```

* 无缓冲的channel使得通信—值的交换—和同步机制组合—共同保证了两个执行线索（Goroutines）运行于可控的状态。
* __循环的迭代变量会在循环中被重用__，因此req变量会在所有Goroutine间共享。
* 为了避免在多个goroutine中贡献变量，可以把参数用函数参数的形式传入，可以创建一个新的同名变量，如下。但它确实是合法的并且在Go中是一种惯用的方法。你可以如法泡制一个新的同名变量，用来为每个Goroutine创建循环变量的私有拷贝。

```go
func Serve(queue chan *Request) {
    for req := range queue {
        <-sem
        req := req // Create new instance of req for the goroutine.
        go func() {
            process(req)
            sem <- 1
        }()
    }}
```

### Channel类型的Channel:
* Channel在Go语言中是一个 first-class 类型，这意味着channel可以像其他 first-class 类型变量一样进行分配、传递。该属性的一个常用方法是用来实现安全、并行的解复用（demultiplexing）处理。

### 并行:
* 对于用户态任务，我们默认仅提供一个物理CPU进行处理。任意数目的Goroutine可以阻塞在系统调用上，但 __默认情况下，在任意时刻，只有一个Goroutine__ 可以被调度执行。
* 目前，你必须通过 __设置GOMAXPROCS环境变量__ 或者 __导入runtime包并调用runtime.GOMAXPROCS(NCPU)__, 来告诉Go的运行时系统最大并行执行的Goroutine数目。
* __可以通过runtime.NumCPU()__ 获得当前运行系统的逻辑核数，作为一个有用的参考。需要重申：上述方法可能会随我们对实现的完善而最终被淘汰。
* 注意不要把“并发”和“并行”这两个概念搞混：“并发”是指用一些彼此独立的执行模块构建程序；而“并行”则是指通过将计算任务在多个处理器上同时执行以 提高效率。尽管对于一些问题，我们可以利用“并发”特性方便的构建一些并行的程序部件，但是Go终究是一门“并发”语言而非“并行”语言，并非所有的并行 编程模式都适用于Go语言模型。

## 错误：
* 向调用者返回某种形式的错误信息是库历程必须提供的一项功能。通过前面介绍的函数多返回值的特性，Go中的错误信息可以很容易同正常情况下的返回值一起返回给调用者。
* 对于需要精确分析错误信息的调用者，可以通过类型开关或类型断言的方式查看具体的错误并深入错误的细节。就PathErrors类型而言，这些细节信息包含在一个内部的Err字段中，可以被用来进行错误恢复。

```go
for try := 0; try < 2; try++ {
    file, err = os.Create(filename)
    if err == nil {
        return
    }
    if e, ok := err.(*os.PathError); ok && e.Err == syscall.ENOSPC {
        deleteTempFiles()  // Recover some space.
        continue
    }
    return
}
```

* 第二个if语句是另一种形式的类型断言。如该断言失败，ok的值将为false且e的值为nil。如果断言成功，则ok值为true，说明当前的错误，也就是e，属于*os.PathError类型，因而可以进一步获取更多的细节信息。

### 严重故障（Panic）:
* 通常来说，向调用者报告错误的方式就是返回一个额外的error变量： Read方法就是一个很好的例子；该方法返回一个字节计数值和一个error变量。但是对于那些不可恢复的错误，比如错误发生后程序将不能继续执行的情况，该如何处理呢？
* 为了解决上述问题，Go语言提供了一个内置的 __panic方法__，用来 __创建一个运行时错误并结束当前程序__（关于退出机制，下一节还有进一步介绍）。该函数接受一个任意类型的参数，并在程序挂掉之前打印该参数内容，通常我们会选择一个字符串作为参数。方法panic还适用于指示一些程序中的不可达状态，比如从一个无限循环中退出。
* 在实际的库设计中，应尽量避免使用panic。如果程序错误可以以某种方式掩盖或是绕过，那么最好还是继续执行而不是让整个程序终止。不过还是有一些反例的，比方说，如果库历程确实没有办法正确完成其初始化过程，那么触发panic退出可能就是一种更加合理的方式。

```go
var user = os.Getenv("USER")

func init() {
    if user == "" {
        panic("no value for $USER")
    }
}
```

### 恢复（Recover）:
* 对于一些隐式的运行时错误，如切片索引越界、类型断言错误等情形下，panic方法就会被调用，它将 __立刻中断当前函数的执行，并展开当前Goroutine的调用栈，依次执行之前注册的defer函数。当栈展开操作达到该Goroutine栈顶端时，程序将终止__。但这时仍然 __可以使用Go的内建recover方法重新获得Goroutine的控制权，并将程序恢复到正常执行的状态__。
* 调用recover方法会终止栈展开操作并返回之前传递给panic方法的那个参数。由于在栈展开过程中，只有defer型函数会被执行，因此recover的调用必须置于defer函数内才有效。
* 在下面的示例应用中，调用recover方法会终止server中失败的那个Goroutine，但server中其它的Goroutine将继续执行，不受影响。

```go
func server(workChan <-chan *Work) {
    for work := range workChan {
        go safelyDo(work)
    }}

func safelyDo(work *Work) {
    defer func() {
        if err := recover(); err != nil {
            log.Println("work failed:", err)
        }
    }()
    do(work)
}
```

* 在这里例子中，如果do(work)调用发生了panic，则其结果 __将被记录且发生错误的那个Goroutine将干净的退出__，不会干扰其他Goroutine。你不需要在defer指示的闭包中做别的操作，仅需调用recover方法，它将帮你搞定一切。
* 只有直接在defer函数中调用recover方法，才会返回非nil的值，因此defer函数的代码可以调用那些本身 __使用了panic和recover的库函数__ 而不会引发错误。还用上面的那个例子说明：safelyDo里的defer函数在调用recover之前可能调用了一个日志记录函数，而日志记录程序的执行将不受panic状态的影响。（这段话的意思讨论的是，在defer函数中需要使用其他库函数时，如果该库函数也使用了panic和recover来优雅退出自身的函数调用链，那么将不会影响defer函数中panic的状态；如果未使用相关的技术，那么将会污染/影响defer函数对panic判断。recover返回空则未panic，返回非空则panic）
* 有了错误恢复的模式，do函数及其调用的代码可以通过调用panic方法，以 __一种很干净的方式从错误状态中恢复__。我们可以使用该特性为那些复杂的软件实现更加简洁的错误处理代码。
* 让我们来看下面这个例子，它是regexp包的一个简化版本，它通过调用panic并传递一个局部错误类型来报告“解析错误”（Parse Error）。下面的代码包括了Error类型定义，error处理方法以及Compile函数：

```go
// Error is the type of a parse error; it satisfies the error interface.
type Error string
func (e Error) Error() string {
    return string(e)}

// error is a method of *Regexp that reports parsing errors by// panicking with an Error.
func (regexp *Regexp) error(err string) {
    panic(Error(err))}

// Compile returns a parsed representation of the regular expression.
func Compile(str string) (regexp *Regexp, err error) {
    regexp = new(Regexp)
    // doParse will panic if there is a parse error.
    defer func() {
        if e := recover(); e != nil {
            regexp = nil    // Clear return value.
            err = e.(Error) // Will re-panic if not a parse error.
        }
    }()
    return regexp.doParse(str), nil
}
```

* 如果doParse方法触发panic，错误恢复代码会将返回值置为nil—因为defer函数可以修改命名的返回值变量；然后，错误恢复代码会对返回的错误类型进行类型断言，__判断其是否属于Error类型__。如果类型断言失败，则会引发运行时错误，并继续进行栈展开，最后终止程序 —— 这个过程将不再会被中断。类型检查失败可能意味着程序中还有其他部分触发了panic，如果某处存在索引越界访问等，因此，即使我们已经使用了panic和recover机制来处理解析错误，程序依然会异常终止。（err = e.(Err)是上面代码的关键部分，如果断言失败，则意味着不是本包有意抛出的panic，因此应该继续向上抛出直至被再次捕捉或者最终终止程序；panic(Error(err)) 这句代码对err进行了类型转换，并传入panic函数中）
* 有了上面的错误处理过程，调用error方法（由于它是一个类型的绑定的方法，因而即使与内建类型error同名，也不会带来什么问题，甚至是一直更加自然的用法）使得“解析错误”的报告更加方便，无需费心去考虑手工处理栈展开过程的复杂问题。
* 上面这种模式的妙处在于，__它完全被封装在模块的内部__，Parse方法将其 __内部对panic的调用隐藏在error之中__；而不会将panics信息暴露给外部使用者。这是一个 __设计良好且值得学习的编程技巧__。
* 这样做的缺点是：
	* 顺便说一下，当确实有错误发生时，我们习惯采取的“重新触发panic”（re-panic）的方法会改变panic的值。但 __新旧错误信息都会出现在崩溃 报告中（上面新错误信息为： interface conversion: interface {} is xxx, not main.Error）__，引发错误的原始点仍然可以找到。所以，通常这种简单的重新触发panic的机制就足够了—所有这些错误最终导致了程序的崩溃 __（可以通过查阅调用栈的方式找到真正发生错误的地方）__—但是如果只想显示最 初的错误信息的话，你就需要稍微多写一些代码来过滤掉那些由重新触发引入的多余信息。这个功能就留给读者自己去实现吧！

