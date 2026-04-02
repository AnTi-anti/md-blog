(function () {
  const postsIndexPath = "./posts.json";

  async function fetchJson(path) {
    const response = await fetch(path, { cache: "no-store" });
    if (!response.ok) {
      throw new Error(`Failed to fetch ${path}: ${response.status}`);
    }
    return response.json();
  }

  function parseFrontMatter(rawText) {
    const frontMatterMatch = rawText.match(/^---\r?\n([\s\S]*?)\r?\n---\r?\n?/);
    if (!frontMatterMatch) {
      return { body: rawText, meta: {} };
    }

    const meta = {};
    const lines = frontMatterMatch[1].split(/\r?\n/);
    let activeArrayKey = null;

    for (const line of lines) {
      const arrayMatch = line.match(/^\s*-\s*(.+)\s*$/);
      if (arrayMatch && activeArrayKey) {
        meta[activeArrayKey] ??= [];
        meta[activeArrayKey].push(arrayMatch[1].trim());
        continue;
      }

      const pairMatch = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
      if (!pairMatch) {
        activeArrayKey = null;
        continue;
      }

      const key = pairMatch[1];
      const value = pairMatch[2].trim();
      if (value.length === 0) {
        meta[key] = [];
        activeArrayKey = key;
        continue;
      }

      meta[key] = value.replace(/^["']|["']$/g, "");
      activeArrayKey = null;
    }

    return {
      body: rawText.slice(frontMatterMatch[0].length),
      meta,
    };
  }

  function renderTags(tags) {
    if (!Array.isArray(tags) || tags.length === 0) {
      return "";
    }
    return tags.map((tag) => `<span class="chip">${tag}</span>`).join("");
  }

  function formatDate(dateValue) {
    if (!dateValue) {
      return "未设置日期";
    }

    const date = new Date(dateValue);
    if (Number.isNaN(date.getTime())) {
      return dateValue;
    }
    return new Intl.DateTimeFormat("zh-CN", {
      year: "numeric",
      month: "long",
      day: "numeric",
    }).format(date);
  }

  function renderStatus(message) {
    return `<div class="status-card">${message}</div>`;
  }

  async function renderHome() {
    const target = document.getElementById("post-list");
    const count = document.getElementById("post-count");

    try {
      const posts = await fetchJson(postsIndexPath);
      count.textContent = `共 ${posts.length} 篇文章`;

      if (!posts.length) {
        target.innerHTML = renderStatus("还没有文章。把 Markdown 文件放进 posts/，再运行一次发布脚本。");
        return;
      }

      target.innerHTML = posts.map((post) => `
        <a class="post-card" href="./article.html?slug=${encodeURIComponent(post.slug)}">
          <div class="post-meta">
            <span>${formatDate(post.date)}</span>
            ${renderTags(post.tags)}
          </div>
          <h3>${post.title}</h3>
          <p>${post.summary || "这篇文章还没有摘要。点击进入阅读全文。"}</p>
        </a>
      `).join("");
    } catch (error) {
      count.textContent = "加载失败";
      target.innerHTML = renderStatus(`文章索引加载失败：${error.message}`);
    }
  }

  async function renderArticle() {
    const params = new URLSearchParams(window.location.search);
    const slug = params.get("slug");
    const titleNode = document.getElementById("article-title");
    const metaNode = document.getElementById("article-meta");
    const bodyNode = document.getElementById("article-body");

    if (!slug) {
      titleNode.textContent = "缺少文章标识";
      bodyNode.innerHTML = renderStatus("URL 中没有 slug 参数，无法定位文章。");
      return;
    }

    try {
      const posts = await fetchJson(postsIndexPath);
      const post = posts.find((item) => item.slug === slug);
      if (!post) {
        titleNode.textContent = "文章不存在";
        bodyNode.innerHTML = renderStatus("索引里没有找到这篇文章。");
        return;
      }

      const response = await fetch(`./${post.source.split("/").map(encodeURIComponent).join("/")}`, { cache: "no-store" });
      if (!response.ok) {
        throw new Error(`文章文件读取失败：${response.status}`);
      }

      const rawText = await response.text();
      const parsed = parseFrontMatter(rawText);
      const articleTitle = parsed.meta.title || post.title || slug;

      document.title = `${articleTitle} | 文章归档`;
      titleNode.textContent = articleTitle;
      metaNode.innerHTML = `
        <div class="article-meta-line">${formatDate(parsed.meta.date || post.date)}</div>
        <div class="post-meta">${renderTags(parsed.meta.tags || post.tags)}</div>
      `;
      bodyNode.innerHTML = marked.parse(parsed.body);
    } catch (error) {
      titleNode.textContent = "加载失败";
      bodyNode.innerHTML = renderStatus(error.message);
    }
  }

  const pageType = document.body.dataset.page;
  if (pageType === "home") {
    renderHome();
  } else if (pageType === "article") {
    renderArticle();
  }
})();
