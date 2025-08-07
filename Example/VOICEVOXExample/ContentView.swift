import SwiftUI

struct ContentView: View {
  @State var viewModel = ViewModel()

  var body: some View {
    VStack {
      TextField("Voice Message", text: $viewModel.message)
        .textFieldStyle(.roundedBorder)

      Button {
        Task {
          await playVoice()
        }
      } label: {
        Text("Play")
      }
      .disabled(!viewModel.isReady)
    }
    .padding()
    .task {
      await viewModel.setup()
    }
  }

  private func playVoice() async {
    let message =
      if viewModel.message.isEmpty {
        "テキストを入力するのだ"
      } else {
        viewModel.message
      }
    await viewModel.playVoice(message: message)
  }
}

#Preview {
  ContentView()
}
