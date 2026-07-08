import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getHebrewErrorMessage(String errorCode) {
    switch (errorCode) {
      case 'invalid-email':
        return 'כתובת האימייל אינה תקינה.';
      case 'user-disabled':
        return 'משתמש זה נחסם על ידי מנהל המערכת.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'שם המשתמש או הסיסמה שגויים.';
      case 'email-already-in-use':
        return 'כתובת האימייל הזו כבר רשומה במערכת.';
      case 'weak-password':
        return 'הסיסמה חלשה מדי. אנא בחר סיסמה עם לפחות 6 תווים.';
      case 'network-request-failed':
        return 'בעיית תקשורת. אנא בדוק את החיבור לאינטרנט.';
      default:
        return 'אירעה שגיאה בתהליך. אנא נסה שוב.';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      if (_isLogin) {
        // התחברות
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseAnalytics.instance.logLogin(loginMethod: 'email');
      } else {
        // הרשמה
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        await FirebaseAnalytics.instance.logSignUp(signUpMethod: 'email');
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _errorMessage = _getHebrewErrorMessage(e.code);
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'אירעה שגיאה בלתי צפויה. נסה שנית.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFBF8F3),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // לוגו או סמל עליון
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF5EFEB),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.menu_book,
                          size: 64,
                          color: Color(0xFF8C6D58),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isLogin ? "כניסה לסידור אונליין" : "הרשמה לסידור אונליין",
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4A3B32),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "התחבר כדי לגשת לסידורים ולתהילים שלך מכל מקום",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      
                      // כרטיס הטופס
                      Card(
                        color: Colors.white,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: Color(0xFFE6DFD5), width: 1),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              // שדה אימייל
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: 'אימייל',
                                  labelStyle: const TextStyle(color: Color(0xFF4A3B32)),
                                  prefixIcon: const Icon(Icons.email, color: Color(0xFF8C6D58)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF8C6D58), width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'אנא הזן כתובת אימייל';
                                  }
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                                    return 'כתובת אימייל לא תקינה';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              
                              // שדה סיסמה
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                decoration: InputDecoration(
                                  labelText: 'סיסמה',
                                  labelStyle: const TextStyle(color: Color(0xFF4A3B32)),
                                  prefixIcon: const Icon(Icons.lock, color: Color(0xFF8C6D58)),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(color: Color(0xFF8C6D58), width: 2),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'אנא הזן סיסמה';
                                  }
                                  if (value.length < 6) {
                                    return 'הסיסמה חייבת להכיל לפחות 6 תווים';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      if (_errorMessage.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red.shade200, width: 1),
                          ),
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.bold, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // כפתור התחברות/הרשמה
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8C6D58),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 3,
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(
                                _isLogin ? "התחברות" : "הרשמה מהירה",
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                      const SizedBox(height: 16),
                      
                      // כפתור מעבר בין התחברות להרשמה
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8C6D58),
                        ),
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            _errorMessage = '';
                          });
                        },
                        child: Text(
                          _isLogin
                              ? "אין לך חשבון? הרשם עכשיו"
                              : "כבר רשום? לחץ כאן להתחברות",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
