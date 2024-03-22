import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qrcode/menu.dart';
import 'package:get_storage/get_storage.dart';

class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TextEditingController _emailController = TextEditingController();
  TextEditingController _usernameController = TextEditingController();
  TextEditingController _passwordController = TextEditingController();
  TextEditingController _confirmPasswordController = TextEditingController();

  String _errorMessage = '';
  Future<void> _register() async {
    try {
      String email = _emailController.text.trim();
      String username = _usernameController.text.trim();
      String password = _passwordController.text.trim();
      String confirmPassword = _confirmPasswordController.text.trim();
      GetStorage().write('isLoggedIn', true);

      if (email.isEmpty ||
          username.isEmpty ||
          password.isEmpty ||
          confirmPassword.isEmpty) {
        setState(() {
          _errorMessage = 'Preencha todos os campos';
        });
        return;
      }

      if (password != confirmPassword) {
        setState(() {
          _errorMessage = 'Senhas diferentes';
        });
        return;
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      bool usernameExists = await checkIfUsernameExists(username);
      if (usernameExists) {
        await userCredential.user?.delete();
        setState(() {
          _errorMessage = 'Nome de usuário em uso';
        });
        return;
      }

      await userCredential.user?.updateDisplayName(username);

      String userId = userCredential.user!.uid;
      Reference extratosReference =
          FirebaseStorage.instance.ref('users/$userId/extratos/');

      try {
        await extratosReference.getDownloadURL();
      } catch (e) {
        await extratosReference.putData(Uint8List(0));
      }

      await _firestore.collection('users').doc(userId).set({
        'email': email,
        'nomeUsuario': username,
        'periodo': '',
        'rendimentos': '',
        'frota': '',
        'outrasFaturas': '',
        'reciboVerdeEmitir': '',
        'reciboVerdeEmitido': '',
        'iva': '',
      });

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => Menu()),
      );

      GetStorage().write('isLoggedIn', true);
    } catch (e) {
      setState(() {
        if (e is FirebaseAuthException) {
          if (e.code == 'email-already-in-use') {
            _errorMessage = 'Email em uso';
          } else if (e.code == 'weak-password') {
            _errorMessage = 'Senha fraca';
          } else {
            _errorMessage = 'Erro ao criar conta';
          }
        } else {
          _errorMessage = e.toString();
        }
      });
    }
  }

  Future<bool> checkIfUsernameExists(String username) async {
    QuerySnapshot result = await _firestore
        .collection('users')
        .where('nomeUsuario', isEqualTo: username)
        .get();

    return result.docs.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Image.asset("images/logo.png"),
              ),
              SizedBox(height: 20),
              Form(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration: InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.email),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _usernameController,
                      decoration: InputDecoration(
                        labelText: 'Nome de usuário',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.person),
                      ),
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Senha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                    SizedBox(height: 10),
                    TextFormField(
                      controller: _confirmPasswordController,
                      decoration: InputDecoration(
                        labelText: 'Confirmar senha',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _register,
                child: Text('Registrar'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  minimumSize: Size(280, 50),
                ),
              ),
              SizedBox(height: 10),
              if (_errorMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    _errorMessage,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
