# 依赖管理

`D:\ChatGPT\dependence` 是共享依赖目录。需要的依赖优先在这里查找或构建，只有必须存在于工作区的依赖才在工作区构建或保留。

共享第三方语料放在 `corpora/`，下载归档放在 `downloads/`，可共享的网页缓存放在 `cache/web/`。绑定当前项目的编译缓存必须放在 `cache/projects/wuwei_dictionary/`，不可与其他项目混用。

通过 `tool/use-shared-dependencies.ps1` 管理迁移及旧路径兼容链接。不要把已有目录覆盖合并，也不要将应用资源、锁文件或已纳入版本管理的数据当作临时依赖删除。
