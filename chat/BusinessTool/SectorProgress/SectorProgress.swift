//
//  SectorProgress.swift
//  SectorProgress
//
//  Created by 陈健 on 2019/2/15.
//  Copyright © 2019年 陈健. All rights reserved.
//

import UIKit

class SectorProgress: UIView {
    var progress: CGFloat = 0.0 {
        didSet {
            shapLayer.strokeStart = progress
        }
    }
    var strokeColor: CGColor = UIColor.init(red: 234 / 255, green: 246 / 255, blue: 1, alpha: 1).cgColor {
        didSet {
            shapLayer.strokeColor = strokeColor
        }
    }
    private let shapLayer: CAShapeLayer
    override init(frame: CGRect) {
        shapLayer = CAShapeLayer.init()
        super.init(frame: frame)
        shapLayer.frame = CGRect.init(x: 0, y: 0, width: frame.size.width, height: frame.size.height)
        self.layer.addSublayer(shapLayer)
        self.backgroundColor = UIColor.clear
        shapLayer.backgroundColor = UIColor.clear.cgColor

        shapLayer.lineWidth = self.frame.size.width * 0.5
        shapLayer.fillColor = UIColor.clear.cgColor
        shapLayer.strokeColor = self.strokeColor
        
        let path = UIBezierPath.init(arcCenter: CGPoint.init(x: self.bounds.size.width * 0.5, y: self.bounds.size.width * 0.5), radius: self.frame.size.width * 0.5 * 0.5, startAngle: -CGFloat(Double.pi * 0.5), endAngle: CGFloat(Double.pi * 3 / 2), clockwise: true)
        shapLayer.path = path.cgPath
    }
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}










