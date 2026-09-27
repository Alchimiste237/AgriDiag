import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/config/app_theme.dart';
import '../../core/widgets/foliage_backdrop.dart';
import '../../l10n/app_strings.dart';
import '../../core/services/settings_service.dart';

/// Onboarding — the AgroDiag interface artwork ("AgroDiag Mobile App
/// Interface.png") fills the hero screen as the background; the glowing logo,
/// wordmark and tagline are part of the image. The only live element is the
/// "Get Started" button, which opens the farmer profile form (same fields,
/// same validation, same submission logic as before).
///
/// Collects the farmer's name, phone, village, preferred language and
/// data-sharing consent, and generates a Farmer ID. Everything is stored
/// locally and works offline.
///
/// The language toggle previews the selection live: the whole screen
/// re-renders in French/English as the user taps, and the choice is
/// persisted on "Get Started".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _OnboardingStage { hero, form }

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _villageController = TextEditingController();
  bool _consent = false;
  String _language = 'en';
  _OnboardingStage _stage = _OnboardingStage.hero;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      final strings = AppStrings.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(strings.consentRequired)));
      return;
    }
    context.read<SettingsService>().completeOnboarding(
          name: _nameController.text,
          phone: _phoneController.text,
          village: _villageController.text,
          language: _language,
          consent: _consent,
        );
    // _RootRouter in app.dart watches SettingsService and flips to Home
    // automatically once onboarding is complete.
  }

  @override
  Widget build(BuildContext context) {
    // Preview the pending selection live; persisted on submit.
    final strings = _language == 'fr' ? AppStrings.french : AppStrings.english;

    return Scaffold(
      backgroundColor: AppColors.deepGreenDark,
      body: _stage == _OnboardingStage.hero
          ? _buildHero(strings)
          : _buildForm(strings),
    );
  }

  // ---------------------------------------------------------------------
  // Stage 1 — hero welcome (matches the left phone in newDesign.png)
  // ---------------------------------------------------------------------
  Widget _buildHero(AppStrings strings) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Interface artwork: sky/foliage, glowing logo, "AgroDiag" wordmark
        // and tagline are baked into the image. BoxFit.cover, top-aligned so
        // any crop trims the empty dark panel at the bottom, never the
        // artwork above it.
        Image.asset(
          'assets/images/onboarding_background.png',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (_, __, ___) => const DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.deepGreenGradient,
            ),
          ),
        ),

        // Foreground content: the only live element is the CTA.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const Spacer(flex: 9),

                // Get started — full-width pill with trailing arrow
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.greenButtonGradient,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.4),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () =>
                            setState(() => _stage = _OnboardingStage.form),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              strings.getStarted,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded,
                                color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Stage 2 — profile form (same logic as the original onboarding form)
  // ---------------------------------------------------------------------
  Widget _buildForm(AppStrings strings) {
    return Stack(
      children: [
        // Dim foliage keeps visual continuity with the hero.
        const FoliageBackdrop(),

        // Veil so form fields stay readable.
        Container(color: AppColors.deepGreenDark.withValues(alpha: 0.55)),

        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: _RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: () =>
                              setState(() => _stage = _OnboardingStage.hero),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(child: BrandMark(size: 56)),
                      const SizedBox(height: 14),
                      Text(
                        strings.welcomeTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.welcomeSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _darkFormField(
                        controller: _nameController,
                        label: strings.nameLabel,
                        hint: strings.nameHint,
                        icon: Icons.person_outline,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? strings.nameRequired
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _darkFormField(
                        controller: _phoneController,
                        label: strings.phoneLabel,
                        hint: strings.phoneHint,
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? strings.phoneRequired
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _darkFormField(
                        controller: _villageController,
                        label: strings.villageLabel,
                        hint: strings.villageHint,
                        icon: Icons.location_on_outlined,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? strings.villageRequired
                            : null,
                      ),
                      const SizedBox(height: 18),

                      // Language picker
                      Text(
                        strings.languageLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment(
                            value: 'en',
                            label: Text(strings.englishName),
                            icon: const Icon(Icons.language),
                          ),
                          ButtonSegment(
                            value: 'fr',
                            label: Text(strings.frenchName),
                            icon: const Icon(Icons.translate),
                          ),
                        ],
                        selected: {_language},
                        onSelectionChanged: (selection) {
                          setState(() => _language = selection.first);
                        },
                      ),
                      const SizedBox(height: 12),

                      // Consent — restyled as a tappable dark card.
                      GestureDetector(
                        onTap: () => setState(() => _consent = !_consent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _consent
                                  ? AppColors.green
                                  : Colors.white.withValues(alpha: 0.25),
                              width: _consent ? 1.5 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _consent
                                      ? AppColors.green
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: _consent
                                        ? AppColors.green
                                        : Colors.white.withValues(alpha: 0.5),
                                    width: 1.6,
                                  ),
                                ),
                                child: _consent
                                    ? const Icon(Icons.check_rounded,
                                        size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  strings.consentLabel,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13.5,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Auto Farmer ID note
                      Row(
                        children: [
                          const Icon(Icons.verified_outlined,
                              size: 17, color: AppColors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              strings.autoFarmerIdNote,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.65),
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Big green Get Started button
                      SizedBox(
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.greenButtonGradient,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    AppColors.green.withValues(alpha: 0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(28),
                              onTap: _submit,
                              child: Center(
                                child: Text(
                                  strings.getStarted,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _darkFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputAction textInputAction = TextInputAction.done,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.green, size: 21),
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.green, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: AppColors.severityHighText, width: 1.4),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide:
              const BorderSide(color: AppColors.severityHighText, width: 1.6),
        ),
        errorStyle: const TextStyle(color: AppColors.severityHighBg),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RoundIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(9),
          child: Icon(Icons.arrow_back_rounded,
              color: Colors.white, size: 22),
        ),
      ),
    );
  }
}
