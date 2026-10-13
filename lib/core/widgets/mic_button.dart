import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech to text with the phone's own recognizer (no cost, nothing sent to
/// Finly): one shared instance for the whole app.
final _speech = SpeechToText();
bool? _speechReady;

/// A 🎤 button for a text field: while listening, what the person says goes
/// into [onText] (updated as they speak). Tapping again stops.
class MicButton extends StatefulWidget {
  final ValueChanged<String> onText;
  final bool enabled;

  const MicButton({super.key, required this.onText, this.enabled = true});

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> {
  bool _listening = false;

  Future<void> _toggle() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    _speechReady ??= await _speech.initialize(
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') && mounted) setState(() => _listening = false);
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (_speechReady != true) {
      _speechReady = null; // ask again next time (the permission may be given later)
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('Não consegui usar o microfone. Verifique a permissão do Finly nas configurações do celular.'),
        ));
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) => widget.onText(result.recognizedWords),
      listenOptions: SpeechListenOptions(
        localeId: 'pt_BR',
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      tooltip: _listening ? 'Parar de ouvir' : 'Falar',
      onPressed: widget.enabled ? _toggle : null,
      icon: Icon(_listening ? Icons.stop_circle_outlined : Icons.mic_none, color: _listening ? scheme.error : null),
    );
  }
}
