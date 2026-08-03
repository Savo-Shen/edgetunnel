#!/usr/bin/env bash
# 一键同步上游 (cmliu/edgetunnel) 更新并推送到自己的 fork
# 用法: ./update.sh

set -euo pipefail

cd "$(dirname "$0")"

UPSTREAM_URL="https://github.com/cmliu/edgetunnel.git"
BRANCH="main"

info()  { printf '\033[36m==> %s\033[0m\n' "$1"; }
ok()    { printf '\033[32m✔  %s\033[0m\n' "$1"; }
warn()  { printf '\033[33m!  %s\033[0m\n' "$1"; }
die()   { printf '\033[31m✘  %s\033[0m\n' "$1" >&2; exit 1; }

# 0. 基本检查
git rev-parse --git-dir >/dev/null 2>&1 || die "当前目录不是 git 仓库"

if ! git remote get-url upstream >/dev/null 2>&1; then
  info "未配置 upstream，正在添加: $UPSTREAM_URL"
  git remote add upstream "$UPSTREAM_URL"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
  warn "当前分支是 $CURRENT_BRANCH，正在切换到 $BRANCH"
  git checkout "$BRANCH"
fi

# 1. 有未提交改动就先停下，避免合并时丢东西
if ! git diff --quiet || ! git diff --cached --quiet; then
  git status --short
  die "有未提交的改动，请先 commit 或 stash 后再运行"
fi

# 2. 拉取上游
info "拉取上游更新..."
git fetch upstream --prune

BEFORE="$(git rev-parse HEAD)"
if [ "$(git rev-parse HEAD)" = "$(git rev-parse "upstream/$BRANCH")" ]; then
  ok "已经是最新版本，无需更新"
  exit 0
fi

info "上游新增提交："
git --no-pager log --oneline HEAD.."upstream/$BRANCH" | head -20

# 3. 合并
info "合并 upstream/$BRANCH ..."
if ! git merge --no-edit "upstream/$BRANCH"; then
  warn "出现冲突，冲突文件如下："
  git diff --name-only --diff-filter=U
  cat <<'EOF'

请手动解决冲突后执行：
  git add <文件>
  git commit
  git push origin main

放弃本次合并：
  git merge --abort

提示：README.md / CHANGELOG / _worker.js 这类上游文件，
直接用上游版本即可： git checkout --theirs <文件>
（wrangler.toml 里的 name = "edgetunnel" 是本地个性化配置，需要保留）
EOF
  exit 1
fi

AFTER="$(git rev-parse HEAD)"
info "本次变更："
git --no-pager diff --stat "$BEFORE" "$AFTER"

# 4. 推送
info "推送到 origin/$BRANCH ..."
git push origin "$BRANCH"

ok "更新完成"
echo
echo "如果是用 wrangler 手动部署，接着执行： npx wrangler deploy"
echo "如果 Workers 已绑定 GitHub 自动部署，push 后会自动构建。"
