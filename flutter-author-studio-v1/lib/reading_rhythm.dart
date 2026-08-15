import 'package:shared_preferences/shared_preferences.dart';

enum ReadingRhythmPreset { compact, standard, immersive }

extension ReadingRhythmPresetData on ReadingRhythmPreset {
  String get label => switch (this) {
        ReadingRhythmPreset.compact => 'Compact',
        ReadingRhythmPreset.standard => 'Standard',
        ReadingRhythmPreset.immersive => 'Immersive',
      };

  double get fontSize => switch (this) {
        ReadingRhythmPreset.compact => 15,
        ReadingRhythmPreset.standard => 17,
        ReadingRhythmPreset.immersive => 19,
      };

  double get lineHeight => switch (this) {
        ReadingRhythmPreset.compact => 1.35,
        ReadingRhythmPreset.standard => 1.55,
        ReadingRhythmPreset.immersive => 1.8,
      };

  double get editorWidth => switch (this) {
        ReadingRhythmPreset.compact => 1100,
        ReadingRhythmPreset.standard => 880,
        ReadingRhythmPreset.immersive => 720,
      };

  double get editorPadding => switch (this) {
        ReadingRhythmPreset.compact => 14,
        ReadingRhythmPreset.standard => 22,
        ReadingRhythmPreset.immersive => 30,
      };
}

class ReadingRhythmStore {
  const ReadingRhythmStore();

  String _key(String projectId) =>
      'author_studio.project.$projectId.reading_rhythm';

  Future<ReadingRhythmPreset> load(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    final saved = preferences.getString(_key(projectId));

    return ReadingRhythmPreset.values.firstWhere(
      (preset) => preset.name == saved,
      orElse: () => ReadingRhythmPreset.standard,
    );
  }

  Future<void> save(String projectId, ReadingRhythmPreset preset) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(projectId), preset.name);
  }
}
