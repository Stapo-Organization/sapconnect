import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - The contract

/// Must be spelled exactly like this: the `live_activities` plugin requests the
/// activity with a struct of the same name, and ActivityKit matches the two
/// across the module boundary by type name and shape.
///
/// Every field is optional on purpose. The plugin's own copy carries only
/// `appGroupId` and ships the real data through the App Group's UserDefaults;
/// a push from the store carries the fields themselves. The view reads
/// whichever is present, so the same card works with the app open, closed, or
/// deleted from memory.
struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
        var appGroupId: String?
        var phase: String?
        var headline: String?
        var headlineEn: String?
        var courier: String?
        var progress: Double?
        var etaMinutes: Int?
        var updatedAt: Int?
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

private let appGroupId = "group.com.zooboxi.app"
private let sharedDefault = UserDefaults(suiteName: appGroupId)

/// The customer's language decides every word and the reading direction.
private var isArabic: Bool { Locale.preferredLanguages.first?.hasPrefix("ar") ?? true }

// MARK: - Reading the state

/// One value with two sources: the push's content state first, the App Group
/// (what the app wrote while it was open) second.
private struct OrderState {
    let phase: String
    let headline: String
    let courier: String
    let progress: Double
    let etaMinutes: Int
    let orderNumber: String
    let route: String

    init(_ context: ActivityViewContext<LiveActivitiesAppAttributes>) {
        let a = context.attributes
        let s = context.state
        let d = sharedDefault
        let arabic = isArabic

        func str(_ key: String, _ pushed: String?) -> String {
            if let p = pushed, !p.isEmpty { return p }
            return d?.string(forKey: a.prefixedKey(key)) ?? ""
        }

        phase = str("phase", s.phase)
        let ar = str("headline", s.headline)
        let en = str("headlineEn", s.headlineEn)
        headline = arabic ? (ar.isEmpty ? en : ar) : (en.isEmpty ? ar : en)
        courier = str("courier", s.courier)
        progress = s.progress ?? (d?.double(forKey: a.prefixedKey("progress")) ?? 0)
        etaMinutes = s.etaMinutes ?? (d?.integer(forKey: a.prefixedKey("etaMinutes")) ?? 0)
        orderNumber = d?.string(forKey: a.prefixedKey("orderNumber")) ?? ""
        route = d?.string(forKey: a.prefixedKey("route")) ?? "/orders"
    }

    var isLive: Bool { phase != "delivered" && phase != "failed" }
    var inTransit: Bool { phase == "in_transit" }

    /// The brand's own palette, phase by phase — the same colours the app uses
    /// for the same moments, so the lock screen reads as the same product.
    var tone: Color {
        switch phase {
        case "searching": return Color(red: 0.91, green: 0.64, blue: 0.24)   // amber
        case "assigned": return Color(red: 0.76, green: 0.25, blue: 0.05)    // express ember
        case "in_transit": return Color(red: 0.26, green: 0.62, blue: 0.61)  // teal
        case "delivered": return Color(red: 0.18, green: 0.64, blue: 0.42)   // success
        case "failed": return Color(red: 0.90, green: 0.28, blue: 0.30)      // error
        default: return Color(red: 0.26, green: 0.62, blue: 0.61)
        }
    }

    var symbol: String {
        switch phase {
        case "searching": return "dot.radiowaves.left.and.right"
        case "assigned": return "storefront"
        case "in_transit": return "scooter"
        case "delivered": return "checkmark"
        case "failed": return "exclamationmark"
        case "ready": return "shippingbox"
        default: return "shippingbox"
        }
    }

    var deepLink: URL {
        URL(string: "zooboxi://app\(route)") ?? URL(string: "zooboxi://app/orders")!
    }
}

// MARK: - The activity

struct ZooboxiOrderActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            LockScreenCard(state: OrderState(context))
                .activityBackgroundTint(Color(.systemBackground).opacity(0.85))
                .activitySystemActionForegroundColor(Color.primary)
        } dynamicIsland: { context in
            let s = OrderState(context)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PhaseGlyph(state: s, size: 40)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if s.inTransit && s.etaMinutes > 0 {
                        MinutesPill(minutes: s.etaMinutes, tone: s.tone)
                            .padding(.trailing, 4)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.headline)
                        .font(.system(size: 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressTrack(progress: s.progress, tone: s.tone)
                        HStack {
                            if !s.courier.isEmpty {
                                Text(s.courier).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if !s.orderNumber.isEmpty {
                                Text("#\(s.orderNumber)").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                Image(systemName: s.symbol)
                    .foregroundStyle(s.tone)
                    .font(.system(size: 13, weight: .bold))
            } compactTrailing: {
                if s.inTransit && s.etaMinutes > 0 {
                    Text(isArabic ? "\(s.etaMinutes)د" : "\(s.etaMinutes)m")
                        .font(.system(size: 13, weight: .bold).monospacedDigit())
                        .foregroundStyle(s.tone)
                } else {
                    ProgressView(value: s.progress)
                        .progressViewStyle(.circular)
                        .tint(s.tone)
                        .frame(width: 16, height: 16)
                }
            } minimal: {
                Image(systemName: s.symbol)
                    .foregroundStyle(s.tone)
                    .font(.system(size: 12, weight: .bold))
            }
            .widgetURL(s.deepLink)
            .keylineTint(s.tone)
        }
    }
}

// MARK: - Lock screen

private struct LockScreenCard: View {
    let state: OrderState

    var body: some View {
        HStack(spacing: 14) {
            PhaseGlyph(state: state, size: 46)
            VStack(alignment: .leading, spacing: 5) {
                Text(state.headline)
                    .font(.system(size: 16, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                HStack(spacing: 6) {
                    if !state.courier.isEmpty {
                        Text(state.courier)
                    }
                    if !state.courier.isEmpty && !state.orderNumber.isEmpty {
                        Text("·")
                    }
                    if !state.orderNumber.isEmpty {
                        Text("#\(state.orderNumber)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                ProgressTrack(progress: state.progress, tone: state.tone)
            }
            if state.inTransit && state.etaMinutes > 0 {
                MinutesPill(minutes: state.etaMinutes, tone: state.tone)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .widgetURL(state.deepLink)
    }
}

// MARK: - Pieces

private struct PhaseGlyph: View {
    let state: OrderState
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(state.tone.opacity(0.18))
            Circle()
                .trim(from: 0, to: max(0.02, min(1, state.progress)))
                .stroke(state.tone, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: state.symbol)
                .font(.system(size: size * 0.42, weight: .bold))
                .foregroundStyle(state.tone)
        }
        .frame(width: size, height: size)
    }
}

private struct MinutesPill: View {
    let minutes: Int
    let tone: Color

    var body: some View {
        VStack(spacing: 0) {
            Text("\(minutes)")
                .font(.system(size: 24, weight: .heavy).monospacedDigit())
            Text(isArabic ? "دقيقة" : "min")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(tone, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ProgressTrack: View {
    let progress: Double
    let tone: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                Capsule().fill(tone.opacity(0.18))
                Capsule()
                    .fill(tone)
                    .frame(width: max(6, geo.size.width * max(0, min(1, progress))))
            }
        }
        .frame(height: 5)
    }
}
