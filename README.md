# GitHub Markdown Blog

这是一个最小可用的 GitHub 博客系统：

- 把文章放进 `posts/`
- 运行脚本生成 `posts.json`
- 推送到 GitHub 后，GitHub Pages 自动发布站点
- 首页显示文章链接，点击进入文章详情页

## 目录约定

- `posts/`: 你的 Markdown 文章
- `scripts/update-posts.ps1`: 重新生成文章索引
- `scripts/publish-once.ps1`: 手动执行一次发布
- `scripts/watch-and-publish.ps1`: 持续监听文章目录，检测到新文章后自动提交并推送
- `.github/workflows/deploy.yml`: GitHub Pages 部署工作流

## 文章写法

文件名请直接使用 URL slug，例如：

```text
posts/github-pages-blog.md
posts/my-second-post.md
```

文章支持可选 front matter：

```md
---
title: 我的文章标题
date: 2026-04-02
summary: 这里是一段首页摘要
tags:
  - GitHub
  - 博客
---

# 我的文章标题

正文内容。
```

如果你不写 `title`、`date`、`summary`，脚本会自动从标题和文件时间里补默认值。

## 初始化步骤

1. 创建一个 GitHub 仓库。
2. 在当前目录执行：

```powershell
git init -b main
git remote add origin <你的仓库地址>
.\scripts\update-posts.ps1
git add .
git commit -m "init blog"
git push -u origin main
```

3. 到 GitHub 仓库设置里启用 Pages，Source 选择 `GitHub Actions`。

## 日常使用

手动发布一次：

```powershell
.\scripts\publish-once.ps1
```

持续监听并自动推送：

```powershell
.\scripts\watch-and-publish.ps1
```

之后你只需要把新的 `.md` 文件放进 `posts/`，脚本就会自动：

1. 更新 `posts.json`
2. `git add` / `git commit`
3. `git push origin main`
4. 触发 GitHub Pages 更新

## 站点链接

部署完成后，站点通常是：

```text
https://<你的 GitHub 用户名>.github.io/<仓库名>/
```

文章详情页链接形式是：

```text
https://<你的 GitHub 用户名>.github.io/<仓库名>/article.html?slug=<文章文件名>
```
