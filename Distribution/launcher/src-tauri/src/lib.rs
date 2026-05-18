// Rivai Launcher — core commands
//
// Responsibilities:
//   1. Read/write the local install state (launcher.json)
//   2. Download a build zip from R2 with streaming progress
//   3. Verify sha256
//   4. Extract (Mac: ditto; Windows: TODO)
//   5. Launch the installed game executable with server args
//
// Each command returns a structured Result so the frontend can show
// meaningful errors instead of generic "something failed".

use std::path::{Path, PathBuf};
use std::process::Stdio;

use chrono::{DateTime, Utc};
use futures_util::StreamExt;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use tauri::{AppHandle, Emitter, Manager};
use tauri_plugin_opener::OpenerExt;
use tokio::fs;
use tokio::io::AsyncWriteExt;

// ---------------------------------------------------------------------------
// Errors
// ---------------------------------------------------------------------------

#[derive(Debug, thiserror::Error)]
pub enum LauncherError {
    #[error("io: {0}")]
    Io(#[from] std::io::Error),
    #[error("http: {0}")]
    Http(#[from] reqwest::Error),
    #[error("json: {0}")]
    Json(#[from] serde_json::Error),
    #[error("path: {0}")]
    Path(String),
    #[error("integrity: expected sha256 {expected}, got {actual}")]
    Integrity { expected: String, actual: String },
    #[error("manifest: missing client.{0} entry")]
    PlatformMissing(String),
    #[error("install: {0}")]
    Install(String),
    #[error("launch: {0}")]
    Launch(String),
}

impl serde::Serialize for LauncherError {
    fn serialize<S: serde::Serializer>(&self, s: S) -> std::result::Result<S::Ok, S::Error> {
        s.serialize_str(&self.to_string())
    }
}

type Result<T> = std::result::Result<T, LauncherError>;

// ---------------------------------------------------------------------------
// Data model
// ---------------------------------------------------------------------------

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PlatformBuild {
    #[serde(rename = "downloadUrl")]
    pub download_url: String,
    pub sha256: String,
    #[serde(rename = "sizeBytes")]
    pub size_bytes: u64,
    pub executable: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientBuilds {
    pub win64: Option<PlatformBuild>,
    pub mac: Option<PlatformBuild>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ServerInfo {
    pub name: String,
    pub host: String,
    pub port: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Manifest {
    pub project: String,
    pub channel: String,
    #[serde(rename = "latestVersion")]
    pub latest_version: String,
    #[serde(rename = "buildId")]
    pub build_id: String,
    #[serde(rename = "releasedAt")]
    pub released_at: Option<String>,
    pub client: ClientBuilds,
    pub server: ServerInfo,
    #[serde(rename = "patchNotesUrl")]
    pub patch_notes_url: Option<String>,
    #[serde(rename = "feedbackUrl")]
    pub feedback_url: Option<String>,
    #[serde(rename = "knownIssuesUrl")]
    pub known_issues_url: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InstallState {
    pub channel: String,
    #[serde(rename = "manifestUrl")]
    pub manifest_url: String,
    #[serde(rename = "installedVersion")]
    pub installed_version: String,
    #[serde(rename = "installedBuildId")]
    pub installed_build_id: String,
    #[serde(rename = "installedAt")]
    pub installed_at: DateTime<Utc>,
    #[serde(rename = "installPath")]
    pub install_path: PathBuf,
    pub executable: String,
    #[serde(rename = "lastChecked")]
    pub last_checked: Option<DateTime<Utc>>,
    #[serde(rename = "lastError")]
    pub last_error: Option<String>,
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

fn app_data_dir(app: &AppHandle) -> Result<PathBuf> {
    app.path()
        .app_data_dir()
        .map_err(|e| LauncherError::Path(format!("app_data_dir: {e}")))
}

fn launcher_json_path(app: &AppHandle) -> Result<PathBuf> {
    Ok(app_data_dir(app)?.join("launcher.json"))
}

fn versions_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(app_data_dir(app)?.join("versions"))
}

fn cache_dir(app: &AppHandle) -> Result<PathBuf> {
    Ok(app_data_dir(app)?.join("cache").join("downloads"))
}

// ---------------------------------------------------------------------------
// Commands
// ---------------------------------------------------------------------------

#[tauri::command]
async fn read_install_state(app: AppHandle) -> Result<Option<InstallState>> {
    let path = launcher_json_path(&app)?;
    if !path.exists() {
        return Ok(None);
    }
    let bytes = fs::read(&path).await?;
    match serde_json::from_slice::<InstallState>(&bytes) {
        Ok(state) => {
            // If the install path no longer exists, treat as not installed.
            if !state.install_path.exists() {
                return Ok(None);
            }
            Ok(Some(state))
        }
        Err(_) => Ok(None), // corrupt → fall back to "not installed"
    }
}

#[tauri::command]
async fn write_install_state(app: AppHandle, state: InstallState) -> Result<()> {
    let path = launcher_json_path(&app)?;
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).await?;
    }
    let bytes = serde_json::to_vec_pretty(&state)?;
    fs::write(&path, bytes).await?;
    Ok(())
}

#[derive(Debug, Serialize, Clone)]
struct ProgressEvent {
    phase: String, // "download" | "verify" | "extract" | "done"
    bytes: u64,
    total: u64,
    message: Option<String>,
}

fn current_platform() -> &'static str {
    if cfg!(target_os = "macos") {
        "mac"
    } else if cfg!(target_os = "windows") {
        "win64"
    } else {
        "other"
    }
}

#[tauri::command]
async fn download_and_install(
    app: AppHandle,
    manifest: Manifest,
    manifest_url: String,
) -> Result<InstallState> {
    let platform = current_platform();
    let build = match platform {
        "mac" => manifest.client.mac.as_ref(),
        "win64" => manifest.client.win64.as_ref(),
        _ => None,
    }
    .ok_or_else(|| LauncherError::PlatformMissing(platform.to_string()))?
    .clone();

    let cache = cache_dir(&app)?;
    fs::create_dir_all(&cache).await?;
    let download_path = cache.join(format!(
        "{}_{}_{}.zip",
        manifest.project, manifest.latest_version, platform
    ));

    // ---- 1. Download with progress ----
    emit_progress(&app, "download", 0, build.size_bytes, None);
    let resp = reqwest::get(&build.download_url).await?.error_for_status()?;
    let total = resp.content_length().unwrap_or(build.size_bytes);
    let mut file = fs::File::create(&download_path).await?;
    let mut hasher = Sha256::new();
    let mut downloaded: u64 = 0;
    let mut stream = resp.bytes_stream();
    while let Some(chunk) = stream.next().await {
        let chunk = chunk?;
        hasher.update(&chunk);
        file.write_all(&chunk).await?;
        downloaded += chunk.len() as u64;
        emit_progress(&app, "download", downloaded, total, None);
    }
    file.flush().await?;
    drop(file);

    // ---- 2. Verify ----
    emit_progress(&app, "verify", 0, 1, Some("sha256 검증".to_string()));
    let actual = hex::encode(hasher.finalize());
    if actual.to_lowercase() != build.sha256.to_lowercase() {
        let _ = fs::remove_file(&download_path).await;
        return Err(LauncherError::Integrity {
            expected: build.sha256,
            actual,
        });
    }
    emit_progress(&app, "verify", 1, 1, Some("sha256 OK".to_string()));

    // ---- 3. Extract (side-by-side) ----
    emit_progress(&app, "extract", 0, 1, Some("압축 해제 중".to_string()));
    let target = versions_dir(&app)?.join(&manifest.latest_version);
    if target.exists() {
        fs::remove_dir_all(&target).await?;
    }
    fs::create_dir_all(&target).await?;
    extract_zip(&download_path, &target, platform).await?;
    emit_progress(&app, "extract", 1, 1, Some("압축 해제 완료".to_string()));

    // ---- 4. Update install state ----
    let install_path = target;
    let state = InstallState {
        channel: manifest.channel.clone(),
        manifest_url,
        installed_version: manifest.latest_version.clone(),
        installed_build_id: manifest.build_id.clone(),
        installed_at: Utc::now(),
        install_path: install_path.clone(),
        executable: build.executable,
        last_checked: Some(Utc::now()),
        last_error: None,
    };
    write_install_state(app.clone(), state.clone()).await?;

    // ---- 5. Cleanup cache ----
    let _ = fs::remove_file(&download_path).await;

    emit_progress(&app, "done", 1, 1, Some("설치 완료".to_string()));
    Ok(state)
}

fn emit_progress(app: &AppHandle, phase: &str, bytes: u64, total: u64, message: Option<String>) {
    let _ = app.emit(
        "install-progress",
        ProgressEvent {
            phase: phase.to_string(),
            bytes,
            total,
            message,
        },
    );
}

async fn extract_zip(zip_path: &Path, target: &Path, platform: &str) -> Result<()> {
    // M0: Mac uses `ditto`. Windows path TBD in a later milestone (we don't ship win64 launcher yet).
    let status = match platform {
        "mac" => {
            tokio::process::Command::new("ditto")
                .args(["-x", "-k"])
                .arg(zip_path)
                .arg(target)
                .stdout(Stdio::null())
                .stderr(Stdio::piped())
                .status()
                .await?
        }
        _ => {
            return Err(LauncherError::Install(format!(
                "extract not implemented for platform {platform} on this host"
            )));
        }
    };
    if !status.success() {
        return Err(LauncherError::Install(format!(
            "extraction failed (exit {:?})",
            status.code()
        )));
    }
    Ok(())
}

#[tauri::command]
async fn launch_game(app: AppHandle) -> Result<()> {
    let state = read_install_state(app.clone())
        .await?
        .ok_or_else(|| LauncherError::Launch("not installed".to_string()))?;

    // Locate executable. On Mac the executable is "Rivai.app"; we resolve to its
    // CFBundleExecutable via `open -a` for simplicity.
    let exe_path = locate_executable(&state.install_path, &state.executable)?;

    let mut cmd = if cfg!(target_os = "macos") && exe_path.extension().and_then(|s| s.to_str()) == Some("app") {
        // `open` does not block and forwards extra args after `--args`.
        let mut c = tokio::process::Command::new("open");
        c.args(["-a"]).arg(&exe_path);
        c
    } else {
        tokio::process::Command::new(&exe_path)
    };

    // Pass server info as args. The actual UE client needs to parse these
    // (this is a placeholder while the binary is still dummy).
    // Read manifest server info from install state's manifestUrl is overkill here;
    // instead persist server info into launcher.json in a later iteration.
    // For v0 we just spawn the executable.

    cmd.stdout(Stdio::null()).stderr(Stdio::null());

    cmd.spawn()
        .map_err(|e| LauncherError::Launch(format!("spawn failed: {e}")))?;
    Ok(())
}

fn locate_executable(install_path: &Path, executable: &str) -> Result<PathBuf> {
    // Walk the install_path looking for the executable (handles staging/<...>/Rivai.app pattern from ditto).
    let direct = install_path.join(executable);
    if direct.exists() {
        return Ok(direct);
    }
    for entry in walkdir(install_path)? {
        if entry.file_name().and_then(|n| n.to_str()) == Some(executable) {
            return Ok(entry);
        }
    }
    Err(LauncherError::Launch(format!(
        "executable {executable} not found under {}",
        install_path.display()
    )))
}

fn walkdir(root: &Path) -> Result<Vec<PathBuf>> {
    let mut out = Vec::new();
    let mut stack = vec![root.to_path_buf()];
    while let Some(p) = stack.pop() {
        if let Ok(rd) = std::fs::read_dir(&p) {
            for e in rd.flatten() {
                let path = e.path();
                if path.is_dir() {
                    stack.push(path.clone());
                }
                out.push(path);
            }
        }
    }
    Ok(out)
}

#[tauri::command]
async fn open_install_folder(app: AppHandle) -> Result<()> {
    let state = read_install_state(app.clone())
        .await?
        .ok_or_else(|| LauncherError::Launch("not installed".to_string()))?;
    app.opener()
        .open_path(state.install_path.to_string_lossy(), None::<&str>)
        .map_err(|e| LauncherError::Launch(format!("open failed: {e}")))?;
    Ok(())
}

#[tauri::command]
async fn open_logs(app: AppHandle) -> Result<()> {
    // UE writes per-project logs under <UserDirectory>/Library/Logs/<Project>/ (macOS)
    // and %LOCALAPPDATA%\<Project>\Saved\Logs\ (Windows). For dummy builds the
    // folder may not exist; we fall back to the install folder.
    let candidate = if cfg!(target_os = "macos") {
        dirs::home_dir().map(|h| h.join("Library").join("Logs").join("Rivai"))
    } else if cfg!(target_os = "windows") {
        dirs::data_local_dir().map(|d| d.join("Rivai").join("Saved").join("Logs"))
    } else {
        None
    };
    let path = match candidate {
        Some(p) if p.exists() => p,
        _ => {
            // fall back to install dir
            match read_install_state(app.clone()).await? {
                Some(s) => s.install_path,
                None => app_data_dir(&app)?,
            }
        }
    };
    app.opener()
        .open_path(path.to_string_lossy(), None::<&str>)
        .map_err(|e| LauncherError::Launch(format!("open failed: {e}")))?;
    Ok(())
}

#[tauri::command]
fn current_platform_cmd() -> &'static str {
    current_platform()
}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_opener::init())
        .plugin(tauri_plugin_shell::init())
        .invoke_handler(tauri::generate_handler![
            read_install_state,
            write_install_state,
            download_and_install,
            launch_game,
            open_install_folder,
            open_logs,
            current_platform_cmd,
        ])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
