import 'dart:io';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;
  final _formKey = GlobalKey<FormState>();
  var _isLogin = true;
  String _userEmail = '';
  String _userName = '';
  String _userPassword = '';
  File _pickedImage;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  Future<void> _pickImage() async {
    final pickedImageFile = await ImagePicker.pickImage(
        source: ImageSource.camera, imageQuality: 50, maxWidth: 150);
    setState(() {
      _pickedImage = pickedImageFile;
    });
  }

  void _trySubmit() async {
    final isValid = _formKey.currentState.validate();
    FocusScope.of(context).unfocus();
    try {
      setState(() {
        _isLoading = true;
      });
      if (_pickedImage == null && !_isLogin) {
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text('Please pick an image'),
        ));
        return;
      }
      if (isValid) {
        _formKey.currentState.save();
        AuthResult authResult;
        if (_isLogin) {
          authResult = await _auth.signInWithEmailAndPassword(
              email: _userEmail, password: _userPassword);
        } else {
          authResult = await _auth.createUserWithEmailAndPassword(
              email: _userEmail, password: _userPassword);
          final ref = FirebaseStorage.instance
              .ref()
              .child('user_image')
              .child(authResult.user.uid + '.jpg');
          await ref.putFile(_pickedImage).onComplete;
          final url = await ref.getDownloadURL();
          await Firestore.instance
              .collection('users')
              .document(authResult.user.uid)
              .setData({
            'username': _userName,
            'email': _userEmail,
            'image_url': url
          });
        }
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } on PlatformException catch (err) {
      var message = 'Check your credentials!';
      if (err.message != null) {
        message = err.message;
        _scaffoldKey.currentState.showSnackBar(SnackBar(
          content: Text(message),
        ));
        setState(() {
          _isLoading = false;
        });
      }
    } catch (err) {
      setState(() {
        _isLoading = false;
      });
      print(err);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Theme.of(context).primaryColor,
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : buildAuthForm(),
    );
  }

  Center buildAuthForm() {
    return Center(
      child: Card(
        margin: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (!_isLogin) userImagePicker(),
                  TextFormField(
                    autocorrect: false,
                    textCapitalization: TextCapitalization.none,
                    enableSuggestions: false,
                    key: ValueKey('email'),
                    validator: (value) {
                      if (value.isEmpty || !value.contains('@')) {
                        return 'Please valid email';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(labelText: 'Email Adress'),
                    onSaved: (val) {
                      _userEmail = val.trim();
                    },
                  ),
                  if (!_isLogin)
                    TextFormField(
                      autocorrect: true,
                      textCapitalization: TextCapitalization.words,
                      key: ValueKey('username'),
                      validator: (value) {
                        if (value.isEmpty || value.length < 4) {
                          return 'too short';
                        }
                        return null;
                      },
                      onSaved: (val) {
                        _userName = val.trim();
                      },
                      decoration: InputDecoration(labelText: 'Username'),
                    ),
                  TextFormField(
                    key: ValueKey('password'),
                    validator: (value) {
                      if (value.isEmpty || value.length < 7) {
                        return 'Password must be at least 7 characters long';
                      }
                      return null;
                    },
                    onSaved: (val) {
                      _userPassword = val.trim();
                    },
                    decoration: InputDecoration(labelText: 'password'),
                    obscureText: true,
                  ),
                  SizedBox(height: 12),
                  RaisedButton(
                      onPressed: _trySubmit,
                      child: Text(_isLogin ? 'Login' : 'Signup')),
                  FlatButton(
                    textColor: Theme.of(context).primaryColor,
                    child: Text('Switch'),
                    onPressed: () {
                      setState(() {
                        _isLogin = !_isLogin;
                      });
                    },
                  )
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget userImagePicker() {
    return Column(
      children: <Widget>[
        CircleAvatar(
          radius: 50,
          backgroundImage:
              _pickedImage != null ? FileImage(_pickedImage) : null,
        ),
        FlatButton.icon(
          onPressed: _pickImage,
          icon: Icon(Icons.image),
          label: Text('Pick an image'),
          textColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }
}
