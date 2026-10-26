/// Phrases for a reaction that starts where you do not speak the language.
///
/// The chef card handles the calm case — handing a list of allergens to a
/// kitchen before you eat. This file handles the other one: something is going
/// wrong now, and the person who can help does not read English.
///
/// Everything here is `const` and ships in the binary. A reaction abroad is
/// exactly when there is no signal and no time, so nothing may depend on a
/// network call or a translation API.
///
/// Wording rules, which differ from the chef card on purpose:
/// - **Short, literal, imperative.** This is read aloud or pointed at by
///   someone under stress, possibly by a stranger holding the phone.
/// - **No idiom.** "I need help" survives a bad reading; "I'm in trouble" does
///   not.
/// - The medical word for epinephrine differs by region — most of Europe says
///   *adrenaline* — so each translation uses whichever term a local responder
///   would recognize, not a literal rendering of the English.
library;

/// One phrase, in English plus every shipped language.
class EmergencyPhrase {
  const EmergencyPhrase({
    required this.id,
    required this.english,
    required this.translations,
    this.urgent = false,
  });

  final String id;

  /// What the user sees when choosing, and the fallback for any language that
  /// is somehow missing a translation.
  final String english;

  /// Keyed by the same ISO 639-1 codes as `kCardLanguages`.
  final Map<String, String> translations;

  /// Phrases that belong at the top because they are what you say first.
  final bool urgent;

  /// The phrase in [code], falling back to English rather than showing nothing.
  String inLanguage(String code) => translations[code] ?? english;
}

/// Ordered most-urgent first. The order is the point: someone scrolling this
/// mid-reaction should hit the sentence that gets an ambulance before the one
/// that explains the diagnosis.
const List<EmergencyPhrase> kEmergencyPhrases = <EmergencyPhrase>[
  EmergencyPhrase(
    id: 'reaction',
    english: 'I am having a severe allergic reaction.',
    urgent: true,
    translations: <String, String>{
      'es': 'Estoy teniendo una reacción alérgica grave.',
      'fr': 'Je fais une réaction allergique grave.',
      'it': 'Sto avendo una grave reazione allergica.',
      'de': 'Ich habe eine schwere allergische Reaktion.',
      'pt': 'Estou a ter uma reação alérgica grave.',
      'nl': 'Ik heb een ernstige allergische reactie.',
      'ja': '重いアレルギー反応が出ています。',
      'zh': '我正在发生严重的过敏反应。',
      'ko': '심한 알레르기 반응이 일어나고 있습니다.',
      'th': 'ฉันกำลังมีอาการแพ้อย่างรุนแรง',
      'ar': 'أعاني من رد فعل تحسسي شديد.',
    },
  ),
  EmergencyPhrase(
    id: 'ambulance',
    english: 'Please call an ambulance.',
    urgent: true,
    translations: <String, String>{
      'es': 'Por favor, llame a una ambulancia.',
      'fr': 'Appelez une ambulance, s’il vous plaît.',
      'it': 'Per favore, chiami un’ambulanza.',
      'de': 'Bitte rufen Sie einen Krankenwagen.',
      'pt': 'Por favor, chame uma ambulância.',
      'nl': 'Bel alstublieft een ambulance.',
      'ja': '救急車を呼んでください。',
      'zh': '请叫救护车。',
      'ko': '구급차를 불러 주세요.',
      'th': 'กรุณาเรียกรถพยาบาล',
      'ar': 'من فضلك اتصل بسيارة إسعاف.',
    },
  ),
  EmergencyPhrase(
    id: 'epinephrine',
    english: 'I need my epinephrine auto-injector. It is in my bag.',
    urgent: true,
    translations: <String, String>{
      'es': 'Necesito mi autoinyector de adrenalina. Está en mi bolso.',
      'fr': 'J’ai besoin de mon auto-injecteur d’adrénaline. Il est dans mon sac.',
      'it': 'Ho bisogno del mio autoiniettore di adrenalina. È nella mia borsa.',
      'de': 'Ich brauche meinen Adrenalin-Autoinjektor. Er ist in meiner Tasche.',
      'pt': 'Preciso do meu autoinjetor de adrenalina. Está na minha mala.',
      'nl': 'Ik heb mijn adrenaline-autoinjector nodig. Die zit in mijn tas.',
      'ja': 'アドレナリン自己注射器が必要です。かばんの中にあります。',
      'zh': '我需要我的肾上腺素自动注射笔。它在我的包里。',
      'ko': '에피네프린 자동주사기가 필요합니다. 제 가방 안에 있습니다.',
      'th': 'ฉันต้องการปากกาฉีดอะดรีนาลีนของฉัน อยู่ในกระเป๋าของฉัน',
      'ar': 'أحتاج إلى حاقن الأدرينالين الخاص بي. إنه في حقيبتي.',
    },
  ),
  EmergencyPhrase(
    id: 'used_it',
    english: 'I have already used my epinephrine auto-injector.',
    urgent: true,
    translations: <String, String>{
      'es': 'Ya he usado mi autoinyector de adrenalina.',
      'fr': 'J’ai déjà utilisé mon auto-injecteur d’adrénaline.',
      'it': 'Ho già usato il mio autoiniettore di adrenalina.',
      'de': 'Ich habe meinen Adrenalin-Autoinjektor bereits benutzt.',
      'pt': 'Já usei o meu autoinjetor de adrenalina.',
      'nl': 'Ik heb mijn adrenaline-autoinjector al gebruikt.',
      'ja': 'アドレナリン自己注射器はもう使いました。',
      'zh': '我已经使用了肾上腺素自动注射笔。',
      'ko': '이미 에피네프린 자동주사기를 사용했습니다.',
      'th': 'ฉันใช้ปากกาฉีดอะดรีนาลีนไปแล้ว',
      'ar': 'لقد استخدمت بالفعل حاقن الأدرينالين الخاص بي.',
    },
  ),
  EmergencyPhrase(
    id: 'breathing',
    english: 'I am having trouble breathing.',
    urgent: true,
    translations: <String, String>{
      'es': 'Me cuesta respirar.',
      'fr': 'J’ai du mal à respirer.',
      'it': 'Ho difficoltà a respirare.',
      'de': 'Ich bekomme schlecht Luft.',
      'pt': 'Estou com dificuldade em respirar.',
      'nl': 'Ik krijg moeilijk adem.',
      'ja': '息が苦しいです。',
      'zh': '我呼吸困难。',
      'ko': '숨쉬기가 힘듭니다.',
      'th': 'ฉันหายใจลำบาก',
      'ar': 'أجد صعوبة في التنفس.',
    },
  ),
  EmergencyPhrase(
    id: 'allergic_to',
    english: 'I am allergic to:',
    translations: <String, String>{
      'es': 'Soy alérgico a:',
      'fr': 'Je suis allergique à :',
      'it': 'Sono allergico a:',
      'de': 'Ich bin allergisch gegen:',
      'pt': 'Sou alérgico a:',
      'nl': 'Ik ben allergisch voor:',
      'ja': '私は次のものにアレルギーがあります：',
      'zh': '我对以下食物过敏：',
      'ko': '저는 다음에 알레르기가 있습니다:',
      'th': 'ฉันแพ้สิ่งต่อไปนี้:',
      'ar': 'لدي حساسية من:',
    },
  ),
  EmergencyPhrase(
    id: 'ate',
    english: 'I think I ate something I am allergic to.',
    translations: <String, String>{
      'es': 'Creo que he comido algo a lo que soy alérgico.',
      'fr': 'Je pense avoir mangé quelque chose auquel je suis allergique.',
      'it': 'Penso di aver mangiato qualcosa a cui sono allergico.',
      'de': 'Ich glaube, ich habe etwas gegessen, wogegen ich allergisch bin.',
      'pt': 'Acho que comi algo a que sou alérgico.',
      'nl': 'Ik denk dat ik iets heb gegeten waar ik allergisch voor ben.',
      'ja': 'アレルギーのあるものを食べてしまったと思います。',
      'zh': '我想我吃了过敏的东西。',
      'ko': '알레르기가 있는 음식을 먹은 것 같습니다.',
      'th': 'ฉันคิดว่าฉันกินสิ่งที่ฉันแพ้เข้าไป',
      'ar': 'أعتقد أنني أكلت شيئًا لدي حساسية منه.',
    },
  ),
  EmergencyPhrase(
    id: 'hospital',
    english: 'Please take me to a hospital.',
    translations: <String, String>{
      'es': 'Por favor, lléveme a un hospital.',
      'fr': 'Emmenez-moi à l’hôpital, s’il vous plaît.',
      'it': 'Per favore, mi porti in ospedale.',
      'de': 'Bitte bringen Sie mich in ein Krankenhaus.',
      'pt': 'Por favor, leve-me a um hospital.',
      'nl': 'Breng me alstublieft naar een ziekenhuis.',
      'ja': '病院に連れて行ってください。',
      'zh': '请带我去医院。',
      'ko': '병원으로 데려가 주세요.',
      'th': 'กรุณาพาฉันไปโรงพยาบาล',
      'ar': 'من فضلك خذني إلى المستشفى.',
    },
  ),
  EmergencyPhrase(
    id: 'call_contact',
    english: 'Please call the number on this screen.',
    translations: <String, String>{
      'es': 'Por favor, llame al número que aparece en esta pantalla.',
      'fr': 'Appelez le numéro affiché sur cet écran, s’il vous plaît.',
      'it': 'Per favore, chiami il numero su questo schermo.',
      'de': 'Bitte rufen Sie die Nummer auf diesem Bildschirm an.',
      'pt': 'Por favor, ligue para o número neste ecrã.',
      'nl': 'Bel alstublieft het nummer op dit scherm.',
      'ja': 'この画面の番号に電話してください。',
      'zh': '请拨打此屏幕上的号码。',
      'ko': '이 화면에 있는 번호로 전화해 주세요.',
      'th': 'กรุณาโทรหาหมายเลขบนหน้าจอนี้',
      'ar': 'من فضلك اتصل بالرقم الظاهر على هذه الشاشة.',
    },
  ),
  EmergencyPhrase(
    id: 'no_food',
    english: 'Please do not give me any food or drink.',
    translations: <String, String>{
      'es': 'Por favor, no me dé ninguna comida ni bebida.',
      'fr': 'Ne me donnez ni nourriture ni boisson, s’il vous plaît.',
      'it': 'Per favore, non mi dia cibo né bevande.',
      'de': 'Bitte geben Sie mir nichts zu essen oder zu trinken.',
      'pt': 'Por favor, não me dê comida nem bebida.',
      'nl': 'Geef me alstublieft geen eten of drinken.',
      'ja': '食べ物や飲み物は与えないでください。',
      'zh': '请不要给我任何食物或饮料。',
      'ko': '음식이나 음료를 주지 마세요.',
      'th': 'กรุณาอย่าให้อาหารหรือเครื่องดื่มแก่ฉัน',
      'ar': 'من فضلك لا تعطني أي طعام أو شراب.',
    },
  ),
];

/// Headings for the phrase screen itself, so the page a stranger is handed is
/// not half in English.
class PhraseScreenStrings {
  const PhraseScreenStrings({
    required this.title,
    required this.showToLabel,
    required this.urgentLabel,
    required this.otherLabel,
  });

  final String title;
  final String showToLabel;
  final String urgentLabel;
  final String otherLabel;
}

const Map<String, PhraseScreenStrings> kPhraseScreenStrings =
    <String, PhraseScreenStrings>{
  'en': PhraseScreenStrings(
    title: 'Emergency phrases',
    showToLabel: 'Show this to someone who can help',
    urgentLabel: 'Say these first',
    otherLabel: 'Also useful',
  ),
  'es': PhraseScreenStrings(
    title: 'Frases de emergencia',
    showToLabel: 'Muestre esto a alguien que pueda ayudar',
    urgentLabel: 'Diga esto primero',
    otherLabel: 'También útil',
  ),
  'fr': PhraseScreenStrings(
    title: 'Phrases d’urgence',
    showToLabel: 'Montrez ceci à quelqu’un qui peut aider',
    urgentLabel: 'Dites ceci en premier',
    otherLabel: 'Également utile',
  ),
  'it': PhraseScreenStrings(
    title: 'Frasi di emergenza',
    showToLabel: 'Mostri questo a qualcuno che può aiutare',
    urgentLabel: 'Dica prima questo',
    otherLabel: 'Anche utile',
  ),
  'de': PhraseScreenStrings(
    title: 'Notfallsätze',
    showToLabel: 'Zeigen Sie das jemandem, der helfen kann',
    urgentLabel: 'Sagen Sie das zuerst',
    otherLabel: 'Ebenfalls nützlich',
  ),
  'pt': PhraseScreenStrings(
    title: 'Frases de emergência',
    showToLabel: 'Mostre isto a alguém que possa ajudar',
    urgentLabel: 'Diga isto primeiro',
    otherLabel: 'Também útil',
  ),
  'nl': PhraseScreenStrings(
    title: 'Noodzinnen',
    showToLabel: 'Laat dit zien aan iemand die kan helpen',
    urgentLabel: 'Zeg dit eerst',
    otherLabel: 'Ook nuttig',
  ),
  'ja': PhraseScreenStrings(
    title: '緊急時のフレーズ',
    showToLabel: '助けてくれる人にこれを見せてください',
    urgentLabel: 'まずこれを伝えてください',
    otherLabel: 'その他',
  ),
  'zh': PhraseScreenStrings(
    title: '紧急用语',
    showToLabel: '请把这个给能帮忙的人看',
    urgentLabel: '请先说这些',
    otherLabel: '其他有用的话',
  ),
  'ko': PhraseScreenStrings(
    title: '긴급 문구',
    showToLabel: '도와줄 수 있는 사람에게 보여주세요',
    urgentLabel: '먼저 말하세요',
    otherLabel: '그 밖에 유용한 말',
  ),
  'th': PhraseScreenStrings(
    title: 'ประโยคฉุกเฉิน',
    showToLabel: 'แสดงสิ่งนี้แก่ผู้ที่สามารถช่วยได้',
    urgentLabel: 'พูดสิ่งนี้ก่อน',
    otherLabel: 'มีประโยชน์เช่นกัน',
  ),
  'ar': PhraseScreenStrings(
    title: 'عبارات الطوارئ',
    showToLabel: 'أظهر هذا لشخص يمكنه المساعدة',
    urgentLabel: 'قل هذا أولاً',
    otherLabel: 'مفيد أيضًا',
  ),
};

/// Prefilled texts for messaging an emergency contact.
///
/// These are written to be read on a lock screen by someone who may be driving
/// or at work: what is happening, what has been done, and what is wanted, in
/// that order. The app never sends them — it opens Messages with the text
/// ready, and the user presses send.
class ContactMessageTemplate {
  const ContactMessageTemplate({
    required this.id,
    required this.label,
    required this.body,
    this.severe = false,
  });

  final String id;

  /// The button the user taps.
  final String label;

  /// `{name}` is replaced with the profile name, if there is one.
  final String body;

  /// Shown in the alarming color and listed first.
  final bool severe;
}

const List<ContactMessageTemplate> kContactMessages = <ContactMessageTemplate>[
  ContactMessageTemplate(
    id: 'used_epi',
    label: 'Used my auto-injector',
    severe: true,
    body:
        '{name} here. I am having an allergic reaction and I have used my '
        'epinephrine auto-injector. Emergency services have been called. '
        'Please call me.',
  ),
  ContactMessageTemplate(
    id: 'reaction_now',
    label: 'Having a reaction',
    severe: true,
    body:
        '{name} here. I am having an allergic reaction right now and may need '
        'help. Please call me.',
  ),
  ContactMessageTemplate(
    id: 'not_sure',
    label: 'Might be reacting',
    body:
        '{name} here. I think I might be reacting to something I ate. I am '
        'watching it and I have my auto-injector with me.',
  ),
  ContactMessageTemplate(
    id: 'im_ok',
    label: "I'm okay now",
    body:
        '{name} here. The reaction has settled and I am okay. I wanted you to '
        'know before you heard it from someone else.',
  ),
];

/// Puts the sender's name into a template body.
///
/// The default profile is called "Me", which would render as "Me here." — so
/// when the name is missing or still the placeholder, the lead sentence is
/// dropped rather than printed wrong. A message that reads oddly is a message
/// the reader stops to parse, and this one is read in a hurry.
String fillContactMessage(String body, String senderName) {
  final name = senderName.trim();
  if (name.isNotEmpty && name.toLowerCase() != 'me') {
    return body.replaceAll('{name}', name);
  }
  return body.replaceAll('{name} here. ', '').replaceAll('{name}', 'I');
}
