import SwiftUI
import WidgetKit

/// The extension hosts the order activity and «رفّ لولو», the pet's food
/// countdown on the home screen.
@main
struct ZooboxiLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ZooboxiOrderActivity()
        ZooboxiPetWidget()
    }
}

// MARK: - «رفّ لولو»

/// What the app last wrote through `zb/widget` (see AppDelegate). The days are
/// NOT stored: `runsOut` is, and every timeline entry counts down to it, so
/// the number is right on a morning the app was never opened.
struct PetShelf: Decodable {
    let lang: String?
    let pet: String?
    let species: String?
    let product: String?
    /// Unix seconds when the food is expected to run out.
    let runsOut: Double?

    var arabic: Bool { (lang ?? "ar") != "en" }

    func daysLeft(at date: Date) -> Int? {
        guard let runsOut else { return nil }
        let seconds = runsOut - date.timeIntervalSince1970
        return max(0, Int((seconds / 86_400).rounded(.up)))
    }

    var symbol: String {
        switch species {
        case "cat": return "cat.fill"
        case "dog": return "dog.fill"
        case "bird": return "bird.fill"
        case "fish": return "fish.fill"
        case "small": return "hare.fill"
        case "reptile": return "tortoise.fill"
        default: return "pawprint.fill"
        }
    }

    static func load() -> PetShelf? {
        guard let json = UserDefaults(suiteName: "group.com.zooboxi.app")?.string(forKey: "zb.petShelf"),
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(PetShelf.self, from: data)
    }

    static let sample = PetShelf(
        lang: "ar", pet: "لولو", species: "cat", product: "طعام جاف للقطط",
        runsOut: Date().addingTimeInterval(4 * 86_400).timeIntervalSince1970
    )
}

struct PetShelfEntry: TimelineEntry {
    let date: Date
    let shelf: PetShelf?
}

struct PetShelfProvider: TimelineProvider {
    func placeholder(in context: Context) -> PetShelfEntry {
        PetShelfEntry(date: Date(), shelf: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (PetShelfEntry) -> Void) {
        completion(PetShelfEntry(date: Date(), shelf: PetShelf.load() ?? .sample))
    }

    /// Now, then every midnight for a week: the count moves at the turn of the
    /// day, not when iOS next happens to wake the extension.
    func getTimeline(in context: Context, completion: @escaping (Timeline<PetShelfEntry>) -> Void) {
        let shelf = PetShelf.load()
        let now = Date()
        let calendar = Calendar.current
        var entries = [PetShelfEntry(date: now, shelf: shelf)]
        let midnight = calendar.startOfDay(for: now)
        for day in 1...7 {
            if let next = calendar.date(byAdding: .day, value: day, to: midnight) {
                entries.append(PetShelfEntry(date: next, shelf: shelf))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct ZooboxiPetWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ZooboxiPetWidget", provider: PetShelfProvider()) { entry in
            PetShelfView(entry: entry)
        }
        .configurationDisplayName("رفّ حيوانك")
        .description("كم يوماً باقٍ على طعام حيوانك، واطلبه بلمسة.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private let deepTeal = Color(red: 0x1F / 255, green: 0x5C / 255, blue: 0x5B / 255)
private let brandTeal = Color(red: 0x42 / 255, green: 0x9D / 255, blue: 0x9C / 255)
private let coral = Color(red: 0xD4 / 255, green: 0x68 / 255, blue: 0x56 / 255)

struct PetShelfView: View {
    let entry: PetShelfEntry
    @Environment(\.widgetFamily) private var family

    private var background: LinearGradient {
        LinearGradient(colors: [deepTeal, brandTeal], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        let shelf = entry.shelf
        let arabic = shelf?.arabic ?? true
        Group {
            if let shelf, let days = shelf.daysLeft(at: entry.date) {
                filled(shelf: shelf, days: days, arabic: arabic)
            } else {
                empty(arabic: arabic)
            }
        }
        .environment(\.layoutDirection, arabic ? .rightToLeft : .leftToRight)
        .widgetURL(URL(string: shelf == nil ? "zooboxi://app/pets" : "zooboxi://app/family/supply"))
        .modifier(ShelfBackground(gradient: background))
    }

    @ViewBuilder
    private func filled(shelf: PetShelf, days: Int, arabic: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: shelf.symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(deepTeal)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.white))
                Text(shelf.pet ?? (arabic ? "حيوانك" : "Your pet"))
                    .font(.system(size: 13, weight: .heavy))
                    .foregroundColor(.white.opacity(0.92))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(days)")
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .environment(\.layoutDirection, .leftToRight)
                if family == .systemMedium, let product = shelf.product {
                    Text(product)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
            }
            Text(caption(days: days, arabic: arabic))
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(2)
            Text(arabic ? "اطلبه" : "Reorder")
                .font(.system(size: 12, weight: .heavy))
                .foregroundColor(days <= 2 ? .white : deepTeal)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 10).fill(days <= 2 ? coral : Color.white))
        }
    }

    @ViewBuilder
    private func empty(arabic: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            Spacer(minLength: 0)
            Text(arabic ? "أضف حيوانك في زوبكسي ليعرف متى يخلص طعامه" : "Add your pet in Zooboxi to see when its food runs out")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(4)
        }
    }

    private func caption(days: Int, arabic: Bool) -> String {
        if arabic {
            switch days {
            case 0: return "طعامه خلص"
            case 1: return "يوم حتى يخلص طعامه"
            case 2: return "يومان حتى يخلص طعامه"
            case 3...10: return "أيام حتى يخلص طعامه"
            default: return "يوماً حتى يخلص طعامه"
            }
        }
        switch days {
        case 0: return "Food has run out"
        case 1: return "day of food left"
        default: return "days of food left"
        }
    }
}

/// iOS 17 wants the background declared as the widget's container (it draws
/// it edge to edge and dims it in StandBy); earlier systems take a plain one.
private struct ShelfBackground: ViewModifier {
    let gradient: LinearGradient

    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            content.containerBackground(for: .widget) { gradient }
        } else {
            content.padding().background(gradient)
        }
    }
}
