# Walker 资源与错误传播设计

> 状态：2026-07-18，实施中。本文约束 `secDirWalker` 的递归工作集与错误语义；不代表 PlainFS 流式化、FFI 分页或 Flutter 虚拟列表已经完成。

## 问题

当前 secure walker 每次只从目录读取固定数量的 backing entry，但递归模式会把同层所有子目录的逻辑路径压入内存栈。超宽目录可使该栈随目录数量无界增长。另一方面，名称解密、`DirEntry.Info`、`ReadDir` 等错误曾被跳过，FFI `ReadDir_FFI` 与 CLI `list` 还会把 `HasNext()` 的 false 视为正常结束，调用方无法区分完整列表与不完整列表。

## 第一阶段边界

第一阶段不改变公开 walker 的逐项接口，也不宣称任意目录都可在固定内存内完整遍历。采用下列 fail-closed 策略：

- recursive walker 的待处理目录数默认最多 1024、绝对最多 4096；达到上限返回稳定的 `ErrWalkerWorkLimit`，不再继续扫描或静默丢弃子树；
- 当前打开目录文件始终只有一个，已入栈项目只保存逻辑相对路径；
- 递归深度由每个栈项自己的 depth 表示，不能使用“已切换目录次数”冒充深度；
- `MaxDepth` 沿用现有含义：限制是否继续打开子目录，边界外的首个目录条目仍可被返回；
- 任何未被 ignore 规则排除的名称解密、entry metadata、目录读取或路径转换失败都必须从 `Next`/`NextBatch` 返回；
- `_cryption.json` 与 `.transfer_v3` 是声明的 plaintext 内部对象，必须在名称解密前由默认 ignore matcher 过滤；其它 plaintext 名称位于名称加密 root 时视为损坏；
- `HasNext` 只能是便利性提示，无法承载错误；FFI、CLI 和 Transfer 必须以 `Next()==io.EOF` 作为唯一正常结束条件。

该选择牺牲了超宽目录的全量操作能力，换取内存上限和不丢数据的错误边界。对超限 root，UI/CLI 应显示具体扫描失败，Transfer 保留现有 unfinished marker，下一次操作在没有提高能力前仍会失败而不是伪造“已完成”。

## 不采用的方案

- **删除 lock 或只缩小 batch**：不影响待处理子目录数量。
- **立即深度优先并保持父目录打开**：目录深度会转化为无上限 file descriptor 占用。
- **关闭后重新打开父目录并跳过已读项**：超宽、多子目录场景退化为二次甚至平方级扫描，且目录并发变更语义更差。
- **内存队列无限扩容**：只是把 OOM 推迟。

真正无损的大树遍历需要带校验的外部工作队列或分页/continuation token，并同时定义临时状态生命周期、取消、崩溃清理和目录并发变更语义。这是后续独立设计，不能与本阶段混合。

## 实施证据

- 2026-07-18：`secDirWalker` 已实现默认/绝对 pending directory 上限、栈项 depth、关闭时释放工作集，以及名称解密和 metadata 错误传播。
- `ReadDir_FFI` 与 CLI `list` 现直接消费 `Next()`，只将 `io.EOF` 当作成功结束；真实 FFI 和 CLI 测试覆盖未声明的明文 store entry 返回错误。

## 验收

- 宽度超过上限时返回 `ErrWalkerWorkLimit`，不会返回部分成功或遗漏错误。
- 深层树使用固定 batch 正常完成，递归深度与 `MaxDepth` 语义正确。
- 损坏名称、entry info 和底层读取错误通过 sec/FFI/CLI 返回；ignore 规则仍可明确过滤内部对象。
- FFI 与 CLI 目录读取不依赖 `HasNext()`；正常结束只接受 `io.EOF`。
- Go 覆盖超宽、超深、关闭、递归/非递归和加密名称；真实 FFI 覆盖错误不被转换为空列表。
