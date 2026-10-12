import Foundation
import SwiftData

@Model
final class WeightEntry {
    var date: Date
    var kg: Double

    init(date: Date = .now, kg: Double) {
        self.date = date
        self.kg = kg
    }
}
