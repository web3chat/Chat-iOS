#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
把 iOS 崩溃日志（.ips）用本地 dSYM 符号化成「函数名 + 文件:行号」。

为什么要这个脚本：
  Xcode / 各种分析工具经常报 "chat: NO_CRASH_STACK" 或「没有详情」，
  原因是它们找的是 `chat` 这个镜像的符号，而实际可能：
    - 本地 Debug 包用的是 Xcode 16+ 的 Debug Dylib 结构，代码在 `chat.debug.dylib` 里；
    - 或者崩溃来自打包/归档的 Release 包，符号在 Archives 里的 `chat.app.dSYM`。
  直接用 atos + 正确的 dSYM 就能还原函数名和行号。

用法：
    python3 scripts/symbolicate_crash.py ~/Desktop/chat-2026-09-18-xxxx.ips
    python3 scripts/symbolicate_crash.py crash.ips --dsym /path/to/chat.app.dSYM

不传 --dsym 时会自动在这些位置找：
    ~/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphoneos/*.app.dSYM
    ~/Library/Developer/Xcode/Archives/**/*.xcarchive/dSYMs/*.app.dSYM
"""
import argparse
import glob
import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")


def load_ips(path):
    """新版 .ips 是「第 1 行 header JSON + 第 2 行起 payload JSON」，老版是一整份 JSON。"""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        raw = f.read()
    lines = raw.split("\n")
    header = {}
    payload = None
    for start in (i for i, line in enumerate(lines) if line.strip().startswith("{")):
        try:
            parsed = json.loads("\n".join(lines[start:]))
        except Exception:
            continue
        if isinstance(parsed, dict) and "threads" in parsed:
            payload = parsed
            break
        if isinstance(parsed, dict) and not header:
            header = parsed
    return header, payload


def find_dsyms(explicit):
    if explicit:
        return [explicit]
    out = []
    out += glob.glob(f"{HOME}/Library/Developer/Xcode/DerivedData/*/Build/Products/*-iphoneos/*.app.dSYM")
    out += glob.glob(f"{HOME}/Library/Developer/Xcode/Archives/**/*.xcarchive/dSYMs/*.app.dSYM", recursive=True)
    return sorted(set(out))


def binary_in_dsym(dsym, image_name):
    """在 dSYM 里找与镜像同名的可执行文件（chat / chat.debug.dylib …）"""
    path = os.path.join(dsym, "Contents", "Resources", "DWARF", image_name)
    return path if os.path.exists(path) else None


def dwarf_uuid(binary):
    try:
        out = subprocess.check_output(["dwarfdump", "--uuid", binary], stderr=subprocess.DEVNULL)
        return out.decode().split("UUID:")[-1].strip()
    except Exception:
        return "?"


def symbolicate(binary, base, addresses):
    """一次 atos 调用把一批地址符号化，返回 {address: 'symbol  file:line'}"""
    if not addresses:
        return {}
    cmd = ["atos", "-arch", "arm64", "-o", binary, "-l", hex(base)] + [hex(a) for a in addresses]
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    except Exception as exc:  # noqa: BLE001
        return {a: f"<atos 失败: {exc}>" for a in addresses}
    symbols = {}
    for address, line in zip(addresses, out.stdout.split("\n")):
        symbols[address] = line.strip()
    if out.stderr.strip():
        print("   ⚠️ atos stderr:", out.stderr.strip()[:300], file=sys.stderr)
    return symbols


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("ips", help="崩溃日志 .ips 文件路径")
    parser.add_argument("--dsym", help="指定 dSYM（不填则自动搜索本地 DerivedData / Archives）")
    args = parser.parse_args()

    header, payload = load_ips(args.ips)
    if payload is None:
        print("❌ 这个文件里没找到 payload（threads）。确认给的是 .ips 原文，不是工具生成的摘要。")
        return 1

    print("=" * 78)
    print("App     :", header.get("app_name"), header.get("app_version"), header.get("bundleID"))
    print("系统     :", header.get("os_version"))
    print("时间     :", header.get("timestamp"))
    print("异常     :", json.dumps(header.get("exception", {}), ensure_ascii=False))
    if header.get("termination"):
        print("终止原因 :", json.dumps(header["termination"], ensure_ascii=False))
    if header.get("asi"):
        print("补充信息 :", json.dumps(header["asi"], ensure_ascii=False)[:500])
    if header.get("lastExceptionBacktrace"):
        print("（有 ObjC 异常回溯，见文件正文）")

    images = payload.get("usedImages", [])
    dsyms = find_dsyms(args.dsym)
    print("本地 dSYM:", *dsyms, sep="\n   - ")

    faulting = payload.get("faultingThread")
    threads = payload.get("threads", [])
    order = ([faulting] if isinstance(faulting, int) and faulting < len(threads) else []) + \
            [i for i in range(len(threads)) if i != faulting]

    for index in order:
        thread = threads[index]
        frames = thread.get("frames", [])
        if not frames:
            continue
        triggered = thread.get("triggered")
        title = f"Thread {index}" + ("  ★崩溃线程" if triggered else "")
        name = thread.get("name") or thread.get("queue")
        print("\n" + "=" * 78)
        print(f"{title}{'  ' + name if name else ''}")
        print("=" * 78)

        # 按镜像分组符号化（同一次 atos 调用处理一个镜像的所有帧）
        by_image = {}
        for i, frame in enumerate(frames):
            by_image.setdefault(frame.get("imageIndex"), []).append((i, frame))

        symbolised = {}
        image_info = {}
        for image_index, items in by_image.items():
            if image_index is None or image_index >= len(images):
                continue
            image = images[image_index]
            image_info[image_index] = image
            name = image.get("name", "?")
            binary = None
            for dsym in dsyms:
                binary = binary_in_dsym(dsym, name)
                if binary:
                    break
            if not binary:
                continue
            base = image.get("base", 0)
            addresses = [base + item[1].get("imageOffset", 0) for item in items]
            symbols = symbolicate(binary, base, addresses)
            for (i, _), address in zip(items, addresses):
                symbolised[i] = symbols.get(address, "")

        for i, frame in enumerate(frames):
            image = image_info.get(frame.get("imageIndex"), {})
            image_name = image.get("name", "?")
            offset = frame.get("imageOffset", 0)
            line = f"{i:>3} {image_name:<28} {image_name}+{offset}"
            resolved = symbolised.get(i, "")
            if resolved and "?" not in resolved[:1]:
                line = f"{i:>3} {image_name:<28} {resolved}"
            elif frame.get("symbol"):
                line += f"   [{frame['symbol']}]"
            elif frame.get("sourceFile"):
                line += f"   [{frame['sourceFile']}:{frame.get('sourceLine', 0)}]"
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
