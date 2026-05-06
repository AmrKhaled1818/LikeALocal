import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/user_provider.dart';

class PreferenceQuizScreen extends StatefulWidget {
  const PreferenceQuizScreen({super.key});

  @override
  State<PreferenceQuizScreen> createState() => _PreferenceQuizScreenState();
}

class _PreferenceQuizScreenState extends State<PreferenceQuizScreen> {
  final PageController _pageCtrl = PageController();
  int _page = 0;
  bool _saving = false;

  String? _budget;
  String? _atmosphere;
  final Set<String> _categories = {};

  static const _budgets = [
    _Option('Low', 'Street food & local joints', Icons.savings_outlined, 'low'),
    _Option('Mid', 'Casual dining & cafés', Icons.restaurant_outlined, 'mid'),
    _Option('High', 'Fine dining & rooftops', Icons.wine_bar_outlined, 'high'),
  ];

  static const _atmospheres = [
    _Option('Cozy', 'Warm, quiet, intimate', Icons.local_cafe_outlined, 'cozy'),
    _Option('Trendy', 'Hip, modern, buzzing', Icons.nightlife_outlined, 'trendy'),
    _Option('Outdoor', 'Parks, gardens, open air', Icons.park_outlined, 'outdoor'),
    _Option('Historic', 'Old charm, cultural gems', Icons.account_balance_outlined, 'historic'),
  ];

  static const _categoryOptions = [
    'Restaurant', 'Café', 'Bar', 'Viewpoint', 'Park', 'Shop',
  ];

  void _next() {
    if (_page < 2) {
      _pageCtrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      setState(() => _page++);
    } else {
      _save();
    }
  }

  bool get _canProceed {
    if (_page == 0) return _budget != null;
    if (_page == 1) return _atmosphere != null;
    return _categories.isNotEmpty;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final auth = context.read<AuthProvider>();
    await context.read<UserProvider>().updatePreferences({
      'budget': _budget,
      'atmosphere': _atmosphere,
      'favCategories': _categories.toList(),
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Preferences saved! The AI now knows your style.'),
            backgroundColor: Colors.green),
      );
      context.pop();
    }
  }

  @override
  void initState() {
    super.initState();
    final prefs = context.read<AuthProvider>().userModel?.preferences ?? {};
    _budget = prefs['budget']?.toString();
    _atmosphere = prefs['atmosphere']?.toString();
    final saved = prefs['favCategories'];
    if (saved is List) _categories.addAll(saved.cast<String>());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: const Text('Style Preferences',
            style:
                TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Progress bar
          LinearProgressIndicator(
            value: (_page + 1) / 3,
            backgroundColor: kMuted,
            valueColor: const AlwaysStoppedAnimation<Color>(kOrange),
            minHeight: 3,
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _QuizPage(
                  step: '1 of 3',
                  question: "What's your typical budget?",
                  subtitle:
                      'This helps the AI suggest places in your range.',
                  child: _OptionGrid(
                    options: _budgets,
                    selected: _budget,
                    onSelect: (v) => setState(() => _budget = v),
                  ),
                ),
                _QuizPage(
                  step: '2 of 3',
                  question: 'What atmosphere do you prefer?',
                  subtitle: 'The AI will match your vibe.',
                  child: _OptionGrid(
                    options: _atmospheres,
                    selected: _atmosphere,
                    onSelect: (v) => setState(() => _atmosphere = v),
                  ),
                ),
                _QuizPage(
                  step: '3 of 3',
                  question: 'What kinds of places do you love?',
                  subtitle: 'Pick all that apply.',
                  child: _CategoryGrid(
                    options: _categoryOptions,
                    selected: _categories,
                    onToggle: (v) => setState(() {
                      if (_categories.contains(v)) {
                        _categories.remove(v);
                      } else {
                        _categories.add(v);
                      }
                    }),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_canProceed && !_saving) ? _next : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kOrange,
                  disabledBackgroundColor: kMuted,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(
                        _page == 2 ? 'Save My Style' : 'Next',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuizPage extends StatelessWidget {
  final String step;
  final String question;
  final String subtitle;
  final Widget child;

  const _QuizPage({
    required this.step,
    required this.question,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(step,
              style: const TextStyle(
                  color: kOrange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1)),
          const SizedBox(height: 8),
          Text(question,
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: null,
                  height: 1.2)),
          const SizedBox(height: 6),
          Text(subtitle,
              style: const TextStyle(fontSize: 13, color: kMutedFg)),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}

class _OptionGrid extends StatelessWidget {
  final List<_Option> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const _OptionGrid(
      {required this.options,
      required this.selected,
      required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.4,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (_, i) {
        final opt = options[i];
        final isSelected = selected == opt.value;
        return GestureDetector(
          onTap: () => onSelect(opt.value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: isSelected ? kOrange : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? kOrange : kMuted,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: kOrange.withValues(alpha: 0.25),
                          blurRadius: 8)
                    ]
                  : [],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(opt.icon,
                    color: isSelected ? Colors.white : kMutedFg, size: 26),
                const SizedBox(height: 8),
                Text(opt.label,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isSelected ? Colors.white : kDark)),
                Text(opt.description,
                    style: TextStyle(
                        fontSize: 11,
                        color: isSelected
                            ? Colors.white70
                            : kMutedFg)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _CategoryGrid(
      {required this.options,
      required this.selected,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: options.map((cat) {
        final isSelected = selected.contains(cat);
        return GestureDetector(
          onTap: () => onToggle(cat),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? kOrange : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: isSelected ? kOrange : kMuted,
                  width: isSelected ? 2 : 1),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: kOrange.withValues(alpha: 0.2),
                          blurRadius: 6)
                    ]
                  : [],
            ),
            child: Text(cat,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: isSelected ? Colors.white : kDark)),
          ),
        );
      }).toList(),
    );
  }
}

class _Option {
  final String label;
  final String description;
  final IconData icon;
  final String value;

  const _Option(this.label, this.description, this.icon, this.value);
}
