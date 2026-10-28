#!/bin/bash
# 一键安装（Intel Mac）：DeepSeek Harness、Kimi Code、Antigravity、Antigravity IDE、
# ChatGPT（含 Codex）、Grok Bot、Claude、微信、QQ、v2rayN（节点软件），并导入 Windows 上的 AI 数据
#
# 双击运行：检查电脑 → 校验安装包 → 逐个装进“应用程序” → 解除隔离 → 打开“应用程序”
# · 某一个装失败不影响其他的，最后列出结果；失败的处理后再双击一次即可。
# · Mac 上已经装好的软件一律保持不动（不管版本新旧），只补装没有的或已损坏的；重复运行很快。
# · 先复制到隐藏的临时名字，完整复制好才换上，中途关窗口或断电不会留下装了一半的软件。
# · 全过程记录在 桌面/一键安装日志.txt。
# 兼容 macOS 自带的 bash 3.2。

# 被用 sh/zsh 运行时换回 bash（下面用到了 bash 才有的功能）
if [ -z "${BASH_VERSION:-}" ]; then exec /bin/bash "$0" "$@"; fi
case ":${SHELLOPTS:-}:" in *:posix:*) exec /bin/bash "$0" "$@" ;; esac

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
  printf '按任意键关闭窗口…'
  read -n 1 -s -r 2>/dev/null </dev/tty
  echo ""
  exit "$1"
}

die() {
  echo ""
  echo "❌ $1"
  pause_exit 1
}

# 临时文件都放在这一个目录里，结束（包括中途关窗口）时统一清掉
WORK=$(mktemp -d /tmp/oneclick.XXXXXX) || die "无法创建临时目录"
CUR_STAGE=""
SUDO=""
LOCK=/tmp/oneclick.lock
LOCKED=0
cleanup() {
  local m
  for m in "$WORK"/mnt.*; do
    [ -d "$m" ] && hdiutil detach "$m" -force -quiet >/dev/null 2>&1
  done
  [ -n "$CUR_STAGE" ] && $SUDO rm -rf "$CUR_STAGE" 2>/dev/null
  case "$WORK" in /tmp/oneclick.?*) rm -rf "$WORK" 2>/dev/null ;; esac
  if [ "$LOCKED" = 1 ]; then rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null; fi
}
trap cleanup EXIT
trap 'exit 130' HUP TERM
trap 'echo ""; echo "⚠️  安装被中断。再双击一次即可继续，已装好的会自动跳过。"; exit 130' INT

# 同一时间只允许运行一个（不小心双击了两次时，第二个直接退出）
if ! mkdir "$LOCK" 2>/dev/null; then
  other=$(cat "$LOCK/pid" 2>/dev/null)
  if [ -n "$other" ] && ps -p "$other" -o command= 2>/dev/null | grep -q '一键安装'; then
    die "一键安装已经在另一个终端窗口里运行了，等那边结束就行，不要同时运行两个。"
  fi
  # 上次异常退出留下的锁，清掉重来
  rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null
  mkdir "$LOCK" 2>/dev/null || die "无法创建 $LOCK，请重启电脑后再运行。"
fi
LOCKED=1
echo $$ > "$LOCK/pid"

# 申请管理员权限（只问一次密码）；已有免密 sudo 时不问
get_admin() {
  [ -n "$SUDO" ] && return 0
  if ! sudo -n true 2>/dev/null; then
    echo ""
    echo "需要输入一次这台 Mac 的开机密码（输入时屏幕上不显示，输完按回车）："
    sudo -v </dev/tty || return 1
  fi
  SUDO="sudo"
  # sudo 默认 5 分钟后忘记密码，安装比这久，后台续期免得中途再问
  ( while kill -0 $$ 2>/dev/null; do sudo -n true; sleep 50; done ) >/dev/null 2>&1 &
  return 0
}

# 系统版本是否 ≥ 要求（比较“主版本.次版本”，例如 13.6）
os_at_least() {
  local a1 a2 b1 b2 rest
  IFS=. read -r a1 a2 rest <<< "$os_version"
  IFS=. read -r b1 b2 rest <<< "$1"
  a1=${a1//[!0-9]/}; a2=${a2//[!0-9]/}; b1=${b1//[!0-9]/}; b2=${b2//[!0-9]/}
  a1=${a1:-0}; a2=${a2:-0}; b1=${b1:-0}; b2=${b2:-0}
  [ "$a1" -gt "$b1" ] || { [ "$a1" -eq "$b1" ] && [ "$a2" -ge "$b2" ]; }
}

echo "=================================================="
echo "        一键安装（Intel Mac 专用）"
echo "=================================================="
echo ""

# ---------- 1. 检查电脑 ----------
arch=$(uname -m)
[ "$arch" = "x86_64" ] || die "这台 Mac 不是 Intel 芯片（检测到 ${arch}），这些安装包是给 Intel Mac 准备的。"
os_version=$(sw_vers -productVersion)
os_at_least 11 || die "系统版本是 macOS ${os_version}，太旧了。请先到“系统设置 → 软件更新”升级（建议 macOS 14 或更新）。"
echo "✅ Intel 芯片，macOS $os_version"
[ -d "$PKG" ] || die "没找到“安装包”文件夹，请把整个“拷到Mac”文件夹完整拷过来。"

# 磁盘空间：安装后约占 6GB，中途解压还要临时空间
free_gb=$(df -g / | awk 'NR==2 {print $4}')
if [ -n "$free_gb" ] && [ "$free_gb" -lt 10 ]; then
  die "磁盘剩余空间只有 ${free_gb}GB，至少需要 10GB。请先清理一些文件再运行。"
fi
echo "✅ 磁盘剩余 ${free_gb}GB"

# 普通账户写不进“应用程序”，这时请求一次开机密码
if [ ! -w /Applications ]; then
  echo ""
  echo "当前账户不能直接写入“应用程序”。"
  get_admin || die "密码不对或当前账户不是管理员，无法安装。"
fi

START=$SECONDS
elapsed() { echo "（用时 $(( SECONDS - $1 )) 秒）"; }

# ---------- 2. 校验所有安装包（全部并行计算，用满所有 CPU 核心）----------
bad_files=""
good_files=""
if [ -f "$HERE/SHA256SUMS.txt" ]; then
  echo ""
  echo "▶ 校验安装包是否完整…"
  t=$SECONDS
  shadir=$(mktemp -d "$WORK/sha.XXXXXX")
  sha_pids=""
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    file=${line#*  }
    [ "$file" != "$line" ] && [ -f "$PKG/$file" ] || continue
    ( shasum -a 256 "$PKG/$file" | awk '{print $1}' > "$shadir/$file" ) &
    sha_pids="$sha_pids $!"
  done < "$HERE/SHA256SUMS.txt"
  # 只等校验任务；不能用不带参数的 wait，否则会一直等后台的防睡眠进程
  [ -n "$sha_pids" ] && wait $sha_pids
  while IFS= read -r line || [ -n "$line" ]; do
    line=${line%$'\r'}
    expected=${line%% *}
    file=${line#*  }
    [ -n "$expected" ] && [ -n "$file" ] && [ "$file" != "$line" ] || continue
    if [ ! -f "$PKG/$file" ]; then
      bad_files="${bad_files}|${file}|"
      echo "   ⚠️  缺少：$file"
    elif [ "$(cat "$shadir/$file" 2>/dev/null)" = "$expected" ]; then
      good_files="${good_files}|${file}|"
      echo "   ✔ $file"
    else
      bad_files="${bad_files}|${file}|"
      echo "   ⚠️  损坏：${file}（对应软件会跳过，从 U 盘重新拷一次这个文件即可）"
    fi
  done < "$HERE/SHA256SUMS.txt"
  echo "   $(elapsed $t)"
else
  echo "⚠️  没找到 SHA256SUMS.txt，跳过完整性校验"
fi
file_ok() { case "$bad_files" in *"|$1|"*) return 1 ;; esac; [ -f "$PKG/$1" ]; }

# ---------- 公共函数 ----------
plist_value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1/Contents/Info.plist" 2>/dev/null; }
app_version() {
  local v b
  v=$(plist_value "$1" CFBundleShortVersionString)
  b=$(plist_value "$1" CFBundleVersion)
  if [ -n "$b" ] && [ "$b" != "$v" ]; then echo "$v ($b)"; else echo "$v"; fi
}

# 这个软件是否已经装好（“应用程序”或个人的“应用程序”里有，且程序文件完整）；找到的路径放在 found_app
found_app=""
app_installed() {
  local p exe
  for p in "/Applications/$1" "$HOME/Applications/$1"; do
    [ -d "$p" ] || continue
    exe=$(plist_value "$p" CFBundleExecutable)
    if [ -n "$exe" ] && [ -x "$p/Contents/MacOS/$exe" ]; then found_app="$p"; return 0; fi
  done
  return 1
}
# 参数：名称  安装包里的版本（不知道时留空）
skip_installed() {
  local have
  have=$(app_version "$found_app")
  if [ -z "$2" ] || [ "$have" = "$2" ]; then
    skip "$1 已经装好（${have:-未知版本}），保持不动"
  else
    skip "$1 已经装好（${have:-未知版本}），保持不动；安装包里是 ${2}，想换成它就先把旧的拖到废纸篓再运行"
  fi
}

# 把损坏的旧版移到废纸篓；不是自己装的（例如 App Store 装的，属于系统管理员）就用管理员权限再试
retire_app() {
  local name stamp dest
  name=$(basename "$1" .app)
  stamp=$(date +%Y%m%d-%H%M%S)
  dest="$HOME/.Trash/${name} 旧版 ${stamp}.app"
  mkdir -p "$HOME/.Trash" 2>/dev/null
  $SUDO mv "$1" "$dest" 2>/dev/null && return 0
  if [ -z "$SUDO" ] && get_admin; then
    $SUDO mv "$1" "$dest" 2>/dev/null && return 0
  fi
  # 废纸篓不让写时放进临时目录（重启后系统自动清理）
  $SUDO mv "$1" "/private/tmp/${name} 旧版 ${stamp}.app" 2>/dev/null
}

# 把一个 .app 装进“应用程序”：版本相同就跳过；否则先复制到隐藏临时名字 → 关掉旧的 → 旧版移到废纸篓 → 换上新版
# 第三个参数为 move 时直接移动（来源是自己解压的临时目录，同一块盘上移动是瞬间完成的）
place_app() {
  local label="$1" src="$2" mode="${3:-copy}" name target stage new_v min
  name=$(basename "$src")
  target="/Applications/$name"
  new_v=$(app_version "$src")
  min=$(plist_value "$src" LSMinimumSystemVersion)
  if [ -n "$min" ] && ! os_at_least "$min"; then
    skip "${label}：需要 macOS $min 或更新（当前 ${os_version}），升级系统后再运行一次"
    return 0
  fi
  # 已经装好的软件一律不动（不管版本新旧），只有程序文件缺失的坏软件才重装
  if app_installed "$name"; then
    skip_installed "$label" "$new_v"
    return 0
  fi
  [ -d "$target" ] && echo "   已有的 $name 已损坏（找不到程序文件），重新安装"
  stage="/Applications/.${name}.oneclick-$$"
  CUR_STAGE="$stage"
  if [ "$mode" = "move" ] && $SUDO mv "$src" "$stage" 2>/dev/null; then
    :
  elif ! $SUDO ditto "$src" "$stage"; then
    $SUDO rm -rf "$stage" 2>/dev/null; CUR_STAGE=""
    bad "${label}：复制到“应用程序”失败（磁盘空间不够？）"
    return 1
  fi
  $SUDO xattr -dr com.apple.quarantine "$stage" 2>/dev/null
  if [ -d "$target" ]; then
    # 只在它正在运行时才去关，避免弹出“找不到应用”的对话框
    if pgrep -f "$target/Contents/MacOS/" >/dev/null 2>&1; then
      echo "   正在关闭正在运行的旧版…"
      osascript -e "tell application \"$target\" to quit" >/dev/null 2>&1
      sleep 3
      pkill -f "$target/Contents/MacOS/" >/dev/null 2>&1
      sleep 1
    fi
    if ! retire_app "$target"; then
      $SUDO rm -rf "$stage" 2>/dev/null; CUR_STAGE=""
      bad "${label}：损坏的旧版本移不走。请在“系统设置 → 隐私与安全性 → App 管理”里打开“终端”，或手动把“应用程序”里的 ${name} 拖到废纸篓，再运行一次"
      return 1
    fi
  fi
  if ! $SUDO mv "$stage" "$target" 2>/dev/null; then
    $SUDO rm -rf "$stage" 2>/dev/null; CUR_STAGE=""
    bad "${label}：放进“应用程序”失败"
    return 1
  fi
  CUR_STAGE=""
  ok "$label $new_v → /Applications/$name"
}

# 从 dmg 安装：挂载 → 复制里面的 .app → 卸载
install_dmg() {
  local label="$1" file="$2" min_os="$3" mnt app found=0 t=$SECONDS verify="-verify"
  echo ""
  echo "▶ $label"
  if ! os_at_least "$min_os"; then
    skip "${label}：需要 macOS $min_os 或更新（当前 ${os_version}），升级系统后再运行一次"
    return
  fi
  if ! file_ok "$file"; then bad "${label}：安装包缺失或损坏（${file}）"; return; fi
  # 这个文件已经用 SHA256 校验过，就不让 hdiutil 再把整个 dmg 读一遍做校验
  case "$good_files" in *"|$file|"*) verify="-noverify" ;; esac
  mnt=$(mktemp -d "$WORK/mnt.XXXXXX")
  # yes 用来自动同意少数 dmg 自带的许可协议
  if ! yes 2>/dev/null | hdiutil attach "$verify" -nobrowse -readonly -noautoopen -noautofsck -mountpoint "$mnt" "$PKG/$file" >/dev/null 2>&1; then
    rmdir "$mnt" 2>/dev/null
    bad "${label}：打不开安装包"
    return
  fi
  for app in "$mnt"/*.app; do
    [ -d "$app" ] || continue
    found=1
    place_app "$label" "$app"
  done
  [ "$found" = 1 ] || bad "${label}：安装包里没找到应用程序"
  hdiutil detach "$mnt" -quiet >/dev/null 2>&1 || hdiutil detach "$mnt" -force -quiet >/dev/null 2>&1
  rmdir "$mnt" 2>/dev/null
  echo "   $(elapsed $t)"
}

# 从 zip 安装：解压到临时目录 → 移动 .app → 删掉临时目录
install_zip() {
  local label="$1" file="$2" min_os="$3" app_name="${4:-}" tmp app found=0 t=$SECONDS
  echo ""
  echo "▶ $label"
  # 已装好就不必先解压整个压缩包
  if [ -n "$app_name" ] && app_installed "$app_name"; then
    skip_installed "$label" ""
    return
  fi
  if ! os_at_least "$min_os"; then
    skip "${label}：需要 macOS $min_os 或更新（当前 ${os_version}），升级系统后再运行一次"
    return
  fi
  if ! file_ok "$file"; then bad "${label}：安装包缺失或损坏（${file}）"; return; fi
  tmp=$(mktemp -d "$WORK/zip.XXXXXX")
  if ! ditto -x -k "$PKG/$file" "$tmp"; then
    rm -rf "$tmp"
    bad "${label}：解压失败"
    return
  fi
  for app in "$tmp"/*.app; do
    [ -d "$app" ] || continue
    found=1
    place_app "$label" "$app" move
  done
  [ "$found" = 1 ] || bad "${label}：压缩包里没找到应用程序"
  rm -rf "$tmp"
  echo "   $(elapsed $t)"
}

# Kimi Code 命令行：按官方安装脚本的做法放到 ~/.kimi-code/bin/kimi 并加进 PATH
KIMI_FILE="kimi-code-2.3.3-darwin-x64.tar.gz"
KIMI_SHA="f0103e2d5605acb488708b05d39a5b3a4280bf2cbfa7a03da42b696d21b00a25"
install_kimi() {
  local label="Kimi Code（命令行）" dir="$HOME/.kimi-code" tmp bin rc line
  echo ""
  echo "▶ $label"
  # 已经装了能用的 kimi（不管版本、不管装在哪）就不动
  for bin in "$dir/bin/kimi" /usr/local/bin/kimi "$HOME/.local/bin/kimi"; do
    if [ -x "$bin" ] && "$bin" --version >/dev/null 2>&1; then
      skip "$label 已经装好（${bin}），保持不动"
      return
    fi
  done
  if ! file_ok "$KIMI_FILE"; then bad "${label}：安装包缺失或损坏（${KIMI_FILE}）"; return; fi
  tmp=$(mktemp -d "$WORK/kimi.XXXXXX")
  tar -xzf "$PKG/$KIMI_FILE" -C "$tmp" 2>/dev/null || { bad "${label}：解压失败"; return; }
  # 在解压出的文件里找校验值对得上的那个程序
  bin=""
  while IFS= read -r f; do
    if [ "$(shasum -a 256 "$f" | awk '{print $1}')" = "$KIMI_SHA" ]; then bin="$f"; break; fi
  done < <(find "$tmp" -type f -size +1M)
  [ -n "$bin" ] || { bad "${label}：程序校验不通过"; return; }
  mkdir -p "$dir/bin"
  # 走到这里说明原来的 kimi 不存在或已经坏了，留一份以防万一
  [ -f "$dir/bin/kimi" ] && cp "$dir/bin/kimi" "$dir/bin/kimi.bak"
  install -m 0755 "$bin" "$dir/bin/kimi" || { bad "${label}：复制失败"; return; }
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

# Windows 电脑上导出的 AI 数据（对话记录、记忆、技能、项目文件）放回各软件在 Mac 上的位置
# · Mac 上已有的同名文件不覆盖；同一块盘上用克隆复制，几乎不额外占空间
# · 登录凭据没有导出，各软件第一次打开时登录一次即可
import_ai_data() {
  local src="$HERE/AI数据" label="AI 数据（对话记录、记忆、技能）" id marker need_kb free_kb d name total missing f ref
  local t=$SECONDS
  echo ""
  echo "▶ $label"
  if [ ! -d "$src/home" ]; then skip "AI 数据：文件夹里没有，跳过"; return; fi
  id=$(head -n 1 "$src/EXPORT_ID" 2>/dev/null)
  marker="$HOME/.oneclick-ai-import-${id:-unknown}"
  if [ -f "$marker" ]; then skip "AI 数据 已经导入过（导出时间 ${id}），跳过"; return; fi
  need_kb=$(du -sk "$src/home" 2>/dev/null | awk '{print $1}')
  free_kb=$(df -k "$HOME" | awk 'NR==2 {print $4}')
  if [ -n "$need_kb" ] && [ -n "$free_kb" ] && [ "$free_kb" -lt $(( need_kb + 2097152 )) ]; then
    bad "AI 数据：磁盘空间不够（需要约 $(( need_kb / 1048576 + 2 ))GB），清理后再运行一次"
    return
  fi
  for d in "$src/home"/.[!.]*; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    mkdir -p "$HOME/$name"
    # -n 不覆盖已有文件；-c 用 APFS 克隆（不支持时自动改为普通复制）
    cp -Rpnc "$d/." "$HOME/$name/" 2>/dev/null
    # 从 U 盘拷来的文件权限是“所有人可读写”，对话记录只留给自己
    chmod -R go-rwx "$HOME/$name" 2>/dev/null
  done
  # 核对：每个文件都到位了才算成功
  total=0; missing=0
  while IFS= read -r f; do
    total=$((total + 1))
    [ -e "$HOME/${f#./}" ] || missing=$((missing + 1))
  done < <(cd "$src/home" && find . -type f)
  ref="$HOME/Documents/Windows AI 原配置（仅供参考）"
  if [ -d "$src/Windows原配置（仅供参考）" ] && [ ! -e "$ref" ]; then
    mkdir -p "$HOME/Documents" && ditto "$src/Windows原配置（仅供参考）" "$ref" 2>/dev/null
  fi
  if [ "$missing" -eq 0 ]; then
    date > "$marker"
    ok "AI 数据 ${total} 个文件 → ~/.claude、~/.codex、~/.grok、~/.gemini、~/.kimi-code、~/.dsh $(elapsed $t)"
  else
    bad "AI 数据：${total} 个文件里有 ${missing} 个没导入成功，再运行一次试试"
  fi
}

# ---------- 3. 逐个安装 ----------
# 参数：名称  安装包文件名  最低 macOS 版本（装的时候还会再按软件自己声明的最低版本检查一次）
dsh_dmg=$(cd "$PKG" && ls -1 deepseek-harness-*.dmg 2>/dev/null | head -n 1)
if [ -n "$dsh_dmg" ]; then
  install_dmg "DeepSeek Harness" "$dsh_dmg" 13
else
  echo ""
  echo "▶ DeepSeek Harness"
  bad "DeepSeek Harness：没找到安装包"
fi
install_kimi
install_dmg "Antigravity"         "Antigravity-2.26.0-Intel.dmg"     13
install_dmg "Antigravity IDE"     "Antigravity-IDE-2.5.5-Intel.dmg"  12
install_dmg "ChatGPT（含 Codex）" "ChatGPT-Codex-Intel.dmg"          13
install_dmg "Grok Bot"            "Grok-Bot-0.77.0-Intel.dmg"        12
install_zip "Claude"              "Claude-3.6556.2-Universal.zip"    13  "Claude.app"
install_dmg "v2rayN（节点软件）"  "v2rayN-7.25.6-Intel.dmg"          13.6
install_dmg "微信"                "WeChat-Universal.dmg"             12
# QQ 官方安装包有就装；没有（官网链接失效时）就在最后打开 App Store 的 QQ 页面
qq_dmg=$(cd "$PKG" && ls -1 QQ-*.dmg 2>/dev/null | head -n 1)
qq_from_store=0
if [ -n "$qq_dmg" ]; then
  install_dmg "QQ" "$qq_dmg" 11
elif [ -d "/Applications/QQ.app" ]; then
  echo ""
  echo "▶ QQ"
  skip "QQ 已经装好，跳过"
else
  echo ""
  echo "▶ QQ"
  skip "QQ：官网安装包暂时下载不了，结束后会打开 App Store 的 QQ 页面，点“获取”即可（需要联网）"
  qq_from_store=1
fi
import_ai_data

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
echo "· 各软件第一次打开时登录自己的账号（登录凭据没有从 Windows 导出，聊天类软件登录后记录会自动同步）。"
echo "· Windows 上的 AI 对话记录、记忆、技能已放回各软件目录；Windows 版的配置文件在 文稿/Windows AI 原配置（仅供参考）。"
echo "· DeepSeek Harness：设置 → 模型，填入 DeepSeek API 密钥。"
echo "· v2rayN：导入你的节点（订阅地址或分享链接）后开启系统代理，海外软件才能登录。"
echo "· 全过程记录在 桌面/一键安装日志.txt"
echo "· 总用时 $(( (SECONDS - START) / 60 )) 分 $(( (SECONDS - START) % 60 )) 秒"
echo "######## $(date '+%Y-%m-%d %H:%M:%S') 结束 ########"
open /Applications
[ "$qq_from_store" = 1 ] && open "macappstore://apps.apple.com/cn/app/qq/id451108668" >/dev/null 2>&1
if [ -n "$fail_list" ]; then pause_exit 1; else pause_exit 0; fi
