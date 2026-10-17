import Foundation

nonisolated enum BeckonPetPresentation {
    static func symbol(for species: String) -> String {
        switch species.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "cat": "cat.fill"
        case "dog": "dog.fill"
        case "bird": "bird.fill"
        case "rabbit", "bunny": "hare.fill"
        default: "pawprint.fill"
        }
    }
}
