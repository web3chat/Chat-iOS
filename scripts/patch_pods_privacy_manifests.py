#!/usr/bin/env python3
"""把 Pods/ 下已有（但没被 Xcode 打包）的 PrivacyInfo.xcprivacy 挂到每个 Pod framework 的 Resources 阶段。

背景
----
`Pods/<Pod>/PrivacyInfo.xcprivacy` 已经随仓库提交（见 commit「隐私文件新增」），
但 Pods.xcodeproj 里没有对应的 fileRef / Resources 条目 ⇒ 构建时不会被拷进
`chat.app/Frameworks/<Pod>.framework/`，App Store 校验会以
「ITMS-91061 / 缺少隐私清单」拒审（`sh verify_privacy_manifest.sh` 的第 ③ 项就是这个）。

为什么用脚本改 Pods.xcodeproj，而不是 `pod install`
------------------------------------------------
本机 rvm 的 ruby 是 x86 二进制（`Bad CPU type in executable`），`pod install` 跑不起来；
Pods.xcodeproj 本身是提交进仓库的，所以直接改它同样可以生效。
Podfile 的 post_install 已经同步修好，换台机器 / 以后能跑 pod install 时结果一致。

幂等：重复执行不会重复插入。

用法：
    /usr/bin/python3 scripts/patch_pods_privacy_manifests.py [--dry-run]
"""

import hashlib
import os
import re
import sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PODS_DIR = os.path.join(REPO, "Pods")
PBXPROJ = os.path.join(PODS_DIR, "Pods.xcodeproj", "project.pbxproj")
MANIFEST_NAME = "PrivacyInfo.xcprivacy"

# 模块名和 Pod 目录名对不上的几个（framework 名 -> Pods/ 下的目录）
DIR_OVERRIDES = {
    "sqlcipher": "WCDBOptimizedSQLCipher",
    "sqliterk": "SQLiteRepairKit",
}


def normalize(name):
    return re.sub(r"[^a-z0-9]", "", name.lower())


def make_id(seed):
    return hashlib.md5(seed.encode()).hexdigest().upper()[:32]


def resolve_manifest_dir(target_name, manifest_dirs):
    """返回该 target 对应的 Pods/<dir>（里面确实有 PrivacyInfo.xcprivacy）。"""
    override = DIR_OVERRIDES.get(target_name.lower())
    if override and os.path.exists(os.path.join(PODS_DIR, override, MANIFEST_NAME)):
        return override

    key = normalize(target_name)
    for d in manifest_dirs:
        if normalize(d) == key:
            return d
    for d in manifest_dirs:
        if normalize(d).startswith(key) or key.startswith(normalize(d)):
            return d
    return None


def main():
    dry_run = "--dry-run" in sys.argv

    if not os.path.exists(PBXPROJ):
        sys.exit("找不到 %s" % PBXPROJ)

    src = open(PBXPROJ, encoding="utf-8").read()

    manifest_dirs = sorted(
        d for d in os.listdir(PODS_DIR)
        if os.path.exists(os.path.join(PODS_DIR, d, MANIFEST_NAME))
    )

    # 每个 framework target：名字 + Resources 阶段 id
    targets = []
    for m in re.finditer(
        r"\n\t\t([0-9A-F]{32}) /\* ([^\n*]+) \*/ = \{\n\t\t\tisa = PBXNativeTarget;\n(.*?)\n\t\t\};",
        src,
        re.S,
    ):
        name, body = m.group(2), m.group(3)
        if '"com.apple.product-type.framework"' not in body:
            continue
        res = re.search(r"([0-9A-F]{32}) /\* Resources \*/,", body)
        if not res:
            continue
        targets.append((name, res.group(1)))

    build_file_inserts = []
    file_ref_inserts = []
    phase_files = {}
    patched, skipped, unmatched = [], [], []

    for name, phase_id in sorted(targets):
        # 该 Resources 阶段里已经有隐私清单（Pod 自己带了）⇒ 不动
        phase_match = re.search(
            r"\t\t%s /\* Resources \*/ = \{\n.*?files = \(\n(.*?)\t\t\t\);" % phase_id,
            src,
            re.S,
        )
        if phase_match and MANIFEST_NAME in phase_match.group(1):
            skipped.append(name)
            continue

        pod_dir = resolve_manifest_dir(name, manifest_dirs)
        if not pod_dir:
            unmatched.append(name)
            continue

        rel_path = "%s/%s" % (pod_dir, MANIFEST_NAME)
        build_id = make_id("buildfile:" + rel_path)
        ref_id = make_id("fileref:" + rel_path)

        if ref_id not in src:
            file_ref_inserts.append(
                "\t\t%s /* %s */ = {isa = PBXFileReference; includeInIndex = 1; "
                'lastKnownFileType = text.xml; name = %s; path = "%s"; '
                'sourceTree = SOURCE_ROOT; };\n' % (ref_id, MANIFEST_NAME, MANIFEST_NAME, rel_path)
            )
        if build_id not in src:
            build_file_inserts.append(
                "\t\t%s /* %s in Resources */ = {isa = PBXBuildFile; fileRef = %s /* %s */; };\n"
                % (build_id, MANIFEST_NAME, ref_id, MANIFEST_NAME)
            )
        phase_files.setdefault(phase_id, []).append(
            "\t\t\t\t%s /* %s in Resources */,\n" % (build_id, MANIFEST_NAME)
        )
        patched.append("%s <- Pods/%s" % (name, pod_dir))

    print("framework target 总数：%d" % len(targets))
    print("已有清单（跳过）：%d %s" % (len(skipped), sorted(skipped)))
    print("本次补挂：%d" % len(patched))
    for p in sorted(patched):
        print("   + %s" % p)
    if unmatched:
        print("⚠️ 没有匹配到 Pods 目录（需人工确认）：%s" % sorted(unmatched))

    if not (build_file_inserts or file_ref_inserts or phase_files):
        print("无需改动。")
        return

    out = src
    if build_file_inserts:
        out = out.replace(
            "/* Begin PBXBuildFile section */\n",
            "/* Begin PBXBuildFile section */\n" + "".join(sorted(build_file_inserts)),
            1,
        )
    if file_ref_inserts:
        out = out.replace(
            "/* Begin PBXFileReference section */\n",
            "/* Begin PBXFileReference section */\n" + "".join(sorted(file_ref_inserts)),
            1,
        )
    for phase_id, lines in phase_files.items():
        block = re.search(
            r"(\t\t%s /\* Resources \*/ = \{\n.*?files = \(\n)(.*?)(\t\t\t\);)" % phase_id,
            out,
            re.S,
        )
        if not block:
            continue
        out = out[: block.end(2)] + "".join(sorted(lines)) + out[block.end(2):]

    if dry_run:
        print("（--dry-run，未写入）")
        return

    open(PBXPROJ, "w", encoding="utf-8").write(out)
    print("已写入 %s" % PBXPROJ)


if __name__ == "__main__":
    main()
