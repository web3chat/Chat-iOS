# Uncomment the next line to define a global platform for your project

##忽略.cocoapods中多个specs源引起的警告问题
install! 'cocoapods', :warn_for_unused_master_specs_repo => false

platform :ios, '12.0'
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
  pod 'Bugly'
  pod 'WCDB.swift'
  pod 'SwiftProtobuf'
  pod 'Parchment'
  pod 'NextGrowingTextView','~> 1.6.1'
  pod 'QRCodeReader.swift'
  pod 'TZImagePickerController', '~> 3.6.8'
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
  target 'chatTests' do
    inherit! :search_paths
    # Pods for testing
  end

  target 'chatUITests' do
    # Pods for testing
  end

end
