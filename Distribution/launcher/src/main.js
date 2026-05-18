// Rivai Launcher — UI controller
//
// Responsibilities:
//   - Fetch manifest, compare with local install state
//   - Drive the primary button (Play | Update | Install) based on state
//   - Stream install progress via Tauri events
//   - Wire auxiliary buttons (logs, links, copy build info)

const { invoke } = window.__TAURI__.core;
const { listen } = window.__TAURI__.event;

async function openUrl(url) {
  return invoke('plugin:opener|open_url', { url });
}

const MANIFEST_URL =
  'https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev/manifest/dev.json';

// ---- State ---------------------------------------------------------------

const state = {
  manifest: null,
  install: null,
  platform: null, // 'mac' | 'win64' | 'other'
  busy: false,
};

// ---- DOM helpers ---------------------------------------------------------

const $ = (id) => document.getElementById(id);
const setText = (id, v) => { const el = $(id); if (el) el.textContent = v ?? '—'; };
const setHidden = (id, hidden) => { const el = $(id); if (el) el.hidden = hidden; };

// ---- Init ----------------------------------------------------------------

window.addEventListener('DOMContentLoaded', async () => {
  state.platform = await invoke('current_platform_cmd');
  setText('footer-platform', `platform: ${state.platform}`);
  setText('footer-manifest', shortenUrl(MANIFEST_URL));

  wireButtons();
  await listen('install-progress', (evt) => renderProgress(evt.payload));
  await refresh();
});

function wireButtons() {
  $('primary-btn').addEventListener('click', () => onPrimary());
  $('retry-btn').addEventListener('click', () => refresh());
  $('open-logs-btn').addEventListener('click', () => invoke('open_logs').catch(showErrorFn));
  $('open-logs-btn-err').addEventListener('click', () => invoke('open_logs').catch(showErrorFn));
  $('open-install-btn').addEventListener('click', () => invoke('open_install_folder').catch(showErrorFn));
  $('copy-info-btn').addEventListener('click', () => copyBuildInfo());
  document.querySelectorAll('[data-link]').forEach((el) => {
    el.addEventListener('click', (e) => {
      e.preventDefault();
      const key = el.dataset.link;
      const url = lookupLink(key);
      if (url) openUrl(url).catch(showErrorFn);
    });
  });
}

// ---- Refresh flow --------------------------------------------------------

async function refresh() {
  hideError();
  setText('status-tagline', 'manifest 확인 중…');
  setPrimary({ label: '확인 중…', disabled: true });

  try {
    const [manifest, install] = await Promise.all([
      fetchManifest(),
      invoke('read_install_state'),
    ]);
    state.manifest = manifest;
    state.install = install;

    renderManifest(manifest);
    renderInstalled(install);
    decidePrimary();
  } catch (err) {
    showError(`manifest를 가져오지 못했어요: ${err.message ?? err}`);
    setPrimary({ label: '재시도', disabled: false, action: 'retry' });
  }
}

async function fetchManifest() {
  const res = await fetch(MANIFEST_URL, { cache: 'no-store' });
  if (!res.ok) throw new Error(`manifest HTTP ${res.status}`);
  return res.json();
}

// ---- Rendering -----------------------------------------------------------

function renderManifest(m) {
  setText('channel-label', m.channel);
  setText('latest-version', m.latestVersion);
  setText('latest-build', `Build ${m.buildId}`);
  setText('server-name', m.server?.name);
  setText('server-host', m.server ? `${m.server.host}:${m.server.port}` : '—');
}

function renderInstalled(install) {
  if (!install) {
    setText('installed-version', '미설치');
    setText('installed-build', '—');
    return;
  }
  setText('installed-version', install.installedVersion);
  setText('installed-build', `Build ${install.installedBuildId}`);
}

function decidePrimary() {
  const m = state.manifest;
  const installed = state.install;
  const supported = !!m?.client?.[state.platform];

  if (!supported) {
    setText('status-tagline', `이 빌드는 ${state.platform} 미지원입니다.`);
    setPrimary({ label: '미지원 플랫폼', disabled: true });
    return;
  }

  if (!installed) {
    setText('status-tagline', '아직 설치되지 않았습니다. Install로 설치를 시작하세요.');
    setPrimary({ label: 'Install', disabled: false, action: 'install' });
    return;
  }
  if (installed.installedBuildId !== m.buildId) {
    setText('status-tagline', `업데이트가 있어요: ${installed.installedVersion} → ${m.latestVersion}`);
    setPrimary({ label: 'Update', disabled: false, action: 'install' });
    return;
  }
  setText('status-tagline', '최신 상태입니다.');
  setPrimary({ label: 'Play', disabled: false, action: 'play' });
}

function setPrimary({ label, disabled, action }) {
  const btn = $('primary-btn');
  setText('primary-label', label);
  btn.disabled = !!disabled;
  btn.dataset.action = action ?? '';
}

async function onPrimary() {
  if (state.busy) return;
  const action = $('primary-btn').dataset.action;
  if (action === 'install') await install();
  else if (action === 'play') await play();
  else if (action === 'retry') await refresh();
}

// ---- Install / Play ------------------------------------------------------

async function install() {
  if (!state.manifest) return;
  state.busy = true;
  hideError();
  setHidden('progress-card', false);
  setPrimary({ label: '설치 중…', disabled: true });

  try {
    const updated = await invoke('download_and_install', {
      manifest: state.manifest,
      manifestUrl: MANIFEST_URL,
    });
    state.install = updated;
    renderInstalled(updated);
    setHidden('progress-card', true);
    decidePrimary();
  } catch (err) {
    setHidden('progress-card', true);
    showError(formatInstallError(err));
    setPrimary({ label: '재시도', disabled: false, action: 'install' });
  } finally {
    state.busy = false;
  }
}

async function play() {
  state.busy = true;
  setPrimary({ label: '실행 중…', disabled: true });
  try {
    await invoke('launch_game');
    setPrimary({ label: 'Play', disabled: false, action: 'play' });
  } catch (err) {
    showError(`실행 실패: ${err.message ?? err}`);
    setPrimary({ label: 'Play', disabled: false, action: 'play' });
  } finally {
    state.busy = false;
  }
}

// ---- Progress ------------------------------------------------------------

function renderProgress({ phase, bytes, total, message }) {
  const fill = $('progress-fill');
  const ratio = total > 0 ? Math.min(1, bytes / total) : 0;
  fill.style.width = `${(ratio * 100).toFixed(1)}%`;
  setText('progress-phase', phaseLabel(phase));
  if (phase === 'download' && total > 0) {
    setText('progress-numbers', `${humanSize(bytes)} / ${humanSize(total)}`);
  } else if (message) {
    setText('progress-numbers', message);
  } else {
    setText('progress-numbers', '');
  }
}

function phaseLabel(phase) {
  return {
    download: '다운로드',
    verify: '무결성 검증',
    extract: '압축 해제',
    done: '완료',
  }[phase] ?? phase;
}

// ---- Utilities -----------------------------------------------------------

function humanSize(bytes) {
  if (!Number.isFinite(bytes)) return '—';
  const gb = bytes / 1_000_000_000;
  if (gb >= 1) return `${gb.toFixed(2)} GB`;
  const mb = bytes / 1_000_000;
  if (mb >= 1) return `${mb.toFixed(1)} MB`;
  const kb = bytes / 1_000;
  if (kb >= 1) return `${kb.toFixed(0)} KB`;
  return `${bytes} B`;
}

function shortenUrl(u) {
  try {
    const parsed = new URL(u);
    return `${parsed.hostname}${parsed.pathname}`;
  } catch {
    return u;
  }
}

function lookupLink(key) {
  const m = state.manifest;
  if (!m) return null;
  if (key === 'patchNotes') return m.patchNotesUrl;
  if (key === 'knownIssues') return m.knownIssuesUrl;
  if (key === 'feedback') return m.feedbackUrl;
  return null;
}

async function copyBuildInfo() {
  const m = state.manifest;
  const inst = state.install;
  const lines = [
    `Project: ${m?.project ?? 'Rivai'}`,
    `Channel: ${m?.channel ?? '—'}`,
    `Latest: ${m?.latestVersion ?? '—'} (Build ${m?.buildId ?? '—'})`,
    `Installed: ${inst?.installedVersion ?? '미설치'}${inst ? ` (Build ${inst.installedBuildId})` : ''}`,
    `Platform: ${state.platform}`,
    `Server: ${m?.server ? `${m.server.name} (${m.server.host}:${m.server.port})` : '—'}`,
    `When: ${new Date().toISOString()}`,
  ];
  try {
    await navigator.clipboard.writeText(lines.join('\n'));
    flashTagline('Build Info를 클립보드에 복사했어요.');
  } catch (err) {
    showError(`클립보드 복사 실패: ${err.message ?? err}`);
  }
}

function flashTagline(msg) {
  const prev = $('status-tagline').textContent;
  setText('status-tagline', msg);
  setTimeout(() => setText('status-tagline', prev), 2000);
}

// ---- Error display -------------------------------------------------------

function showError(message) {
  setText('error-message', message);
  setHidden('error-card', false);
}

function hideError() {
  setHidden('error-card', true);
}

function showErrorFn(err) {
  showError(err.message ?? String(err));
}

function formatInstallError(err) {
  const msg = err.message ?? String(err);
  if (msg.startsWith('integrity:')) {
    return `다운로드된 zip의 sha256이 manifest 값과 다릅니다. 다시 시도해주세요.\n${msg}`;
  }
  if (msg.startsWith('http:')) {
    return `다운로드 실패: ${msg}`;
  }
  return msg;
}
