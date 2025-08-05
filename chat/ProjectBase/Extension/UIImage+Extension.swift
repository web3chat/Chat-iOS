//
//  UIImage+Extension.swift
//  xls
//
//  Created by 陈健 on 2020/12/8.
//  Copyright © 2020 陈健. All rights reserved.
//

import Foundation

extension UIImage{
    
    /// 判断图片是否为空
    /// - Returns: bool值，图片是否为空判断结果
    func imageIsEmpty() -> Bool {
        guard let cgImage = self.cgImage,
              let dataProvider = cgImage.dataProvider else
        {
            return true
        }

        let pixelData = dataProvider.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        let imageWidth = Int(self.size.width)
        let imageHeight = Int(self.size.height)
        for x in 0..<imageWidth {
            for y in 0..<imageHeight {
                let pixelIndex = ((imageWidth * y) + x) * 4
                let r = data[pixelIndex]
                let g = data[pixelIndex + 1]
                let b = data[pixelIndex + 2]
                let a = data[pixelIndex + 3]
                if a != 0 {
                    if r != 0 || g != 0 || b != 0 {
                        return false
                    }
                }
            }
        }

        return true
    }
    
    func compress(bytesSize: Int) -> Data? {
        var data = self.jpegData(compressionQuality: 1)!
        guard data.count > bytesSize else { return data }
        
        var compression: CGFloat = 1
        var max: CGFloat = 1
        var min: CGFloat = 0
        
        for _ in 0..<6 {
            compression = (max + min) / 2
            data = self.jpegData(compressionQuality: compression)!
            if CGFloat(data.count) < CGFloat(bytesSize) * 0.9 {
                min = compression
            } else if data.count > bytesSize {
                max = compression
            } else {
                break
            }
        }
        
        guard data.count > bytesSize else { return data }
        
        var resultImage: UIImage = UIImage(data: data)!
        var lastDataLength = 0
        while data.count > bytesSize && data.count != lastDataLength {
            lastDataLength = data.count
            let ratio: CGFloat = CGFloat(bytesSize) / CGFloat(data.count)
            let size: CGSize = CGSize(width: Int(resultImage.size.width * sqrt(ratio)),
                                      height: Int(resultImage.size.height * sqrt(ratio)))
            UIGraphicsBeginImageContext(size)
            resultImage.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            resultImage = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()
            data = resultImage.jpegData(compressionQuality: compression)!
        }
        return data
    }
    
}


