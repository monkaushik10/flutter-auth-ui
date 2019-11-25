import 'dart:collection';
import 'dart:core';

import 'package:faui/src/09_utility/FauiUtil.dart';
import 'package:faui/src/09_utility/FbException.dart';
import 'package:faui/src/09_utility/Http.dart';
import 'package:faui/src/09_utility/HttpMethod.dart';

import 'package:uuid/uuid.dart';

import 'package:faui/FauiUser.dart';

var uuid = Uuid();

// https://firebase.google.com/docs/reference/rest/auth

/// The class performs operations with Firebase
class AuthConnector {
  static Future<void> deleteUserIfExists({
    String apiKey,
    String idToken,
  }) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: idToken, name: "idToken");

    await _sendFbApiRequest(
      apiKey: apiKey,
      action: FirebaseActions.DeleteAccount,
      content: {
        "idToken": idToken,
      },
      acceptableWordsInErrorBody: HashSet.from({FbException.UserNotFoundCode}),
    );
  }

  static Future<void> sendResetLink({
    String apiKey,
    String email,
  }) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: email, name: "email");
    await _sendFbApiRequest(
      apiKey: apiKey,
      action: FirebaseActions.SendResetLink,
      content: {
        "email": email,
        "requestType": "PASSWORD_RESET",
      },
    );
  }

  static Future registerUser(
      {String apiKey, String email, String password}) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: email, name: "email");

    await _sendFbApiRequest(
      apiKey: apiKey,
      action: FirebaseActions.RegisterUser,
      content: {
        "email": email,
        "password": password ?? uuid.v4(),
      },
    );

    await sendResetLink(apiKey: apiKey, email: email);
  }

  static Future<FauiUser> signInUser({
    String apiKey,
    String email,
    String password,
  }) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: email, name: "email");
    FauiUtil.throwIfNullOrEmpty(value: password, name: "password");

    Map<String, dynamic> response = await _sendFbApiRequest(
      apiKey: apiKey,
      action: FirebaseActions.SignIn,
      content: {
        "email": email,
        "password": password,
        "returnSecureToken": true,
      },
    );

    FauiUser user = fbResponseToUser(response);

    if (user.email == null)
      throw Exception(
          "Email is not expected to be null in Firebase response for sign in");
    if (user.userId == null)
      throw Exception(
          "UserId is not expected to be null in Firebase response for sign in");

    return user;
  }

  static Future<FauiUser> verifyToken({
    String apiKey,
    String token,
  }) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: token, name: "token");

    Map<String, dynamic> response = await _sendFbApiRequest(
      apiKey: apiKey,
      action: FirebaseActions.Verify,
      content: {
        "idToken": token,
        "returnSecureToken": true,
      },
    );

    List<dynamic> users = response['users'];
    if (users == null || users.length != 1) {
      return null;
    }

    Map<String, dynamic> fbUser = users[0];

    FauiUser user = FauiUser(
      email: fbUser['email'],
      userId: fbUser["localId"],
      token: token,
      refreshToken: null,
    );

    return user;
  }

  static FauiUser fbResponseToUser(Map<String, dynamic> response) {
    String idToken = response['idToken'] ?? response['id_token'];

    Map<String, dynamic> parsedToken = FauiUtil.parseJwt(idToken);

    var user = FauiUser(
      email: response['email'] ?? parsedToken['email'],
      userId: parsedToken["userId"] ?? parsedToken["user_id"],
      token: idToken,
      refreshToken: response['refreshToken'] ?? response['refresh_token'],
    );

    return user;
  }

  static Future<Map<String, dynamic>> _sendFbApiRequest({
    String apiKey,
    String action,
    Map<String, dynamic> content,
    HashSet<String> acceptableWordsInErrorBody,
  }) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: action, name: "action");

    Map<String, String> headers = {'Content-Type': 'application/json'};
    String url =
        "https://identitytoolkit.googleapis.com/v1/accounts:$action?key=$apiKey";

    return await Http.send(
      HttpMethod.post,
      headers,
      url,
      content,
      acceptableWordsInErrorBody,
      action,
    );
  }

  static Future<FauiUser> refreshToken({FauiUser user, String apiKey}) async {
    FauiUtil.throwIfNullOrEmpty(value: apiKey, name: "apiKey");
    FauiUtil.throwIfNullOrEmpty(value: user.refreshToken, name: "apiKey");

    Map<String, String> headers = {'Content-Type': 'application/json'};
    String url = "https://securetoken.googleapis.com/v1/token?key=$apiKey";
    Map<String, dynamic> content = {
      "grant_type": "refresh_token",
      "refresh_token": user.refreshToken,
    };

    Map<String, dynamic> response = await Http.send(
      HttpMethod.post,
      headers,
      url,
      content,
      null,
      "refresh_token",
    );

    return fbResponseToUser(response);
  }
}

//https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=[API_KEY]
//https://identitytoolkit.googleapis.com/v1/accounts:delete?key=[API_KEY]
//https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=[API_KEY]
//https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=[API_KEY]
//https://identitytoolkit.googleapis.com/v1/accounts:lookup?key=[API_KEY]
class FirebaseActions {
  static const SendResetLink = "sendOobCode";
  static const DeleteAccount = "delete";
  static const RegisterUser = "signUp";
  static const SignIn = "signInWithPassword";
  static const Verify = "lookup";
}