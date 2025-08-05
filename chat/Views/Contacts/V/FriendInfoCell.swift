//
//  FriendInfoCell.swift
//  chat
//
//  Created by 王俊豪 on 2021/5/28.
//

import UIKit
import SnapKit

// 黑名单
class FriendInfoBlackListCell: UITableViewCell {
    
    var selectedBlock: (()->())?
    
    lazy var leftLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    lazy var rightLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    lazy var moreImageView: UIImageView = {
        let extractedExpr = #imageLiteral(resourceName: "cell_right_dot")
        let imageView = UIImageView.init(image: extractedExpr)
        return imageView
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        self.contentView.addSubview(self.leftLab)
        self.leftLab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(self.rightLab)
        self.rightLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-24)
            m.centerY.equalToSuperview()
        }
        
        self.contentView.addSubview(self.moreImageView)
        self.moreImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        let btn1 = UIButton.init(type: .custom)
        btn1.addTarget(self, action: #selector(clickServer), for: .touchUpInside)
        self.addSubview(btn1)
        btn1.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.leftLab.text = nil
        self.leftLab.attributedText = nil
        self.rightLab.text = nil
        self.rightLab.attributedText = nil
        DispatchQueue.main.async {
            self.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 0)
        }
    }
    
    func configure(with model: FriendInfoTextCellModel) {
        
        self.leftLab.text = model.leftString
        
        self.rightLab.text = model.rightString
        
        self.selectedBlock = model.selectedBlock
    }
    
    @objc private func clickServer() {
        self.selectedBlock?()
    }
}

// 服务器cell
class FriendInfoServerCell: UITableViewCell {
    
    var selectedBlock: NormalBlock?
    
    private lazy var serverNameLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        lab.numberOfLines = 0
        return lab
    }()
    
    private lazy var serverUrlLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_8A97A5, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var statusImageView: UIImageView = {
        let imageView = UIImageView.init(frame: CGRect.init(x: 0, y: 0, width: 10, height: 10))
        imageView.layer.cornerRadius = 5
        imageView.backgroundColor = Color_DD5F5F
        imageView.isHidden = true
        return imageView
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.serverNameLab.text = nil
        self.serverUrlLab.text = nil
        self.statusImageView.backgroundColor = Color_DD5F5F
    }
    
    private func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        
        let lab1 = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: "接收TA消息的服务器")
        lab1.numberOfLines = 2
        self.addSubview(lab1)
        lab1.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.centerY.equalToSuperview()
            m.width.equalTo(95)
        }
        
        self.addSubview(self.serverNameLab)
        self.serverNameLab.snp.makeConstraints { (m) in
            m.top.equalToSuperview().offset(12)
            m.right.equalToSuperview().offset(-39)
        }
        
        self.addSubview(self.statusImageView)
        self.statusImageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 10, height: 10))
            m.right.equalToSuperview().offset(-24)
            m.centerY.equalTo(serverNameLab)
        }
        
        self.addSubview(self.serverUrlLab)
        self.serverUrlLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-24)
            m.bottom.equalToSuperview().offset(-12)
            m.width.lessThanOrEqualTo(k_ScreenWidth-30-15-95-10-24)
        }
        
        let imageView = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        self.addSubview(imageView)
        imageView.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalToSuperview()
        }
        
        let btn1 = UIButton.init(type: .custom)
        btn1.addTarget(self, action: #selector(clickServer), for: .touchUpInside)
        self.addSubview(btn1)
        btn1.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        DispatchQueue.main.async {
            self.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 0)
        }
    }
    
    func configure(with model: FriendInfoServerCellModel) {
        
        self.serverNameLab.text = model.serverName
        
        self.serverUrlLab.text = model.serverUrlStr
        
        self.statusImageView.isHidden = model.serverUrlStr?.isEmpty != nil ? false : true
        
        self.statusImageView.backgroundColor = (model.isAvailable ?? false) ? Color_62DEAD : Color_DD5F5F
        
        self.selectedBlock = model.selectedBlock
    }
    
    @objc private func clickServer() {
        self.selectedBlock?()
    }
}

// 免打扰/置顶设置cell
class FriendInfoSettingCell: UITableViewCell {
    
    var isOnTopSwitchChangeBlock: BoolBlock?
    
    var isMuteSwitchChangeBlock: BoolBlock?
    
    var clickChatRecordBlock: NormalBlock?
    
    var clickChatFileBlock: NormalBlock?
    
    private lazy var isMuteSwitch: UISwitch = {
        let v = UISwitch()
        v.onTintColor = Color_Theme
        v.addTarget(self, action: #selector(isMuteSwitchChange(_:)), for: .valueChanged)
        return v
    }()
    
    private lazy var isOnTopSwitch: UISwitch = {
        let v = UISwitch()
        v.onTintColor = Color_Theme
        v.addTarget(self, action: #selector(inOnTopSwitchChange(_:)), for: .valueChanged)
        return v
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    private func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        
        let lab1 = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: "查找聊天记录")
        self.addSubview(lab1)
        lab1.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview()
            m.height.equalTo(50)
        }
        
        let imageView1 = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        self.addSubview(imageView1)
        imageView1.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(lab1)
        }
        
        let btn1 = UIButton.init(type: .custom)
        btn1.addTarget(self, action: #selector(clickChatRecord), for: .touchUpInside)
        self.addSubview(btn1)
        btn1.snp.makeConstraints { make in
            make.left.right.top.equalToSuperview()
            make.height.equalTo(50)
        }
        
        let lineV1 = UIView.init()
        lineV1.backgroundColor = Color_E6EAEE
        self.addSubview(lineV1)
        lineV1.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(lab1.snp.bottom)
        }
        
        let lab2 = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: "聊天文件")
        self.addSubview(lab2)
        lab2.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(lab1.snp.bottom)
            m.height.equalTo(50)
        }
        
        let imageView2 = UIImageView.init(image: #imageLiteral(resourceName: "cell_right_dot"))
        self.addSubview(imageView2)
        imageView2.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 4, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(lab2)
        }
        
        let btn2 = UIButton.init(type: .custom)
        btn2.addTarget(self, action: #selector(clickChatFile), for: .touchUpInside)
        self.addSubview(btn2)
        btn2.snp.makeConstraints { make in
            make.left.right.equalToSuperview()
            make.top.equalTo(lab1.snp.bottom)
            make.height.equalTo(50)
        }
        
        let lineV2 = UIView.init()
        lineV2.backgroundColor = Color_E6EAEE
        self.addSubview(lineV2)
        lineV2.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(lab2.snp.bottom)
        }
        
        let lab3 = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: "消息免打扰")
        self.addSubview(lab3)
        lab3.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(lab2.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.addSubview(isMuteSwitch)
        isMuteSwitch.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 40, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(lab3)
        }
        
        let lineV3 = UIView.init()
        lineV3.backgroundColor = Color_E6EAEE
        self.addSubview(lineV3)
        lineV3.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(lab3.snp.bottom)
        }
        
        let lab4 = UILabel.getLab(font: UIFont.systemFont(ofSize: 16), textColor: Color_24374E, textAlignment: .left, text: "置顶聊天")
        self.addSubview(lab4)
        lab4.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(lab3.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.addSubview(isOnTopSwitch)
        isOnTopSwitch.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 40, height: 20))
            m.right.equalToSuperview().offset(-15)
            m.centerY.equalTo(lab4)
        }
        
        DispatchQueue.main.async {
            self.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 0)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.isMuteSwitch.isOn = false
        self.isOnTopSwitch.isOn = false
    }
    
    func configure(with model: FriendInfoSwitchCellModel) {
        
        self.isMuteSwitch.isOn = model.isMuteNofification ?? false
        
        self.isOnTopSwitch.isOn = model.isOnTop ?? false
        
        self.isMuteSwitchChangeBlock = model.isMuteSwitchChangeBlock
        
        self.isOnTopSwitchChangeBlock = model.isOnTopSwitchChangeBlock
        
        self.clickChatRecordBlock = model.clickChatRecordBlock
        
        self.clickChatFileBlock = model.clickChatFileBlock
    }
    
    @objc private func isMuteSwitchChange(_ sender :UISwitch) {
        self.isMuteSwitchChangeBlock?(sender.isOn)
    }
    
    @objc private func inOnTopSwitchChange(_ sender :UISwitch) {
        self.isOnTopSwitchChangeBlock?(sender.isOn)
    }
    
    @objc private func clickChatRecord() {
        self.clickChatRecordBlock?()
    }
    
    @objc private func clickChatFile() {
        self.clickChatFileBlock?()
    }
}

// 员工信息cell
class FriendInfoTeamCell: UITableViewCell {
    var modelData : FriendInfoTeamCellModel?
    
    private lazy var usernameLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var organizationLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        lab.minimumScaleFactor = 0.5
        return lab
    }()
    
    private lazy var phoneView : UIView = {
        let view = UIView.init()
        return view
    }()
    
    private lazy var phoneLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var btnPhone: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_eye"), for: .normal)
        btn.setImage(#imageLiteral(resourceName: "icon_call"), for: .selected)
        btn.addTarget(self, action: #selector(callPhone(_:)), for: .touchUpInside)
        btn.enlargeClickEdge(12, 12, 12, 12)
        return btn
    }()
    
    private lazy var shortPhoneView : UIView = {
        let view = UIView.init()
        return view
    }()
    
    private lazy var shortPhoneLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var btnShortPhone: UIButton = {
        let btn = UIButton.init(type: .custom)
        btn.setImage(#imageLiteral(resourceName: "icon_eye"), for: .normal)
        btn.setImage(#imageLiteral(resourceName: "icon_call"), for: .selected)
        btn.addTarget(self, action: #selector(callShortPhone(_:)), for: .touchUpInside)
        btn.enlargeClickEdge(12, 12, 12, 12)
        return btn
    }()
    
    private lazy var emailLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var departmentLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    private lazy var positionLab: UILabel = {
        let lab = UILabel.getLab(font: UIFont.mediumFont(16), textColor: Color_24374E, textAlignment: .right, text: nil)
        return lab
    }()
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.selectionStyle = .none
        self.setupViews()
    }
    
    private func setupViews() {
        self.contentView.backgroundColor = Color_FFFFFF
        
        let lab = UILabel.getLab(font: .boldFont(16), textColor: Color_Theme, textAlignment: .left, text: "成员信息")
        self.contentView.addSubview(lab)
        lab.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview()
            m.height.equalTo(40)
        }
        
        let labName = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "姓名")
        self.contentView.addSubview(labName)
        labName.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(lab.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.contentView.addSubview(self.usernameLab)
        self.usernameLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(lab.snp.bottom)
            m.height.equalTo(50)
        }
        
        let lineV1 = UIView.init()
        lineV1.backgroundColor = Color_E6EAEE
        self.contentView.addSubview(lineV1)
        lineV1.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(usernameLab.snp.bottom)
        }
        
        let labTeam = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "团队")
        self.contentView.addSubview(labTeam)
        labTeam.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(usernameLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.contentView.addSubview(self.organizationLab)
        self.organizationLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(usernameLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        let lineV2 = UIView.init()
        lineV2.backgroundColor = Color_E6EAEE
        self.contentView.addSubview(lineV2)
        lineV2.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(organizationLab.snp.bottom)
        }
        
        self.contentView.addSubview(phoneView)
        phoneView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(organizationLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        
        let labPhone = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "手机号")
        phoneView.addSubview(labPhone)
        labPhone.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview()
            m.height.equalTo(50)
        }
        
        phoneView.addSubview(self.phoneLab)
        self.phoneLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-46)
            m.top.equalToSuperview()
            m.height.equalTo(50)
        }
        
        phoneView.addSubview(btnPhone)
        btnPhone.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 26, height: 26))
            m.centerY.equalTo(phoneLab)
            m.right.equalToSuperview().offset(-15)
        }
        
        let lineV3 = UIView.init()
        lineV3.backgroundColor = Color_E6EAEE
        phoneView.addSubview(lineV3)
        lineV3.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(phoneLab.snp.bottom)
        }
        
        self.contentView.addSubview(shortPhoneView)
        shortPhoneView.snp.makeConstraints { (m) in
            m.left.right.equalToSuperview()
            m.top.equalTo(phoneView.snp.bottom)
            m.height.equalTo(50)
        }
        
        let labShortPhone = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "短号")
        shortPhoneView.addSubview(labShortPhone)
        labShortPhone.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalToSuperview()
            m.height.equalTo(50)
        }
        
        shortPhoneView.addSubview(self.shortPhoneLab)
        self.shortPhoneLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-46)
            m.top.equalTo(phoneView.snp.bottom)
            m.height.equalTo(50)
        }
        
        shortPhoneView.addSubview(btnShortPhone)
        btnShortPhone.snp.makeConstraints { (m) in
            m.size.equalTo(CGSize.init(width: 26, height: 26))
            m.centerY.equalTo(shortPhoneLab)
            m.right.equalToSuperview().offset(-15)
        }
        
        let lineV4 = UIView.init()
        lineV4.backgroundColor = Color_E6EAEE
        shortPhoneView.addSubview(lineV4)
        lineV4.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(shortPhoneLab.snp.bottom)
        }
        
        let labEmail = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "邮箱")
        self.contentView.addSubview(labEmail)
        labEmail.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(shortPhoneView.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.contentView.addSubview(self.emailLab)
        self.emailLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(shortPhoneView.snp.bottom)
            m.height.equalTo(50)
        }
        
        let lineV5 = UIView.init()
        lineV5.backgroundColor = Color_E6EAEE
        self.addSubview(lineV5)
        lineV5.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(emailLab.snp.bottom)
        }
        
        let labDepartment = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "部门")
        self.addSubview(labDepartment)
        labDepartment.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(emailLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.addSubview(self.departmentLab)
        self.departmentLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(emailLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        let lineV6 = UIView.init()
        lineV6.backgroundColor = Color_E6EAEE
        self.addSubview(lineV6)
        lineV6.snp.makeConstraints { (m) in
            m.width.equalToSuperview()
            m.height.equalTo(0.5)
            m.top.equalTo(departmentLab.snp.bottom)
        }
        
        let labPosition = UILabel.getLab(font: .mediumFont(14), textColor: Color_8A97A5, textAlignment: .left, text: "职位")
        self.addSubview(labPosition)
        labPosition.snp.makeConstraints { (m) in
            m.left.equalToSuperview().offset(15)
            m.top.equalTo(departmentLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        self.addSubview(self.positionLab)
        self.positionLab.snp.makeConstraints { (m) in
            m.right.equalToSuperview().offset(-15)
            m.top.equalTo(departmentLab.snp.bottom)
            m.height.equalTo(50)
        }
        
        DispatchQueue.main.async {
            self.roundCorners([.topLeft, .topRight, .bottomLeft, .bottomRight], radius: 5)
        }
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.usernameLab.text = nil
        self.organizationLab.text = nil
        self.phoneLab.text = nil
        self.shortPhoneLab.text = nil
        self.emailLab.text = nil
        self.departmentLab.text = nil
        self.positionLab.text = nil
    }
    
    func configure(with model: FriendInfoTeamCellModel) {
        self.modelData = model
        self.usernameLab.text = model.userRealName
        
        self.organizationLab.text = model.organizationName
        
        self.emailLab.text = model.email
        
        self.departmentLab.text = model.depName
        
        self.positionLab.text = model.position
        
        // 手机号
        if let phone = model.phone, !phone.isBlank {
            self.phoneLab.text = phone.secretPhone
        } else {
            //隐藏手机号
            self.phoneView.isHidden = true
            self.phoneView.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
        }
        
        // 短号
        if let shortPhone = model.shortPhone, !shortPhone.isBlank {
            self.shortPhoneLab.text = "****"
        } else {
            //隐藏短号
            self.shortPhoneView.isHidden = true
            self.shortPhoneView.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
        }
    }
    
    @objc private func callPhone(_ sender:UIButton) {
        
        if sender.isSelected == true {
            guard let tempPhone = self.modelData?.phone, !tempPhone.isBlank else {
                return
            }
            
            self.startCallPhone(tempPhone, isPhone: true)
        }else{
            
            self.phoneLab.text = self.modelData?.phone
            sender.isSelected = !sender.isSelected
        }
        
        
        
    }
    
    @objc private func callShortPhone(_ sender:UIButton) {
        if sender.isSelected == true {
            guard let tempPhone = self.shortPhoneLab.text, !tempPhone.isBlank else {
                return
            }
            
            self.startCallPhone(tempPhone, isPhone: false)
        }else{
            self.shortPhoneLab.text = self.modelData?.shortPhone
            sender.isSelected = !sender.isSelected
        }
        
    }
    
    // 打电话
    private func startCallPhone(_ tempPhone: String,isPhone: Bool) {
        if isPhone {
            self.btnPhone.isSelected = !self.btnPhone.isSelected
            self.phoneLab.text = self.modelData?.phone?.secretPhone
        }else{
            self.btnShortPhone.isSelected = !self.btnShortPhone.isSelected
            self.shortPhoneLab.text = "****"
        }
        
        let phone = "telprompt://" + tempPhone
        if UIApplication.shared.canOpenURL(URL(string: phone)!) {
            if #available(iOS 10.0, *) {
                UIApplication.shared.open(URL(string: phone)!, options: [:], completionHandler: nil)
            } else {
                UIApplication.shared.openURL(URL(string: phone)!)
            }
        }
    }
}

