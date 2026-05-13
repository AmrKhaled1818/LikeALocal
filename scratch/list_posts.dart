import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:like_a_local/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  
  final db = FirebaseFirestore.instance;
  final snap = await db.collection('posts').get();
  
  print('--- POST LIST START ---');
  for (final doc in snap.docs) {
    final data = doc.data();
    print('ID: ${doc.id} | Title: ${data['title']} | Cat: ${data['category']} | Loc: ${data['location']}');
  }
  print('--- POST LIST END ---');
}
