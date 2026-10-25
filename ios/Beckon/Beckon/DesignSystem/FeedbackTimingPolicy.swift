import Foundation


/// How long a message that dismisses itself stays: a fixed time to notice it, plus the time to read it, with a floor so a short
/// message is not gone in a blink. What it asks the person to do adds time (an error says what to try; a snackbar must also be
/// reached for). A message that still runs past its cap is too long for a toast: say less, or use a banner or a dialog.
enum FeedbackTimingPolicy {
    enum Kind {
        /// A toast that says something is done.
        case notice
        /// A toast that says something failed and what to try.
        case error
        /// A snackbar: the message and the one action that expires with it.
        case snackbar

        fileprivate var extra: TimeInterval {
            switch self {
            case .notice: 0
            case .error: 1
            case .snackbar: 2
            }
        }

        fileprivate var floor: TimeInterval {
            switch self {
            case .notice: 4
            case .error: 5
            case .snackbar: 6
            }
        }

        fileprivate var cap: TimeInterval {
            switch self {
            case .notice: 8
            case .error: 9
            case .snackbar: 10
            }
        }
    }

    /// Seconds to notice the message appear.
    private static let noticing: TimeInterval = 1.5
    /// Seconds per word: about 170 words a minute, slower than reading a page because the eyes arrive from somewhere else.
    private static let perWord: TimeInterval = 0.35

    static func seconds(_ kind: Kind, words: Int) -> TimeInterval {
        min(kind.cap, max(kind.floor, noticing + kind.extra + perWord * Double(words)))
    }

    static func seconds(_ kind: Kind, _ texts: String?...) -> TimeInterval {
        seconds(kind, words: texts.compactMap { $0 }.reduce(0) { $0 + $1.split(whereSeparator: \.isWhitespace).count })
    }
}
