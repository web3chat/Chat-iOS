//
//  MessageCellDelegate.swift
//  chat
//
//  Created by 陈健 on 2020/12/22.
//

import Foundation

protocol MessageCellDelegate: MessageLabelDelegate {
    
    func didTapBackground(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapMessage(in cell: MessageContentCell, message: Message)
    
    func didTapAvatar(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapSelfAvatar(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapCellTopLabel(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapCellBottomLabel(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapMessageTopLabel(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapMessageBottomLabel(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapStatusView(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapAccessoryView(in cell: MessageCollectionViewCell, message: Message)
    
    func didTapLeadingView(in cell: MessageCollectionViewCell, message: Message)
    
    
    
    func didLongPressBackground(in cell: MessageContentCell, message: Message)

    func didLongPressMessage(in cell: MessageContentCell, message: Message)

    func didLongPressAvatar(in cell: MessageContentCell, message: Message)
    
    func didLongPressSelfAvatar(in cell: MessageContentCell, message: Message)

    func didLongPressCellTopLabel(in cell: MessageContentCell, message: Message)

    func didLongPressCellBottomLabel(in cell: MessageContentCell, message: Message)

    func didLongPressMessageTopLabel(in cell: MessageContentCell, message: Message)

    func didLongPressMessageBottomLabel(in cell: MessageContentCell, message: Message)

    func didLongPressAccessoryView(in cell: MessageContentCell, message: Message)

    func didLongPressLeadingView(in cell: MessageContentCell, message: Message)
}

extension MessageCellDelegate {
    
    func didTapBackground(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapMessage(in cell: MessageContentCell, message: Message) { }
    
    func didTapAvatar(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapSelfAvatar(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapCellTopLabel(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapCellBottomLabel(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapMessageTopLabel(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapMessageBottomLabel(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapAccessoryView(in cell: MessageCollectionViewCell, message: Message) { }
    
    func didTapLeadingView(in cell: MessageCollectionViewCell, message: Message) { }
    
    
    
    func didLongPressBackground(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressMessage(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressAvatar(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressSelfAvatar(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressCellTopLabel(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressCellBottomLabel(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressMessageTopLabel(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressMessageBottomLabel(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressAccessoryView(in cell: MessageContentCell, message: Message) { }
    
    func didLongPressLeadingView(in cell: MessageContentCell, message: Message) { }
}
