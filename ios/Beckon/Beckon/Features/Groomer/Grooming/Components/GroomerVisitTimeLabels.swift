import Foundation

struct GroomerVisitRequestTimeLabels {
    let startDate: String
    let endDate: String?
    let startTime: String
    let endTime: String

    init(start: Date, end: Date, calendar: Calendar) {
        let style = Date.FormatStyle(locale: Locale(identifier: "en_US"), calendar: calendar, timeZone: calendar.timeZone)
        let day = style.weekday(.abbreviated).month(.abbreviated).day()
        let year = calendar.component(.year, from: start)
        let dateStyle = year != calendar.component(.year, from: end) || year != calendar.component(.year, from: Date()) ? day.year() : day
        let clock = style.hour().minute()
        let changesOffset = calendar.timeZone.secondsFromGMT(for: start) != calendar.timeZone.secondsFromGMT(for: end)
        func time(_ date: Date) -> String {
            date.formatted(clock) + (changesOffset ? " " + BeckonDateTimeFormatter.zoneLabel(calendar.timeZone, at: date) : "")
        }
        startDate = start.formatted(dateStyle)
        endDate = calendar.isDate(start, inSameDayAs: end) ? nil : end.formatted(dateStyle)
        startTime = time(start)
        endTime = time(end)
    }
}
