import '../models/allergen.dart';

/// Chef card translations — hard-coded, shipped in the binary, no network.
///
/// The one serious translation-card product in this category gates its languages
/// behind a subscription and is reported to fail with no connection — which is
/// precisely the condition travel imposes. Everything here is a `const`, so a
/// card renders identically on a plane, in a basement restaurant, or abroad on a
/// dead SIM.
///
/// Wording notes:
/// - Each allergen name leads with the term a kitchen would actually recognise and,
///   where the category is broad (tree nuts, crustaceans, molluscs), follows it with
///   two or three concrete examples in brackets. A chef who does not know the word
///   "molluscs" knows "mussels, squid, octopus".
/// - The register is polite-formal throughout (usted / vous / Sie / 敬語 / 존댓말).
///   This card is handed to a stranger who is being asked for a favour.
/// - No exclamation marks anywhere. This is a safety document, not a plea.
class CardLanguage {
  const CardLanguage({
    required this.code,
    required this.english,
    required this.native,
    required this.flag,
    this.rtl = false,
  });

  /// ISO 639-1 code, used as the key into [kAllergenTranslations] and [kCardStrings].
  final String code;

  /// The language's name in English, for the user choosing it.
  final String english;

  /// The language's name in itself, for the person reading the card.
  final String native;

  final String flag;

  /// True for right-to-left scripts. The UI must set `TextDirection.rtl` for these.
  final bool rtl;
}

/// The twelve languages the card ships in.
const List<CardLanguage> kCardLanguages = [
  CardLanguage(code: 'en', english: 'English', native: 'English', flag: '🇬🇧'),
  CardLanguage(code: 'es', english: 'Spanish', native: 'Español', flag: '🇪🇸'),
  CardLanguage(code: 'fr', english: 'French', native: 'Français', flag: '🇫🇷'),
  CardLanguage(code: 'it', english: 'Italian', native: 'Italiano', flag: '🇮🇹'),
  CardLanguage(code: 'de', english: 'German', native: 'Deutsch', flag: '🇩🇪'),
  CardLanguage(
    code: 'pt',
    english: 'Portuguese',
    native: 'Português',
    flag: '🇵🇹',
  ),
  CardLanguage(code: 'nl', english: 'Dutch', native: 'Nederlands', flag: '🇳🇱'),
  CardLanguage(code: 'ja', english: 'Japanese', native: '日本語', flag: '🇯🇵'),
  CardLanguage(code: 'zh', english: 'Chinese', native: '简体中文', flag: '🇨🇳'),
  CardLanguage(code: 'ko', english: 'Korean', native: '한국어', flag: '🇰🇷'),
  CardLanguage(code: 'th', english: 'Thai', native: 'ไทย', flag: '🇹🇭'),
  CardLanguage(
    code: 'ar',
    english: 'Arabic',
    native: 'العربية',
    flag: '🇸🇦',
    rtl: true,
  ),
];

/// The sentence frames around the allergen list.
class ChefCardStrings {
  const ChefCardStrings({
    required this.heading,
    required this.leadIn,
    required this.crossContact,
    required this.consequence,
    required this.thanks,
    required this.severityLabels,
    required this.noteLabel,
  });

  /// "I have a severe food allergy"
  final String heading;

  /// "I cannot eat any food containing:"
  final String leadIn;

  /// The cross-contact request — the part no menu translation app covers.
  final String crossContact;

  /// "Even a very small amount can make me seriously ill."
  final String consequence;

  final String thanks;

  /// The strictness word shown against the list, keyed by [Severity].
  final Map<Severity, String> severityLabels;

  /// Heading for the profile's free-text note.
  final String noteLabel;
}

const ChefCardStrings _english = ChefCardStrings(
  heading: 'I have a severe food allergy',
  leadIn: 'I cannot eat any food containing:',
  crossContact:
      'Please make sure my food does not touch these ingredients, and that '
      'clean utensils, pans and surfaces are used.',
  consequence: 'Even a very small amount can make me seriously ill.',
  thanks: 'Thank you very much for your help.',
  severityLabels: {
    Severity.severe: 'Severe — risk of anaphylaxis',
    Severity.intolerance: 'Intolerance',
    Severity.preference: 'Avoiding by choice',
  },
  noteLabel: 'Note',
);

const Map<String, ChefCardStrings> kCardStrings = {
  'en': _english,

  'es': ChefCardStrings(
    heading: 'Tengo una alergia alimentaria grave',
    leadIn: 'No puedo comer ningún alimento que contenga:',
    crossContact:
        'Por favor, asegúrese de que mi comida no entre en contacto con estos '
        'ingredientes y de que se utilicen utensilios, sartenes y superficies '
        'limpios.',
    consequence:
        'Incluso una cantidad muy pequeña puede ponerme gravemente enfermo.',
    thanks: 'Muchas gracias por su ayuda.',
    severityLabels: {
      Severity.severe: 'Grave — riesgo de anafilaxia',
      Severity.intolerance: 'Intolerancia',
      Severity.preference: 'Lo evito por elección',
    },
    noteLabel: 'Nota',
  ),

  'fr': ChefCardStrings(
    heading: 'J’ai une allergie alimentaire grave',
    leadIn: 'Je ne peux manger aucun aliment contenant :',
    crossContact:
        'Merci de veiller à ce que mon plat n’entre pas en contact avec ces '
        'ingrédients, et à ce que des ustensiles, des poêles et des surfaces '
        'propres soient utilisés.',
    consequence:
        'Même une très petite quantité peut me rendre gravement malade.',
    thanks: 'Merci beaucoup de votre aide.',
    severityLabels: {
      Severity.severe: 'Grave — risque d’anaphylaxie',
      Severity.intolerance: 'Intolérance',
      Severity.preference: 'Évité par choix',
    },
    noteLabel: 'Remarque',
  ),

  'it': ChefCardStrings(
    heading: 'Ho una grave allergia alimentare',
    leadIn: 'Non posso mangiare alcun alimento che contenga:',
    crossContact:
        'Per favore, si assicuri che il mio cibo non venga a contatto con '
        'questi ingredienti e che vengano usati utensili, padelle e superfici '
        'puliti.',
    consequence:
        'Anche una quantità molto piccola può farmi stare gravemente male.',
    thanks: 'Grazie mille per il suo aiuto.',
    severityLabels: {
      Severity.severe: 'Grave — rischio di anafilassi',
      Severity.intolerance: 'Intolleranza',
      Severity.preference: 'Evitato per scelta',
    },
    noteLabel: 'Nota',
  ),

  'de': ChefCardStrings(
    heading: 'Ich habe eine schwere Lebensmittelallergie',
    leadIn: 'Ich darf keine Speisen essen, die Folgendes enthalten:',
    crossContact:
        'Bitte achten Sie darauf, dass mein Essen nicht mit diesen Zutaten in '
        'Berührung kommt und dass sauberes Besteck, saubere Pfannen und saubere '
        'Arbeitsflächen verwendet werden.',
    consequence:
        'Schon eine sehr kleine Menge kann mich schwer krank machen.',
    thanks: 'Vielen Dank für Ihre Hilfe.',
    severityLabels: {
      Severity.severe: 'Schwer — Gefahr eines anaphylaktischen Schocks',
      Severity.intolerance: 'Unverträglichkeit',
      Severity.preference: 'Wird bewusst gemieden',
    },
    noteLabel: 'Hinweis',
  ),

  'pt': ChefCardStrings(
    heading: 'Tenho uma alergia alimentar grave',
    leadIn: 'Não posso comer nenhum alimento que contenha:',
    crossContact:
        'Por favor, certifique-se de que a minha comida não toca nestes '
        'ingredientes e de que são usados utensílios, panelas e superfícies '
        'limpos.',
    consequence:
        'Mesmo uma quantidade muito pequena pode deixar-me gravemente doente.',
    thanks: 'Muito obrigado pela sua ajuda.',
    severityLabels: {
      Severity.severe: 'Grave — risco de anafilaxia',
      Severity.intolerance: 'Intolerância',
      Severity.preference: 'Evito por opção',
    },
    noteLabel: 'Nota',
  ),

  'nl': ChefCardStrings(
    heading: 'Ik heb een ernstige voedselallergie',
    leadIn: 'Ik kan geen voedsel eten dat het volgende bevat:',
    crossContact:
        'Zorg er alstublieft voor dat mijn eten niet in aanraking komt met deze '
        'ingrediënten en dat er schoon keukengerei, schone pannen en schone '
        'werkbladen worden gebruikt.',
    consequence:
        'Zelfs een heel kleine hoeveelheid kan mij ernstig ziek maken.',
    thanks: 'Hartelijk dank voor uw hulp.',
    severityLabels: {
      Severity.severe: 'Ernstig — risico op anafylaxie',
      Severity.intolerance: 'Intolerantie',
      Severity.preference: 'Vermijd ik bewust',
    },
    noteLabel: 'Opmerking',
  ),

  'ja': ChefCardStrings(
    heading: '重い食物アレルギーがあります',
    leadIn: '以下の食材が入っている料理は一切食べられません。',
    crossContact:
        '調理の際、これらの食材が私の料理に触れないようにし、清潔な調理器具・鍋・調理台をお使いください。',
    consequence: 'ごく少量でも重い症状を起こすことがあります。',
    thanks: 'ご協力いただきありがとうございます。',
    severityLabels: {
      Severity.severe: '重度 — アナフィラキシーの危険があります',
      Severity.intolerance: '不耐症',
      Severity.preference: '避けています',
    },
    noteLabel: '備考',
  ),

  'zh': ChefCardStrings(
    heading: '我有严重的食物过敏',
    leadIn: '我不能吃任何含有以下成分的食物：',
    crossContact: '请确保我的食物不会接触到这些成分，并使用干净的餐具、锅具和台面。',
    consequence: '即使极少量也可能让我病得很严重。',
    thanks: '非常感谢您的帮助。',
    severityLabels: {
      Severity.severe: '严重 — 有过敏性休克的风险',
      Severity.intolerance: '不耐受',
      Severity.preference: '主动忌口',
    },
    noteLabel: '备注',
  ),

  'ko': ChefCardStrings(
    heading: '저는 심한 음식 알레르기가 있습니다',
    leadIn: '다음 재료가 들어간 음식은 전혀 먹을 수 없습니다:',
    crossContact:
        '제 음식이 이 재료들과 닿지 않도록 해 주시고, 깨끗한 조리 도구와 팬, 조리대를 사용해 주세요.',
    consequence: '아주 적은 양이라도 심각한 증상이 나타날 수 있습니다.',
    thanks: '도와주셔서 진심으로 감사합니다.',
    severityLabels: {
      Severity.severe: '중증 — 아나필락시스 위험',
      Severity.intolerance: '불내증',
      Severity.preference: '스스로 피하는 음식',
    },
    noteLabel: '참고',
  ),

  'th': ChefCardStrings(
    heading: 'ฉันแพ้อาหารอย่างรุนแรง',
    leadIn: 'ฉันไม่สามารถกินอาหารที่มีส่วนผสมต่อไปนี้ได้เลย:',
    crossContact:
        'กรุณาอย่าให้อาหารของฉันสัมผัสกับส่วนผสมเหล่านี้ '
        'และโปรดใช้ภาชนะ กระทะ และพื้นที่ปรุงอาหารที่สะอาด',
    consequence: 'แม้เพียงปริมาณเล็กน้อยก็อาจทำให้ฉันป่วยหนักได้',
    thanks: 'ขอบคุณมากสำหรับความช่วยเหลือ',
    severityLabels: {
      Severity.severe: 'รุนแรง — เสี่ยงต่ออาการแพ้รุนแรงเฉียบพลัน',
      Severity.intolerance: 'ย่อยไม่ได้ / ไม่ทนต่ออาหาร',
      Severity.preference: 'หลีกเลี่ยงโดยสมัครใจ',
    },
    noteLabel: 'หมายเหตุ',
  ),

  'ar': ChefCardStrings(
    heading: 'لدي حساسية غذائية شديدة',
    leadIn: 'لا أستطيع تناول أي طعام يحتوي على:',
    crossContact:
        'يرجى التأكد من أن طعامي لا يلامس هذه المكونات، ومن استخدام أدوات '
        'ومقالٍ وأسطح نظيفة.',
    consequence: 'حتى كمية صغيرة جدًا قد تسبب لي مرضًا خطيرًا.',
    thanks: 'شكرًا جزيلًا على مساعدتكم.',
    severityLabels: {
      Severity.severe: 'شديدة — خطر حدوث صدمة تحسسية',
      Severity.intolerance: 'عدم تحمّل',
      Severity.preference: 'أتجنبه باختياري',
    },
    noteLabel: 'ملاحظة',
  ),
};

/// Every [Allergen] in every language. Keyed by language code, then allergen.
const Map<String, Map<Allergen, String>> kAllergenTranslations = {
  'en': {
    Allergen.milk: 'Milk and dairy',
    Allergen.egg: 'Egg',
    Allergen.peanut: 'Peanut',
    Allergen.treeNut: 'Tree nuts (walnut, almond, hazelnut)',
    Allergen.soy: 'Soy',
    Allergen.wheat: 'Wheat and gluten',
    Allergen.fish: 'Fish',
    Allergen.shellfish: 'Crustaceans (prawn, crab, lobster)',
    Allergen.sesame: 'Sesame',
    Allergen.mollusc: 'Mollusks (mussel, squid, octopus)',
    Allergen.celery: 'Celery',
    Allergen.mustard: 'Mustard',
    Allergen.lupin: 'Lupin',
    Allergen.sulphite: 'Sulfites (sulfur dioxide)',
  },

  'es': {
    Allergen.milk: 'Leche y productos lácteos',
    Allergen.egg: 'Huevo',
    Allergen.peanut: 'Cacahuete (maní)',
    Allergen.treeNut: 'Frutos secos de cáscara (nuez, almendra, avellana)',
    Allergen.soy: 'Soja',
    Allergen.wheat: 'Trigo y gluten',
    Allergen.fish: 'Pescado',
    Allergen.shellfish: 'Crustáceos (gamba, cangrejo, langosta)',
    Allergen.sesame: 'Sésamo (ajonjolí)',
    Allergen.mollusc: 'Moluscos (mejillón, calamar, pulpo)',
    Allergen.celery: 'Apio',
    Allergen.mustard: 'Mostaza',
    Allergen.lupin: 'Altramuz (lupino)',
    Allergen.sulphite: 'Sulfitos (dióxido de azufre)',
  },

  'fr': {
    Allergen.milk: 'Lait et produits laitiers',
    Allergen.egg: 'Œuf',
    Allergen.peanut: 'Arachide (cacahuète)',
    Allergen.treeNut: 'Fruits à coque (noix, amande, noisette)',
    Allergen.soy: 'Soja',
    Allergen.wheat: 'Blé et gluten',
    Allergen.fish: 'Poisson',
    Allergen.shellfish: 'Crustacés (crevette, crabe, homard)',
    Allergen.sesame: 'Sésame',
    Allergen.mollusc: 'Mollusques (moule, calamar, poulpe)',
    Allergen.celery: 'Céleri',
    Allergen.mustard: 'Moutarde',
    Allergen.lupin: 'Lupin',
    Allergen.sulphite: 'Sulfites (dioxyde de soufre)',
  },

  'it': {
    Allergen.milk: 'Latte e latticini',
    Allergen.egg: 'Uova',
    Allergen.peanut: 'Arachidi',
    Allergen.treeNut: 'Frutta a guscio (noci, mandorle, nocciole)',
    Allergen.soy: 'Soia',
    Allergen.wheat: 'Grano e glutine',
    Allergen.fish: 'Pesce',
    Allergen.shellfish: 'Crostacei (gamberi, granchio, aragosta)',
    Allergen.sesame: 'Sesamo',
    Allergen.mollusc: 'Molluschi (cozze, calamari, polpo)',
    Allergen.celery: 'Sedano',
    Allergen.mustard: 'Senape',
    Allergen.lupin: 'Lupini',
    Allergen.sulphite: 'Solfiti (anidride solforosa)',
  },

  'de': {
    Allergen.milk: 'Milch und Milchprodukte',
    Allergen.egg: 'Ei',
    Allergen.peanut: 'Erdnuss',
    Allergen.treeNut: 'Schalenfrüchte / Nüsse (Walnuss, Mandel, Haselnuss)',
    Allergen.soy: 'Soja',
    Allergen.wheat: 'Weizen und Gluten',
    Allergen.fish: 'Fisch',
    Allergen.shellfish: 'Krebstiere (Garnele, Krabbe, Hummer)',
    Allergen.sesame: 'Sesam',
    Allergen.mollusc: 'Weichtiere (Muschel, Tintenfisch, Krake)',
    Allergen.celery: 'Sellerie',
    Allergen.mustard: 'Senf',
    Allergen.lupin: 'Lupine',
    Allergen.sulphite: 'Sulfite (Schwefeldioxid)',
  },

  'pt': {
    Allergen.milk: 'Leite e lacticínios',
    Allergen.egg: 'Ovo',
    Allergen.peanut: 'Amendoim',
    Allergen.treeNut: 'Frutos de casca rija (noz, amêndoa, avelã)',
    Allergen.soy: 'Soja',
    Allergen.wheat: 'Trigo e glúten',
    Allergen.fish: 'Peixe',
    Allergen.shellfish: 'Crustáceos (camarão, caranguejo, lagosta)',
    Allergen.sesame: 'Sésamo (gergelim)',
    Allergen.mollusc: 'Moluscos (mexilhão, lula, polvo)',
    Allergen.celery: 'Aipo (salsão)',
    Allergen.mustard: 'Mostarda',
    Allergen.lupin: 'Tremoço',
    Allergen.sulphite: 'Sulfitos (dióxido de enxofre)',
  },

  'nl': {
    Allergen.milk: 'Melk en zuivel',
    Allergen.egg: 'Ei',
    Allergen.peanut: 'Pinda',
    Allergen.treeNut: 'Noten (walnoot, amandel, hazelnoot)',
    Allergen.soy: 'Soja',
    Allergen.wheat: 'Tarwe en gluten',
    Allergen.fish: 'Vis',
    Allergen.shellfish: 'Schaaldieren (garnaal, krab, kreeft)',
    Allergen.sesame: 'Sesam',
    Allergen.mollusc: 'Weekdieren (mossel, inktvis, octopus)',
    Allergen.celery: 'Selderij',
    Allergen.mustard: 'Mosterd',
    Allergen.lupin: 'Lupine',
    Allergen.sulphite: 'Sulfiet (zwaveldioxide)',
  },

  'ja': {
    Allergen.milk: '牛乳・乳製品',
    Allergen.egg: '卵',
    Allergen.peanut: 'ピーナッツ（落花生）',
    Allergen.treeNut: '木の実類（くるみ、アーモンド、ヘーゼルナッツ）',
    Allergen.soy: '大豆',
    Allergen.wheat: '小麦・グルテン',
    Allergen.fish: '魚',
    Allergen.shellfish: '甲殻類（えび、かに、ロブスター）',
    Allergen.sesame: 'ごま',
    Allergen.mollusc: '軟体動物（貝類、いか、たこ）',
    Allergen.celery: 'セロリ',
    Allergen.mustard: 'マスタード（からし）',
    Allergen.lupin: 'ルピナス豆',
    Allergen.sulphite: '亜硫酸塩（二酸化硫黄）',
  },

  'zh': {
    Allergen.milk: '牛奶及乳制品',
    Allergen.egg: '鸡蛋',
    Allergen.peanut: '花生',
    Allergen.treeNut: '坚果（核桃、杏仁、榛子）',
    Allergen.soy: '大豆',
    Allergen.wheat: '小麦及麸质',
    Allergen.fish: '鱼',
    Allergen.shellfish: '甲壳类（虾、蟹、龙虾）',
    Allergen.sesame: '芝麻',
    Allergen.mollusc: '软体动物（贝类、鱿鱼、章鱼）',
    Allergen.celery: '芹菜',
    Allergen.mustard: '芥末',
    Allergen.lupin: '羽扇豆',
    Allergen.sulphite: '亚硫酸盐（二氧化硫）',
  },

  'ko': {
    Allergen.milk: '우유 및 유제품',
    Allergen.egg: '달걀',
    Allergen.peanut: '땅콩',
    Allergen.treeNut: '견과류 (호두, 아몬드, 헤이즐넛)',
    Allergen.soy: '대두 (콩)',
    Allergen.wheat: '밀 및 글루텐',
    Allergen.fish: '생선',
    Allergen.shellfish: '갑각류 (새우, 게, 바닷가재)',
    Allergen.sesame: '참깨',
    Allergen.mollusc: '연체동물 (조개, 오징어, 문어)',
    Allergen.celery: '셀러리',
    Allergen.mustard: '겨자',
    Allergen.lupin: '루핀콩',
    Allergen.sulphite: '아황산염 (이산화황)',
  },

  'th': {
    Allergen.milk: 'นมและผลิตภัณฑ์จากนม',
    Allergen.egg: 'ไข่',
    Allergen.peanut: 'ถั่วลิสง',
    Allergen.treeNut: 'ถั่วเปลือกแข็ง (วอลนัท อัลมอนด์ เฮเซลนัท)',
    Allergen.soy: 'ถั่วเหลือง',
    Allergen.wheat: 'ข้าวสาลีและกลูเตน',
    Allergen.fish: 'ปลา',
    Allergen.shellfish: 'สัตว์น้ำเปลือกแข็ง (กุ้ง ปู ล็อบสเตอร์)',
    Allergen.sesame: 'งา',
    Allergen.mollusc: 'หอยและปลาหมึก (หอยแมลงภู่ ปลาหมึก ปลาหมึกยักษ์)',
    Allergen.celery: 'ขึ้นฉ่ายฝรั่ง (เซเลอรี)',
    Allergen.mustard: 'มัสตาร์ด',
    Allergen.lupin: 'ถั่วลูปิน',
    Allergen.sulphite: 'ซัลไฟต์ (ซัลเฟอร์ไดออกไซด์)',
  },

  'ar': {
    Allergen.milk: 'الحليب ومنتجات الألبان',
    Allergen.egg: 'البيض',
    Allergen.peanut: 'الفول السوداني',
    Allergen.treeNut: 'المكسرات (الجوز، اللوز، البندق)',
    Allergen.soy: 'فول الصويا',
    Allergen.wheat: 'القمح والغلوتين',
    Allergen.fish: 'السمك',
    Allergen.shellfish: 'القشريات (الروبيان، السلطعون، الكركند)',
    Allergen.sesame: 'السمسم',
    Allergen.mollusc: 'الرخويات (بلح البحر، الحبار، الأخطبوط)',
    Allergen.celery: 'الكرفس',
    Allergen.mustard: 'الخردل',
    Allergen.lupin: 'الترمس',
    Allergen.sulphite: 'الكبريتيت (ثاني أكسيد الكبريت)',
  },
};

/// The language for [code], falling back to English rather than throwing.
CardLanguage cardLanguageFor(String code) {
  for (final l in kCardLanguages) {
    if (l.code == code) return l;
  }
  return kCardLanguages.first;
}

/// The sentence frames for [code], falling back to English.
ChefCardStrings cardStringsFor(String code) => kCardStrings[code] ?? _english;

/// [a] translated into [code]. Falls back to the English label, never to a blank.
String allergenNameIn(String code, Allergen a) =>
    kAllergenTranslations[code]?[a] ?? a.label;

