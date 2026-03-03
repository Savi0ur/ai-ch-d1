import 'package:hive/hive.dart';
import '../models/communication_profile.dart';

class CommunicationProfileService {
  static const _boxName = 'profiles';
  static const _settingsBoxName = 'settings';
  static const _activeProfileKey = 'active_profile_id';

  Box<CommunicationProfile> get _box =>
      Hive.box<CommunicationProfile>(_boxName);
  Box get _settings => Hive.box(_settingsBoxName);

  List<CommunicationProfile> getProfiles() {
    return _box.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  CommunicationProfile? getProfile(String id) {
    return _box.values.cast<CommunicationProfile?>().firstWhere(
          (p) => p?.id == id,
          orElse: () => null,
        );
  }

  void saveProfile(CommunicationProfile profile) {
    _box.put(profile.id, profile);
  }

  void deleteProfile(String id) {
    _box.delete(id);
    if (getActiveProfileId() == id) {
      setActiveProfileId(null);
    }
  }

  String? getActiveProfileId() =>
      _settings.get(_activeProfileKey) as String?;

  void setActiveProfileId(String? id) {
    if (id == null) {
      _settings.delete(_activeProfileKey);
    } else {
      _settings.put(_activeProfileKey, id);
    }
  }

  CommunicationProfile? getActiveProfile() {
    final id = getActiveProfileId();
    if (id == null) return null;
    return getProfile(id);
  }

  bool hasMemory(CommunicationProfile profile) {
    return (profile.userProfile?.isNotEmpty ?? false) ||
        (profile.userFacts?.isNotEmpty ?? false) ||
        (profile.userInstructions?.isNotEmpty ?? false) ||
        (profile.userGlossary?.isNotEmpty ?? false);
  }

  String buildProfilePrompt(CommunicationProfile profile) {
    final parts = <String>[];

    // Communication style block
    parts.add([
      '[Communication style]',
      CommunicationProfile.tonePrompts[profile.tone] ??
          CommunicationProfile.tonePrompts['neutral']!,
      CommunicationProfile.depthPrompts[profile.depth] ??
          CommunicationProfile.depthPrompts['standard']!,
      CommunicationProfile.structurePrompts[profile.structure] ??
          CommunicationProfile.structurePrompts['no_structure']!,
      CommunicationProfile.rolePrompts[profile.role] ??
          CommunicationProfile.rolePrompts['partner']!,
      CommunicationProfile.initiativePrompts[profile.initiative] ??
          CommunicationProfile.initiativePrompts['reactive']!,
    ].join('\n'));

    // Memory blocks (mirrors MemoryService.buildMemoryPrompt format)
    if (profile.userInstructions != null &&
        profile.userInstructions!.isNotEmpty) {
      parts.add('[Always-on instructions]\n${profile.userInstructions}');
    }
    if (profile.userProfile != null && profile.userProfile!.isNotEmpty) {
      parts.add('[Known user profile]\n${profile.userProfile}');
    }
    if (profile.userGlossary != null && profile.userGlossary!.isNotEmpty) {
      parts.add('[Glossary]\n${profile.userGlossary}');
    }
    if (profile.userFacts != null && profile.userFacts!.isNotEmpty) {
      parts.add('[Known user facts]\n${profile.userFacts}');
    }

    return parts.join('\n\n');
  }
}
