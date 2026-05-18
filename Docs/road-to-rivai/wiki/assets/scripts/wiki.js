localStorage.removeItem('wiki-theme');

const input = document.getElementById('wiki-search');
const results = document.getElementById('search-results');

function getDocs() {
  const indexEl = document.getElementById('search-index');
  if (!indexEl) return [];
  try {
    return JSON.parse(indexEl.textContent);
  } catch {
    return [];
  }
}

function renderSearchResults() {
  if (!input || !results) return;
  const query = input.value.trim().toLowerCase();
  results.innerHTML = '';
  if (!query) return;

  const matches = getDocs()
    .filter((doc) => [doc.title, doc.type, doc.excerpt].join(' ').toLowerCase().includes(query))
    .slice(0, 8);

  for (const doc of matches) {
    const li = document.createElement('li');
    const a = document.createElement('a');
    a.href = doc.url;
    a.textContent = doc.title;
    li.append(a);
    results.append(li);
  }
}

function taskStorageKey(taskId) {
  return `road-to-rivai:task:${taskId}`;
}

function initTaskCheckboxes(root = document) {
  const checkboxes = root.querySelectorAll('.task-checkbox[data-task-id]');
  for (const checkbox of checkboxes) {
    const key = taskStorageKey(checkbox.dataset.taskId);
    const saved = localStorage.getItem(key);
    if (saved !== null) checkbox.checked = saved === '1';
    checkbox.addEventListener('change', () => {
      localStorage.setItem(key, checkbox.checked ? '1' : '0');
    });
  }
}

input?.addEventListener('input', renderSearchResults);
initTaskCheckboxes();

function isInternalDocumentLink(anchor) {
  if (!anchor.href) return false;
  if (anchor.target && anchor.target !== '_self') return false;
  if (anchor.hasAttribute('download')) return false;

  const url = new URL(anchor.href, window.location.href);
  if (url.origin !== window.location.origin) return false;
  if (url.hash && url.pathname === window.location.pathname && url.search === window.location.search) return false;
  if (/\.[a-z0-9]+$/i.test(url.pathname) && !url.pathname.endsWith('/index.html')) return false;
  return true;
}

function normalizeDocumentUrl(url) {
  const normalized = new URL(url, window.location.href);
  const last = normalized.pathname.split('/').pop() || '';
  const looksLikeFile = last.includes('.');
  if (!normalized.pathname.endsWith('/') && !looksLikeFile) {
    normalized.pathname = `${normalized.pathname}/`;
  }
  return normalized;
}

function replaceElement(selector, nextDocument) {
  const current = document.querySelector(selector);
  const next = nextDocument.querySelector(selector);
  if (!current && !next) return;
  if (current && next) {
    current.replaceWith(next);
  } else if (current && !next) {
    current.remove();
  } else if (!current && next) {
    document.querySelector('.shell')?.append(next);
  }
}

function applyDocument(nextDocument) {
  const nextTitle = nextDocument.querySelector('title')?.textContent;
  if (nextTitle) document.title = nextTitle;

  replaceElement('.content', nextDocument);
  replaceElement('.toc', nextDocument);

  const currentNav = document.querySelector('nav[aria-label="Wiki navigation"]');
  const nextNav = nextDocument.querySelector('nav[aria-label="Wiki navigation"]');
  if (currentNav && nextNav) currentNav.replaceWith(nextNav);

  const currentIndex = document.getElementById('search-index');
  const nextIndex = nextDocument.getElementById('search-index');
  if (currentIndex && nextIndex) currentIndex.replaceWith(nextIndex);

  if (input) input.value = '';
  if (results) results.innerHTML = '';
  initTaskCheckboxes(document);
}

async function navigateTo(url, { push = true } = {}) {
  const target = normalizeDocumentUrl(url);
  document.documentElement.classList.add('is-navigating');

  try {
    const response = await fetch(target.href, {
      headers: { Accept: 'text/html' },
      credentials: 'same-origin',
    });
    if (!response.ok) throw new Error(`Navigation failed: ${response.status}`);

    const html = await response.text();
    const nextDocument = new DOMParser().parseFromString(html, 'text/html');
    if (!nextDocument.querySelector('.content')) throw new Error('Invalid wiki document');

    applyDocument(nextDocument);
    if (push) window.history.pushState({}, '', target.href);

    if (target.hash) {
      document.querySelector(target.hash)?.scrollIntoView();
    } else {
      window.scrollTo({ top: 0, behavior: 'instant' });
      document.querySelector('.sidebar')?.scrollTo({ top: 0, behavior: 'instant' });
    }
  } catch (error) {
    window.location.href = target.href;
  } finally {
    document.documentElement.classList.remove('is-navigating');
  }
}

document.addEventListener('click', (event) => {
  const anchor = event.target.closest('a');
  if (!anchor || !isInternalDocumentLink(anchor)) return;

  event.preventDefault();
  navigateTo(anchor.href);
});

window.addEventListener('popstate', () => {
  navigateTo(window.location.href, { push: false });
});
