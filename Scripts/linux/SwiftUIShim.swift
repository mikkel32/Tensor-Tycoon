import Foundation

/// Stand-in for SwiftUI.Color, so the few engine files that name a colour compile without SwiftUI.
struct Color: Equatable {
    let name: String
    static let green = Color(name: "green"), yellow = Color(name: "yellow"), orange = Color(name: "orange"),
               red = Color(name: "red"), blue = Color(name: "blue"), purple = Color(name: "purple"),
               gray = Color(name: "gray"), secondary = Color(name: "secondary"), primary = Color(name: "primary"),
               mint = Color(name: "mint"), teal = Color(name: "teal"), cyan = Color(name: "cyan"),
               pink = Color(name: "pink"), indigo = Color(name: "indigo"), brown = Color(name: "brown")
}
