import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_response.dart';
import 'client_service.dart';


class AuthService {
      
  Future<LoginResponse> login(
      String email,
      String password
  ) async {
    final response = await http.post(
      Uri.parse("${ClientService.baseUrl}/auth/login"),
      headers: {
        "Accept":"application/json",
        "Content-Type":"application/json",
      },

      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );


    if(response.statusCode == 200){
      final json = jsonDecode(response.body);
      final loginResponse =
          LoginResponse.fromJson(json);
      // sauvegarde token + id utilisateur (nécessaire pour distinguer "mes
      // messages" des messages des autres dans le chat)
      final prefs =
          await SharedPreferences.getInstance();
      await prefs.setString(
          "token",
          loginResponse.token
      );
      await prefs.setInt(
          "user_id",
          loginResponse.user.id
      );
      return loginResponse;
    }else{
      final error =
          jsonDecode(response.body);
      throw Exception(
          error['message']
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token != null) {
      try {
        await http.post(
          Uri.parse("${ClientService.baseUrl}/auth/logout"),
          headers: {
            "Accept": "application/json",
            "Authorization": "Bearer $token",
          },
        );
      } catch (_) {
        // Si l'appel réseau échoue, on efface quand même la session locale.
      }
    }
    await prefs.remove('token');
    await prefs.remove('user_id');
  }

}