import SwiftUI

@main struct MemoraApp: App {
  @AppStorage("appLanguage") private var language = AppLanguage.chinese.rawValue
  @StateObject private var library = Library()
  var body: some Scene {
    WindowGroup("Memora") {
      ContentView().environmentObject(library)
        .environment(\.locale, Locale(identifier: language))
        .id(language)
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 1080, minHeight: 700)
        .onOpenURL { library.add([$0]) }
        .alert(
          "Memora",
          isPresented: Binding(
            get: { library.message != nil }, set: { if !$0 { library.message = nil } })
        ) {
          Button(L("好")) { library.message = nil }
        } message: {
          Text(L(library.message ?? ""))
        }
    }
    .windowStyle(.hiddenTitleBar)
    .defaultSize(width: 1320, height: 850)
    .commands {
      CommandGroup(replacing: .newItem) {
        Button(L("打开图片…"), action: library.open).keyboardShortcut("o").disabled(library.busy)
      }
      CommandGroup(replacing: .saveItem) {
        Button(L("保存更改"), action: library.saveDraft).keyboardShortcut("s", modifiers: [.command])
          .disabled(library.selected == nil || library.busy)
        Button(L("无损另存为…"), action: library.exportImage).keyboardShortcut(
          "s", modifiers: [.command, .shift]
        ).disabled(library.selected == nil || library.busy)
      }
    }
  }
}
