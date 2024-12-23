//
//  FourCharCode+String.swift
//  GreenScreenCam
//
//  Created by Dory on 26/04/2024.
//

import Foundation

extension FourCharCode {
    func toString() -> String {
        let bytes: [CChar] = [
            CChar((self >> 24) & 0xff),
            CChar((self >> 16) & 0xff),
            CChar((self >> 8) & 0xff),
            CChar(self & 0xff),
            0
        ]
        return String(cString: bytes)
    }
}
