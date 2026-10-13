import Foundation
import SwiftData

/// One user message (photo and/or text) in a meal conversation, with the model's estimate for it once answered.
@Model
final class MealTurn {
    var id: UUID
    var index: Int
    var createdAt: Date
    var text: String?
    @Attribute(.externalStorage) var photo: Data?
    var replyJSON: Data?
    var meal: Meal?

    init(index: Int, text: String?, photo: Data?) {
        id = UUID()
        self.index = index
        createdAt = .now
        self.text = text
        self.photo = photo
    }

    var reply: MealAnalysis? {
        replyJSON.flatMap { try? JSONDecoder().decode(MealAnalysis.self, from: $0) }
    }

    func setReply(_ analysis: MealAnalysis) {
        replyJSON = try? JSONEncoder().encode(analysis)
    }

    struct Snapshot: Sendable {
        let index: Int
        let createdAt: Date
        let text: String?
        let photo: Data?
        let replyJSON: Data?
    }

    var snapshot: Snapshot {
        Snapshot(index: index, createdAt: createdAt, text: text, photo: photo, replyJSON: replyJSON)
    }

    convenience init(snapshot: Snapshot) {
        self.init(index: snapshot.index, text: snapshot.text, photo: snapshot.photo)
        createdAt = snapshot.createdAt
        replyJSON = snapshot.replyJSON
    }

    var conversationTurn: ConversationTurn {
        ConversationTurn(imageJPEG: photo, text: text, reply: reply)
    }
}
