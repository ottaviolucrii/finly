import 'package:finly/core/widgets/grouped_list.dart';
import 'package:finly/features/ai/domain/repositories/ai_repository.dart';
import 'package:finly/features/ai/presentation/ai_messages.dart';
import 'package:flutter/material.dart';

/// The switch of the AI quick add in Configurações. Turning it on first
/// shows what is sent to the AI and asks for the person's consent.
class AiSettingsCard extends StatefulWidget {
  final AiRepository repository;

  const AiSettingsCard({super.key, required this.repository});

  @override
  State<AiSettingsCard> createState() => _AiSettingsCardState();
}

class _AiSettingsCardState extends State<AiSettingsCard> {
  bool? _enabled;
  bool? _askEnabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await widget.repository.isEnabled();
    final ask = await widget.repository.isAskEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = result.getOrElse(() => false);
      _askEnabled = ask.getOrElse(() => false);
    });
  }

  Future<bool> _askConsent() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Ligar a inteligência artificial?'),
        content: const SingleChildScrollView(
          child: Text(
            'Com a IA, você escreve como falaria ("gastei 50 no mercado ontem") e o Finly '
            'preenche o lançamento para você conferir e salvar.\n\n'
            'O que vai para a IA: só a frase que você escrever e os nomes das suas categorias e '
            'contas. Nunca saldos, histórico ou documentos.\n\n'
            'A frase é enviada a um serviço de IA (Claude, da Anthropic) e não é guardada pelo '
            'Finly. Nada é salvo sem você tocar em Salvar. Você pode desligar quando quiser.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Agora não')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Ligar')),
        ],
      ),
    );
    return accepted == true;
  }

  Future<void> _change(bool value) async {
    if (value && !await _askConsent()) return;
    if (!mounted) return;
    setState(() => _busy = true);
    final result = await widget.repository.setEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isRight()) _enabled = value;
    });
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aiSaveFailureMessage(failure)))),
      (_) {},
    );
  }

  Future<void> _changeAsk(bool value) async {
    if (value) {
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permitir perguntas sobre seu dinheiro?'),
          content: const SingleChildScrollView(
            child: Text(
              'Você pergunta à Amora, por exemplo "quanto gastei com Uber esse ano?". Para responder, ela busca '
              'totais no seu Finly, como "R\$ 812,40 em 31 lançamentos", e só esses totais vão para a IA '
              '(Claude, da Anthropic). Ela nunca vê seus lançamentos um a um, e nada fica guardado.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Agora não')),
            FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Permitir')),
          ],
        ),
      );
      if (accepted != true || !mounted) return;
    }
    setState(() => _busy = true);
    final result = await widget.repository.setAskEnabled(value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (result.isRight()) _askEnabled = value;
    });
    result.fold(
      (failure) => ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(aiSaveFailureMessage(failure)))),
      (_) {},
    );
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final askEnabled = _askEnabled;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Inteligência artificial'),
        Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              SwitchListTile(
            secondary: const IconBadge(icon: Icons.auto_awesome),
            title: const Text('Lançar escrevendo'),
            subtitle: const Text(
              'Escreva "gastei 50 no mercado ontem" no "+" e o Finly preenche para você conferir. '
              'Só a frase e os nomes de categorias e contas vão para a IA.',
            ),
            value: enabled ?? false,
            onChanged: (enabled == null || _busy) ? null : _change,
              ),
              const Divider(height: 1),
              SwitchListTile(
                secondary: const IconBadge(icon: Icons.insights_outlined),
                title: const Text('Perguntas sobre meu dinheiro'),
                subtitle: const Text(
                  'A Amora responde "quanto gastei com Uber esse ano?". Só totais vão para a IA, nunca seus '
                  'lançamentos um a um.',
                ),
                value: askEnabled ?? false,
                onChanged: (askEnabled == null || _busy) ? null : _changeAsk,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
