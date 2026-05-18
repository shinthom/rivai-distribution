const MANIFEST_URL =
  'https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev/manifest/dev.json';
const LAUNCHER_MANIFEST_URL =
  'https://pub-0ac7d3ef69e344e1bb87f0d1475315cb.r2.dev/manifest/launcher/dev.json';

async function main() {
  fillText('manifestSource', MANIFEST_URL);

  // 두 manifest를 병렬 fetch. 런처 manifest는 실패해도 게임 다운로드 흐름은 계속.
  const [gameRes, launcherRes] = await Promise.allSettled([
    fetchManifest(MANIFEST_URL),
    fetchManifest(LAUNCHER_MANIFEST_URL),
  ]);

  if (gameRes.status === 'rejected') {
    throw gameRes.reason;
  }
  const m = gameRes.value;

  fillText('latestVersion', m.latestVersion ?? '—');
  fillText('buildId', m.buildId ?? '—');
  fillText('releasedAt', formatDate(m.releasedAt));
  fillText('serverName', m.server?.name ?? '—');

  applyPlatform('downloadWin64', 'sizeWin64', m.client?.win64);
  applyPlatform('downloadMac', 'sizeMac', m.client?.mac);

  setLink('patchNotesLink', m.patchNotesUrl);
  setLink('knownIssuesLink', m.knownIssuesUrl);
  setLink('knownIssuesLink2', m.knownIssuesUrl);
  setLink('feedbackLink', m.feedbackUrl);

  highlightDetectedPlatform(m);
  setExecutableHint(m);

  // 런처 카드
  if (launcherRes.status === 'fulfilled') {
    renderLauncher(launcherRes.value);
  } else {
    applyPlatform('downloadLauncherMac', 'sizeLauncherMac', null);
    fillText('launcherVersion', '런처 정보를 불러오지 못함');
  }
}

function renderLauncher(lm) {
  fillText('launcherVersion', lm.latestVersion ?? '—');
  fillText('launcherBuildId', lm.buildId ? `Build ${lm.buildId}` : '—');

  const mac = lm.launcher?.mac;
  const win = lm.launcher?.win64;

  const targets = [];
  if (mac) {
    const macLabel = mac.arch === 'arm64' ? 'macOS (Apple Silicon)' : `macOS (${mac.arch})`;
    targets.push(mac.format === 'dmg' ? `${macLabel}, DMG` : macLabel);
  }
  if (win) targets.push(win.arch === 'x64' ? 'Windows (x64)' : `Windows (${win.arch})`);
  fillText('launcherTarget', targets.join(' / ') || '—');

  applyPlatform('downloadLauncherMac', 'sizeLauncherMac', mac);
  applyPlatform('downloadLauncherWin64', 'sizeLauncherWin64', win);

  // Mac DMG일 때 카드 라벨에 명시
  if (mac?.format === 'dmg') {
    const macLabelEl = document.querySelector('[data-slot="downloadLauncherMac"] .dl-label');
    if (macLabelEl) macLabelEl.textContent = 'Download Launcher (Mac · DMG)';
  }
}

async function fetchManifest(url) {
  const res = await fetch(url, { cache: 'no-store' });
  if (!res.ok) throw new Error(`manifest fetch failed: ${res.status} ${res.statusText}`);
  return res.json();
}

function applyPlatform(linkSlot, sizeSlot, platform) {
  const linkEl = slot(linkSlot);
  const sizeEl = slot(sizeSlot);
  if (!platform || !platform.downloadUrl) {
    if (linkEl) {
      linkEl.classList.add('is-disabled');
      linkEl.removeAttribute('href');
      linkEl.setAttribute('aria-disabled', 'true');
    }
    if (sizeEl) sizeEl.textContent = '미지원';
    return;
  }
  if (linkEl) {
    linkEl.href = platform.downloadUrl;
    linkEl.setAttribute('download', '');
  }
  if (sizeEl) sizeEl.textContent = humanSize(platform.sizeBytes);
}

function highlightDetectedPlatform(m) {
  const os = detectOS();
  if (os === 'win' && m.client?.win64?.downloadUrl) {
    slot('downloadWin64')?.classList.add('is-recommended');
  } else if (os === 'mac' && m.client?.mac?.downloadUrl) {
    slot('downloadMac')?.classList.add('is-recommended');
  }
}

function setExecutableHint(m) {
  const os = detectOS();
  const exe =
    (os === 'mac' ? m.client?.mac?.executable : m.client?.win64?.executable) ??
    m.client?.win64?.executable ??
    'Rivai.exe';
  fillText('executableHint', exe);
}

function detectOS() {
  const ua = (navigator.userAgent || '').toLowerCase();
  const plat = (navigator.platform || '').toLowerCase();
  if (ua.includes('mac') || plat.includes('mac')) return 'mac';
  if (ua.includes('win') || plat.includes('win')) return 'win';
  return 'other';
}

function humanSize(bytes) {
  if (!Number.isFinite(bytes)) return '—';
  const gb = bytes / 1_000_000_000;
  if (gb >= 1) return `${gb.toFixed(2)} GB`;
  const mb = bytes / 1_000_000;
  if (mb >= 1) return `${mb.toFixed(1)} MB`;
  return `${bytes} B`;
}

function formatDate(iso) {
  if (!iso) return '—';
  try {
    const d = new Date(iso);
    return d.toLocaleString('ko-KR', {
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
      hour: '2-digit',
      minute: '2-digit',
    });
  } catch {
    return iso;
  }
}

function slot(name) {
  return document.querySelector(`[data-slot="${name}"]`);
}

function fillText(name, value) {
  const el = slot(name);
  if (el) el.textContent = value;
}

function setLink(name, url) {
  const els = document.querySelectorAll(`[data-slot="${name}"]`);
  if (!url) return;
  els.forEach((el) => {
    el.href = url;
    el.rel = 'noopener';
  });
}

function showError(message) {
  const el = slot('error');
  if (!el) return;
  el.hidden = false;
  el.textContent = `오류: ${message}. 잠시 후 다시 시도하거나 피드백 채널에 알려주세요.`;
}

main().catch((err) => {
  console.error(err);
  showError(err.message ?? String(err));
});
