#import "../lib.typ": *
= C 函数 → 汇编
#labnote[ 第四站：栈帧与调用约定 ]

函数调用是编译中最复杂的部分——涉及参数传递、栈管理、返回值、寄存器保存和恢复。

== 调用约定的意义

#definition[
  *调用约定*（calling convention）是调用者和被调用者之间关于参数传递、栈清理和寄存器使用的协议。

  没有它，调用者不知道把参数放哪里，被调用者不知道返回值放哪里，两边的寄存器使用互相覆盖。

  不同的 ABI（Application Binary Interface）定义了不同的调用约定。
]

=== System V AMD64 ABI（Linux/macOS 上 C 的默认约定）

| 方面 | 规则 |
|:---|:---|
| 整数参数 1–6 | `rdi` `rsi` `rdx` `rcx` `r8` `r9` |
| 浮点参数 1–8 | `xmm0`–`xmm7` |
| 多余参数 | 栈传递（从右到左压栈） |
| 返回值 | `rax`（整数）或 `xmm0`（浮点） |
| 被调用者保存 | `rbx` `rbp` `r12`–`r15` — 被调用者必须恢复 |
| 调用者保存 | `rax` `rcx` `rdx` `rsi` `rdi` `r8`–`r11` — 调用者自己保存 |
| 栈对齐 | 调用前 16 字节对齐 |

#concept[
  被调用者保存 vs 调用者保存：

  - *被调用者保存*：函数如果要用这些寄存器，必须先 push 旧值，返回前 pop 回去。
  - *调用者保存*：如果调用者在这些寄存器中存了重要数据，必须在调用前自己保存。

  这避免了每个 call 都要保存所有寄存器——只有真正需要的才保存。
]

== 栈帧

```c
int add(int a, int b) {
    int result = a + b;
    return result;
}
```

这个函数的栈帧（简化）：

```
       高地址
    +---------------+
    | 返回地址       |  ← call 指令自动 push
    +---------------+
    | 旧 rbp        |  ← push rbp; mov rbp, rsp
    +---------------+  ← rbp
    | result (-4)   |  ← 局部变量
    +---------------+  ← rsp
       低地址
```

汇编：

```asm
add:
    push rbp
    mov rbp, rsp
    sub rsp, 16          ; 分配局部变量空间（这里只需要 4，对齐到 16）
    mov [rbp-4], edi     ; result = a  (a 在 edi 中)
    add [rbp-4], esi     ; result += b  (b 在 esi 中)
    mov eax, [rbp-4]     ; 返回值 = result
    leave                ; mov rsp, rbp; pop rbp
    ret
```

#intuition[
  栈帧就是函数在栈上划出的一小块私有空间。

  里面放着：
  - 旧的 rbp（链式回溯）
  - 返回地址（知道返回哪里）
  - 局部变量
  - 溢出的寄存器
  - 传给下一级函数的额外参数
]

== call 和 ret 的内部操作

```asm
call func
```

等价于：

```asm
push rip+5       ; 把下一条指令地址压栈
jmp func         ; 跳到函数
```

```asm
ret
```

等价于：

```asm
pop rip          ; 从栈顶弹出返回地址，跳到那里
```

整个机制依赖栈——`call` 把返回地址 push 到栈上，`ret` 从栈上 pop 回来。递归就是这个机制的自动应用。

== 递归的栈展开

```c
int factorial(int n) {
    if (n <= 1) return 1;
    return n * factorial(n - 1);
}
```

调用 `factorial(3)` 时栈的样子：

```
factorial(1)  rbp → [n=1, ...]
factorial(2)  rbp → [n=2, ...]
factorial(3)  rbp → [n=3, ...]
main          rbp → [...]
```

每次递归调用在栈上 push 一个新的帧，返回时 pop 掉。如果递归太深——`factorial(1000000)`——栈溢出。

== 尾调用优化

```c
int tail_sum(int n, int acc) {
    if (n == 0) return acc;
    return tail_sum(n - 1, acc + n);  // 尾调用
}
```

尾调用的特点：调用者的栈帧在调用之后不再需要。编译器可以*复用*调用者的栈帧：

```asm
tail_sum:
    cmp edi, 0
    jne .recurse
    mov eax, esi         ; return acc
    ret
.recurse:
    add esi, edi         ; acc += n
    sub edi, 1           ; n--
    jmp tail_sum         ; 不是 call！是 jmp——复用栈帧
```

#intuition[
  尾调用优化把 `call + ret` 变成 `jmp`：

  正常调用：`call func; ...; ret` — 每个调用占用一个新栈帧
  尾调用：`jmp func` — 复用当前栈帧，O(1) 栈空间

  这就是为什么尾递归不会栈溢出。
]

== 和 MLOG 的对比

| 特性 | x86 函数 | MLOG |
|:---|:---|:---|
| 调用机制 | call / ret + 栈 | *不支持* |
| 参数传递 | 寄存器 + 栈 | N/A |
| 局部变量 | 栈帧 | 全局变量（唯一名称化） |
| 递归 | 自动（栈） | 不可能 |
| 编译策略 | 复杂的栈帧管理 | 内联展开所有逻辑 |

MLOG 没有调用栈——这不是 bug，是设计约束。我们的 MLOG 编译器通过内联展开模拟"函数"——把所有逻辑铺平成一条指令流。

#concept[
  函数编译的通用模式：

  1. 调用者把参数放到约定位置（寄存器或栈）
  2. `call` 保存返回地址
  3. 被调用者建立栈帧（push rbp; mov rbp, rsp）
  4. 执行函数体
  5. 把返回值放入约定寄存器
  6. 恢复栈帧，`ret` 返回
]

== 小结

- 调用约定是调用者和被调用者的协议
- 栈帧 = 函数在栈上的私有空间
- call = push 返回地址 + jmp；ret = pop + jmp
- 递归依赖栈，尾调用可以优化为循环
- MLOG 没调用栈——所有逻辑必须内联展开
- 函数编译的核心问题：参数传递、栈管理、寄存器保存
#pagebreak()
