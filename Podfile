# Uncomment the next line to define a global platform for your project

##忽略.cocoapods中多个specs源引起的警告问题
install! 'cocoapods', :warn_for_unused_master_specs_repo => false

platform :ios, '15.0'
use_frameworks!
inhibit_all_warnings!
target 'chat' do
  #Base
  pod 'AspectsV1.4.2'
  pod 'SwifterSwift'
  pod 'SnapKit'
  pod 'SwiftyJSON'
  pod 'MJRefresh'
  pod 'Toast-Swift'
  pod 'Moya/RxSwift'
  pod 'Kingfisher'
  pod 'RxSwift'
  pod 'RxCocoa'
  pod 'Moya'
  pod 'GDPerformanceView-Swift',  :configurations => ['Debug']
  pod 'IQKeyboardManagerSwift'
  pod 'TSVoiceConverter'
  pod 'AFNetworking'
  pod 'ReachabilitySwift', '~> 5.0.0'
  pod 'MBProgressHUD', '~> 1.2.0'
  pod 'KeychainAccess', '~> 4.2.2'
  pod 'IDMPhotoBrowser', '~> 1.11.3'
  pod 'RTRootNavigationController', '~> 0.8.0'
  pod 'Lantern', '~> 1.1.2'
  pod 'CryptoSwift', '~> 1.5.1'
  pod 'GKNavigationBarSwift', '~> 1.3.1'
  pod 'KeychainAccess', '~> 4.2.2'
#  pod 'AMLeaksFinder', '~> 2.1.5'
  
  #友盟推送  UMCCommonLog 日志库（调试），开发阶段进行调试SDK及相关功能使用，可在发布 App 前移除
  pod 'UMCCommonLog'
  pod 'UMCommon', '~> 7.3.0'
  pod 'UMDevice', '~> 1.2.0'
  pod 'UMPush', '~> 3.3.1'
  
  #Business
  pod 'Starscream'
  pod 'AliyunOSSiOS', :git => 'https://github.com/aliyun/aliyun-oss-ios-sdk.git/'
#  pod 'WebViewJavascriptBridge'
  pod 'Bugly', '2.6.1'
  pod 'WCDB.swift'
  pod 'SwiftProtobuf'
  pod 'Parchment'
  pod 'NextGrowingTextView','~> 1.6.1'
  pod 'QRCodeReader.swift'
  pod 'TZImagePickerController'
  pod 'SectionIndexView'
  pod 'dsBridge', '~> 3.0.6'
  #mydao
  pod 'Masonry'
  pod 'YYModel'
  pod 'YYText'
  pod 'FMDB', '~> 2.7.5'
  pod 'SDWebImage'
  pod 'YYWebImage'
  pod 'JKBigInteger', '~> 0.0.1'
  pod 'BL_IPTool', :git => 'https://github.com/bolee/BL_IPTool.git'
  pod 'SAMKeychain'
  pod 'WebViewJavascriptBridge'
  
  # Web3 - Ethereum blockchain interaction
  pod 'web3swift' #, '~> 3.0.0'
  pod 'Mixpanel-swift', '~> 3.1'
  pod 'MJExtension','~> 3.0.15.1'
  pod 'ReactiveObjC'
  target 'chatTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'chatUITests' do
    # Pods for testing
  end

end

post_install do |installer|
      # 修复 WCDB.swift TimedQueue 上游 bug：`map[key] = list.startIndex`（恒为 0），
      # 队列里有多个 handle 时 remove/reQueue 会错删元素，list 清空后 map 仍残留 key，
      # 下次 `list.remove(at: 0)` 在空数组上越界 → Swift _assertionFailure 闪退
      # （崩溃栈：ContiguousArray.remove(at:) ← WCDBSwift ← DBManager 插入消息）。
      # 修改已直接作用于 Pods/ 源码，pod install 重装后会还原，这里自动重新打补丁（幂等）。
      timed_queue_path = File.join(installer.sandbox.root, 'WCDB.swift/swift/source/util/TimedQueue.swift')
      if File.exist?(timed_queue_path)
          timed_queue = File.read(timed_queue_path)
          patched = timed_queue.gsub('map[key] = list.startIndex', 'map[key] = list.index(before: list.endIndex)')
          patched = patched.gsub(
              "        guard let index = map.index(forKey: key) else {\n            return\n        }\n        list.remove(at: map[index].value)",
              "        guard let index = map.index(forKey: key) else {\n            return\n        }\n        let listIndex = map[index].value\n        if listIndex < list.count {\n            list.remove(at: listIndex)\n        }")
          patched = patched.gsub(
              "        if let index = map.index(forKey: key) {\n            list.remove(at: map[index].value)",
              "        if let index = map.index(forKey: key) {\n            let listIndex = map[index].value\n            if listIndex < list.count {\n                list.remove(at: listIndex)\n            }")
          if patched != timed_queue
              File.write(timed_queue_path, patched)
              puts "[WCDB] Patched TimedQueue.swift (upstream bug fix)"
          end
      end

      # 修复 Lantern 转场快照：视图未布局（bounds 为 0）时
      # UIGraphicsBeginImageContextWithOptions 会 NSAssert 闪退（主线程 SIGABRT）。
      lantern_path = File.join(installer.sandbox.root, 'Lantern/Sources/Lantern/LanternAnimatedTransitioning.swift')
      if File.exist?(lantern_path)
          lantern = File.read(lantern_path)
          patched_lantern = lantern.gsub(
              "    public func fastSnapshot(with view: UIView) -> UIView? {\n        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)",
              "    public func fastSnapshot(with view: UIView) -> UIView? {\n        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }\n        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)")
          patched_lantern = patched_lantern.gsub(
              "    public func snapshot(with view: UIView) -> UIView? {\n        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)",
              "    public func snapshot(with view: UIView) -> UIView? {\n        guard view.bounds.width > 0, view.bounds.height > 0 else { return nil }\n        UIGraphicsBeginImageContextWithOptions(view.bounds.size, false, UIScreen.main.scale)")
          if patched_lantern != lantern
              File.write(lantern_path, patched_lantern)
              puts "[Lantern] Patched LanternAnimatedTransitioning.swift (zero-size snapshot guard)"
          end
      end

      # 修复 YYText 的光标定位：`a < b < (cond ? x : y)` 是链式比较（C 里等价于 (a<b) < ...），
      # 结果只会是 0 或 1，导致点击 emoji / 组合字符附近时光标位置错乱，同时触发
      # "Chained comparison 'X < Y < Z' does not behave the same as a mathematical expression" 告警。
      yylayout_path = File.join(installer.sandbox.root, 'YYText/YYText/Component/YYTextLayout.m')
      if File.exist?(yylayout_path)
          yylayout = File.read(yylayout_path)
          patched_yylayout = yylayout.gsub(
              /position = fabs\(left - point\.([xy])\) < fabs\(right - point\.\1\) < \(right \? prev : next\);/,
              'position = (fabs(left - point.\1) < fabs(right - point.\1)) ? prev : next;')
          if patched_yylayout != yylayout
              File.write(yylayout_path, patched_yylayout)
              puts "[YYText] Patched YYTextLayout.m (chained comparison -> ternary)"
          end
      end

      # 修复 DT_TOOLCHAIN_DIR 问题
      installer.pods_project.targets.each do |target|
          target.build_configurations.each do |config|
          xcconfig_path = config.base_configuration_reference.real_path
          xcconfig = File.read(xcconfig_path)
          xcconfig_mod = xcconfig.gsub(/DT_TOOLCHAIN_DIR/, "TOOLCHAIN_DIR")
          File.open(xcconfig_path, "w") { |file| file << xcconfig_mod }
          end
      end
      
      # 确保每个 Pod framework 都把自己的 PrivacyInfo.xcprivacy 打进 Resources 阶段。
      #
      # 🔴 原来的写法只在「文件不存在」时才补 —— 而 `Pods/<Pod>/PrivacyInfo.xcprivacy`
      #    是随仓库提交的（文件早就存在），于是 `next` 直接跳过，**从来没往 Pods.xcodeproj
      #    里加过 fileRef / Resources 条目** ⇒ 构建出来的 framework 里根本没有清单，
      #    App Store 以「缺少隐私清单」拒审（`sh verify_privacy_manifest.sh` 第 ③ 项报错）。
      #    现在改成：文件缺了就写模板，但**无论文件在不在，都补齐工程引用**。
      #
      # 本机 rvm 的 ruby 跑不起来（x86 二进制）时 `pod install` 用不了，
      # 可以先跑 /usr/bin/python3 scripts/patch_pods_privacy_manifests.py 达到同样效果。
      template_path = File.join(__dir__, 'app_privacy_manifest_fixer', 'Templates', 'FrameworkTemplate.xcprivacy')
      template_content = File.read(template_path)
      pods_root = installer.sandbox.root

      # framework target 名和 Pod 目录名可能对不上（模块名 vs Pod 名），按「去掉非字母数字后相等」匹配
      norm = lambda { |s| s.to_s.downcase.gsub(/[^a-z0-9]/, '') }
      pod_dirs = Dir.children(pods_root).select { |d| File.directory?(File.join(pods_root, d)) }
      # 模块名和 Pod 目录名差得比较远的几个（normalize 匹配不到时兜底）
      dir_overrides = { 'wcdboptimizedsqlcipher' => 'WCDBOptimizedSQLCipher', 'sqliterk' => 'SQLiteRepairKit' }

      installer.pods_project.targets.each do |target|
          next unless target.respond_to?(:product_type) && target.product_type == 'com.apple.product-type.framework'
          next if target.name.start_with?('Pods-')

          res_phase = target.resources_build_phase
          next unless res_phase

          # Pod 自己已经带了清单（如 IQKeyboardManagerSwift / Kingfisher）⇒ 不重复加
          already = res_phase.files.any? do |f|
              f.file_ref && f.file_ref.path.to_s.include?('PrivacyInfo.xcprivacy')
          end
          next if already

          pod_dir_name = dir_overrides[target.name.downcase]
          pod_dir_name ||= pod_dirs.find { |d| norm.call(d) == norm.call(target.name) }
          pod_dir_name ||= pod_dirs.find { |d| norm.call(d).start_with?(norm.call(target.name)) || norm.call(target.name).start_with?(norm.call(d)) }
          next unless pod_dir_name

          privacy_file = File.join(pods_root, pod_dir_name, 'PrivacyInfo.xcprivacy')
          unless File.exist?(privacy_file)
              puts "[Privacy] Adding PrivacyInfo.xcprivacy to #{pod_dir_name}"
              File.write(privacy_file, template_content)
          end

          rel_path = File.join(pod_dir_name, 'PrivacyInfo.xcprivacy')
          # 复用已有引用（pod install 幂等），没有再新建
          file_ref = installer.pods_project.main_group.recursive_children.find do |c|
              c.isa == 'PBXFileReference' && c.path == rel_path
          end
          file_ref ||= installer.pods_project.new_file(privacy_file)
          file_ref.include_in_index = '1'
          res_phase.add_file_reference(file_ref)
          puts "[Privacy] Linked #{rel_path} into #{target.name} Resources"
      end
  end
