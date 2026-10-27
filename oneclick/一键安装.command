#!/bin/bash
# 一键安装（Intel Mac）：DeepSeek Harness、Kimi Code、Antigravity、Antigravity IDE、
# ChatGPT（含 Codex）、Grok Bot、Claude
#
# 双击运行：检查电脑 → 校验安装包 → 逐个装进“应用程序” → 解除隔离 → 打开“应用程序”
# · 某一个装失败不影响其他的，最后列出结果；失败的处理后再双击一次即可。
# · 已经装好且版本相同的会自动跳过，重复运行很快。
# · 全过程记录在 桌面/一键安装日志.txt。
# 兼容 macOS 自带的 bash 3.2。

set -u
cd "$(dirname "$0")" || exit 1
HERE="$(pwd)"
PKG="$HERE/安装包"
LOG="$HOME/Desktop/一键安装日志.txt"
[ -d "$HOME/Desktop" ] || LOG="$HOME/一键安装日志.txt"

# 全部输出同时写进日志，方便出问题时排查
exec > >(tee -a "$LOG") 2>&1
echo ""
echo "######## $(date '+%Y-%m-%d %H:%M:%S') 开始 ########"

# 安装期间不让电脑睡眠
caffeinate -dims -w $$ >/dev/null 2>&1 &

ok_list=""
fail_list=""
skip_list=""
ok()   { ok_list="${ok_list}  ✅ $1"$'\n'; echo "   ✅ $1"; }
bad()  { fail_list="${fail_list}  ❌ $1"$'\n'; echo "   ❌ $1"; }
skip() { skip_list="${skip_list}  ⏭  $1"$'\n'; echo "   ⏭  $1"; }

pause_exit() {
  echo ""
  read -n 1 -s -r -p "按任意键关闭窗口…" </dev/tty
  echo ""
  exit "$1"
}

die() {
  echo ""
  echo "❌ $1"
  pause_exit 1
}

echo "=================================================="
echo "        一键安装（Intel Mac 专用）"
echo "=================================================="
echo ""

# ---------- 1. 检查电脑 ----------
arch=$(uname -m)
[ "$arch" = "x86_64" ] || die "这台 Mac 不是 Intel 芯片（检测到 $arch），这些安装包是给 Intel Mac 准备的。"
os_version=$(sw_vers -productVersion)
os_major=${os_version%%.*}
[ "$os_major" -ge 11 ] || die "系统版本是 macOS $os_version，太旧了。请先到“系统设置 → 软件更新”升级（建议 macOS 14 或更新）。"
echo "✅ Intel 芯片，macOS $os_version"
[ -d "$PKG" ] || die "没找到“安装包”文件夹，请把整个“拷到Mac”文件夹完整拷过来。"

# 磁盘空间：安装后约占 6GB，中途解压还要临时空间
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ -n "$free_gb" ] && [ "$free_gb" -lt 10 ]; then
  die "磁盘剩余空间只有 ${free_gb}GB，至少需要 10GB。请先清理一些文件再运行。"
fi
echo "✅ 磁盘剩余 ${free_gb}GB"

# 管理员权限：普通账户写不进“应用程序”，这时请求一次开机密码
SUDO=""
if [ ! -w /Applications ]; then
  echo ""
  echo "当前账户不能直接写入“应用程序”，需要输入一次这台 Mac 的开机密码（输入时不显示，输完回车）："
  sudo -v </dev/tty || die "密码不对或当前账户不是管理员，无法安装。"
  SUDO="sudo"
fi

# ---------- 2. 校验所有安装包 ----------
bad_files=""
if [ -f "$HERE/SHA256SUMS.txt" ]; then
  echo ""
  echo "▶ 校验安装包是否完整（约 1～3 分钟）…"
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    expected=${line%% *}
    file=${line#*  }
    [ -n "$expected" ] && [ -n "$file" ] && [ "$file" != "$line" ] || continue
    if [ ! -f "$PKG/$file" ]; then
      bad_files="${bad_files}|${file}|"
      echo "   ⚠️  缺少：$file"
      continue
    fi
    actual=$(shasum -a 256 "$PKG/$file" | awk '{print $1}')
    if [ "$actual" = "$expected" ]; then
      echo "   ✔ $file"
    else
      bad_files="${bad_files}|${file}|"
      echo "   ⚠️  损坏：$file（对应软件会跳过，从 U 盘重新拷一次这个文件即可）"
    fi
  done < "$HERE/SHA256SUMS.txt"
else
  echo "⚠️  没找到 SHA256SUMS.txt，跳过完整性校验"
fi
file_ok() { case "$bad_files" in *"|$1|"*) return 1 ;; esac; [ -f "$PKG/$1" ]; }

# ---------- 公共函数 ----------
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }

# 把一个 .app 装进“应用程序”：版本相同就跳过；否则关掉旧的 → 旧版移到废纸篓 → 复制 → 去隔离
place_app() {
  local label="$1" src="$2" name target new_v old_v
  name=$(basename "$src")
  target="/Applications/$name"
  new_v="$(plist_value "$src" CFBundleShortVersionString) ($(plist_value "$src" CFBundleVersion))"
  if [ -d "$target" ]; then
    old_v="$(plist_value "$target" CFBundleShortVersionString) ($(plist_value "$target" CFBundleVersion))"
    if [ "$old_v" = "$new_v" ]; then
      skip "$label 已是这个版本 $new_v，跳过"
      return 0
    fi
    # 只在它正在运行时才去关，避免弹出“找不到应用”的对话框
    if pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1; then
      osascript -e "tell application \"$target\" to quit" >/dev/null 2>&1
      sleep 3
      pkill -f "$target/Contents/MacOS/" >/dev/null 2>&1
      sleep 1
    fi
    if ! $SUDO mv "$target" "$HOME/.Trash/${name%.app} 旧版 $(date +%Y%m%d-%H%M%S).app" 2>/dev/null; then
      bad "$label：旧版本移不走，请手动把“应用程序”里的 $name 拖到废纸篓后再运行"
      return 1
    fi
  fi
  if ! $SUDO ditto "$src" "$target"; then
    bad "$label：复制到“应用程序”失败"
    return 1
  fi
  $SUDO xattr -dr com.apple.quarantine "$target" 2>/dev/null
  ok "$label $new_v → /Applications/$name"
}

# 从 dmg 安装：挂载 → 复制里面的 .app → 卸载
install_dmg() {
  local label="$1" file="$2" min_major="$3" mnt app found=0
  echo ""
  echo "▶ $label"
  if [ "$os_major" -lt "$min_major" ]; then
    skip "$label：需要 macOS $min_major 或更新（当前 $os_version），升级系统后再运行一次"
    return
  fi
  if ! file_ok "$file"; then bad "$label：安装包缺失或损坏（$file）"; return; fi
  mnt=$(mktemp -d /tmp/oneclick.XXXXXX)
  # yes 用来自动同意少数 dmg 自带的许可协议
  if ! yes | hdiutil attach -nobrowse -readonly -noautoopen -mountpoint "$mnt" "$PKG/$file" >/dev/null 2>&1; then
    rmdir "$mnt" 2>/dev/null
    bad "$label：打不开安装包"
    return
  fi
  for app in "$mnt"/*.app; do
    [ -d "$app" ] || continue
    found=1
    place_app "$label" "$app"
  done
  [ "$found" = 1 ] || bad "$label：安装包里没找到应用程序"
  hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || hdiutil detach "$mnt" -force -quiet >/dev/null 2>&1
  rmdir "$mnt" 2>/dev/null
}

# 从 zip 安装：解压到临时目录 → 复制 .app（临时目录在 /tmp，重启自动清理）
install_zip() {
  local label="$1" file="$2" min_major="$3" tmp app found=0
  echo ""
  echo "▶ $label"
  if [ "$os_major" -lt "$min_major" ]; then
    skip "$label：需要 macOS $min_major 或更新（当前 $os_version）"
    return
  fi
  if ! file_ok "$file"; then bad "$label：安装包缺失或损坏（$file）"; return; fi
  tmp=$(mktemp -d /tmp/oneclick.XXXXXX)
  if ! ditto -x -k "$PKG/$file" "$tmp"; then
    bad "$label：解压失败"
    return
  fi
  for app in "$tmp"/*.app; do
    [ -d "$app" ] || continue
    found=1
    place_app "$label" "$app"
  done
  [ "$found" = 1 ] || bad "$label：压缩包里没找到应用程序"
}

# Kimi Code 命令行：按官方安装脚本的做法放到 ~/.kimi-code/bin/kimi 并加进 PATH
KIMI_FILE="kimi-code-2.3.3-darwin-x64.tar.gz"
KIMI_SHA="f0103e2d5605acb488708b05d39a5b3a4280bf2cbfa7a03da42b696d21b00a25"
install_kimi() {
  local label="Kimi Code（命令行）" dir="$HOME/.kimi-code" tmp bin rc line
  echo ""
  echo "▶ $label"
  if ! file_ok "$KIMI_FILE"; then bad "$label：安装包缺失或损坏（$KIMI_FILE）"; return; fi
  if [ -f "$dir/bin/kimi" ] && [ "$(shasum -a 256 "$dir/bin/kimi" | awk '{print $1}')" = "$KIMI_SHA" ]; then
    skip "$label 已是 2.3.3，跳过"
    return
  fi
  tmp=$(mktemp -d /tmp/oneclick.XXXXXX)
  tar -xzf "$PKG/$KIMI_FILE" -C "$tmp" 2>/dev/null || { bad "$label：解压失败"; return; }
  # 在解压出的文件里找校验值对得上的那个程序
  bin=""
  while IFS= read -r f; do
    if [ "$(shasum -a 256 "$f" | awk '{print $1}')" = "$KIMI_SHA" ]; then bin="$f"; break; fi
  done < <(find "$tmp" -type f -size +1M)
  [ -n "$bin" ] || { bad "$label：程序校验不通过"; return; }
  mkdir -p "$dir/bin"
  [ -f "$dir/bin/kimi" ] && cp "$dir/bin/kimi" "$dir/bin/kimi.bak"
  install -m 0755 "$bin" "$dir/bin/kimi" || { bad "$label：复制失败"; return; }
  xattr -d com.apple.quarantine "$dir/bin/kimi" 2>/dev/null
  # 和官方安装脚本一致：标记国内渠道（首次登录后以登录信息为准）
  [ -f "$dir/region" ] || printf 'mainland-cn\n' > "$dir/region"
  # 加进 PATH（zsh 是 macOS 默认终端，bash 也顺带配上）
  line="export PATH=\"$dir/bin:\$PATH\""
  for rc in "$HOME/.zshrc" "$HOME/.bash_profile"; do
    grep -qsF "$dir/bin" "$rc" || printf '\n# kimi-code\n%s\n' "$line" >> "$rc"
  done
  if "$dir/bin/kimi" --version >/dev/null 2>&1; then
    ok "$label 2.3.3 → ~/.kimi-code/bin/kimi（新开终端输入 kimi 使用）"
  else
    ok "$label 2.3.3 已安装到 ~/.kimi-code/bin/kimi（新开终端输入 kimi 使用）"
  fi
}

# ---------- 3. 逐个安装 ----------
# 参数：名称  安装包文件名  最低 macOS 主版本
dsh_dmg=$(cd "$PKG" && ls -1 deepseek-harness-*.dmg 2>/dev/null | head -n 1)
if [ -n "$dsh_dmg" ]; then
  install_dmg "DeepSeek Harness" "$dsh_dmg" 13
else
  echo ""
  echo "▶ DeepSeek Harness"
  bad "DeepSeek Harness：没找到安装包"
fi
install_kimi
install_dmg "Antigravity"         "Antigravity-2.26.0-Intel.dmg"     12
install_dmg "Antigravity IDE"     "Antigravity-IDE-2.5.5-Intel.dmg"  12
install_dmg "ChatGPT（含 Codex）" "ChatGPT-Codex-Intel.dmg"          14
install_dmg "Grok Bot"            "Grok-Bot-0.77.0-Intel.dmg"        12
install_zip "Claude"              "Claude-3.6556.2-Universal.zip"    11

# ---------- 4. 结果 ----------
echo ""
echo "================ 安装结果 ================"
[ -n "$ok_list" ]   && printf '%s' "$ok_list"
[ -n "$skip_list" ] && printf '%s' "$skip_list"
[ -n "$fail_list" ] && printf '%s' "$fail_list"
echo "=========================================="
echo ""
echo "· 桌面软件都在“应用程序”里，也可以按 Command+空格 搜索名字打开。"
echo "· Kimi Code 是命令行工具：新开一个“终端”窗口，输入 kimi 回车。"
echo "· 各软件第一次打开时登录自己的账号。"
echo "· DeepSeek Harness：设置 → 模型，填入 DeepSeek API 密钥。"
echo "· 全过程记录在 桌面/一键安装日志.txt"
echo "######## $(date '+%Y-%m-%d %H:%M:%S') 结束 ########"
open /Applications
if [ -n "$fail_list" ]; then pause_exit 1; else pause_exit 0; fi
