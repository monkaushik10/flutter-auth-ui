import '../../lib/src/10_auth/auth_connector.dart';
import '../../lib/src/90_model/faui_user.dart';
import 'package:test/test.dart';

import 'package:uuid/uuid.dart';

import 'config.dart';

final _uuid = new Uuid();

class AuthUtil {
  static Future<FauiUser> signIn() async {
    final String id = _uuid.v4();
    final String email = "_test_$id@fakedomain.com";

    await AuthConnector.registerUser(
        apiKey: testDb.apiKey, email: email, password: id);

    FauiUser user = await AuthConnector.signInUser(
        apiKey: testDb.apiKey, email: email, password: id);

    expect(user.userId == null, false);
    expect(user.email, email);
    expect(user.token == null, false);

    return user;
  }

  static Future<void> deleteUser(FauiUser u) async {
    await AuthConnector.deleteUserIfExists(
        apiKey: testDb.apiKey, idToken: u.token);
  }
}
