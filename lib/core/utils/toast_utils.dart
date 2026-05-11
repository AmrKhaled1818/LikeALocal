import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../theme/app_colors.dart';

class AppToast {
  static void success(String msg) => Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: Colors.green,
        textColor: Colors.white,
      );

  static void error(String msg) => Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: kDestructive,
        textColor: Colors.white,
      );

  static void warning(String msg) => Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: kAmber,
        textColor: Colors.white,
      );

  static void info(String msg) => Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.TOP,
        backgroundColor: kMutedFg,
        textColor: Colors.white,
      );
}
