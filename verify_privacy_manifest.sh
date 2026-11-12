#!/bin/bash
#
# 隐私清单（PrivacyInfo.xcprivacy）发布前校验
#
# 为什么需要这个脚本：
#   * App 自己的清单必须在 chat.app 根目录且内容正确 —— 构建期脚本按「App 主二进制」做符号扫描，
#     而 Debug 构建的真实代码在 chat.debug.dylib 里，扫描结果为 0，会把清单里的
#     NSPrivacyAccessedAPITypes 裁成空数组；且脚本对「已存在」的清单一律跳过修复，错误会被固化。
#   * 每个内嵌的 .framework 都必须自带清单，否则 App Store 会以 ITMS-91053 拒审。
#
# 用法：
#   sh scripts/verify_privacy_manifest.sh <chat.app | xxx.xcarchive | xxx.ipa>
#
# 退出码：0 = 通过；1 = 有问题（原因见输出）

APP_PATH="${1:-}"

if [ -z "$APP_PATH" ]; then
    echo "用法：sh scripts/verify_privacy_manifest.sh <chat.app | xxx.xcarchive | xxx.ipa>"
    exit 1
fi

if [ ! -e "$APP_PATH" ]; then
    echo "❌ 路径不存在：$APP_PATH"
    exit 1
fi

TMP_DIR=""
cleanup() { if [ -n "$TMP_DIR" ]; then rm -rf "$TMP_DIR"; fi; }
trap cleanup EXIT

# ---------- 0. 定位 .app ----------
case "$APP_PATH" in
    *.app)
        APP="$APP_PATH"
        ;;
    *.xcarchive)
        APP=$(ls -d "$APP_PATH"/Products/Applications/*.app 2>/dev/null | head -1)
        ;;
    *.ipa)
        TMP_DIR=$(mktemp -d)
        if ! unzip -q "$APP_PATH" -d "$TMP_DIR"; then
            echo "❌ 无法解压 $APP_PATH"
            exit 1
        fi
        APP=$(ls -d "$TMP_DIR"/Payload/*.app 2>/dev/null | head -1)
        ;;
    *)
        echo "❌ 只支持 .app / .xcarchive / .ipa，收到：$APP_PATH"
        exit 1
        ;;
esac

if [ -z "$APP" ] || [ ! -d "$APP" ]; then
    echo "❌ 未能在 $APP_PATH 中找到 .app"
    exit 1
fi

FAIL=0
ok()   { echo "   ✅ $1"; }
warn() { echo "   ⚠️  $1"; }
fail() { echo "   ❌ $1"; FAIL=1; }

echo "🔍 校验目标：$APP"
echo

# ---------- 1. App 自己的清单 ----------
echo "① App bundle 根目录的清单"
MANIFEST="$APP/PrivacyInfo.xcprivacy"
DECLARED=""

if [ ! -f "$MANIFEST" ]; then
    fail "缺少 ${MANIFEST}（应由 chat/PrivacyInfo.xcprivacy 随 Copy Bundle Resources 打包进来）"
else
    if plutil -lint "$MANIFEST" >/dev/null 2>&1; then
        ok "存在且为合法 plist"
    else
        fail "plist 格式非法：$MANIFEST"
    fi

    DECLARED=$(plutil -extract NSPrivacyAccessedAPITypes json -o - "$MANIFEST" 2>/dev/null \
               | grep -oE "NSPrivacyAccessedAPICategory[A-Za-z]+" | sort -u)

    if [ -z "$DECLARED" ]; then
        fail "NSPrivacyAccessedAPITypes 是空的 —— 必备 API 声明缺失，会被判 ITMS-91053"
    else
        echo "      已声明：$(echo "$DECLARED" | tr '\n' ' ')"
    fi
fi
echo

# ---------- 2. 清单内容 ↔ 二进制实际使用 交叉核对 ----------
echo "② 清单内容 vs 二进制实际使用的 Required Reason API"
EXE="$APP/$(basename "$APP" .app)"
SYM_OUT=$(mktemp /tmp/privacy_sym.XXXXXX)

BINARIES="$EXE"
for d in "$APP"/*.debug.dylib; do
    [ -f "$d" ] && BINARIES="$BINARIES $d"
done

FOUND_BIN=0
for b in $BINARIES; do
    [ -f "$b" ] || continue
    FOUND_BIN=1
    nm -u "$b" 2>/dev/null >> "$SYM_OUT"
    nm "$b" 2>/dev/null >> "$SYM_OUT"
    strings "$b" 2>/dev/null >> "$SYM_OUT"
done

if [ "$FOUND_BIN" = "0" ]; then
    warn "未找到主可执行文件 ${EXE}，跳过交叉核对"
else
    check_cat() {
        cat_name="$1"
        cat_re="$2"
        used=0
        declared=0
        grep -Eq "$cat_re" "$SYM_OUT" && used=1
        echo "$DECLARED" | grep -q "$cat_name" && declared=1

        if [ "$used" = "1" ] && [ "$declared" = "0" ]; then
            fail "${cat_name}：二进制有使用但清单未声明（漏声明 → ITMS-91053）"
        elif [ "$used" = "0" ] && [ "$declared" = "1" ]; then
            warn "${cat_name}：清单声明了但二进制未扫描到使用（多声明，需核实是否真用得上）"
        elif [ "$used" = "1" ]; then
            ok "${cat_name}：已声明且确有使用"
        else
            ok "${cat_name}：未使用、未声明（一致）"
        fi
    }

    check_cat "NSPrivacyAccessedAPICategoryFileTimestamp" \
        "_stat|_fstat|_lstat|_fstatat|_getattrlist|_NSFileCreationDate|_NSFileModificationDate|_NSURLCreationDateKey|NSURLContentModificationDateKey"
    check_cat "NSPrivacyAccessedAPICategorySystemBootTime" \
        "_mach_absolute_time|systemUptime"
    check_cat "NSPrivacyAccessedAPICategoryDiskSpace" \
        "statfs|statvfs|NSFileSystemFreeSize|NSFileSystemSize|NSURLVolumeAvailableCapacity|NSURLVolumeTotalCapacity"
    check_cat "NSPrivacyAccessedAPICategoryActiveKeyboards" \
        "activeInputModes"
    check_cat "NSPrivacyAccessedAPICategoryUserDefaults" \
        "NSUserDefaults"
fi
rm -f "$SYM_OUT"
echo

# ---------- 3. 内嵌 framework 的清单 ----------
echo "③ 内嵌 framework 的清单"
FW_DIR="$APP/Frameworks"
MISSING=""
NESTED=""
COUNT=0

if [ ! -d "$FW_DIR" ]; then
    warn "没有 Frameworks 目录，跳过"
else
    for fw in "$FW_DIR"/*.framework; do
        [ -d "$fw" ] || continue
        COUNT=$((COUNT + 1))
        name=$(basename "$fw" .framework)

        if [ -f "$fw/PrivacyInfo.xcprivacy" ]; then
            plutil -lint "$fw/PrivacyInfo.xcprivacy" >/dev/null 2>&1 || \
                warn "${name}：清单 plist 格式非法"
            continue
        fi

        # 部分 SDK 把清单放在资源包内（Apple 建议放在 framework bundle 根目录）
        nested=$(find "$fw" -maxdepth 3 -name "PrivacyInfo.xcprivacy" 2>/dev/null | head -1)
        if [ -n "$nested" ]; then
            NESTED="$NESTED $name"
        else
            MISSING="$MISSING $name"
        fi
    done

    echo "      共检查 $COUNT 个 framework"
    if [ -n "$MISSING" ]; then
        fail "缺少清单：$MISSING"
    else
        ok "所有 framework 都有清单"
    fi
    if [ -n "$NESTED" ]; then
        warn "清单在资源包内、不在 framework 根目录（建议用 Xcode → Organizer → Generate Privacy Report 核实是否被收录）：$NESTED"
    fi
fi
echo

# ---------- 结论 ----------
if [ "$FAIL" = "1" ]; then
    echo "❌ 校验未通过，请修复上方 ❌ 项后再打包上传"
    exit 1
fi

echo "✅ 校验通过"
exit 0
