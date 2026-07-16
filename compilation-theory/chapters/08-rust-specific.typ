#import "../lib.typ": *
= Rust 特有构造 → 汇编
#labnote[ 第八站：enum / match / 闭包 / async ]

Rust 有几个 C 没有的语言构造——enum（带数据的 tagged union）、match 穷尽模式匹配、闭包、async/await。它们在汇编层怎么表示？

== enum 和 match

```rust
enum Option<T> {
    None,
    Some(T),
}

fn unwrap_or_default(x: Option<i32>) -> i32 {
    match x {
        Some(v) => v,
        None => 0,
    }
}
```

汇编层实现是 *tagged union*：一个 tag（判别符）+ union（数据）。

```
; Option<i32> 的内存布局（niche 优化前）
; offset 0: tag (0 = None, 1 = Some)
; offset 4: data (在 Some 时有效，4 字节对齐后可能偏移 8)
```

match 编译为：

```
    cmp [rdi], 0          ; tag == None ?
    je .none
    mov eax, [rdi + 4]    ; Some(v) → 取 v
    ret
.none:
    xor eax, eax           ; return 0
    ret
```

=== Niche 优化

`Option<&T>` 利用了一个事实：引用不可能为 null。所以 `None` = null pointer：

```
Option<&T> 的内存布局：
  Some(ptr) → 存储 ptr
  None      → 存储 0x0 (null)

不需要额外的 tag 字段——嵌入在指针值的 null 状态中。
```

#intuition[
  `Option<Box<T>>`、`Option<&T>`、`Option<NonZeroU32>` 都享受 niche 优化。

  编译器找到一个类型的"不可能值"，用那个值表示 `None`。
  这完全免费——不需要额外的 tag 字节。
]

=== 跳转表

当 match 的 arm 很多且判别符的值密集时，用跳转表（和 C switch 一样）：

```rust
match x {
    0 => ..., 1 => ..., 2 => ..., ..., 10 => ...
}
```

```
    cmp eax, 10; ja .default
    jmp [jt + rax*8]
jt: .quad .L0, .L1, .L2, ..., .L10
```

== 闭包

=== 无捕获闭包

```rust
let f = |x| x + 1;
```

不捕获任何环境变量 → 就是普通函数指针：

```rust
// 编译后等价于
fn __closure_1(x: i32) -> i32 { x + 1 }
let f = __closure_1 as fn(i32) -> i32;
```

=== 捕获闭包

```rust
let base = 10;
let f = |x| x + base;
```

捕获了 `base` → 变成一个 struct + call 方法：

```rust
// 编译器生成的
struct __Closure_1 { base: i32 }

impl Fn(i32) -> i32 for __Closure_1 {
    fn call(&self, x: i32) -> i32 { x + self.base }
}

let f = __Closure_1 { base: 10 };
```

汇编层面：`f(x)` 变成加载 `f.base` + 做加法的普通指令序列。没有动态分发。

=== trait object 闭包

```rust
let f: Box<dyn Fn(i32) -> i32> = Box::new(|x| x + base);
```

`dyn Fn` → vtable。调用 `f(x)` → load vtable → call vtable[0]。

== async / .await

```rust
async fn fetch() -> i32 { ... }
```

编译器把 async 函数转换为*状态机*：

```rust
// 编译器生成的
enum FetchFuture {
    Start,
    AfterFirstAwait { /* 保存的局部变量 */ },
    Done,
}

impl Future for FetchFuture {
    fn poll(self: Pin<&mut Self>, cx: &mut Context) -> Poll<i32> {
        match *self {
            FetchFuture::Start => {
                // ...启动异步操作...
                *self = FetchFuture::AfterFirstAwait { ... };
                Poll::Pending
            }
            FetchFuture::AfterFirstAwait { ... } => {
                // ...继续...
                Poll::Ready(result)
            }
            FetchFuture::Done => panic!("polled after ready"),
        }
    }
}
```

#concept[
  async fn 的核心变换：*函数体 → 状态机*。

  每个 `.await` 点是状态机的一个状态。
  局部变量跨 `.await` 存活 → 保存在状态机结构体中。

  这是 Rust 编译器中最复杂的变换之一——但输出仍然是普通的汇编。
]

== 所有 Rust 构造的汇编归宿

#table(
  columns: (auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*Rust 构造*], [*汇编表示*],
  [`enum`], [tag + union],
  [`match`], [cmp + jmp / 跳转表],
  [`Option<T>`], [niche 优化后可能是 null],
  [闭包（无捕获）], [函数指针],
  [闭包（捕获）], [struct + 函数调用],
  [trait object], [fat pointer + vtable],
  [`async fn`], [状态机 enum],
  [`.await`], [状态机的 poll 方法],
  [`Box<T>`], [指针（和 C `malloc` 一样）],
  [`&T`], [指针],
  [`Vec<T>`], [ptr + len + cap（3 个字段）],
)

所有高级抽象最终都变成：mov、add、cmp、jmp、call、ret。

#intuition[
  这是 Rust 设计的精妙之处：*丰富的类型系统 + 零成本抽象*。

  编译器在编译时做了大量的分析和变换——
  但最终生成的机器码和精心手写的 C 一样精简。
]

== 练习

#note[
  *题目位置*：`exercises/src/ch08_enum.rs`

  *任务*：实现 `call_draw` 函数——通过 vtable（虚函数表）调用 trait 方法。这是 `&dyn Trait` 动态分发的底层机制，和 C++ 的虚函数调用完全相同。

  *验证*：`cd exercises && cargo test ch08`

  *答案参考*：`exercises/answers/ch08_enum.rs`
]

提示：fat pointer 的后 8 字节是指向 vtable 的指针；解引用 vtable 得到函数指针表，第一个槽位就是第一个 trait 方法。用 `unsafe` 块调用原始函数指针。

== 小结

- enum = tagged union（tag + union 的内存布局）
- match = cmp + jmp 或跳转表
- Niche 优化让 Option<&T> 等零额外开销
- 闭包 = 函数指针（无捕获）或 struct（捕获）
- async fn = 状态机变换
- 所有高级构造最终变成 mov/add/cmp/jmp/call/ret
- 编译后的 Rust 和编译后的 C 在汇编层几乎无法区分
#pagebreak()
