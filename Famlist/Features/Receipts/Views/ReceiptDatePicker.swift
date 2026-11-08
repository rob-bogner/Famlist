/*
 ReceiptDatePicker.swift
 Famlist
 Created on: 08.11.2026

 ------------------------------------------------------------------------
 📄 File Overview:
 - Inhalt der Aktionskarte „Kaufdatum ändern“ (Board ReceiptDateDialog, T-008):
   Pillen Heute · Gestern · Vorgestern und ein Monatskalender.

 🔰 Notes for Beginners:
 - Board: Pillen 34 hoch, Einzug 14, DM 13/600, Abstand 8. Gewählt = flache Fläche `info` mit
   CTA-Text (Kontrast 7,10:1 Light / 9,29:1 Dark; das Akzent-Glas erreicht mit weißer Schrift nur 3,06:1).
 - Kalender: Fläche field, Rahmen fieldBorder, Radius 22, Einzug 12 / 10 / 8 / 10 plus Rahmen 1.
   Kopf = MonthSwitcher (Glas 36, Outfit 18/600), Wochentage DM 12/600 sub, Tage DM 15 in Kreisen 36
   (Zeilenhöhe 40). Heute: Ring 1,5 in `info`, Schrift `info` 600. Tage nach heute: gesperrt, sub, 40 %.
 - Die Woche beginnt am Montag. `selection` ist immer der Tagesbeginn.

 📝 Last Change:
 - Initial creation (T-008).
 ------------------------------------------------------------------------
 */

import SwiftUI

struct ReceiptDatePicker: View {
    let k: SheetTheme
    @Binding var selection: Date
    let today: Date

    @State private var month: Date

    private static let calendar = Calendar.current
    private static let locale = Locale(identifier: "de_DE")

    init(k: SheetTheme, selection: Binding<Date>, today: Date) {
        self.k = k
        self._selection = selection
        self.today = today
        _month = State(initialValue: Self.firstOfMonth(selection.wrappedValue))
    }

    var body: some View {
        let d = ActionCardTokens(k)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                quickPill("Heute", daysAgo: 0, d: d)
                quickPill("Gestern", daysAgo: 1, d: d)
                quickPill("Vorgestern", daysAgo: 2, d: d)
            }
            calendarCard(d: d)
        }
    }

    // MARK: - Pillen

    private func quickPill(_ title: String, daysAgo: Int, d: ActionCardTokens) -> some View {
        let day = Self.calendar.date(byAdding: .day, value: -daysAgo, to: Self.calendar.startOfDay(for: today)) ?? today
        let isOn = Self.calendar.isDate(day, inSameDayAs: selection)
        return Button(action: { pick(day) }) {
            Text(title)
                .font(AppFont.dm(13, 600))
                .foregroundStyle(isOn ? k.ctaText : d.text)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background {
                    if isOn {
                        CSSBox(shape: Pill, paint: .color(d.info), shadows: k.ctaShadow)
                    } else {
                        GlassPillBackground(style: .neutral, appearance: k.appearance, accent: k.a, height: 34)
                    }
                }
                .contentShape(Pill)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Kalender

    private func calendarCard(d: ActionCardTokens) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)
        return VStack(spacing: 8) {
            MonthSwitcher(title: month.formatted(.dateTime.month(.wide).year().locale(Self.locale)),
                          canGoBack: true, canGoForward: month < Self.firstOfMonth(today), k: k,
                          onBack: { shiftMonth(-1) }, onForward: { shiftMonth(1) })
                .padding(.horizontal, 2)
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"], id: \.self) { name in
                    Text(name)
                        .font(AppFont.dm(12, 600))
                        .foregroundStyle(d.sub)
                        .accessibilityHidden(true)
                }
            }
            LazyVGrid(columns: columns, spacing: 0) {
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day { dayCell(day, d: d) } else { Color.clear.frame(height: 40) }
                }
            }
        }
        .padding(EdgeInsets(top: 13, leading: 11, bottom: 9, trailing: 11))
        .background(CSSBox(shape: RR(22), paint: .color(d.field), border: 1, borderColor: d.fieldBorder))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Kalender")
    }

    private func dayCell(_ day: Date, d: ActionCardTokens) -> some View {
        let isSelected = Self.calendar.isDate(day, inSameDayAs: selection)
        let isToday = Self.calendar.isDate(day, inSameDayAs: today)
        let isFuture = Self.calendar.startOfDay(for: day) > Self.calendar.startOfDay(for: today)
        let color: Color = isSelected ? k.ctaText : isToday ? d.info : isFuture ? d.sub : d.text
        return Button(action: { pick(day) }) {
            Text("\(Self.calendar.component(.day, from: day))")
                .font(AppFont.dm(15, isSelected || isToday ? 600 : 500))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .background {
                    if isSelected {
                        CSSBox(shape: Circle(), paint: .color(d.info), shadows: k.ctaShadow)
                    } else if isToday {
                        Circle().strokeBorder(d.info, lineWidth: 1.5)
                    }
                }
                .contentShape(Circle())
                .opacity(isFuture ? 0.4 : 1)
                .frame(height: 40)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel((isToday ? "Heute, " : "")
                            + day.formatted(.dateTime.weekday(.wide).day().month(.wide).year().locale(Self.locale)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Tage des angezeigten Monats; nil = leere Zelle vor dem 1. (Woche ab Montag).
    private var cells: [Date?] {
        let cal = Self.calendar
        guard let range = cal.range(of: .day, in: .month, for: month) else { return [] }
        let leading = (cal.component(.weekday, from: month) + 5) % 7   // Sonntag = 1 → 6 leere Zellen
        let days: [Date?] = range.compactMap { cal.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days
    }

    private func pick(_ day: Date) {
        let start = Self.calendar.startOfDay(for: day)
        guard start <= Self.calendar.startOfDay(for: today) else { return }
        selection = start
        month = Self.firstOfMonth(start)
    }

    private func shiftMonth(_ value: Int) {
        guard let next = Self.calendar.date(byAdding: .month, value: value, to: month),
              next <= Self.firstOfMonth(today) else { return }
        month = next
    }

    private static func firstOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
}

private extension ReceiptDatePicker {
    /// Board-Stand: heute So 08.11.2026, gewählt Sa 07.11.2026 („Gestern“).
    static var previewToday: Date { calendar.date(from: DateComponents(year: 2026, month: 11, day: 8, hour: 12))! }
}

#Preview("Kaufdatum ändern") {
    @Previewable @State var day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 7))!
    ReceiptDatePicker(k: SheetTheme(.light), selection: $day, today: ReceiptDatePicker.previewToday)
        .padding(16)
        .background(Color.white)
}

#Preview("Kaufdatum ändern – Dark") {
    @Previewable @State var day = Calendar.current.date(from: DateComponents(year: 2026, month: 11, day: 7))!
    ReceiptDatePicker(k: SheetTheme(.dark), selection: $day, today: ReceiptDatePicker.previewToday)
        .padding(16)
        .background(Color.rgba(20, 34, 37, 1))
}
