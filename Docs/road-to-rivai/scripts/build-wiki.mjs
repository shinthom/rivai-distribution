import fs from 'node:fs/promises';
import path from 'node:path';
import matter from 'gray-matter';
import MarkdownIt from 'markdown-it';
import markdownItAnchor from 'markdown-it-anchor';

const root = process.cwd();
const docsDir = path.join(root, 'wiki');
const outDir = path.join(root, 'site');
const staticDirs = ['assets'];
let homeRel = 'index.md';

const site = {
  title: 'Road to Rivai Wiki',
  description: 'GunZ-like high-speed multiplayer TPS development wiki',
};

function slugify(input) {
  return input
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^\p{Letter}\p{Number}\s-]/gu, '')
    .trim()
    .replace(/\s+/g, '-')
    .replace(/-+/g, '-');
}

function isMarkdown(file) {
  return file.endsWith('.md');
}

async function walk(dir) {
  const entries = await fs.readdir(dir, { withFileTypes: true });
  const files = [];
  for (const entry of entries) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...await walk(full));
    } else if (entry.isFile()) {
      files.push(full);
    }
  }
  return files;
}

function toPosix(p) {
  return p.split(path.sep).join('/');
}

function urlRelFromRel(rel) {
  return rel;
}

function pageUrlFromRel(rel) {
  if (rel === homeRel) return 'index.html';
  const urlRel = urlRelFromRel(rel);
  const noExt = urlRel.replace(/\.md$/, '');
  if (noExt === 'index') return 'index.html';
  if (noExt.endsWith('/index')) return `${noExt.slice(0, -'/index'.length)}/index.html`;
  return `${noExt}/index.html`;
}

function sourcePageUrlFromRel(rel) {
  const noExt = rel.replace(/\.md$/, '');
  if (noExt === 'index') return 'index.html';
  if (noExt.endsWith('/index')) return `${noExt.slice(0, -'/index'.length)}/index.html`;
  return `${noExt}/index.html`;
}

function outputPathFromRel(rel) {
  return path.join(outDir, pageUrlFromRel(rel));
}

function redirectOutputPathFromUrl(url) {
  return path.join(outDir, url);
}

function relativeUrl(fromUrl, toUrl) {
  const fromDir = path.posix.dirname(fromUrl);
  let href = path.posix.relative(fromDir, toUrl);
  if (!href) href = 'index.html';
  return href;
}

function redirectPage({ fromUrl, toUrl, title }) {
  const href = relativeUrl(fromUrl, toUrl);
  const safeTitle = escapeHtml(title);
  const safeHref = escapeHtml(href);
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta http-equiv="refresh" content="0; url=${safeHref}">
  <link rel="canonical" href="${safeHref}">
  <title>${safeTitle} · Redirect</title>
</head>
<body>
  <p><a href="${safeHref}">${safeTitle}</a> 문서로 이동합니다.</p>
</body>
</html>`;
}

function titleFromMarkdown(content, fallback) {
  const match = content.match(/^#\s+(.+)$/m);
  return match ? match[1].trim() : fallback;
}

function fallbackTitle(rel) {
  const base = path.basename(rel, '.md');
  return base
    .split('-')
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join(' ');
}

function normalizeWikiTarget(target) {
  return target
    .trim()
    .replace(/\.md$/, '')
    .replace(/^\//, '')
    .toLowerCase();
}

function relativeHref(fromRel, toRel) {
  return relativeUrl(pageUrlFromRel(fromRel), pageUrlFromRel(toRel));
}

async function copyDir(src, dst) {
  try {
    await fs.cp(src, dst, { recursive: true });
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
}

function escapeHtml(value = '') {
  return value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function navSection(page) {
  return page.rel.includes('/') ? page.rel.split('/')[0] : 'Milestone';
}

function sectionRank(section) {
  if (section === 'Road to Rivai') return 0;
  if (section === 'Milestone') return 1;
  return 2;
}

function pageRank(page) {
  const ordered = new Map([
    ['Road to Rivai/Goal.md', 0],
    ['Road to Rivai/Document-Rule.md', 1],
    ['Milestone/M0.md', 1],
    ['Milestone/M1.md', 2],
    ['M0/A01-directory-convention.md', 0],
    ['M0/B01-project-type-decision.md', 1],
    ['M0/B02-project-setup.md', 2],
    ['M0/C01-ai-tool-evaluation.md', 3],
  ]);
  return ordered.get(page.rel) ?? 100;
}

function navTree(pages) {
  return [...pages].sort((a, b) => {
    const sectionA = navSection(a);
    const sectionB = navSection(b);
    const rankA = sectionRank(sectionA);
    const rankB = sectionRank(sectionB);
    if (rankA !== rankB) return rankA - rankB;
    const pageRankA = pageRank(a);
    const pageRankB = pageRank(b);
    if (pageRankA !== pageRankB) return pageRankA - pageRankB;
    if (a.rel === homeRel) return -1;
    if (b.rel === homeRel) return 1;
    return a.rel.localeCompare(b.rel, 'ko');
  });
}

function renderNav(pages, currentRel) {
  const grouped = new Map();

  for (const page of navTree(pages)) {
    const section = navSection(page);
    if (!grouped.has(section)) grouped.set(section, []);
    grouped.get(section).push(page);
  }

  return [...grouped.entries()].map(([section, sectionPages]) => {
    const items = sectionPages.map((page) => {
      const active = page.rel === currentRel ? ' aria-current="page" class="active"' : '';
      return `<li><a${active} href="${relativeHref(currentRel, page.rel)}">${escapeHtml(page.title)}</a></li>`;
    }).join('\n');
    return `<section class="nav-section"><h2>${escapeHtml(section)}</h2><ul>${items}</ul></section>`;
  }).join('\n');
}

function renderBacklinks(page, backlinks, pagesByRel) {
  const links = [...new Set(backlinks.get(page.rel) ?? [])];
  if (links.length === 0) return '';
  return `<aside class="backlinks"><h2>Backlinks</h2><ul>${links.map((rel) => {
    const source = pagesByRel.get(rel);
    return `<li><a href="${relativeHref(page.rel, rel)}">${escapeHtml(source?.title ?? rel)}</a></li>`;
  }).join('')}</ul></aside>`;
}

function stripHtml(value = '') {
  return value.replace(/<[^>]*>/g, '').replace(/&amp;/g, '&').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&quot;/g, '"');
}

function extractToc(renderedHtml) {
  const headings = [];
  const headingPattern = /<h([2-4])\s+id="([^"]+)"[^>]*>(.*?)<\/h\1>/g;
  let match;
  while ((match = headingPattern.exec(renderedHtml)) !== null) {
    headings.push({
      level: Number(match[1]),
      id: match[2],
      title: stripHtml(match[3]).replace(/#$/, '').trim(),
    });
  }
  return headings;
}

function renderToc(headings = []) {
  if (headings.length === 0) return '';
  return `<aside class="toc" aria-label="Page table of contents"><h2>Contents</h2><ol>${headings.map((heading) => (
    `<li class="toc-level-${heading.level}"><a href="#${escapeHtml(heading.id)}">${escapeHtml(heading.title)}</a></li>`
  )).join('')}</ol></aside>`;
}

function hashString(value) {
  let hash = 5381;
  for (let index = 0; index < value.length; index += 1) {
    hash = ((hash << 5) + hash) ^ value.charCodeAt(index);
  }
  return (hash >>> 0).toString(36);
}

function renderTaskLists(html, pageRel) {
  let taskIndex = 0;
  return html.replace(/<li>\[( |x|X)\]\s+([\s\S]*?)<\/li>/g, (match, checkedMark, itemHtml) => {
    const text = stripHtml(itemHtml).replace(/\s+/g, ' ').trim();
    const taskId = hashString(`${pageRel}:${taskIndex}:${text}`);
    taskIndex += 1;
    const checked = checkedMark.toLowerCase() === 'x' ? ' checked' : '';
    return `<li class="task-list-item"><label><input type="checkbox" class="task-checkbox" data-task-id="${taskId}"${checked}> <span>${itemHtml}</span></label></li>`;
  });
}

function layout({ page, pages, pagesByRel, backlinks, content, toc }) {
  const nav = renderNav(pages, page.rel);
  const depth = pageUrlFromRel(page.rel).split('/').length - 1;
  const rootPrefix = depth === 0 ? './' : '../'.repeat(depth);
  return `<!doctype html>
<html lang="ko">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>${escapeHtml(page.title)} · ${escapeHtml(site.title)}</title>
  <meta name="description" content="${escapeHtml(site.description)}">
  <script>
    (() => {
      const path = window.location.pathname;
      const last = path.split('/').pop() || '';
      const looksLikeFile = last.includes('.');
      if (!path.endsWith('/') && !looksLikeFile) {
        window.location.replace(path + '/' + window.location.search + window.location.hash);
      }
    })();
  </script>
  <link rel="icon" href="${rootPrefix}assets/logo.svg">
  <link rel="preconnect" href="https://fonts.googleapis.com">
  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
  <link href="https://fonts.googleapis.com/css2?family=Noto+Sans+KR:wght@400;500;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="${rootPrefix}assets/styles/extra.css">
</head>
<body>
  <header class="topbar">
    <a class="brand" href="${rootPrefix}index.html"><img src="${rootPrefix}assets/logo.svg" alt=""/> <span>Road to Rivai</span></a>
  </header>
  <div class="shell">
    <aside class="sidebar">
      <input id="wiki-search" type="search" placeholder="Search docs" autocomplete="off">
      <ul id="search-results"></ul>
      <nav aria-label="Wiki navigation">${nav}</nav>
    </aside>
    <main class="content">
      ${content}
      ${renderBacklinks(page, backlinks, pagesByRel)}
    </main>
    ${toc}
  </div>
  <script type="application/json" id="search-index">${JSON.stringify(pages.map((p) => ({ title: p.title, url: relativeHref(page.rel, p.rel), type: p.type, excerpt: p.excerpt }))).replaceAll('<', '\\u003c')}</script>
  <script src="${rootPrefix}assets/scripts/wiki.js"></script>
</body>
</html>`;
}

async function main() {
  await fs.rm(outDir, { recursive: true, force: true });
  await fs.mkdir(outDir, { recursive: true });

  const files = (await walk(docsDir)).filter(isMarkdown);
  const rawPages = [];

  for (const file of files) {
    const rel = toPosix(path.relative(docsDir, file));
    const raw = await fs.readFile(file, 'utf8');
    const parsed = matter(raw);
    const title = parsed.data.title ?? titleFromMarkdown(parsed.content, fallbackTitle(rel));
    rawPages.push({
      rel,
      file,
      title,
      type: parsed.data.type ?? '',
      raw: parsed.content,
      excerpt: parsed.content.replace(/[#>*_`\-|\[\]()]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, 180),
    });
  }

  if (rawPages.length === 0) {
    throw new Error(`No markdown files found in ${docsDir}`);
  }

  const indexPage = rawPages.find((page) => path.basename(page.rel).toLowerCase() === 'index.md');
  const goalPage = rawPages.find((page) => path.basename(page.rel).toLowerCase() === 'goal.md');
  const roadmapPage = rawPages.find((page) => path.basename(page.rel).toLowerCase() === 'roadmap.md');
  homeRel = (indexPage ?? goalPage ?? roadmapPage ?? rawPages.sort((a, b) => a.rel.localeCompare(b.rel, 'ko'))[0]).rel;

  const pages = rawPages;
  const pagesByRel = new Map(pages.map((page) => [page.rel, page]));
  const targetIndex = new Map();
  for (const page of pages) {
    const noExt = page.rel.replace(/\.md$/, '');
    targetIndex.set(normalizeWikiTarget(noExt), page.rel);
    targetIndex.set(normalizeWikiTarget(path.basename(noExt)), page.rel);
    targetIndex.set(normalizeWikiTarget(page.title), page.rel);
  }

  const md = new MarkdownIt({
    html: true,
    linkify: true,
    typographer: true,
  }).use(markdownItAnchor, { slugify });

  const backlinks = new Map();
  const forwardLinks = new Map();

  for (const page of pages) {
    const linked = [];
    page.raw = page.raw.replace(/\[\[([^\]|]+)(?:\|([^\]]+))?\]\]/g, (match, rawTarget, rawLabel) => {
      const target = normalizeWikiTarget(rawTarget);
      const targetRel = targetIndex.get(target);
      const label = rawLabel?.trim() || rawTarget.trim();
      if (!targetRel) {
        return `<span class="missing-wikilink" title="Missing page: ${escapeHtml(rawTarget)}">${escapeHtml(label)}</span>`;
      }
      linked.push(targetRel);
      return `[${label}](${relativeHref(page.rel, targetRel)})`;
    });

    page.raw = page.raw.replace(/(\[[^\]]+\])\(([^)\s]+\.md)((?:#[^)\s]*)?)\)/g, (match, labelPart, mdPath, anchor) => {
      if (/^[a-z][a-z0-9+.-]*:/i.test(mdPath)) return match;
      const currentDir = path.posix.dirname(page.rel === homeRel ? page.rel : page.rel);
      const baseDir = currentDir === '.' ? '' : currentDir;
      const resolvedRel = toPosix(path.posix.normalize(baseDir ? `${baseDir}/${mdPath}` : mdPath));
      let targetRel = pagesByRel.has(resolvedRel) ? resolvedRel : null;
      if (!targetRel) {
        const lookup = targetIndex.get(normalizeWikiTarget(resolvedRel.replace(/\.md$/, '')));
        if (lookup) targetRel = lookup;
      }
      if (!targetRel) return match;
      linked.push(targetRel);
      return `${labelPart}(${relativeHref(page.rel, targetRel)}${anchor || ''})`;
    });

    forwardLinks.set(page.rel, linked);
    for (const targetRel of linked) {
      if (!backlinks.has(targetRel)) backlinks.set(targetRel, []);
      backlinks.get(targetRel).push(page.rel);
    }
  }

  for (const page of pages) {
    const rendered = renderTaskLists(md.render(page.raw), page.rel);
    const toc = renderToc(extractToc(rendered));
    const output = outputPathFromRel(page.rel);
    await fs.mkdir(path.dirname(output), { recursive: true });
    await fs.writeFile(output, layout({ page, pages, pagesByRel, backlinks, content: rendered, toc }), 'utf8');

    const canonicalUrl = pageUrlFromRel(page.rel);
    const sourceUrl = sourcePageUrlFromRel(page.rel);
    if (sourceUrl !== canonicalUrl) {
      const redirectOutput = redirectOutputPathFromUrl(sourceUrl);
      await fs.mkdir(path.dirname(redirectOutput), { recursive: true });
      await fs.writeFile(redirectOutput, redirectPage({ fromUrl: sourceUrl, toUrl: canonicalUrl, title: page.title }), 'utf8');
    }
  }

  for (const dir of staticDirs) {
    await copyDir(path.join(docsDir, dir), path.join(outDir, dir));
  }

  console.log(`Built ${pages.length} pages into ${path.relative(root, outDir)}`);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});
