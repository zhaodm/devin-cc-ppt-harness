---
skill: spec-merge
trigger: /ppt-archive 命令
executor: PM
---

## 上下文围栏（Context Fence）

执行本 Skill 时，PM MUST 遵守以下约束：

1. **读取角色定义**: 读取 `agents/pm.md`
2. **读取状态文件**: 读取 `deliverables/{REQ-ID}/.state.md` 确认当前阶段和前置条件
3. **输入范围**: 仅读取本 Skill「前置条件」和「执行步骤」中明确引用的文件路径
4. **忽略角色推理**: 不得依赖对话中 SA/DE/TE 的推理过程，仅依据产出文件内容做判断
5. **输出隔离**: 仅向本 Skill「输出物」中指定的路径写入
6. **状态更新**: 每完成一个 Step 更新 `.state.md`

## 前置条件
- src/scripts/archive.sh 执行 PASS
- deliverables/{REQ-ID}/te/final-test-report.md 标记为 PASS
- deliverables/{REQ-ID}/SR3-record.md 存在且标记为 PASS

## 执行步骤

### Step 1: 需求归档（ARC-1）
1. 复制文件：
   ```bash
   cp deliverables/{REQ-ID}/sa/requirement-spec.md spec/requirement-spec.md
   ```
2. 自检：
   - [ ] spec/requirement-spec.md 存在
   - [ ] 内容与源文件一致（diff 无差异）

### Step 2: 设计归档（ARC-2）
1. 复制文件：
   ```bash
   cp deliverables/{REQ-ID}/sa/design.md spec/design.md
   ```
2. 自检：
   - [ ] spec/design.md 存在
   - [ ] 内容与源文件一致

### Step 3: 代码归档（ARC-3）
1. 复制所有页面文件：
   ```bash
   cp deliverables/{REQ-ID}/final_output/*.html output/final/
   ```
2. 更新或创建 output/final/index.html：
   - 如果 index.html 不存在：基于 templates/index-skeleton.html 创建
   - 如果已存在：在 .chapter-list 中追加新章节条目
   - 每个章节条目格式：
     ```html
     <a class="chapter-item" href="{filename}">
       <span class="chapter-num">{序号}</span>
       <span class="chapter-title">{章节标题}</span>
       <span class="chapter-desc">{简要描述}</span>
     </a>
     ```
   - 章节标题和描述从 design.md 的章节划分表格中提取
3. 自检：
   - [ ] output/final/ 下所有页面文件存在
   - [ ] index.html 存在
   - [ ] index.html 中所有 href 指向的文件存在（无死链）
   - [ ] 新归档页面在 index.html 中有对应条目

### Step 4: 项目结项确认（SR4）
1. 生成归档摘要：
   ```
   [项目结项确认]
   评审节点: SR4
   需求编号: {REQ-ID}
   
   归档文件:
     - spec/requirement-spec.md
     - spec/design.md
     - output/final/{页面文件列表}
     - output/final/index.html
   
   演示文稿入口: output/final/index.html
   总页面数: {N}
   
   请确认结项: 通过 / 驳回
   ```
2. 等待用户确认
3. 用户通过：记录到 SR4 评审记录
4. 用户驳回：记录原因，回退到对应步骤

## 归档后清理（可选）
归档完成后，提示用户：
```
归档已完成。deliverables/{REQ-ID}/ 目录中的过程产物可以保留（用于追溯）或清理。
是否保留过程产物？（建议保留）
```

## 自检清单
- [ ] spec/requirement-spec.md 存在且与源一致
- [ ] spec/design.md 存在且与源一致
- [ ] output/final/ 下所有页面文件存在
- [ ] output/final/index.html 存在且无死链
- [ ] 用户已确认结项

## 输出物
- spec/requirement-spec.md
- spec/design.md
- output/final/{pages}.html
- output/final/index.html

## 完成标志
用户确认结项后，向用户报告：
```
[/ppt-archive 完成]
需求编号: {REQ-ID}
项目状态: DONE
演示文稿入口: output/final/index.html
可在浏览器中打开查看最终效果。
```
