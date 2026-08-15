import 'package:shared_preferences/shared_preferences.dart';

class ManuscriptStore {
  const ManuscriptStore();

  static String _key(String projectId) =>
      'author_studio.manuscript.$projectId';

  Future<String> load(String projectId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getString(_key(projectId)) ?? '';
  }

  Future<void> save(String projectId, String manuscript) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_key(projectId), manuscript);
  }
}