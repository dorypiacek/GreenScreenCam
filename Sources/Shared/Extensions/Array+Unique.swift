//
//  Array+Unique.swift
//  GreenScreenCam
//
//  Created by Dory on 01/10/2024.
//

import Foundation

extension Array where Element: Hashable {
    func unique() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
