import Foundation

struct HawlTracker {
    let hijriCalendar = Calendar(identifier: .islamicUmmAlQura)

    func hawlEndDate(from startDate: Date) -> Date {
        hijriCalendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
    }

    func daysRemaining(from now: Date, hawlEnd: Date) -> Int {
        let components = Calendar.current.dateComponents([.day], from: now, to: hawlEnd)
        return max(0, components.day ?? 0)
    }

    func isHawlComplete(startDate: Date, currentDate: Date) -> Bool {
        return currentDate >= hawlEndDate(from: startDate)
    }

    func hijriDateString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = hijriCalendar
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
}
