import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/workday.dart';
import 'client_service.dart';

class PointageService {
    Future<Map<String, String>> _headers() async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('token');
        if (token == null) throw Exception('Utilisateur non authentifié');
        return {
        "Accept": "application/json",
        "Content-Type": "application/json",
        "Authorization": "Bearer $token",
        };
    }

    Future<Workday> getToday() async {
        final response = await http.get(
        Uri.parse("${ClientService.baseUrl}/workday/today"),
        headers: await _headers(),
        );

        if (response.statusCode == 200) {
        return Workday.fromJson(jsonDecode(response.body));
        } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message']);
        }
    } 

    
    Future<List<WorkdayHistoryEntry>> getHistory() async {
        final response = await http.get(
        Uri.parse("${ClientService.baseUrl}/workday/history"),
        headers: await _headers(),
        );

        if (response.statusCode == 200) {
        final Map<String, dynamic> json = jsonDecode(response.body);
        final List<dynamic> data = json['data'];
        return data.map((e) => WorkdayHistoryEntry.fromJson(e)).toList();
        } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message']);
        }
    }

    Future<void> startWorkday() => _post('/workday/start');
    Future<void> startPause() => _post('/workday/pause/start');
    Future<void> endPause() => _post('/workday/pause/end');
    Future<void> endWorkday() => _post('/workday/end');

    Future<void> _post(String path) async {
        final response = await http.post(
        Uri.parse("${ClientService.baseUrl}$path"),
        headers: await _headers(),
        );

        if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        throw Exception(error['message']);
        }
    }


}