import SwiftUI
import WidgetKit

/// The extension's one job: host the order activity. Nothing else lives here.
@main
struct ZooboxiLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        ZooboxiOrderActivity()
    }
}
