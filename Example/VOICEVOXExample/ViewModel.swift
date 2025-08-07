import AVFAudio
import Foundation
import VOICEVOX

@Observable
final class ViewModel {
  var message = ""

  var isReady: Bool {
    synthesizer != nil
  }

  private var synthesizer: VOICEVOXSynthesizer?
  @ObservationIgnored private var audioPlayer: AVAudioPlayer?

  /// Sets up the VOICEVOX synthesizer with required resources.
  @MainActor
  func setup() async {
    guard let resourceURL = Bundle.main.resourceURL else {
      fatalError("Could not find application resource bundle")
    }
    let openJTalkURL = resourceURL.appending(path: "lib/open_jtalk_dic_utf_8")
    let modelURL = resourceURL.appending(path: "lib/vvms/0.vvm")

    let config = VOICEVOXConfiguration(
      openJTalkDictionaryURL: openJTalkURL
    )
    do {
      let synthesizer = try await VOICEVOXSynthesizer(configuration: config)
      try await synthesizer.loadVoiceModel(from: modelURL)

      self.synthesizer = synthesizer
    } catch {
      fatalError("Failed to initialize VOICEVOX synthesizer: \(error)")
    }
  }

  /// Synthesizes and plays the given text as speech.
  ///
  /// - Parameter message: The text to synthesize and play.
  @MainActor
  func playVoice(message: String) async {
    guard let synthesizer else {
      return
    }

    do {
      let audioData = try await synthesizer.synthesize(
        text: message,
        styleId: 0,
        options: .standard
      )

      audioPlayer = try AVAudioPlayer(data: audioData)
      audioPlayer?.prepareToPlay()
      audioPlayer?.play()
    } catch {
      print("Failed to synthesize or play audio: \(error)")
    }
  }
}
