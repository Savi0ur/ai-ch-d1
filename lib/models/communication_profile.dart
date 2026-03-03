import 'package:hive/hive.dart';

class CommunicationProfile extends HiveObject {
  String id;
  String name;
  String tone;
  String depth;
  String structure;
  String role;
  String initiative;
  DateTime updatedAt;

  // User memory fields (per-profile LTM)
  String? userProfile;      // имя, язык, предпочтения
  String? userFacts;        // JSON: профессия, проекты, интересы
  String? userInstructions; // всегда-включённые инструкции
  String? userGlossary;     // JSON: термин → определение

  CommunicationProfile({
    required this.id,
    required this.name,
    this.tone = 'neutral',
    this.depth = 'standard',
    this.structure = 'no_structure',
    this.role = 'partner',
    this.initiative = 'reactive',
    required this.updatedAt,
    this.userProfile,
    this.userFacts,
    this.userInstructions,
    this.userGlossary,
  });

  // ─── UI Labels (Russian) ──────────────────────────────────────────────────

  static const toneLabels = <String, String>{
    'neutral': 'Нейтральный',
    'friendly': 'Дружелюбный',
    'formal': 'Формальный',
    'informal': 'Неформальный',
    'motivating': 'Мотивирующий',
    'empathic': 'Эмпатичный',
    'strict': 'Строгий',
    'humorous': 'Юмористический',
  };

  static const depthLabels = <String, String>{
    'brief': 'Кратко',
    'standard': 'Стандартно',
    'detailed': 'Подробно',
    'expert': 'Экспертно',
    'eli5': 'Просто (ELI5)',
  };

  static const structureLabels = <String, String>{
    'no_structure': 'Без структуры',
    'lists': 'Списки',
    'step_by_step': 'По шагам',
    'examples': 'С примерами',
    'tables': 'Таблицы',
    'conclusions': 'Выводы',
  };

  static const roleLabels = <String, String>{
    'mentor': 'Наставник',
    'coach': 'Коуч',
    'analyst': 'Аналитик',
    'partner': 'Партнёр',
    'expert': 'Эксперт',
    'critic': 'Критик',
    'secretary': 'Секретарь',
  };

  static const initiativeLabels = <String, String>{
    'reactive': 'Реактивный',
    'proactive': 'Проактивный',
    'clarifying': 'Уточняющий',
    'minimal_questions': 'Минум вопросов',
  };

  // ─── Prompt Instructions (English) ───────────────────────────────────────

  static const tonePrompts = <String, String>{
    'neutral': 'Use a calm, neutral tone.',
    'friendly': 'Communicate warmly and supportively.',
    'formal': 'Use a formal, professional style.',
    'informal': 'Use a casual, conversational style.',
    'motivating': 'Use an inspiring, motivating tone.',
    'empathic': 'Show empathy; acknowledge feelings.',
    'strict': 'Be direct and concise; no filler.',
    'humorous': 'Include light, appropriate humor.',
  };

  static const depthPrompts = <String, String>{
    'brief': 'Keep responses short: 2–5 sentences.',
    'standard': 'Provide balanced, moderately detailed explanations.',
    'detailed': 'Give thorough explanations with reasoning and examples.',
    'expert': 'Provide expert-level depth: nuances, edge cases, references.',
    'eli5': 'Explain in simple terms as if to a complete beginner.',
  };

  static const structurePrompts = <String, String>{
    'no_structure': 'Use flowing prose without special formatting.',
    'lists': 'Use bullet lists to organize information.',
    'step_by_step': 'Break down answers into numbered steps.',
    'examples': 'Illustrate every key point with a concrete example.',
    'tables': 'Use tables when comparing or listing structured data.',
    'conclusions': 'End each response with a clear conclusion or takeaway.',
  };

  static const rolePrompts = <String, String>{
    'mentor': 'Act as a mentor: guide, teach, and encourage growth.',
    'coach': 'Act as a coach: ask questions that help the user find answers.',
    'analyst': 'Act as an analyst: focus on data, logic, and evidence.',
    'partner': 'Act as a collaborative partner: think together.',
    'expert': 'Act as a subject-matter expert: provide authoritative answers.',
    'critic': 'Act as a constructive critic: highlight weaknesses and improvements.',
    'secretary': 'Act as an assistant: be efficient, organized, and task-focused.',
  };

  static const initiativePrompts = <String, String>{
    'reactive': 'Only address what the user asks; do not add unsolicited suggestions.',
    'proactive': 'Proactively offer related tips, warnings, or next steps.',
    'clarifying': 'Ask clarifying questions when the request is ambiguous.',
    'minimal_questions': 'Minimize questions; make reasonable assumptions and proceed.',
  };
}

class CommunicationProfileAdapter extends TypeAdapter<CommunicationProfile> {
  @override
  final int typeId = 3;

  @override
  CommunicationProfile read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CommunicationProfile(
      id: fields[0] as String,
      name: fields[1] as String,
      tone: (fields[2] as String?) ?? 'neutral',
      depth: (fields[3] as String?) ?? 'standard',
      structure: (fields[4] as String?) ?? 'no_structure',
      role: (fields[5] as String?) ?? 'partner',
      initiative: (fields[6] as String?) ?? 'reactive',
      updatedAt: (fields[7] as DateTime?) ?? DateTime.now(),
      userProfile: fields[8] as String?,
      userFacts: fields[9] as String?,
      userInstructions: fields[10] as String?,
      userGlossary: fields[11] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, CommunicationProfile obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.tone)
      ..writeByte(3)
      ..write(obj.depth)
      ..writeByte(4)
      ..write(obj.structure)
      ..writeByte(5)
      ..write(obj.role)
      ..writeByte(6)
      ..write(obj.initiative)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.userProfile)
      ..writeByte(9)
      ..write(obj.userFacts)
      ..writeByte(10)
      ..write(obj.userInstructions)
      ..writeByte(11)
      ..write(obj.userGlossary);
  }
}
