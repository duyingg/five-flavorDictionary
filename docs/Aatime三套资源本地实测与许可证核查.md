# Aatime 三套资源本地实测与许可证核查

核查日期：2026-09-27
工作目录：`D:\ChatGPT\wuwei_dictionary\Aatime`
目标：核对三个新下载资源**实际包含什么**、现代汉语译文规模、原始来源与许可证，供代码工程师决定是否接入字典 App。用户已导入约 30 万首诗，本轮以补译文和注释为重点。资源准入仍按“每个独立库至少 1000 首完整诗词译文、译文来源明确、许可支持项目使用”判断。

## 一、结论

| 下载目录 | 本地实际内容 | 现代译文实测 | 授权判断 | 产品接入 |
| --- | --- | --- | --- | --- |
| `ACP-RAG-main` | 27 个文件，约 2.94 MB；代码、图片、README、申请表；**没有 ACP-Corpus 数据包** | 本地 0 条 | 数据仅限非商业研究，需机构申请，CC BY-NC-SA 4.0；原始内容权利归来源方 | **不接入** |
| `chinese-ancient-poetry-translation-master` | 72,423 个文件，约 112.51 MB；其中 72,417 个诗歌 JSON，另有 CSV、脚本和 GPLv3 文件 | 5,931 个 JSON 含非空 `fanyi`；其中 4,787 个以“译文”开头；CSV 15,761 行**句/段**对应 | 仓库 GPLv3 文件存在，但每篇现代译文的作者、首发来源与可再授权证据缺失 | **暂不接入译文/注释/赏析** |
| `chinese-classical-corpus-main` | 69 个文件，约 170.06 MB；`corpus.jsonl` 12,009 条，另有古籍 JSON 和断句数据；**没有 `translate.jsonl`** | 本地结构化语料无译文字段 | 作者将古籍结构化输出声明 CC0、代码 MIT；网上宣称的翻译指令数据来自 NiuTrans，现代译文上游权利需另核 | 可单独评估原文/《说文》释字；**不作为译文库** |

**可立即计入“10 个独立、各有至少 1000 首完整诗词白话译文且授权清楚的库”：0 个。** 第二套包的 5,931 是“有 `fanyi` 字段”的诗歌文件数，不是已核实完整译文数，更不是已授权数。没有把 15,761 行 CSV 当成 15,761 首诗。

## 二、核查口径与方法

1. 只读取 `Aatime` 内三个新资源目录，递归统计文件数量与字节数；不以 GitHub 项目 README 的宣称数字替代本地实测。
2. 逐个解析 72,417 个 `poetry_*.json`，统计 `content`、`fanyi`、`about`、`shangxi` 字段；按标准 CSV 读取 `output.csv` 行数。
3. 逐行解析 `corpus.jsonl`，统计记录数和所有字段名，另检查 `output/instruct/` 的实际文件清单。
4. 查本地 `LICENSE` / README，同时复核项目方在线说明；“仓库开源”与“仓库内每篇现代译文获授权”分别判断。
5. 本报告没有对诗歌译文做逐篇质量审校，也没有将待审数据导入 App。

### 可复核的文件指纹

| 文件 | 字节 | SHA-256 |
| --- | ---: | --- |
| `chinese-ancient-poetry-translation-master/output.csv` | 2,314,465 | `0C2A8701281942B5EB6CFBE6C88E7E9CAE371C299E81218DB4BF160417DD98D7` |
| `chinese-classical-corpus-main/output/corpus.jsonl` | 53,918,993 | `41F2B6105754DC1F384ECC5C3805CFCA85BE355F0D6314B855EBD4747F225381` |
| `chinese-classical-corpus-main/output/instruct/punctuate.jsonl` | 61,420,969 | `5C89EDA602321086E73E3FA4F2280C8166D871F580142DEA09899C6747FA7FA9` |

## 三、ACP-RAG-main

### 实际内容与规模

- 本地 27 个文件：16 个 Python 程序、7 张 PNG 图、1 份 DOCX 申请表、README、依赖表与 `.gitignore`。目录含去重、索引、检索、评估及训练代码；**未发现古诗正文、白话译文、ACP-Corpus 或 ACP-QA 的数据文件**。
- [项目 README](https://github.com/SCUT-DLVCLab/ACP-RAG) 说 ACP-Corpus 有约 110 万首古诗与 99 万条相关文本，并在材料类型中列出 VT（白话译文）、ET（英译）、WE（字词解释）、PA（赏析）等。以上是项目整体介绍；不能用来推断本地包包含这些文本，也不能把 110 万首原文当作 110 万首带译文的诗。

### 许可证与来源

- README 的“License”段把工作/代码标为 MIT，把**数据集**标为 [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/)。本地包没有独立 `LICENSE` 文件，当前以 README 的明确声明为准；如果未来复用代码，应保存项目版本和版权声明。
- README 的“Data Acquisition Method”写明 ACP-Corpus/ACP-QA **仅用于非商业研究**，需机构签署申请，通过后另获下载链接和密码。项目还声明原始数据来自公开网络，版权保留于原内容提供者，并将数据许可对象限定为大学与研究机构。
- 结论：当前下载的只是公开代码包。即使另行获准取得数据，也必须按批准用途和协议使用；本项目产品数据源不得直接采用。

### 工程处置

保留在 `Aatime` 作研究参考；不要建立“ACP 已下载 110 万首诗/译文”的导入任务，不要爬取或绕过申请获取数据。

## 四、chinese-ancient-poetry-translation-master

### 实际内容与规模

| 实测项 | 数量 | 含义 |
| --- | ---: | --- |
| `data/poetry/*.json` | 72,417 | 诗歌 JSON 文件，均有非空 `content`；不是译文数 |
| 有非空 `fanyi` 的 JSON | 5,931 | 可能含译文或注释的文件上限；其中内容类型混杂 |
| `fanyi` 以“译文”开头 | 4,787 | 译文候选上限，尚未判整首完整、去重与授权 |
| `fanyi` 以“注释”开头 | 1,078 | 开头是注释，不能直接当译文 |
| `fanyi` 含“注释”章节 | 4,492 | 同一字段混装译文和注释 |
| `fanyi` 含“译文二” | 77 | 存在多译本，需记录版本与译者，不能任意合并 |
| 有 `shangxi` 字段 | 5,943 | 现代赏析文本，同样需要逐篇权利来源 |
| `output.csv` | 15,761 行 | 句或片段与白话对应行，**不是完整诗的篇数** |
| 不同 `content` 字符串 | 65,993 | 原诗正文去重后粗数；也不是译文数 |

本地 JSON 结构包括 `id`、`name`、`poet`、`dynasty`、`content`、`fanyi`、`about`、`shangxi`、`tags`、`star`。`poetry_1.json`《关雎》显示 `fanyi` 中先是“译文”，随后混入“注释”；`about` / `shangxi` 是独立的现代评论文本。这个实例证明**原始 JSON 比 CSV 更接近按篇保存**，但样例不能证明全部 4,787 条都是完整整篇翻译。

[处理脚本](https://github.com/YuRuiii/chinese-ancient-poetry-translation/blob/master/poetry_process.py) 遍历诗歌 JSON，将 `content` 与 `fanyi` 按换行拆分，再逐行写入 `output.csv`；CSV 不保留诗歌 ID、题名、作者、译者、来源或完整篇结构。原脚本有宽泛的 `except: pass`，因此行数不能用于反推成功处理了多少首诗。脚本上界 73,281 只是尝试的编号范围。

### 许可证与权利链

- 本地 `LICENSE` 是 **GNU GPLv3** 全文；[仓库](https://github.com/YuRuiii/chinese-ancient-poetry-translation) 标明 fork 自 `javayhu/poetry`。本地 README 没有逐篇现代译文作者、原始站点、出版版本或授权表。
- 全部 72,417 个 JSON 的字段名中**没有** `source`、`url`、`license`、`translator`、`translation_author`。个别正文/赏析会写“选自某书”等引文，说明内容可能来自第三方现代出版物，但这不是系统化授权记录；例如《关雎》样本的 `about` 明示引用 1995 年出版物。
- GPLv3 文件说明仓库发布者的许可主张，不能证明其有权把每篇上游现代译文、注释、赏析按 GPLv3 再授权。按用户“来源不明直接排除”的规则，这批 `fanyi`、`about`、`shangxi` 暂不进入 App，也不计入合格库。

### 工程处置

保留原始文件和上述哈希，暂停现代文字段导入。若以后找到可信的上游来源表，先逐篇建立 `poem_id → translator/rightsholder → publication_url/book → license/grant → permitted_use`，再计算**完整、去重、与已有 30 万首匹配**的篇数。多版本译文需单独保留版本 ID。CSV 仅适合研究对齐方法，不建议作为最终整诗导入源。

## 五、chinese-classical-corpus-main

### 实际内容与规模

- 本地 69 个文件，约 170.06 MB。`output/corpus.jsonl` 实测 **12,009 条结构化古籍记录**，其中《说文解字》9,831 条、《诗经》305 条，其余为经史等章节。全文件记录**没有任何键名含 `translation` 或“译”的字段**。
- `output/wujing/shijing.json` 是《诗经》原文的篇目、作者、章类和 `content`；没有白话译文。`output/shuowen.json` 提供字、部首、反切、释义正文等**文字条目**；未见《说文》字形图片或图片路径。它可以补古籍/字书原文结构，但不能填诗词“现代译文”或“字形图片”。
- `output/instruct/` 本地只有 `punctuate.jsonl` 与说明文档，**没有**网上 README 所述的 `translate.jsonl`（约 640 MB）。本地断句文件约 61.42 MB，是去标点/补标点任务，不是白话翻译。
- [项目说明](https://github.com/gujilab/chinese-classical-corpus/blob/main/output/instruct/README.md) 明确：网上所述 1,924,378 条双向古今指令由 [NiuTrans/Classical-Modern](https://github.com/NiuTrans/Classical-Modern) 的约 97 万古文句对生成，不构成第二个独立译文来源，也不是 192 万首诗。

### 许可证与来源

- 本地 `LICENSE` 把古籍结构化输出（`output/*.json`、`output/corpus.jsonl`）声明为 **CC0 1.0**，脚本与文档声明 MIT。README 列明殆知阁、Wikisource、ctext、shuowenjiezi、chtxt、NiuTrans 等上游。
- 古籍原文本身与现代译文需分开处理；本地包压根没有译文文件。若日后补下载翻译指令数据，须回到 NiuTrans 的逐书 `数据来源.txt` 核实现代译文权利，不能仅凭本仓库 CC0 或上游仓库 MIT 作产品许可结论。

### 工程处置

可将《说文》文字条目和《诗经》原文结构作为**另一个工作包**评估质量、编码、繁简体与当前数据重复率；保留源项目、版本及许可证。不得将本包列为已到手的白话译文或《说文》图片资源。

## 六、给代码工程师的实施顺序

1. **不要改动现有诗词数据表**，三个包目前都缺少可直接入库的合规整诗白话译文。
2. 若要做《说文》或《诗经》原文增强，从 `chinese-classical-corpus-main/output/` 单独建立预览样本，先查已有数据重复和文字质量；许可记录写明 CC0、上游来源和所用文件哈希。
3. 若研究古诗翻译包，对 5,931 个 `fanyi` 候选逐篇追溯权利；只在取得译文作者及许可依据后，再做整篇完整性、去重和与现库 JOIN。`shangxi` / `about` 权利单独判定。
4. ACP-RAG 只保留为非商业科研方向的线索；当前本地包没有可导入数据。

## 七、文档清理记录

本次新建 `docs/垃圾/`，仅移动已被本次实测取代或与用户最新资源筛选规则冲突的旧调研文档；原文件保留，可随时恢复：

| 移入垃圾的旧文档 | 原因 |
| --- | --- |
| `docs/古典文献译注与文化资源整合清单.md` | 旧摘要仍将用户已排除的 Mobvoi 库列为优先资源，和后续指示冲突；其他候选内容保存在归档供查证 |
| `docs/用户所给古诗译文资源目录逐项核查.md` | 只核对网上宣称，现已由本报告的三包本地实测更新 |
| 根目录同名 `用户所给古诗译文资源目录逐项核查.md` | 前次导出形成的重复副本，内容同上 |

继续保留 `docs/诗词白话译文独立资源与授权核查.md`（更广泛的其他来源排除记录）、`docs/素材筛选、终选与废案规则.md`（现行准入规则）、`docs/文化页独立性检查与协作交接.md`（其他工作线的交接文档）。三个下载资源目录均未移动或删除。
