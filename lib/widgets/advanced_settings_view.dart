import 'package:flutter/material.dart';
import '../models/app_settings.dart';

class AdvancedSettingsView extends StatefulWidget {
  final AppSettings settings;
  final Function(AppSettings) onSave;

  const AdvancedSettingsView({
    Key? key,
    required this.settings,
    required this.onSave,
  }) : super(key: key);

  @override
  State<AdvancedSettingsView> createState() => _AdvancedSettingsViewState();
}

class _AdvancedSettingsViewState extends State<AdvancedSettingsView> {
  late TextEditingController _openRouterKeyController;
  late TextEditingController _cerebrasKeyController;
  late TextEditingController _promptController;
  late String _selectedLanguage;
  late AIProvider _activeProvider;
  late bool _useGlobalContext;

  final List<String> _languages = ['Spanish', 'English', 'French', 'German', 'Italian', 'Portuguese'];

  @override
  void initState() {
    super.initState();
    _openRouterKeyController = TextEditingController(text: widget.settings.openRouterApiKey);
    _cerebrasKeyController = TextEditingController(text: widget.settings.cerebrasApiKey);
    _promptController = TextEditingController(text: widget.settings.systemInstructions);
    _selectedLanguage = widget.settings.targetLanguage;
    _activeProvider = widget.settings.activeProvider;
    _useGlobalContext = widget.settings.useGlobalContext;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('ADVANCED SETTINGS', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {
              final newSettings = AppSettings(
                openRouterApiKey: _openRouterKeyController.text,
                cerebrasApiKey: _cerebrasKeyController.text,
                targetLanguage: _selectedLanguage,
                systemInstructions: _promptController.text,
                activeProvider: _activeProvider,
                useGlobalContext: _useGlobalContext,
              );
              widget.onSave(newSettings);
              Navigator.pop(context);
            },
            child: const Text('SAVE', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'AI PROVIDER',
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildProviderButton('OPENROUTER', AIProvider.openRouter),
                    _buildProviderButton('CEREBRAS', AIProvider.cerebras),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'SEMANTIC MEMORY (BETA)',
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Global Context', style: TextStyle(color: Colors.white, fontSize: 13)),
                subtitle: Text(
                  'Allows the AI to see relevant content from other saved notes.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11),
                ),
                trailing: Switch(
                  value: _useGlobalContext,
                  activeColor: Colors.redAccent,
                  onChanged: (val) => setState(() => _useGlobalContext = val),
                ),
              ),
            ),
            const SizedBox(height: 64),
            Center(
              child: Text(
                'V O I D - v13.0.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.1),
                  fontSize: 10,
                  letterSpacing: 4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildSection(
              'API KEYS',
              Column(
                children: [
                  TextField(
                    controller: _openRouterKeyController,
                    obscureText: true,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: _fieldDecoration('OpenRouter API Key'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cerebrasKeyController,
                    obscureText: true,
                    style: const TextStyle(fontFamily: 'JetBrains Mono', fontSize: 13),
                    decoration: _fieldDecoration('Cerebras API Key'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'LANGUAGE PREFERENCE',
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white10),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    dropdownColor: const Color(0xFF111111),
                    isExpanded: true,
                    items: _languages.map((l) => DropdownMenuItem(
                      value: l, 
                      child: Text(l, style: const TextStyle(color: Colors.white, fontSize: 14))
                    )).toList(),
                    onChanged: (val) => setState(() => _selectedLanguage = val!),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSection(
              'SYSTEM INSTRUCTIONS (AI PROMPT)',
              TextField(
                controller: _promptController,
                maxLines: 8,
                style: const TextStyle(fontSize: 13, height: 1.5),
                decoration: _fieldDecoration('Edit AI Instructions...'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProviderButton(String label, AIProvider provider) {
    bool isActive = _activeProvider == provider;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeProvider = provider),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? Colors.white10 : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white38,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      filled: true,
      fillColor: const Color(0xFF111111),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.all(16),
    );
  }
}
