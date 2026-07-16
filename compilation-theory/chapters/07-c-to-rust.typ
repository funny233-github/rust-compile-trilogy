#import "../lib.typ": *
= 从 C 到 Rust — 多了什么
#labnote[ 第七站：新语言的编译挑战 ]

前六章讨论的是 C → 汇编的经典模式。现在转到 Rust——它在编译层面比 C 多了什么？

答案出人意料：*大部分"多的东西"在编译时解决，运行时和 C 几乎一样。*

== C 编译器已经解决的问题

#table(
  columns: (auto, auto, auto),
  fill: (rgb("#e5e7eb"),),
  inset: 6pt,
  stroke: 0.5pt,
  [*问题*], [*C 的方式*], [*Rust 也继承*],
  [表达式分解], [三地址码], [相同],
  [控制流翻译], [cmp + jmp], [相同],
  [函数调用], [调用约定 + 栈帧], [相同],
  [类型擦除], [编译后消失], [相同],
  [结构体布局], [字段偏移计算], [相同],
  [寄存器分配], [图着色], [相同],
)

Rust 的编译器后端（LLVM）和 C/C++ 共享——生成的机器码在结构上和 C 编译器生成的没有本质区别。

== Rust 多了什么——在编译时

=== 所有权和借用

Rust 最独特的特性——所有权、借用、生命周期——全部在编译时检查。

```
Rust: let y = &x;  // 借用检查：y 的存活范围不能超过 x
C:    int *y = &x; // 没有任何检查
```

编译完成后，`&x` 和 C 的 `&x` 生成相同的汇编——都是 `lea rax, [rbp-4]`。所有权的信息完全消失了。

#intuition[
  *Rust 的所有权系统是编译时验证，运行时零成本。*

  这适用于：所有权、借用、生命周期、Send/Sync、Unpin……

  编译时验证 → 编译后擦除 → 运行时性能和 C 完全一样。
]

=== 泛型和单态化 (Monomorphization)

```rust
fn max<T: Ord>(a: T, b: T) -> T {
    if a > b { a } else { b }
}

let x = max(3, 5);       // T = i32
let y = max(3.0, 5.0);   // T = f64
```

编译器生成两份独立的机器码——一份给 `i32`，一份给 `f64`。和手动写两个 `max_i32`、`max_f64` 函数完全等价。

```
max_i32:                    max_f64:
    cmp edi, esi                ucomisd xmm0, xmm1
    jge .a                      jae .a
    mov eax, esi                movapd xmm0, xmm1
    ret                     .a:
.a:                             ret
    mov eax, edi
    ret
```

单态化的代价是*代码膨胀*——每个类型组合生成一份代码。但运行时性能和手写特化代码一样快。

== 动态分发：trait object

```rust
fn draw(shape: &dyn Drawable) {
    shape.draw();
}
```

编译器不能为 `dyn Drawable` 做单态化——因为不知道运行时具体是哪个类型。改用 *vtable*：

```
; shape 在 rdi 中
; &dyn Drawable = (data_ptr, vtable_ptr) — fat pointer
mov rax, [rdi + 8]    ; rax = vtable_ptr
call [rax + 0]        ; 调用 vtable[0] = draw 方法
```

#concept[
  *Fat Pointer*：`&dyn Trait` 是 16 字节——8 字节数据指针 + 8 字节 vtable 指针。

  vtable 是一个函数指针数组，每个 trait 方法占一个槽位。

  C++ 的虚函数和 Rust 的 trait object 使用*完全相同的机制*。
]

== Rust 仍然面临和 C 相同的编译问题

尽管 Rust 有更丰富的类型系统，编译后端面对的问题没有变：

- 表达式仍然需要分解为三地址码
- 控制流仍然是 cmp + jmp
- 函数仍然是栈帧 + 调用约定
- 寄存器仍然有限，仍然需要分配
- 优化 pass 仍然在做常量折叠、死代码消除、循环变换

Rust 的创新在*前端*（类型检查、借用验证），不在后端。后端的挑战和 C 编译器完全一样。

== 小结

- Rust 编译后端（LLVM）和 C/C++ 共享——底层相同
- 所有权/借用/生命周期 = 编译时验证，编译后擦除
- 泛型 = 编译时复制粘贴（单态化）
- trait object = vtable + fat pointer（和 C++ 虚函数相同）
- 编译后端的核心挑战（表达式、控制流、函数、寄存器）没变
- Rust 的创新在前端，不在后端
#pagebreak()
