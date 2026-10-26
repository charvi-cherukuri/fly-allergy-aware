import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// The languages the on-device translator offers, in the order a traveler is
/// likely to need them.
///
/// ML Kit's Flutter plugin exposes 59; this is the subset worth putting in a
/// list someone scrolls at a boarding gate, covering the languages spoken
/// wherever commercial aviation goes. Every code here is checked against
/// [TranslateLanguage] at startup by a test, so a typo cannot ship.
class TranslatorLanguage {
  const TranslatorLanguage({
    required this.code,
    required this.english,
    required this.native,
    required this.flag,
    this.rtl = false,
  });

  /// BCP-47, matching [TranslateLanguage.bcpCode].
  final String code;
  final String english;
  final String native;
  final String flag;
  final bool rtl;

  /// The plugin's enum value for this code, or null if the plugin does not
  /// know it. Resolved by lookup rather than a second hand-written table,
  /// because two tables of language codes is one table too many.
  TranslateLanguage? get model {
    for (final TranslateLanguage l in TranslateLanguage.values) {
      if (l.bcpCode == code) return l;
    }
    return null;
  }
}

/// English is the pivot: ML Kit translates to and from English, and any other
/// pair goes through it. It is downloaded with the first language the user
/// picks and is never offered for deletion on its own.
const String kPivotLanguage = 'en';

const List<TranslatorLanguage> kTranslatorLanguages = <TranslatorLanguage>[
  TranslatorLanguage(code: 'en', english: 'English', native: 'English', flag: '🇬🇧'),
  TranslatorLanguage(code: 'es', english: 'Spanish', native: 'Español', flag: '🇪🇸'),
  TranslatorLanguage(code: 'zh', english: 'Chinese', native: '中文', flag: '🇨🇳'),
  TranslatorLanguage(code: 'hi', english: 'Hindi', native: 'हिन्दी', flag: '🇮🇳'),
  TranslatorLanguage(code: 'ar', english: 'Arabic', native: 'العربية', flag: '🇸🇦', rtl: true),
  TranslatorLanguage(code: 'fr', english: 'French', native: 'Français', flag: '🇫🇷'),
  TranslatorLanguage(code: 'de', english: 'German', native: 'Deutsch', flag: '🇩🇪'),
  TranslatorLanguage(code: 'pt', english: 'Portuguese', native: 'Português', flag: '🇵🇹'),
  TranslatorLanguage(code: 'ru', english: 'Russian', native: 'Русский', flag: '🇷🇺'),
  TranslatorLanguage(code: 'ja', english: 'Japanese', native: '日本語', flag: '🇯🇵'),
  TranslatorLanguage(code: 'bn', english: 'Bengali', native: 'বাংলা', flag: '🇧🇩'),
  TranslatorLanguage(code: 'ur', english: 'Urdu', native: 'اردو', flag: '🇵🇰', rtl: true),
  TranslatorLanguage(code: 'id', english: 'Indonesian', native: 'Bahasa Indonesia', flag: '🇮🇩'),
  TranslatorLanguage(code: 'it', english: 'Italian', native: 'Italiano', flag: '🇮🇹'),
  TranslatorLanguage(code: 'tr', english: 'Turkish', native: 'Türkçe', flag: '🇹🇷'),
  TranslatorLanguage(code: 'ko', english: 'Korean', native: '한국어', flag: '🇰🇷'),
  TranslatorLanguage(code: 'vi', english: 'Vietnamese', native: 'Tiếng Việt', flag: '🇻🇳'),
  TranslatorLanguage(code: 'th', english: 'Thai', native: 'ไทย', flag: '🇹🇭'),
  TranslatorLanguage(code: 'ta', english: 'Tamil', native: 'தமிழ்', flag: '🇮🇳'),
  TranslatorLanguage(code: 'te', english: 'Telugu', native: 'తెలుగు', flag: '🇮🇳'),
  TranslatorLanguage(code: 'mr', english: 'Marathi', native: 'मराठी', flag: '🇮🇳'),
  TranslatorLanguage(code: 'gu', english: 'Gujarati', native: 'ગુજરાતી', flag: '🇮🇳'),
  TranslatorLanguage(code: 'kn', english: 'Kannada', native: 'ಕನ್ನಡ', flag: '🇮🇳'),
  TranslatorLanguage(code: 'fa', english: 'Persian', native: 'فارسی', flag: '🇮🇷', rtl: true),
  TranslatorLanguage(code: 'he', english: 'Hebrew', native: 'עברית', flag: '🇮🇱', rtl: true),
  TranslatorLanguage(code: 'ms', english: 'Malay', native: 'Bahasa Melayu', flag: '🇲🇾'),
  TranslatorLanguage(code: 'tl', english: 'Tagalog', native: 'Tagalog', flag: '🇵🇭'),
  TranslatorLanguage(code: 'sw', english: 'Swahili', native: 'Kiswahili', flag: '🇰🇪'),
  TranslatorLanguage(code: 'nl', english: 'Dutch', native: 'Nederlands', flag: '🇳🇱'),
  TranslatorLanguage(code: 'pl', english: 'Polish', native: 'Polski', flag: '🇵🇱'),
  TranslatorLanguage(code: 'uk', english: 'Ukrainian', native: 'Українська', flag: '🇺🇦'),
  TranslatorLanguage(code: 'el', english: 'Greek', native: 'Ελληνικά', flag: '🇬🇷'),
  TranslatorLanguage(code: 'cs', english: 'Czech', native: 'Čeština', flag: '🇨🇿'),
  TranslatorLanguage(code: 'ro', english: 'Romanian', native: 'Română', flag: '🇷🇴'),
  TranslatorLanguage(code: 'hu', english: 'Hungarian', native: 'Magyar', flag: '🇭🇺'),
  TranslatorLanguage(code: 'sv', english: 'Swedish', native: 'Svenska', flag: '🇸🇪'),
  TranslatorLanguage(code: 'da', english: 'Danish', native: 'Dansk', flag: '🇩🇰'),
  TranslatorLanguage(code: 'no', english: 'Norwegian', native: 'Norsk', flag: '🇳🇴'),
  TranslatorLanguage(code: 'fi', english: 'Finnish', native: 'Suomi', flag: '🇫🇮'),
];

/// Roughly what one language costs on disk. ML Kit does not report the real
/// size before a download, and its own guidance is "around 30 MB", so this is
/// labelled as approximate everywhere it is shown.
const int kApproxModelMegabytes = 30;

TranslatorLanguage? translatorLanguageFor(String code) {
  for (final TranslatorLanguage l in kTranslatorLanguages) {
    if (l.code == code) return l;
  }
  return null;
}
