import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../data/models/user_model.dart';
import '../data/services/api_service.dart';

class AuthState {
  final UserModel? user;
  final bool isLoading;
  final bool isAuthenticated;
  final String? error;

  AuthState({
    this.user,
    this.isLoading = false,
    this.isAuthenticated = false,
    this.error,
  });

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    bool? isAuthenticated,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      error: error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState());

  Future<void> checkAuth() async {
    state = state.copyWith(isLoading: true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.tokenKey);
      final userData = prefs.getString(AppConstants.userKey);

      if (token != null && userData != null) {
        final user = UserModel.fromJson(jsonDecode(userData));
        if (user.role == 'livreur') {
          state = state.copyWith(
            user: user,
            isAuthenticated: true,
            isLoading: false,
          );
        } else {
          await logout();
        }
      } else {
        state = state.copyWith(isLoading: false, isAuthenticated: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, isAuthenticated: false);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      debugPrint('[AUTH] Attempting login with email: $email');
      final response = await ApiService.instance.login(email, password);
      debugPrint('[AUTH] Login response: ${response.data}');
      final data = response.data;

      final user = UserModel.fromJson(data['user']);
      debugPrint('[AUTH] User role: ${user.role}');

      if (user.role != 'livreur') {
        state = state.copyWith(
          isLoading: false,
          error: 'هذا التطبيق مخصص للسائقين فقط',
        );
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.tokenKey, data['token']);
      await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));

      state = state.copyWith(
        user: user,
        isAuthenticated: true,
        isLoading: false,
      );

      return true;
    } on DioException catch (e) {
      debugPrint('[AUTH] DioException: ${e.type}');
      debugPrint('[AUTH] DioException message: ${e.message}');
      debugPrint('[AUTH] DioException response: ${e.response?.data}');

      String errorMessage;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.sendTimeout) {
        errorMessage = 'انتهت مهلة الاتصال - تأكد من الاتصال بالشبكة';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'فشل الاتصال بالخادم - تأكد من أنك على نفس الشبكة';
      } else if (e.response?.statusCode == 401) {
        errorMessage = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
      } else if (e.response?.statusCode == 422) {
        errorMessage = e.response?.data['message'] ?? 'بيانات غير صالحة';
      } else {
        errorMessage = 'خطأ في الاتصال: ${e.message}';
      }

      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return false;
    } catch (e) {
      debugPrint('[AUTH] Error: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'خطأ غير متوقع: $e',
      );
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.instance.logout();
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);

    state = AuthState();
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
